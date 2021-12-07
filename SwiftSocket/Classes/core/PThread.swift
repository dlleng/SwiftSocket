//
//  NIOThread.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/9/29.
//

import Foundation

private typealias ThreadBoxValue = (body: (PThread?) -> Void, name: String?)

final class Box<T> {
    let value: T
    init(_ value: T) { self.value = value }
}

final class PThread {
    private var _thread: pthread_t?
    var inCurrent: Bool { pthread_equal(_thread, pthread_self()) != 0 }
    var isRunning: Bool { _thread != nil }
    
    func start(name: String = "SwiftSocket.thread",body: @escaping (PThread?)->Void){
        let box: Box<ThreadBoxValue> = Box((body: body, name: name))
        let arg = Unmanaged.passRetained(box).toOpaque()
        
        let res = pthread_create(&_thread, nil, {
            let boxed = Unmanaged<Box<ThreadBoxValue>>.fromOpaque(($0 as UnsafeMutableRawPointer?)!).takeRetainedValue()
            let (body, name) = (boxed.value.body, boxed.value.name)
            if let name = name {
                PThread.setCurrentThreadName(name)
            }
            body(nil)
            return nil
        }, arg)
        assert(res == 0, "Create thread failed")
    }
        
    func join() {
        guard let t = _thread else { return }
        let err = pthread_join(t, nil)
        assert(err == 0)
        _thread = nil
    }
        
    deinit{
        print("\(self)   \(#function)")
    }
}

extension PThread {
    @discardableResult
    static func setCurrentThreadName(_ name: String) -> Int32 {
        return name.withCString { namePtr in
            return pthread_setname_np(namePtr)
        }
    }
    
    static func threadName(_ thread: pthread_t?) -> String? {
        guard let thread = thread else { return nil }
        var chars: [CChar] = Array(repeating: 0, count: 64)
        return chars.withUnsafeMutableBufferPointer { ptr in
            guard pthread_getname_np(thread, ptr.baseAddress!, ptr.count) == 0 else {
                return nil
            }

            let buffer: UnsafeRawBufferPointer =
                UnsafeRawBufferPointer(UnsafeBufferPointer<CChar>(rebasing: ptr.prefix { $0 != 0 }))
            return String(decoding: buffer, as: Unicode.UTF8.self)
        }
    }
    //Current thread name
    static var currentThreadName: String? { PThread.threadName(pthread_self()) }
    //This PThread's thread name
    var threadName: String? { PThread.threadName(_thread) }
}
