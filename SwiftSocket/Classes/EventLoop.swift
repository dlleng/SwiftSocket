//
//  EventLoop.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/10/9.
//

import Foundation


///Task
public class Task: Comparable {
    private var repeated: Bool = false
    private var nextTime: TimeInterval = 0
    private var execute: ()->Void
    private var cancelled: Bool = false
    var interval: TimeInterval = 0
    
    var remainTime: TimeInterval {
        nextTime - Date().timeIntervalSince1970
    }
    
    init(after: TimeInterval, execute: @escaping ()->Void) {
        nextTime = Date().timeIntervalSince1970 + after
        self.execute = execute
    }
    
    init(interval: TimeInterval, repeated: Bool = true, execute: @escaping ()->Void) {
        nextTime = Date().timeIntervalSince1970 + interval
        self.interval = interval
        self.repeated = repeated
        self.execute = execute
    }
    
    public func cancel() {
        cancelled = true
    }
    
    //return: If the task is complete
    func executeTask() -> Bool {
        guard !cancelled else { return true }
        execute()
        if repeated {
            nextTime = Date().timeIntervalSince1970 + interval
            return false
        }
        return true
    }
    
    public static func < (lhs: Task, rhs: Task) -> Bool {
        return lhs.nextTime < rhs.nextTime
    }
    
    public static func == (lhs: Task, rhs: Task) -> Bool {
        return lhs.nextTime == rhs.nextTime
    }
}

///Event Loop
public class EventLoop {
    let selector = Selector()
    var thread: PThread?
    var tasks = Heap<Task>()
    private var lock = NSLock()
    private var running: Bool = true
    
    public var inCurrent: Bool { thread?.inCurrent ?? false }
    
    public func assertCurrentLoop() {
        assert(inCurrent)
    }
    
    init() {
    }
    
    func loop() {
        while running {
            lock.lock()
            let timeout: TimeInterval = tasks.root?.remainTime ?? 600
            lock.unlock()
            selector.waitForEvents(timeout: max(timeout, 0))
            if !running { return }
            
            //excuse tasks
            lock.lock()
            while let task = tasks.root, task.remainTime <= 0 {
                if task.executeTask() {
                    tasks.removeRoot()
                }else {
                    tasks.heapifyRoot()
                }
            }
            lock.unlock()
        }
    }
    
    func startup() {
        assert(thread == nil, "There are already a thread exsit")
        thread = PThread(body: {_ in
            self.loop()
        })
    }
    
    func shutdown() {
        assert(!self.inCurrent, "Can not call in EventLoop")
        assert(thread != nil, "There are no thread exsit")
        
        running = false
        selector.wakeup()
        thread?.join()
        thread = nil
        tasks.removeAll()
        selector.clean()
    }
}

///EventLoop task
extension EventLoop {
    public func execute(work: @escaping ()->Void) {
        if self.inCurrent {
            work()
        }else {
            let task = Task(after: 0, execute: work)
            lock.lock()
            tasks.append(task)
            lock.unlock()
            selector.wakeup()
        }
    }
    
    public func execute(after: TimeInterval, work: @escaping ()->Void) -> Task {
        let task = Task(after: after, execute: work)
        if self.inCurrent {
            tasks.append(task)
        }else {
            lock.lock()
            tasks.append(task)
            lock.unlock()
            selector.wakeup()
        }
        return task
    }
    
    public func execute(timer interval: TimeInterval, work: @escaping ()->Void) -> Task {
        let task = Task(interval: interval, repeated: true, execute: work)
        if self.inCurrent {
            tasks.append(task)
        }else {
            lock.lock()
            tasks.append(task)
            lock.unlock()
            selector.wakeup()
        }
        return task
    }
}
