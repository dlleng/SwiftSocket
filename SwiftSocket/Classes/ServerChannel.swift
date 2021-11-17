//
//  NIOServer.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/10/9.
//

import Foundation

public class ServerChannel {
    public let eventLoop: EventLoop
    private weak var observer: ChannelObserver?
     private var socket: Socket?
    
    public init(observer: ChannelObserver?) {
        self.observer = observer
        self.eventLoop = EventLoop()
        self.eventLoop.startup()

    }
    
    public func start(host: String, port: Int) throws {
        let addr = try SocketAddress.makeAddress(host: host, port: port)
        switch addr {
        case .v4(_):
            socket = try Socket(family: .inet, type: .tcp)
        case .v6(_):
            socket = try Socket(family: .inet6, type: .tcp)
        }
        socket?.enableReuseAddr(true)
        try socket?.bind(address: addr)
        try socket?.listen()
        
        try socket?.enableNonBlock(true)
        socket?.ignoreSIGPIPE()
        
        eventLoop.selector.registEvent(selectable: self, events: [.read])
    }
    
    public func shutdown() {
        eventLoop.shutdown()
        socket?.close()
        socket = nil
    }
}

extension ServerChannel: Selectable {
    var isActive: Bool {
        socket != nil
    }
    
    var fd: Int32 {
        socket?.fd ?? 0
    }
    
    func onEvents(_ events: EventSet) {
        if events.contains(.read) {
            self.onAcceptable()
        }
    }
}

extension ServerChannel {
    ///IO
    func onAcceptable() {
        guard let newSocket = try? self.socket?.accept() else {
            return
        }
        let newClient = ClientChannel(observer: observer, eventLoop: eventLoop, socket: newSocket)
        eventLoop.selector.registEvent(selectable: newClient, events: [.read, .write])
        
        observer?.channel(self, didAccept: newClient)
    }
    
    func onError(_ error: ChannelError?) {
        assert(false)
        observer?.channel(self, error: error)
    }
}
