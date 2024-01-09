//
//  DDFUtils.swift
//  ISO8211Reader
//
//  Created by Christopher Alford on 28/1/22.
//

import Foundation

public struct DDFUtils {

    /**
     * Fetch a variable length string from a record, and allocate
     * it as a new string.
     */
    public static func fetchVariable(source: String,
                                     maxChars: Int,
                                     delimiter1: UInt8,
                                     delimiter2: UInt8,
                                     consumedChars: Int) -> (Int, String?) {
        var consumed = consumedChars
            var i = 0
        while i < maxChars - 1 && source.value(at: i) != delimiter1 && source.value(at: i) != delimiter2 {
                i += 1
            }
            consumed = i
            if i < maxChars && (source.value(at: i) == delimiter1 || source.value(at: i) == delimiter2) {
                consumed += 1
            }
        if i > 0 {
            let rawString = source.substring(to: i)
            var str = ""
            for ch in rawString {
                if ch.asciiValue != 0 {
                    str.append(ch)
                }
            }
            return (consumed, str)
        }
        return (consumed, "")
    }

    public static func DDFScanInt(source: Data, fromIndex: Int, maxChars: Int) -> Int? {
        var maxChars = maxChars
        if maxChars > 32 || maxChars == 0 {
            maxChars = 32
        }
        if fromIndex+maxChars-1 > source.count {
            return nil
        }
        let data = Array(source[fromIndex...(fromIndex + maxChars - 1)])
        let str = String(bytes: data, encoding: .utf8) ?? ""
        return Int(str)
    }
}
