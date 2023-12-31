//
//  DDFUtils.swift
//  ISO8211Reader
//
//  Created by Christopher Alford on 28/1/22.
//

import Foundation

let DDF_FIELD_TERMINATOR = 30
let DDF_UNIT_TERMINATOR = 31

public struct DDFUtils {

//    /// DDFScanVariable
//    /// Establish the length of a variable length string in a record.
//    public static func scanVariable(source: [UInt8], maxChars: Int, delimiter: UInt8) -> Int {
//        var i = 0
//        while i < maxChars - 1 && source[i] != delimiter {
//            i += 1
//        }
//        return i
//    }
//
    /// DDFFetchVariable
    /// Fetch a variable length string from a record, and allocate
    /// it as a new string (with CPLStrdup()).
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
            //var newBuffer = [UInt8](repeating: 0, count: i)
            let rawString = source.substring(to: i)
            //let rawString = String(bytes: newBuffer, encoding: .utf8) ?? ""
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

//    /*
//     public static void arraycopy(Object source_arr, int sourcePos,
//                                 Object dest_arr, int destPos, int len)
//     Parameters :
//     source_arr : array to be copied from
//     sourcePos : starting position in source array from where to copy
//     dest_arr : array to be copied in
//     destPos : starting position in destination array, where to copy in
//     len : total no. of components to be copied.
//     //============
//     The java.lang.System.arraycopy() method copies a source array from a specific beginning position to the destination array from the mentioned position. No. of arguments to be copied are decided by len argument.
//     The components at source_Position to source_Position + length – 1 are copied to destination array from destination_Position to destination_Position + length – 1
//     */
//
//    /// Our version inserts the source into the destination so the array may have trailing data!!!
//    public static func arraycopy(_ sourceArray: [CChar],
//                          _ sourceIndex: Int,
//                          _ destinationArray: inout [CChar],
//                          _ destinationIndex: Int,
//                          _ count: Int) throws {
//        if sourceArray.count == 0 {
//            throw Exception.ArrayIndexOutOfBoundsException
//        }
//        if sourceIndex < 0 || destinationIndex < 0 {
//            throw Exception.ArrayIndexOutOfBoundsException
//        }
//        if sourceIndex + count - 1 > sourceArray.count {
//            throw Exception.ArrayIndexOutOfBoundsException
//        }
//
//        let subArray = Array(sourceArray[sourceIndex...(sourceIndex + count - 1)])
//        destinationArray.insert(contentsOf: subArray, at: destinationIndex)
//    }
//
//    public static func DDFScanInt(source: CString, nMaxChars: Int ) -> Int? {
//        var maxChars = nMaxChars
//        if maxChars > 32 || maxChars == 0 {
//            maxChars = 32
//        }
//        let data = Array(source[0...(nMaxChars - 1)])
//        let str = data.toString()
//        return Int(str)
//    }

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
