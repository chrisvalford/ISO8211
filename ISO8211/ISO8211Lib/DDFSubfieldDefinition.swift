//
//  DDFSubfieldDefinition.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public struct DDFSubfieldDefinition {

    private(set) var name = ""  // a.k.a. subfield mnemonic
    private var formatString = ""

    private(set) var dataType: DataType = .stringType
    private(set) var binaryFormat: BinaryFormat = .notBinary

    // isVariable determines whether we using the
    // formatDelimeter (true), or the fixed width (false).
    private var isVariable: Bool = true

    private var formatDelimeter = DDF_UNIT_TERMINATOR

    // zero for variable
    private(set) var formatWidth = 0
    
    private var maximumBufferCharacters = 0
    private var asciiBuffer: [UInt8] = []

    public func getFormat() -> String {
        return formatString
    }

    public mutating func setFormat(_ format: String) -> Bool {
        formatString.removeAll()
        formatString = format

        if formatString.count > 1 {
            // These values will likely be used.
            if formatString[1] == "(" {
                let bytesStr = formatString.substring(from: 2)
                var str = ""
                for ch in bytesStr {
                    if ch.isNumber {
                        str.append(ch)
                    } else {
                        break
                    }
                }
                formatWidth = Int(str) ?? 0
                isVariable = (formatWidth == 0)
            } else {
                isVariable = true
            }
        }

        // Interpret the format string.
        switch formatString[0] {
        case "A", "C": // It isn't clear to me how this is different than 'A'
            dataType = .stringType

        case "R":
            dataType = .floatType

        case "I", "S":
            dataType = .intType

        case "B", "b":
            // Is the width expressed in bits? (is it a bitstring)
            isVariable = false
            if formatString.count > 1 {
                if formatString[1] == "(" {
                    let bytesStr = formatString.substring(from: 2)
                    let value = Int(bytesStr) ?? 0
                    assert(value % 8 == 0)
                    formatWidth = value / 8
                    binaryFormat = .signedInteger
                    
                    if formatWidth < 5 {
                        dataType = .intType
                    } else {
                        dataType = .binaryStringType
                    }
                } else { // or do we have a binary type indicator? (is it binary)
                    var charValue = formatString[1].asciiValue!
                    charValue -= "0".byte
                    binaryFormat = BinaryFormat(rawValue: Int(charValue))!
                    let bytesStr = formatString.substring(from: 2)
                    formatWidth = Int(bytesStr) ?? 0
                    if binaryFormat == .signedInteger || binaryFormat == .unsignedInteger {
                        dataType = .intType
                    } else {
                        dataType = .floatType
                    }
                }
            }

        case "X":
            print("Format type of \(formatString[0]) not supported.")
            return false

        default:
            print("Format type of \(formatString[0]) not recognised.")
            return false
        }

        return true
    }

    public func getName() -> String {
        return name
    }

    public mutating func setName(_ name: String) {
        //TODO: Do we still have to check for trailing 0
        self.name = name
    }

    /**
     * Extract a zero terminated string containing the data for this subfield.
     * Given a pointer to the data
     * for this subfield (from within a DDFRecord) this method will return the
     * data for this subfield.  The number of bytes
     * consumed as part of this field can also be fetched.  This number may
     * be one longer than the string length if there is a terminator character
     * used.
     *
     * This function will return the raw binary data of a subfield for
     * types other than DDFString, including data past zero chars.  This is
     * the standard way of extracting DDFBinaryString subfields for instance.<p>
     *
     * - Parameter data The pointer to the raw data for this field.  This
     * may have come from DDFRecord::getData(), taking into account skip factors
     * over previous subfields data.
     * - Parameter maximumBytes The maximum number of bytes that are accessable after
     * pachSourceData.
     * - Parameter bytesConsumed Pointer to an integer into which the number of
     * bytes consumed by this field should be written.  May be NULL to ignore.
     * This is used as a skip factor to increment pachSourceData to point to the
     * next subfields data.
     *
     * - Returns A `UInt8` array of the fields data.
     */
    mutating func extractStringData(data: Data,
                                    maximumBytes: Int,
                                    bytesConsumed: inout Int?) -> [UInt8] {
        let nLength = getDataLength(data: data,
                                    maximumBytes: maximumBytes,
                                    bytesConsumed: &bytesConsumed)

        // Do we need to grow the buffer.
        if maximumBufferCharacters < nLength { // +1 {
            asciiBuffer.removeAll()
            maximumBufferCharacters = nLength // +1
            asciiBuffer = [UInt8](repeating: 0, count: maximumBufferCharacters)
        }

        // Copy the data to the buffer.  We use memcpy() so that it
        // will work for binary data.
        if nLength > 0 {
            let bytes: [UInt8] = Array(data)
            let subBytes = Array(bytes[...(nLength-1)]) //FIXME: one byte too long so -1
            asciiBuffer = subBytes
        }
        return asciiBuffer
    }

    /**
     * Extract a subfield value as a float.  Given a pointer to the data
     * for this subfield (from within a DDFRecord) this method will return the
     * floating point data for this subfield.  The number of bytes
     * consumed as part of this field can also be fetched.  This method may be
     * called for any type of subfield, and will return zero if the subfield is
     * not numeric.
     *
     * - Parameter pachSourceData The pointer to the raw data for this field.  This
     * may have come from DDFRecord::getData(), taking into account skip factors
     * over previous subfields data.
     * - Parameter nMaxBytes The maximum number of bytes that are accessable after
     * pachSourceData.
     * - Parameter pnConsumedBytes Pointer to an integer into which the number of
     * bytes consumed by this field should be written.  May be NULL to ignore.
     * This is used as a skip factor to increment pachSourceData to point to the
     * next subfields data.
     *
     * - Returns The subfield's numeric value (or zero if it isn't numeric).
     */
    mutating func extractFloatData(data: Data,
                                   maximumBytes: Int,
                                   bytesConsumed: inout Int?) -> Double {
        switch formatString[0] {
        case "A", "I", "R", "S", "C":
            let bytes = extractStringData(data: data,
                                          maximumBytes: maximumBytes,
                                          bytesConsumed: &bytesConsumed)
            let bytesStr = String(bytes: bytes, encoding: .utf8) ?? ""
            return Double(bytesStr) ?? 0

        case "B", "b":
            let abyData: [UInt8] = [0,0,0,0,0,0,0,0]
            assert(formatWidth <= maximumBytes)
            if bytesConsumed != nil {
                bytesConsumed = formatWidth
            }

            // Byte swap the data if it isn't in machine native format.
            // In any event we copy it into our buffer to ensure it is
            // word aligned.

            //            if formatString[0] == "B".byte || formatString[0] == "b".byte {
            //                for i in 0..<formatWidth {
            //                    abyData[formatWidth-i-1] = pachSourceData[i];
            //                }
            //            } else {
            //                    memcpy(abyData, pachSourceData, formatWidth);
            //            }

            // Interpret the bytes of data.
            switch binaryFormat {
//            case .unsignedInteger, .signedInteger, .floatReal:
//                let n = formatString[0] == "B" ? MoreMath.buildIntegerBE(bytevec: abyData, offset: 0) : MoreMath.buildIntegerLE(bytevec: abyData, offset: 0)
//                return Double(n)

            case .unsignedInteger:
                if formatWidth == 1 {
                    let byte = abyData[0]
                    let str = String(bytes: [byte], encoding: .utf8) ?? ""
                    return Double(str) ?? 0
                } else if formatWidth == 2 {
                    let abyStr = String(bytes: abyData, encoding: .utf8) ?? ""
                    return Double(abyStr) ?? 0
                }

            case .signedInteger:
                let abyStr = String(bytes: abyData, encoding: .utf8) ?? ""
                return Double(abyStr) ?? 0

            case .floatReal:
                let abyStr = String(bytes: abyData, encoding: .utf8) ?? ""
                return Double(abyStr) ?? 0

            case .notBinary, .floatingPointReal, .floatComplex:
                return 0.0
            }
            // end of 'b'/'B' case.


        default:
            return 0.0
        }
        return 0.0
    }

    /**
     * Extract a subfield value as an integer.  Given a pointer to the data
     * for this subfield (from within a DDFRecord) this method will return the
     * int data for this subfield.  The number of bytes
     * consumed as part of this field can also be fetched.  This method may be
     * called for any type of subfield, and will return zero if the subfield is
     * not numeric.
     *
     * - Parameter data The pointer to the raw data for this field.  This
     * may have come from DDFRecord::getData(), taking into account skip factors
     * over previous subfields data.
     * - Parameter maximumBytes The maximum number of bytes that are accessable after
     * pachSourceData.
     * - Parameter bytesConsumed Pointer to an integer into which the number of
     * bytes consumed by this field should be written.  May be NULL to ignore.
     * This is used as a skip factor to increment pachSourceData to point to the
     * next subfields data.
     *
     * - Returns The subfield's numeric value (or zero if it isn't numeric).
     */
    mutating func extractIntData(data: Data,
                                 maximumBytes: Int,
                                 bytesConsumed: inout Int?) -> Int {
        switch formatString[0] {
        case "A", "I", "R", "S", "C":
            let bytes = extractStringData(data: data,
                                          maximumBytes: maximumBytes,
                                          bytesConsumed: &bytesConsumed)
            let bytesStr = String(bytes: bytes, encoding: .utf8) ?? ""
            return Int(bytesStr) ?? 0

        case "B", "b":
            var abyData = [UInt8](repeating: 0, count: 80)
            if formatWidth > maximumBytes {
                print("Attempt to extract int subfield \(name) with format \(formatString)")
                print("failed as only \(maximumBytes) bytes available.  Using zero.")
                return 0
            }
            if bytesConsumed != nil {
                bytesConsumed = formatWidth
            }

            // Byte swap the data if it isn't in machine native format.
            // In any event we copy it into our buffer to ensure it is
            // word aligned.

//            if formatString[0] == "B" || formatString[0] == "b" {
                // Reverse the bytes
//                for i in 0..<formatWidth {
//                    let source: [UInt8] = Array(data)
//                    //Skip the leading CR (10)if present
////                    if source[0] == 10 {
////                        source = Array(source[1...])
////                    }
//                    let index = formatWidth-i-1
//                    abyData[index] = source[i]
//                }
//            } else {

            if formatWidth == 0 {
                print("Zero length format width.")
                print("Possible Field name: VRPT: description: Vector record pointer field (VS)        NAME = 0x(VS) 78(VS) 72(VS) 02(VS) 00(VS) 00(VS)    VRID RCNM = 120,RCID = 626(VS)        ORNT = 255")
                abyData = Array(data)
            }

            else if formatWidth == 1 {
                if let byte = data.first {
                    abyData = [byte]
                }
            } else {
                let byteArray = Array(data)
                let subBytes = byteArray[0...formatWidth-1]
                //let subBytes = data.prefix(upTo: formatWidth)
                abyData = Array(subBytes)
            }
//                let data: [UInt8] = Array(data)
//                abyData = Array(data[...formatWidth])
//            }

            // Interpret the bytes of data.
            switch binaryFormat {
//            case .unsignedInteger, .signedInteger, .floatReal:
//                let n = formatString[0] == "B" ? MoreMath.buildIntegerBE(bytevec: abyData, offset: 0) : MoreMath.buildIntegerLE(bytevec: abyData, offset: 0)
//                return n

            case .unsignedInteger:
                if formatWidth == 4 {
                    let subData = abyData.prefix(upTo: formatWidth)
                    let x = subData.withUnsafeBytes({
                        (rawPtr: UnsafeRawBufferPointer) in
                        return rawPtr.load(as: Int32.self)
                    })
                    return Int(x)

//                    var str = String(bytes: subData, encoding: .ascii) ?? ""
//                    if str.last != "\0" {
//                        str.append("\0")
//                    }
//                    return Int(str) ?? 0
                } else if formatWidth == 1 {
                    return Int(abyData[0])
                } else if formatWidth == 2 {
                    let subData = abyData.prefix(upTo: formatWidth)
                    let x = subData.withUnsafeBytes({
                        (rawPtr: UnsafeRawBufferPointer) in
                        return rawPtr.load(as: Int16.self)
                    })
                    return Int(x)
//                    let first = abyData[0] * 2
//                    let second = abyData[1] * 4
//                    let sum = first + second
//                    let str = String(bytes: abyData, encoding: .ascii) ?? ""
//                    return Int(sum)
                } else {
                    return 0
                }

            case .signedInteger:
                if formatWidth == 4 {
                    let x = abyData.withUnsafeBytes({
                        (rawPtr: UnsafeRawBufferPointer) in
                        return rawPtr.load(as: Int32.self)
                    })
                    return Int(x)
//                    let str = String(bytes: abyData, encoding: .utf8) ?? ""
//                    return Int(str) ?? 0
                } else if (formatWidth == 1 ) {
                    let str = String(bytes: abyData, encoding: .utf8) ?? ""
                    return Int(str) ?? 0
                } else if (formatWidth == 2 ) {
                    let str = String(bytes: abyData, encoding: .utf8) ?? ""
                    return Int(str) ?? 0
                } else {
                    return 0
                }

            case .floatReal:
                if formatWidth == 4 {
                    let x = abyData.withUnsafeBytes({
                        (rawPtr: UnsafeRawBufferPointer) in
                        return rawPtr.load(as: Int32.self)
                    })
                    return Int(x)
//                    let str = String(bytes: abyData, encoding: .utf8) ?? ""
//                    return Int(str) ?? 0
                } else if (formatWidth == 8 ) {
                    let str = String(bytes: abyData, encoding: .utf8) ?? ""
                    return Int(str) ?? 0
                } else {
                    return 0
                }

            case .notBinary, .floatingPointReal, .floatComplex:
                return 0
            }
            // end of 'b'/'B' case.

        default:
            return 0
        }
    }

    /**
     * Scan for the end of variable length data.  Given a pointer to the data
     * for this subfield (from within a DDFRecord) this method will return the
     * number of bytes which are data for this subfield.  The number of bytes
     * consumed as part of this field can also be fetched.  This number may
     * be one longer than the length if there is a terminator character
     * used.<p>
     *
     * This method is mainly for internal use, or for applications which
     * want the raw binary data to interpret themselves.  Otherwise use one
     * of ExtractStringData(), ExtractIntData() or ExtractFloatData().
     *
     * - Parameter pachSourceData The pointer to the raw data for this field.  This
     * may have come from DDFRecord::getData(), taking into account skip factors
     * over previous subfields data.
     * - Parameter nMaxBytes The maximum number of bytes that are accessable after
     * pachSourceData.
     * - Parameter pnConsumedBytes Pointer to an integer into which the number of
     * bytes consumed by this field should be written.  May be NULL to ignore.
     *
     * - Returns The number of bytes at pachSourceData which are actual data for
     * this record (not including unit, or field terminator).
     */
    func getDataLength(data: Data,
                       maximumBytes: Int,
                       bytesConsumed: inout Int?) -> Int {

        let bytes = Array(data)

        if !isVariable {
            if formatWidth > maximumBytes {
                print("Only \(maximumBytes) bytes available for subfield \(name) with")
                print("format string \(formatString) ... returning shortened data.")
                if bytesConsumed != nil {
                    bytesConsumed = maximumBytes
                }
                return maximumBytes
            } else {
                if bytesConsumed != nil {
                    bytesConsumed = formatWidth
                }
                return formatWidth
            }
        } else {
            var length = 0
            var checkFieldTerminator = true

            /* We only check for the field terminator because of some buggy
             * datasets with missing format terminators.  However, we have found
             * the field terminator is a legal character within the fields of
             * some extended datasets (such as JP34NC94.000).  So we don't check
             * for the field terminator if the field appears to be multi-byte
             * which we established by the first character being out of the
             * ASCII printable range (32-127).
             */
            if bytes[0] < 32 || bytes[0] >= 127 {
                checkFieldTerminator = false
            }

            while length < maximumBytes && bytes[length] != formatDelimeter  {
                if checkFieldTerminator && bytes[length] == DDF_FIELD_TERMINATOR  {
                    break
                }
                length += 1
            }

            if bytesConsumed != nil {
                if maximumBytes == 0 {
                    bytesConsumed = length
                } else {
                    bytesConsumed = length+1
                }
            }
            return length
        }
    }
}
