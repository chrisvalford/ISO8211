//
//  String+.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public extension String {

    var byte: UInt8 {
        return self.utf8.first ?? 0
    }

    var bytes: [UInt8] {
        let bytes = self.utf8
        return [UInt8](bytes)
    }

    subscript (at: Int) -> Character {
        return self[index(startIndex, offsetBy: at)]
    }

    func character(at: Int) -> Character {
        return self[index(startIndex, offsetBy: at)]
    }

    func value(at: Int) -> UInt8 {
        let ch = self[index(startIndex, offsetBy: at)]
        return ch.utf8.first ?? 0
    }

    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }

    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }

    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }

    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
}

extension String {
    var trimmed: String {
        if self.first != "0" {
            return self
        }
        var str = self
        //TODO: Try this
        //return String(str.trimmingPrefix(while: "0"))
        while str.first == "0" {
            str = String(str.dropFirst())
        }
        return str
    }
}
