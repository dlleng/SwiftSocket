//
//  Socket.swift
//  SwiftSocket
//
//  Created by dlleng on 2021/8/10.
//

import Foundation

extension Socket {
    struct Family: Equatable {
        var rawValue: Int32 = 0
        static let inet = Family(rawValue: AF_INET)
        static let inet6 = Family(rawValue: AF_INET6)
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
    }
    
    struct SocketType: Equatable {
        var rawValue: Int32 = 0
        static let tcp = SocketType(rawValue: SOCK_STREAM)
        static let udp = SocketType(rawValue: SOCK_DGRAM)
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
    }
}


class Socket {
    var fd: Int32 = -1
    init(family: Family, type: SocketType) throws {
        fd = socket(family.rawValue, type.rawValue, 0)
        if fd < 0 {
            throw ChannelError.socketError("Create socket failed!", errno)
        }
    }
    
    init?(socket: Int32) {
        if socket < 0 { return nil }
        self.fd = socket
    }
    
    func bind(host: String, port: Int) throws {
        let addr = try SocketAddress.makeAddress(host: host, port: port)
        try bind(address: addr)
    }
    
    func bind(address: SocketAddress) throws {
        let result = address.withSockAddr { ptr, size in
            Darwin.bind(fd, ptr, socklen_t(size))
        }
        if result < 0 {
            throw ChannelError.socketError("Bind socket failed!", errno)
        }
    }
    
    func listen(backlog: Int32 = 128) throws {
        if Darwin.listen(fd, backlog) < 0 {
            throw ChannelError.socketError("Listen socket failed!", errno)
        }
    }
    
    func accept() throws -> Socket? {
        let fd = Darwin.accept(fd, nil, nil)
        if fd < 0 {
            throw ChannelError.socketError("Accept error!", errno)
        }
        return Socket(socket: fd)
    }
    
    func connect(addr: UnsafePointer<sockaddr>, len: socklen_t) throws {
        if Darwin.connect(fd, addr, len) < 0 {
            throw ChannelError.socketError("Connect socket failed!", errno)
        }
    }
    
    func write(buf: UnsafeRawPointer, size: Int) -> Int {
        return Darwin.write(fd, buf, size)
    }
    
    func read(buf: UnsafeMutableRawPointer, size: Int) -> Int {
        return Darwin.read(fd, buf, size)
    }
     
    func close() {
        guard fd >= 0 else { return }
        Darwin.close(fd)
        fd = -1
    }
    
    deinit {
        close()
    }
    
    func enableNonBlock(_ on: Bool) throws {
        var flags = fcntl(fd, F_GETFL, 0)
        if flags < 0 {
            throw ChannelError.socketError("fcntl get error!", errno)
        }
        if on {
            flags = O_NONBLOCK | flags
        }else {
            flags = ~O_NONBLOCK & flags
        }
        if fcntl(fd, F_SETFL, flags) < 0 {
            throw ChannelError.socketError("fcntl set error!", errno)
        }
    }
    
    func ignoreSIGPIPE() {
        var value: Int32 = 1
        let len = socklen_t(MemoryLayout.size(ofValue: value))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &value, len)
    }
    
    func enableReuseAddr(_ on: Bool) {
        var v: Int32 = on ? 1 : 0
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &v, socklen_t(MemoryLayout.size(ofValue: v)))
    }
}

extension Socket {
    public var localAddress: SocketAddress {
        SocketAddress.makeAddress(socketFD: fd, local: true)
    }
    
    public var remoteAddress: SocketAddress {
        SocketAddress.makeAddress(socketFD: fd, local: false)
    }
}


/// DNS Resolver
struct AddressResolver {
    var host: String = ""
    var port: Int = 0
    
    func resolveHost() throws -> [SocketAddress] {
        var addrs = [SocketAddress]()
        var info: UnsafeMutablePointer<addrinfo>?
        var hint = addrinfo()
        hint.ai_socktype = SOCK_STREAM
        hint.ai_protocol = IPPROTO_TCP
        guard Darwin.getaddrinfo(host, String(port), &hint, &info) == 0 else {
            throw ChannelError.dnsFailed(host)
        }
        guard var vInfo = info else {
            throw ChannelError.dnsFailed(host)
        }
        while true {
            switch Socket.Family(rawValue: vInfo.pointee.ai_family) {
            case .inet:
                vInfo.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ptr in
                    addrs.append(.v4(ptr.pointee))
                }
            case .inet6:
                vInfo.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr in
                    addrs.append(.v6(ptr.pointee))
                }
            default:()
            }
            guard let next = vInfo.pointee.ai_next else { break }
            vInfo = next
        }
        freeaddrinfo(info)
        //print(addrs)
        return addrs
    }
}
