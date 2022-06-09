//
//  SSLHandler.swift
//
//  Created by dl leng on 2022/6/8.
//

import UIKit
import Network

public protocol SSLHandlerDelegate {
    func sslHandshakeSuccessed(_ handler: SSLHandler)
    func sslHandshake(_ handler: SSLHandler, fail code: Int32)
    func ssl(_ handler: SSLHandler, inData: Data)
    func ssl(_ handler: SSLHandler, outData: Data)
}

public class SSLHandler {
    private let serailQueue = DispatchQueue(label: "com.serail.SSLHandler")
    private let sslContext: SSLContext
    private var readBuffer = Data()
    public var delegate: SSLHandlerDelegate?
    public var state: SSLSessionState {
        var state: SSLSessionState = .idle
        SSLGetSessionState(sslContext, &state)
        return state
    }
    public var sslConnected: Bool { self.state == .connected }
    
    public init(delegate: SSLHandlerDelegate, domain: String? = nil) {
        let context = SSLCreateContext(kCFAllocatorDefault, .clientSide, .streamType)!
        self.delegate = delegate
        sslContext = context

        if let domain = domain {
            SSLSetPeerDomainName(sslContext, domain, domain.count)
        }
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        SSLSetConnection(sslContext, ptr)
        //SSLSetIOFuncs(sslContext, sslReadCallback, sslWriteCallback)
        SSLSetIOFuncs(sslContext) { connection, data, dataLen in
            let manager = Unmanaged<SSLHandler>.fromOpaque(connection).takeUnretainedValue()
            return manager.sslReadCallback(data, dataLen)
        } _: { connection, data, dataLen in
            let manager = Unmanaged<SSLHandler>.fromOpaque(connection).takeUnretainedValue()
            return manager.sslWriteCallback(data, dataLen)
        }

    }
    
    //send data to ssl
    func send(data: Data) {
        serailQueue.async {
            let ptr = data.withUnsafeBytes{$0}
            var processed = 0
            SSLWrite(self.sslContext, ptr.baseAddress, data.count, &processed)
        }
    }
    
    //receive data from tcp
    func onReceive(data: Data) {
        serailQueue.async {
            self.readBuffer.append(data)
            guard self.state == .connected else {
                self._handshake()
                return
            }
            var rbuf = [UInt8](repeating: 0, count: 4096)
            let pp = rbuf.withUnsafeMutableBytes{$0}
            var processed = 0
            let status = SSLRead(self.sslContext, pp.baseAddress!, rbuf.count, &processed)
            if processed > 0 {
                let sslData = Data(bytes: rbuf, count: processed)
                self.delegate?.ssl(self, inData: sslData)
            }
        }
    }
    
    func handshake() {
        serailQueue.async {
            self._handshake()
        }
    }
    
    private func _handshake() {
        let status = SSLHandshake(self.sslContext)
        if status == noErr {
            self.delegate?.sslHandshakeSuccessed(self)
        }else if status == errSSLWouldBlock {
            //need more data
        }else {
            self.delegate?.sslHandshake(self, fail: status)
        }
    }
}

//MARK: IO Callback
extension SSLHandler {
    private func sslReadCallback(
        _ data: UnsafeMutableRawPointer,
        _ dataLen: UnsafeMutablePointer<Int>) -> OSStatus {
        if dataLen.pointee == 0 {
            return noErr
        }else if readBuffer.count == 0 {
            dataLen.pointee = 0
            return errSSLWouldBlock
        }else if readBuffer.count < dataLen.pointee {
            let p = readBuffer.withUnsafeBytes{$0}
            data.copyMemory(from: p.baseAddress!, byteCount: readBuffer.count)
            dataLen.pointee = readBuffer.count
            readBuffer.removeAll()
            return errSSLWouldBlock
        }else {
            let p = readBuffer.withUnsafeBytes{$0}
            
            data.copyMemory(from: p.baseAddress!, byteCount: dataLen.pointee)
            readBuffer.removeSubrange(0..<dataLen.pointee)
            
            return noErr
        }
    }

    private func sslWriteCallback(
        _ data: UnsafeRawPointer,
        _ dataLen: UnsafeMutablePointer<Int>) -> OSStatus {
        let data = Data(bytes: data, count: dataLen.pointee)
        delegate?.ssl(self, outData: data)
        return noErr
    }
}
