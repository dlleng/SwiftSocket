//
//  Error.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/10/18.
//

import Foundation

public enum ChannelError: Error {
    case unknown
    //host
    case dnsFailed(String)
    //timeout
    case connectTimeout(TimeInterval)
    //descript  errorno
    case socketError(String,Int32)
    case peerPartyDisconnected
}

extension ChannelError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}

extension ChannelError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            return "Unknow error"
        case .dnsFailed(let host):
            return "DNS resolved error: \(host)"
        case .connectTimeout(let timeout):
            return "Connect timeout: \(timeout)"
        case .socketError(let des, let erno):
            return "Socket error:\(des)[\(erno):\(erno.errDescription)]"
        case .peerPartyDisconnected:
            return "The peer party disconnected"
        }
    }
}


extension Int32 {
    var ignorable: Bool {
        self == EINTR || self == EWOULDBLOCK || self == EAGAIN
    }
    
    var errDescription: String {
        guard let cStr = strerror(self) else {
            return "NULL"
        }
        return String(cString: cStr)
    }
}
