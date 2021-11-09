//
//  Selector.swift
//  SwiftSocket
//
//  Created by dl leng on 2021/9/28.
//

import Foundation

struct EventSet: OptionSet {
    let rawValue: Int32
    static let read     = EventSet(rawValue: 1<<1)
    static let write    = EventSet(rawValue: 1<<2)
    static let except   = EventSet(rawValue: 1<<3)
    static let user     = EventSet(rawValue: 1<<4)

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    var filterList: [Int32] {
        var list = [Int32]()
        for (ev,filter) in [
            (EventSet.read,EVFILT_READ),
            (EventSet.write,EVFILT_WRITE),
            (EventSet.except,EVFILT_EXCEPT),
            (EventSet.user,EVFILT_USER)
        ] {
            if self.contains(ev) {
                list.append(filter)
            }
        }
        return list
    }
}

struct ActionSet: OptionSet {
    let rawValue: Int32
    static let add     = ActionSet(rawValue: EV_ADD)
    static let delete  = ActionSet(rawValue: EV_DELETE)
    static let enable  = ActionSet(rawValue: EV_ENABLE)
    static let disable = ActionSet(rawValue: EV_DISABLE)
    static let clear   = ActionSet(rawValue: EV_CLEAR)

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

class Selector{
    private var selectorFd: Int32 = -1
    
    private var eventsCapacity: Int = 16
    private var events: UnsafeMutablePointer<kevent>
    
    private var registerMap = [Int32: Selectable]()
    
    init() {
        self.selectorFd = Darwin.kqueue()
        self.events = Selector.allocateEventsArray(capacity: eventsCapacity)
        
        updateEventSet(events: .user, action: [.add,.enable,.clear], fflags: UInt32(NOTE_FFNOP))
    }
    
    func clean() {
        registerMap.forEach{ removeEvent(selectable: $1) }
        registerMap.removeAll()
    }
    
    func waitForEvents(timeout: TimeInterval) {
        assert(timeout >= 0)
        var timespec = timeout.toTimespec()
        let ready = withUnsafePointer(to: &timespec) { ts in
            Int(kevent(selectorFd, nil, 0, events, Int32(eventsCapacity), ts))
        }
        guard ready >= 0 else {
            return
        }
        //print("\(Date()) waitForEvents \(ready)")
        
        var map = [Int32: EventSet]()
        for i in 0..<ready {
            let ev = events[i]
            let filter = Int32(ev.filter)
            guard filter != EVFILT_USER else {
                continue
            }
            var evs = map[Int32(ev.ident)] ?? []
            switch filter {
            case EVFILT_READ:  evs.formUnion(.read)
            case EVFILT_WRITE: evs.formUnion(.write)
            case EVFILT_EXCEPT: evs.formUnion(.except)
            default: assert(false)
            }
            map[Int32(ev.ident)] = evs
        }
        for (k,v) in map {
            registerMap[k]?.onEvents(v)
        }
        
        doubleEventArrayIfNeeded(ready: ready)
    }
    
    func registEvent(selectable: Selectable, events: EventSet) {
        assert(selectable.fd >= 0)
        guard selectable.fd >= 0 else { return }
        registerMap[selectable.fd] = selectable
        updateEventSet(ident: UInt(selectable.fd), events: events, action: [.add, .enable])
    }
    
    func removeEvent(selectable: Selectable) {
        assert(selectable.fd >= 0)
        guard selectable.fd >= 0 else { return }
        registerMap.removeValue(forKey: selectable.fd)
        updateEventSet(ident: UInt(selectable.fd), events: [.read, .write, .except], action: [.delete, .disable])
    }
    
    func enableWritable(selectable: Selectable, on: Bool) {

        assert(selectable.fd >= 0)
        guard selectable.fd >= 0 else { return }
        updateEventSet(ident: UInt(selectable.fd), events: .write, action: on ? .enable : .disable)
    }
    
    func wakeup() {
        updateEventSet(events: .user, fflags: UInt32(NOTE_TRIGGER | NOTE_FFNOP))
    }
}

extension Selector {
    
    private func updateEventSet(
        ident: UInt = 0,
        events: EventSet = [],
        action: ActionSet = [],
        fflags: UInt32 = 0,
        data: Int = 0,
        udata: UnsafeMutableRawPointer? = nil) {
            
        for filter in events.filterList {
            var event = kevent()
            event.ident = ident
            event.filter = Int16(filter)
            event.flags = UInt16(action.rawValue)
            event.fflags = fflags
            event.data = data
            event.udata = udata
            
            withUnsafeMutablePointer(to: &event) { ptr in
                let arr = UnsafeMutableBufferPointer(start: ptr, count: 1)
                kevent(self.selectorFd, arr.baseAddress, Int32(arr.count), nil, 0, nil)
            }
        }
    }
    
    func doubleEventArrayIfNeeded(ready: Int) {
          guard ready == eventsCapacity else { return }
          Selector.deallocateEventsArray(events: events, capacity: eventsCapacity)
          // double capacity
          eventsCapacity = eventsCapacity * 2
          events = Selector.allocateEventsArray(capacity: eventsCapacity)
      }
    
    private static func allocateEventsArray(capacity: Int) -> UnsafeMutablePointer<kevent> {
        let events: UnsafeMutablePointer<kevent> = UnsafeMutablePointer.allocate(capacity: capacity)
        events.initialize(to: kevent())
        return events
    }

    private static func deallocateEventsArray(events: UnsafeMutablePointer<kevent>, capacity: Int) {
        events.deinitialize(count: capacity)
        events.deallocate()
    }
}


extension TimeInterval {
    func toTimespec() -> timespec {
        let sec: Int = Int(self)
        let nsec: Int = Int((self - TimeInterval(sec))*1000_000_000)
        return timespec(tv_sec: __darwin_time_t(sec), tv_nsec: nsec)
    }
}


protocol Selectable {
    var isActive: Bool { get }
    
    var fd: Int32 { get }

    func onEvents(_ events: EventSet)
}
