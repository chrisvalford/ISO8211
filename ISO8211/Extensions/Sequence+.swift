//
//  Sequence+.swift
//  ISO8211
//
//  Created by Christopher Alford on 25/4/22.
//

import Foundation

// Convert array of characters to an array of UInt8
public extension Sequence where Element == Character {
    var byteArray: [UInt8] {
        return String(self).utf8.map{UInt8($0)}
    }
}

// Convert [UInt8] to String
public extension Sequence where Element == UInt8 {
    var string: String {
        return String(bytes: self, encoding: String.Encoding.ascii) ?? ""
    }

    func int(at index: Int, length: Int) -> Int? {
        let bytes = Array(self)
        // Might have to remove leading zeros
        let ss = Array(bytes[index...(index+length)])
        let intS = String(bytes: ss, encoding: .utf8) ?? ""
        return Int(intS)
    }
}
