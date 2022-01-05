//
//  IPDetector.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/12/7.
//

import UIKit

///Detect whether a ip is exist in the local
///This class can be used to quickly detect whether a connection is valid sometimes
public class IPDetector {
    private var localIP = ""
    private var timer: DispatchSourceTimer?
    private var eventBlock: (()->Void)?

    init() {
    }
    
    //start detect per second
    public func startDetect(localIp: String, happened: @escaping ()->Void) {
        timer?.cancel()
        guard localIp.count > 0 else { return }
        guard isIPExist(localIp) else { return }
        self.localIP = localIp
        self.eventBlock = happened
        
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now(), repeating: 1)
        timer.setEventHandler { [weak self] in
            self?.localIPDetect()
        }
        timer.resume()
        self.timer = timer
    }
    
    
    public func stopDetect() {
        timer?.cancel()
        timer = nil
        localIP = ""
        eventBlock = nil
    }
    
    
    private func localIPDetect() {
        guard self.localIP.count > 0 else { return }
        if isIPExist(self.localIP) { return }
        
        eventBlock?()
    }
    
    
    private func isIPExist(_ ip: String) -> Bool {
        guard ip.count > 0 else { return true }
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0 else { return true }
        
        guard let firstAddr = ifaddr else { return true }
        
        var isExist = false
        for ifptr in sequence(first: firstAddr, next: {$0.pointee.ifa_next}) {
            let interface = ifptr.pointee
            let saFamily = interface.ifa_addr.pointee.sa_family
            guard let addrPtr = interface.ifa_addr else { continue }
            
            if saFamily == UInt8(AF_INET) {
                var buffer: [CChar] = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var addrIn = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1){$0.pointee}
                inet_ntop(Int32(saFamily), &addrIn.sin_addr,&buffer, socklen_t(INET_ADDRSTRLEN))
                let ipStr = String(cString: buffer)
                if ipStr == ip {
                    isExist = true
                    break
                }
            }else if saFamily == UInt8(AF_INET6) {
                var buffer: [CChar] = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                var addrIn = addrPtr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1){$0.pointee}
                inet_ntop(Int32(saFamily), &addrIn.sin6_addr,&buffer, socklen_t(INET6_ADDRSTRLEN))
                let ipStr = String(cString: buffer)
                if ipStr == ip {
                    isExist = true
                    break
                }
            }
            
        }
        
        freeifaddrs(ifaddr)
        return isExist
    }
}
