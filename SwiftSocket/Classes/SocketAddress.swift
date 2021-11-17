//
//  SocketAddress.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/11/9.
//

import Foundation

public enum SocketAddress {
    case v4(sockaddr_in)
    case v6(sockaddr_in6)
    
    var family: Socket.Family {
        switch self {
        case .v4(_): return .inet
        case .v6(_): return .inet6
        }
    }
    
    func withSockAddr<T>(_ body: (UnsafePointer<sockaddr>, Int) -> T) -> T {
        switch self {
        case .v4(var addr):
            return withUnsafeBytes(of: &addr) { p in
                body(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
            }
        case .v6(var addr):
            return withUnsafeBytes(of: &addr) { p in
                body(p.baseAddress!.assumingMemoryBound(to: sockaddr.self), p.count)
            }
        }
    }
        
    public var ip: String {
        switch self {
        case .v4(var addr):
            var buffer: [CChar] = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(self.family.rawValue, &addr.sin_addr,&buffer, socklen_t(INET_ADDRSTRLEN))
            return String(cString: buffer)
        case .v6(var addr):
            var buffer: [CChar] = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, &addr.sin6_addr,&buffer, socklen_t(INET6_ADDRSTRLEN))
            return String(cString: buffer)
        }
    }
    
    public var port: Int {
        switch(self) {
        case .v4(let addr):
            return Int(in_port_t(bigEndian: addr.sin_port))
        case .v6(let addr):
            return Int(in_port_t(bigEndian: addr.sin6_port))
        }
    }
}

extension SocketAddress: CustomStringConvertible {
    public var description: String { "\(ip):\(port)" }
}

extension SocketAddress {
    static func makeAddress(addr: sockaddr) -> SocketAddress {
        var addr = addr
        if addr.sa_family == AF_INET {
            let addrIn = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            }
            return .v4(addrIn)
        }else {
            let addrIn = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
            }
            return .v6(addrIn)
        }
    }
    
    
    /// Get socket address from socket fd
    /// - Parameters:
    ///   - socketFD: Socket fd
    ///   - local: True for local address and False for remote address
    /// - Returns: Socket address
    static func makeAddress(socketFD: Int32, local: Bool = true) -> SocketAddress {
        var storage = sockaddr_storage()
        let addr = withUnsafeMutableBytes(of: &storage) { p -> sockaddr in
            let pAddr = p.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            var size = socklen_t(p.count)
            if local {
                Darwin.getsockname(socketFD, pAddr, &size)
            }else {
                Darwin.getpeername(socketFD, pAddr, &size)
            }
            return pAddr.pointee
        }
        return makeAddress(addr: addr)
    }

    static func makeAddress(host: String, port: Int) throws -> SocketAddress {
        var info: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(host, String(port), nil, &info) != 0 {
            throw ChannelError.dnsFailed(host)
        }
        guard let info = info else {
            throw ChannelError.dnsFailed(host)
        }
        defer { freeaddrinfo(info) }
        switch Socket.Family(rawValue: info.pointee.ai_family) {
        case .inet:
            return info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ptr in
                    .v4(ptr.pointee)
            }
        case .inet6:
            return info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr in
                    .v6(ptr.pointee)
            }
        default:break
        }
        throw ChannelError.dnsFailed(host)
    }
}
