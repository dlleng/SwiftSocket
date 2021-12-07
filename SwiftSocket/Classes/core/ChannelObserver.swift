//
//  ChannelObserver.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/10/26.
//

import Foundation

public protocol ChannelObserver: AnyObject {
    func channel(_ server: ServerChannel, didAccept client: ClientChannel)
    func channel(_ server: ServerChannel, error: ChannelError?)
    func channel(_ client: ClientChannel, didConnect host: String, port: Int)
    func channel(_ client: ClientChannel, didDisconnect error: ChannelError?)
    func channel(_ client: ClientChannel, didRead buffer: ByteBuffer)
    func channel(_ client: ClientChannel, didWrite buffer: ByteBuffer, userInfo: [String: Any]?)
    func channelHeartBeat(_ client: ClientChannel)
}

extension ChannelObserver {
    public func channel(_ server: ServerChannel, didAccept client: ClientChannel){}
    public func channel(_ server: ServerChannel, error: ChannelError?) {}

    public func channelHeartBeat(_ client: ClientChannel){}
}
