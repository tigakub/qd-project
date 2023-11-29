//
//  BinaryCodable.swift
//  qd-control
//
//  Created by Edward Janne on 10/25/23.
//

import Foundation

protocol BinaryDecoder {
    func decode<T>(_ : T.Type)->T
}

protocol BinaryEncoder {
    func encode<T>(_ : T)
}

protocol BinaryCodable {
    init(from decoder: BinaryDecoder)
    func encode(to encoder: BinaryEncoder)
}

class QDDecoder: BinaryDecoder {
    var data: Data
    var streamIndex: Int
    
    init(source: Data) {
        data = source
        streamIndex = 0
    }
    
    func decode<T: BinaryCodable>(_ : T.Type)->T {
        return T(from: self)
    }
    
    func decode<T>(_ type: T.Type)->T {
        return data.withUnsafeBytes {
            var t: T
            t = $0.load(fromByteOffset: streamIndex, as: T.self)
            return t
        }
    }
}

class QDEncoder: BinaryEncoder {
    var capacity: Int
    var data: Data
    
    init(capacity: Int = 68) {
        self.capacity = capacity
        data = Data(capacity: capacity)
    }
    
    func encode<T: BinaryCodable>(_ encodable: T) {
        encodable.encode(to: self)
        if data.count < capacity {
            data.append(contentsOf: [UInt8](repeating: 0, count: capacity - data.count))
        }
    }
    
    func encode<T>(_ value: T) {
        withUnsafePointer(to: value) {
            ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size) {
                ptr in
                data.append(ptr, count: MemoryLayout<T>.size)
            }
        }
    }
}
