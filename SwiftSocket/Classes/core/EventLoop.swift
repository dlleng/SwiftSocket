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
        
    public func tryFinish() -> Bool {
        guard !cancelled else { return true }
        if repeated {
            nextTime = Date().timeIntervalSince1970 + interval
            return false
        }
        return true
    }
    
    public func executeTask() {
        guard !cancelled else { return }
        execute()
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
    internal let selector = Selector()
    private var thread = PThread()
    private var tasks = Heap<Task>()
    private var lock = NSLock()
    private var running: Bool = true
    
    public var inCurrent: Bool { thread.inCurrent }
    
    public func assertCurrentLoop() {
        assert(inCurrent)
    }
    
    func loop() {
        while running {
            //Get nearest task execute time
            lock.lock()
            let timeout: TimeInterval = tasks.root?.remainTime ?? 600
            lock.unlock()
            
            //sleep while no task
            selector.waitForEvents(timeout: max(timeout, 0))
            if !running { return }
            
            var arrExecutable = [Task]()
            lock.lock()
            while let task = tasks.root, task.remainTime <= 0 {
                arrExecutable.append(task)
                //Remove task if finished, reset next execute time if no
                if task.tryFinish() {
                    tasks.removeRoot()
                }else {
                    tasks.heapifyRoot()
                }
            }
            lock.unlock()
            
            //excuse tasks
            arrExecutable.forEach{ $0.executeTask() }
        }
    }
    
    func startup() {
        if thread.isRunning {
            assert(false, "Thread is already running")
            return
        }
        running = true
        thread.start(body: {_ in
            self.loop()
        })
    }
    
    func shutdown() {
        assert(!self.inCurrent, "Can not call in EventLoop")
        if !thread.isRunning {
            return
        }
        
        running = false
        selector.wakeup()
        thread.join()
        tasks.removeAll()
        selector.clean()
    }
}

///EventLoop task
extension EventLoop {
    private func syncAppend(task: Task) {
        lock.lock()
        tasks.append(task)
        lock.unlock()
    }
    
    public func execute(work: @escaping ()->Void) {
        if self.inCurrent {
            work()
        }else {
            let task = Task(after: 0, execute: work)
            syncAppend(task: task)
            selector.wakeup()
        }
    }
    
    public func execute(after: TimeInterval, work: @escaping ()->Void) -> Task {
        let task = Task(after: after, execute: work)
        if self.inCurrent {
            syncAppend(task: task)
        }else {
            syncAppend(task: task)
            selector.wakeup()
        }
        return task
    }
    
    public func execute(timer interval: TimeInterval, work: @escaping ()->Void) -> Task {
        let task = Task(interval: interval, repeated: true, execute: work)
        if self.inCurrent {
            syncAppend(task: task)
        }else {
            syncAppend(task: task)
            selector.wakeup()
        }
        return task
    }
}
