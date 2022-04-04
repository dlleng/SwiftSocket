//
//  ClientVC.swift
//  SwiftSocket_Example
//
//  Created by dl leng on 2021/10/28.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import UIKit
import libSwiftSocket

class ClientVC: UIViewController {
    var client: ClientChannel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.backgroundColor = .white
        
        client = ClientChannel(observer: self)
        client.connect(host: "www.apple.com", port: 80)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        client.disconnect()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        let data = "GET / HTTP/1.2\r\nHost: www.apple.com\r\n\r\n".data(using: .utf8)!
        client.write(data: data)
    }
    
}

extension ClientVC: ChannelObserver {
    func channel(_ client: ClientChannel, didDisconnect error: ChannelError?) {
        print("connect err: \(String(describing: error))")
    }
    
    func channel(_ client: ClientChannel, didConnect host: String, port: Int) {
        print("connect \(host):\(port) successed ")
        client.enableHeartBeat(interval: 10, resetOnRead: true, resetOnWrite: true)
        
        print("local: \(client.localAddress)")
        print("remote: \(client.remoteAddress)")
    }
    
    func channel(_ client: ClientChannel, didRead buffer: ByteBuffer) {
        let str = String(data: buffer.toData(), encoding: .utf8) ?? "NULL"
        print("\(client)  read: \(buffer.count) \(str)")
        client.write(data: "rcv: \(str)".data(using: .utf8)!)
    }
    
    func channel(_ client: ClientChannel, didWrite buffer: ByteBuffer, userInfo: [String: Any]?) {
        print("\(client)  write: \(buffer.count)")
    }
    
    func channelHeartBeat(_ client: ClientChannel) {
        client.write(data: "heart beat\n".data(using: .utf8)!)
    }
}


