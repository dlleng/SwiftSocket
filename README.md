# SwiftSocket

[![CI Status](https://img.shields.io/travis/zhaoxin/SwiftSocket.svg?style=flat)](https://travis-ci.org/zhaoxin/SwiftSocket)
[![Version](https://img.shields.io/cocoapods/v/SwiftSocket.svg?style=flat)](https://cocoapods.org/pods/SwiftSocket)
[![License](https://img.shields.io/cocoapods/l/SwiftSocket.svg?style=flat)](https://cocoapods.org/pods/SwiftSocket)
[![Platform](https://img.shields.io/cocoapods/p/SwiftSocket.svg?style=flat)](https://cocoapods.org/pods/SwiftSocket)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

SwiftSocket is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SwiftSocket', :git => 'https://github.com/dlleng/SwiftSocket.git', :branch => 'main'
```

### Task
```swift
let client = ClientChannel(observer: self)
client.eventLoop.execute {
    //task
}
let timerTask = client.eventLoop.execute(timer: 1) {
    //timer task
}
let delayTask = client.eventLoop.execute(after: 1) {
    //delay task
}
```

### Client
```swift
let client = ClientChannel(observer: self)
client.connect(host: "www.apple.com", port: 80)

extension XXX: ChannelObserver {
    func channel(_ client: ClientChannel, didDisconnect error: ChannelError?) {
        print("connect err: \(String(describing: error))")
    }
    
    func channel(_ client: ClientChannel, didConnect host: String, port: Int) {
        print("connect \(host):\(port) successed ")
        client.enableHeartBeat(interval: 10, resetOnRead: true, resetOnWrite: true)
        
        print("\(client.localAddress)")
        print("\(client.remoteAddress)")
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
        print("should send heartbeat")
        client.write(data: "heartbeat\n".data(using: .utf8)!)
    }
}

```
### Server
```swift
let server = ServerChannel(observer: self)
do {
    try server.startServer(host: "0.0.0.0", port: 9999)
    print("Start server successed")
} catch {
    print(error)
}

extension XXX: ChannelObserver {
    func channel(_ client: ClientChannel, didDisconnect error: ChannelError?) {
        print("connect err: \(String(describing: error))")
    }
    
    func channel(_ client: ClientChannel, didConnect host: String, port: Int) {
        print("connect \(host):\(port) successed ")
    }
    
    func channel(_ client: ClientChannel, didRead buffer: ByteBuffer) {
        let str = String(data: buffer.toData(), encoding: .utf8) ?? "NULL"
        print("\(client)  read: \(buffer.count) \(str)")
        client.write(data: "rcv: \(str)".data(using: .utf8)!)
    }
    
    func channel(_ client: ClientChannel, didWrite buffer: ByteBuffer, userInfo: [String: Any]?) {
        print("\(client)  write: \(buffer.count)")
    }
    
    
    func channel(_ server: ServerChannel, didAccept client: ClientChannel) {
        print("didAccept : \(client)")
        self.client = client
        
        //if need
        //client.enableHeartBeat(interval: 10, resetOnRead: true, resetOnWrite: true)
    }
    
    //if need
    //func channelHeartBeat(_ client: ClientChannel) {
        //print("Heartbeat")
        //client.write(data: "heartbeat\n".data(using: .utf8)!)
    //}
}
```

## Author

dlleng, 2190931560@qq.com

## License

SwiftSocket is available under the MIT license. See the LICENSE file for more info.
