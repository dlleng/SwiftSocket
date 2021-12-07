//
//  Client.swift
//  SwiftSocket
//
//  Created by dlleng on 2021/8/10.
//

import Foundation

enum ChannelState {
    case idle
    case connecting
    case connected
}

public class ClientChannel {
    
    private var socket: Socket?
    private var addressResolver = AddressResolver()
    private var writingBuffer = CircularBuffer<ByteBuffer>()
    private weak var observer: ChannelObserver?
    private var state: ChannelState = .idle
    private var hbConfig = HeartBeartConfig()
    private weak var connectTimer: Task?
    
    public let eventLoop: EventLoop
    
    public var localAddress: SocketAddress? {
        socket?.localAddress
    }
    
    public var remoteAddress: SocketAddress? {
        socket?.remoteAddress
    }
        
    public init(observer: ChannelObserver?) {
        self.observer = observer
        self.eventLoop = EventLoop()
        self.eventLoop.startup()
    }
    
    init(observer: ChannelObserver?, eventLoop: EventLoop, socket: Socket?) {
        self.state = .connected
        self.observer = observer
        self.eventLoop = eventLoop
        self.socket = socket
    }
    
    //userInfo use for channel(_:didWrite:userInfo:)
    public func write(data: Data, userInfo: [String: Any]? = nil) {
        eventLoop.execute {
            guard self.socket != nil else { return }
            var byteBuf = ByteBuffer(data: data)
            byteBuf.userInfo = userInfo
            self.writingBuffer.append(byteBuf)
            self.registWritable()
        }
    }
    
    public func disconnect() {
        eventLoop.execute {
            guard self.socket != nil else { return }
            self.onDisconnect()
        }
    }
    
    public func connect(host: String, port: Int, timeout: TimeInterval? = nil) {
        eventLoop.execute {
            self.addressResolver = AddressResolver(host: host, port: port)
            
            do {
                self.state = .connecting
                let addrs = try self.addressResolver.resolveHost()
                if addrs.count == 0 {
                    self.state = .idle
                    self.observer?.channel(self, didDisconnect: .dnsFailed(self.addressResolver.host))
                    return
                }
                let addr = addrs[0]
                                        
                let sock = try Socket(family: addr.family, type: .tcp)
                self.socket = sock
                
                try sock.enableNonBlock(true)
                sock.ignoreSIGPIPE()
                
                self.eventLoop.selector.registEvent(selectable: self, events: [.read, .write])
                
                switch addr {
                case .v4(let v4Addr):
                    try? self.connectAddress(socket: sock,v4Addr)
                case .v6(let v6Addr):
                    try? self.connectAddress(socket: sock,v6Addr)
                }
                let timeout = timeout ?? 60
                self.connectTimer = self.eventLoop.execute(after: timeout, work: {[weak self] in
                    self?.onDisconnect(.connectTimeout(timeout))
                })
                
            } catch {
                self.state = .idle
                let err = (error as? ChannelError) ?? ChannelError.unknown
                self.observer?.channel(self, didDisconnect: err)
            }
        }
    }
        
    private func connectAddress<T>(socket: Socket,_ addr: T) throws {
        try withUnsafePointer(to: addr) { ptr in
            try ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                try socket.connect(addr: ptr, len: socklen_t(MemoryLayout<T>.size))
            }
        }
    }
}

///MARK: selectable
extension ClientChannel: Selectable {
    public var isActive: Bool {
        self.state == .connected
    }
    
    var fd: Int32 {
        socket?.fd ?? -1
    }
    
    func onEvents(_ events: EventSet) {
        if state == .connecting {
            if events == .write {
                onConnect()
                return
            }else if events == [.write, .read] {
                onDisconnect(.socketError("Connect error", errno))
                return
            }
        }
        
        if events.contains(.write) {
            onWritable()
        }
        
        if events.contains(.read) {
            onReadable()
        }
    }
}

extension ClientChannel {
    func onConnect() {
        connectTimer?.cancel()
        connectTimer = nil
        state = .connected
        unregistWritable()
        observer?.channel(self, didConnect: addressResolver.host, port: addressResolver.port)
    }
    
