//
//  CircularBuffer.swift
//  SwiftSocket
//
//  Created by dlleng on 2021/8/11.
//

import Foundation


public struct ByteBuffer {
    typealias Element = UInt8
    private var buffer: [Element]
    private var readIndex = 0
    private var writeIndex = 0
    private(set) var capacity: Int
    public var count: Int { max(0, writeIndex - readIndex) }
    internal var userInfo: [String: Any]?
    
    init(capacity: Int = 1024) {
        self.capacity = capacity
        buffer = [Element](repeating: 0, count: capacity)
    }
    
    init(data: Data) {
        let bytesArr = [UInt8](data)
        buffer = bytesArr
        capacity = bytesArr.count
        readIndex = 0
        writeIndex = bytesArr.count
        
    }
    
    public func toData() -> Data {
        let buf = [UInt8](buffer[readIndex..<writeIndex])
        return Data(bytes: buf, count: buf.count)
    }
    
    mutating func readPointer() -> UnsafeRawBufferPointer {
        let skip = readIndex * MemoryLayout<Element>.stride
        let bufPtr = buffer.withUnsafeMutableBytes {$0}
        return UnsafeRawBufferPointer(start: bufPtr.baseAddress?.advanced(by: skip), count: count)
    }
    
    mutating func writePointer() -> UnsafeMutableRawBufferPointer {
        let skip = writeIndex * MemoryLayout<Element>.stride
        let bufPtr = buffer.withUnsafeMutableBytes {$0}
        return UnsafeMutableRawBufferPointer(start: bufPtr.baseAddress?.advanced(by: skip), count: count)
    }
    
    ///read/write
    mutating func readInteger<T: FixedWidthInteger>(_ type: T.Type,bigendian: Bool = true) -> T? {
        let size = MemoryLayout<T>.size
        guard size <= count else { return nil }
        var value: T = 0
        let skip = readIndex * MemoryLayout<Element>.stride
        let valuePtr = withUnsafeMutableBytes(of: &value) {$0}
        let bufPtr = buffer.withUnsafeMutableBytes {$0}
        let readPtr = UnsafeRawBufferPointer(start: bufPtr.baseAddress?.advanced(by: skip), count: count)
        valuePtr.copyMemory(from: readPtr)
        return bigendian ? value.bigEndian : value.littleEndian
    }
    
    mutating func writeInteger<T: FixedWidthInteger>(_ v: T, bigendian: Bool = true) {
        let size = MemoryLayout<T>.size
        if writeIndex + size > capacity {
            doubleCapacity()
        }
        var value = bigendian ? v.bigEndian : v.littleEndian
        let skip = writeIndex * MemoryLayout<Element>.stride
        let valuePtr = withUnsafeBytes(of: &value) {$0}
        let bufPtr = buffer.withUnsafeMutableBytes {$0}
        let writePtr = UnsafeMutableRawBufferPointer(start: bufPtr.baseAddress?.advanced(by: skip), count: capacity - writeIndex)
        writePtr.copyMemory(from: valuePtr)
        
        moveWriteIndex(by: size)
    }
    
    ///move index
    mutating func moveReadIndex(to newIndex: Int) {
        readIndex = newIndex
    }
    
    mutating func moveWriteIndex(to newIndex: Int) {
        writeIndex = newIndex
    }
    
    mutating func moveReadIndex(by offset: Int) {
        readIndex += offset
    }
    
    mutating func moveWriteIndex(by offset: Int) {
        writeIndex += offset
    }
    
    mutating func doubleCapacity() {
        let newCapacity = capacity * 2
        var newBuffer = [Element](repeating: 0, count: newCapacity)
        for i in 0..<count {
            newBuffer[i] = buffer[readIndex + i]
        }
        capacity = newCapacity
        buffer = newBuffer
        readIndex = 0
        writeIndex = count
    }
}

struct CircularBuffer<Element>{
    private var buf: ContiguousArray<Element?>
    private var headIndex = 0
    private var tailIndex = 0
    private var mask: Int { buf.count &- 1 }
    
    private(set) var capacity = 0
    var count: Int { (tailIndex - headIndex) & mask }
    var isEmpty: Bool { tailIndex == headIndex }
    var first: Element? {
        if count > 0 { return self[0] }
        return nil
    }
    var last: Element? {
        if count > 0 { return self[count-1] }
        return nil
    }
    
    init() {
        capacity = 8
        buf = ContiguousArray<Element?>(repeating: nil, count: capacity)
    }
    
    mutating func removeAll() {
        buf.removeAll()
        headIndex = 0
        tailIndex = 0
    }
    
    mutating func removeFirst(){
        guard count > 0 else { return }
        buf[headIndex] = nil
        moveHeadIndex(offset: 1)
    }
    
    mutating func removeLast(){
        guard count > 0 else { return }
        buf[(tailIndex - 1) & mask] = nil
        moveTailIndex(offset: 1)
    }
    
    subscript(index: Int) -> Element {
        get{
            buf[(headIndex + index) & mask]!
        }
        set{
            buf[(headIndex + index) & mask] = newValue
        }
    }
    
    mutating func append(_ element: Element) {
        buf[tailIndex] = element
        moveTailIndex(offset: 1)
        if headIndex == tailIndex {
            doubleCapacity()
        }
    }
    
    private mutating func doubleCapacity() {
        let newCapacity = capacity * 2
        var newBuf = ContiguousArray<Element?>(repeating: nil, count: newCapacity)
        let cnt = count
        for i in 0..<cnt {
            newBuf[i] = self[i]
        }
        buf = newBuf
        capacity = newCapacity
        headIndex = 0
        tailIndex = cnt
    }
    
    private mutating func moveHeadIndex(offset: Int){
        headIndex = (headIndex + offset) & mask
    }
    
    private mutating func moveTailIndex(offset: Int){
        tailIndex = (tailIndex + offset) & mask
    }
}


struct Heap<Element: Comparable> {
    var storage: ContiguousArray<Element>
    init() {
        self.storage = []
    }
    
    mutating func removeAll() {
        storage.removeAll()
    }
    
    mutating func append(_ value: Element) {
        var i = storage.count
        self.storage.append(value)
        while i > 0 && storage[i] < storage[i.parentIndex] {
            storage.swapAt(i, i.parentIndex)
            i = i.parentIndex
        }
    }
    
    var root: Element? { storage.first }
    
    @discardableResult
    mutating func removeRoot() -> Element? {
        guard let root = storage.first else {
            return nil
        }
        if storage.count == 1 {
            storage.removeFirst()
            return root
        }
        storage[0] = storage[storage.count - 1]
        storage.removeLast()
        
        _heapify(0)
        
        return root
    }
    
    mutating func heapifyRoot() {
        _heapify(0)
    }
    
    private mutating func _heapify(_ index: Int) {
        let left = index.leftIndex
        let right = index.rightIndex

        var root: Int
        if left < storage.count && storage[left] < storage[index] {
            root = left
        } else {
            root = index
        }

        if right < storage.count && storage[right] < storage[root] {
            root = right
        }

        if root != index {
            storage.swapAt(index, root)
            _heapify(root)
        }
    }
}

fileprivate extension Int {
    var leftIndex: Int { 2*self + 1 }
    var rightIndex: Int { 2*self + 2 }
    var parentIndex: Int { (self-1) / 2 }
}
