//
//  UInt8+.swift
//  ISO8211
//
//  Created by Christopher Alford on 25/4/22.
//

import Foundation

public extension UInt8 {
    var isNumber: Bool {
        if (48...57).contains(self) {
            return true
        }
        return false
    }

    func isAlpha() -> Bool {
        var isAlpha = false
        if (97...122) ~= self {
           isAlpha = true
        }
        else if (65...90) ~= self {
            isAlpha = true
        }
        return isAlpha
    }
}
