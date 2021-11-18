//
//  ServerVC.swift
//  SwiftSocket_Example
//
//  Created by dl leng on 2021/10/28.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import SwiftSocket

class ServerVC: UIViewController {
    var client: ClientChannel?
    var server: ServerChannel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.backgroundColor = .white
        
        server = ServerChannel(observer: self)
        do {
            try server.startServer(host: "0.0.0.0", port: 9999)
            print("Start server successed")
        } catch {
            print(error)
            assert(false)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        let data = "GET / HTTP/1.2\r\nHost: www.cnblogs.com\r\n\r\n".data(using: .utf8)!
        client?.write(data: data)
    }

}

extension ServerVC: ChannelObserver {
    func channel(_ client: ClientChannel, didDisconnect error: ChannelError?) {
        print("connect err: \(String(describing: error))")
    }
    
    func channel(_ client: ClientChannel, didConnect host: String, port: Int) {
        print("connect \(host):\(port) successed ")
    }
    
    func channel(_ client: ClientChannel, didRead buffer: ByteBuffer) {
        let str = String(data: buffer.toData(), encoding: .utf8) ?? "NULL"
        print("\(client)  read: \(buffer.count) \(str)")
        client.write(data: "我收到你发的: \(str)".data(using: .utf8)!)
    }
    
    func channel(_ client: ClientChannel, didWrite buffer: ByteBuffer, userInfo: [String: Any]?) {
        print("\(client)  write: \(buffer.count)")
    }
    
    
    func channel(_ server: ServerChannel, didAccept client: ClientChannel) {
        print("didAccept : \(client)")
        self.client = client
        
        client.enableHeartBeat(interval: 10, resetOnRead: true, resetOnWrite: true)
    }
    
    func channelHeartBeat(_ client: ClientChannel) {
        print("== 心跳")
        client.write(data: "心跳\n".data(using: .utf8)!)
    }
}

