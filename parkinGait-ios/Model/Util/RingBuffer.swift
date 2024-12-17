//
//  RingBuffer.swift
//  parkinGait-ios
//
//  Created by 신창민 on 12/16/24.
//


struct RingBuffer<T> {
    private var buffer: [T?]
    private var index = 0
    private let size: Int

    init(size: Int) {
        self.size = size
        self.buffer = Array(repeating: nil, count: size)
    }

    mutating func append(_ element: T) {
        buffer[index % size] = element
        index += 1
    }

    func elements() -> [T] {
        // Return the buffer elements in insertion order, ignoring `nil` values
        let start = index >= size ? index % size : 0
        return (buffer[start..<buffer.count] + buffer[0..<start]).compactMap { $0 }
    }

    mutating func clear() {
        buffer = Array(repeating: nil, count: size)
        index = 0
    }
}
