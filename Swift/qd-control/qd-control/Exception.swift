//
//  Exception.swift
//  qd-control
//
//  Created by Edward Janne on 10/25/23.
//

import Foundation

struct Exception: Error {
    var file: String
    var function: String
    var line: Int
    var message: String
    
    var localizedDescription: String {
        get {
            return "\(file) \(function) \(line): \(message)"
        }
    }
}
