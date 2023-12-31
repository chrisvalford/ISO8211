//
//  Maths.swift
//  ISO8211F
//
//  Created by Christopher Alford on 15/5/23.
//

import Foundation

struct MoreMath {
    /**
     * Converts a byte in the range of -128 to 127 to an int in the
     * range 0 - 255.
     *
     * - Parameter b (-128 &lt;= b &lt;= 127)
     * - Returns int (0 &lt;= b &lt;= 255)
     */
    public static func signedToInt(b: UInt8) -> Int {
        return Int(b & 0xff)
    }

    /**
     * Build int out of bytes (in big endian order).
     *
     * - Parameter bytevec bytes
     * - Parameter offset byte offset
     * - Returns int
     */
    public static func buildIntegerBE(bytevec: [UInt8], offset: Int) -> Int {
        let a = Int((bytevec[0 + offset]) << 24)
        let b = signedToInt(b: bytevec[1 + offset]) << 16
        let c = signedToInt(b: bytevec[2 + offset]) << 8
        let d = signedToInt(b: bytevec[3 + offset])
        return a | b | c | d
    }

    /**
     * Build int out of bytes (in little endian order).
     *
     * - Parameter bytevec bytes
     * - Parameter offset byte offset
     * - Returns int
     */
    public static func buildIntegerLE(bytevec: [UInt8], offset: Int) -> Int {
        let a = Int((bytevec[3 + offset]) << 24)
        let b = signedToInt(b: bytevec[2 + offset]) << 16
        let c = signedToInt(b: bytevec[1 + offset]) << 8
        let d = signedToInt(b: bytevec[0 + offset])
        return a | b | c | d
    }
}