    func onDisconnect(_ error: ChannelError? = nil) {
        disableHeartBeat()
        connectTimer?.cancel()
        connectTimer = nil
        state = .idle
        eventLoop.selector.removeEvent(selectable: self)
        observer?.channel(self, didDisconnect: error)
        socket?.close()
        socket = nil
        writingBuffer.removeAll()
    }
        
    func onWritable() {
        eventLoop.assertCurrentLoop()
        
        guard writingBuffer.count > 0 else {
            unregistWritable()
            return
        }
        guard let sock = socket else {
            unregistWritable()
            return
        }
        var byteBuf = writingBuffer[0]
        let writeBytes = sock.write(buf: byteBuf.readPointer().baseAddress!, size: byteBuf.count)

        if writeBytes == byteBuf.count {
            //write whole ByteBuffer
            writingBuffer.removeFirst()
            observer?.channel(self, didWrite: byteBuf, userInfo: byteBuf.userInfo)
            resetHeartBeatIfNeed(type: .write)
        }else if writeBytes > 0 {
            byteBuf.moveReadIndex(by: writeBytes)
            resetHeartBeatIfNeed(type: .write)
        }else if writeBytes == 0 {
            onDisconnect(.peerPartyDisconnected)
        }else if writeBytes < 0 {
            if errno.canIgnoreErrno { return }
            
            onDisconnect(.socketError("Socket Write size(\(writeBytes)) error", errno))
        }
    }
    
    func onReadable() {
        eventLoop.assertCurrentLoop()

        guard let sock = socket else {
            assert(false, "socket can't be nil")
            return
        }
        var buffer = ByteBuffer()
        let readBytes = sock.read(buf: buffer.writePointer().baseAddress!, size: buffer.capacity)
        
        if readBytes > 0 {
            buffer.moveWriteIndex(by: readBytes)
            observer?.channel(self, didRead: buffer)
            resetHeartBeatIfNeed(type: .read)
        }else if readBytes == 0 {
            onDisconnect(.peerPartyDisconnected)
        }else if readBytes < 0 {
            if errno.canIgnoreErrno { return }
            
            onDisconnect(.socketError("Socket Read size(\(readBytes)) error", errno))
        }
    }
    
    ///readable writable
    func registWritable() {
        eventLoop.assertCurrentLoop()
        eventLoop.selector.enableWritable(selectable: self, on: true)
    }
    
    func unregistWritable() {
        eventLoop.assertCurrentLoop()
        eventLoop.selector.enableWritable(selectable: self, on: false)
    }
}

//heart beat
extension ClientChannel {
    public func enableHeartBeat(interval: TimeInterval, resetOnRead: Bool = false, resetOnWrite: Bool = false) {
        assert(hbConfig.heartBeatTimer == nil)
        assert(interval > 0)
        hbConfig.interval = interval
        hbConfig.enable = true
        if resetOnRead {
            hbConfig.resetType.formUnion(.read)
        }
        if resetOnWrite {
            hbConfig.resetType.formUnion(.write)
        }
        resetHeartBeatIfNeed(type: .none)
    }
    
    public func disableHeartBeat() {
        hbConfig.enable = false
        hbConfig.heartBeatTimer?.cancel()
        hbConfig.heartBeatTimer = nil
    }
    
    private func resetHeartBeatIfNeed(type: HeartBeartConfig.ResetType) {
        guard hbConfig.valid(for: type) else { return }
        
        hbConfig.heartBeatTimer?.cancel()
        let interval = hbConfig.interval
        hbConfig.heartBeatTimer = eventLoop.execute(timer: interval, work: {[weak self] in
            guard let self = self else { return }
            self.observer?.channelHeartBeat(self)
        })
    }
    
    struct HeartBeartConfig {
        struct ResetType: OptionSet {
            var rawValue: Int
            static let none = ResetType([])
            static let read = ResetType(rawValue: 1<<0)
            static let write = ResetType(rawValue: 1<<1)
        }
        var resetType: ResetType = .none
        var interval: TimeInterval = 0
        var enable = true
        weak var heartBeatTimer: Task? = nil
        
        func valid(for type: ResetType) -> Bool {
            if enable && resetType.contains(type) {
                return true
            }
            return false
        }
    }
}

fileprivate extension Int32 {
    var canIgnoreErrno: Bool {
        self == EINTR || self == EWOULDBLOCK || self == EAGAIN
    }
}
