//
//  DDFFieldDefinition.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public struct DDFFieldDefinition {
    private var module: DDFModule?
    private var tag = ""
    private var _fieldName = ""
    private var arrayDescription = ""
    private var formatControls = ""
    private var repeatingSubfields = false
    private(set) var fixedWidth = 0 // zero if variable.
    private var dataStructCode = DataStructCode.elementary
    private var dataTypeCode: DataTypeCode = .charString
    private(set) var subfieldCount = 0
    private(set) var subfieldDefinitions: [DDFSubfieldDefinition] = []

    public mutating func initialize(module: DDFModule,
                                    tag: String,
                                    fieldEntrySize: Int,
                                    data: Data) -> Bool {
        var offset = module.fieldControlLength
        self.module = module
        self.tag = tag

        guard let dataStr = String(data: data, encoding: .utf8) else {
            print("Failed to get string from pachFieldData")
            return false
        }

        // Set the data struct and type codes.
        switch dataStr[0] {
        case "0":
            dataStructCode = .elementary

        case "1":
            dataStructCode = .vector

        case "2":
            dataStructCode = .array

        case "3":
            dataStructCode = .concatenated

        default:
            print("Unrecognised data_struct_code value \(data[0]).")
            print("Field \(tag) initialization incorrect.")
            dataStructCode = .elementary
        }

        switch(dataStr[1]) {
        case "0":
            dataTypeCode = .charString

        case "1":
            dataTypeCode = .implicitPoint

        case "2":
            dataTypeCode = .explicitPoint

        case "3":
            dataTypeCode = .explicitPointScaled

        case "4":
            dataTypeCode = .charBitString

        case "5":
            dataTypeCode = .bitString

        case "6":
            dataTypeCode = .mixedDataType

        default:
            print("Unrecognised data_type_code value \(data[1]).")
            print("Field \(tag) initialization incorrect.")
            dataTypeCode = .charString
        }

        // Capture the field name, description (sub field names), and format statements.
        var result = DDFUtils.fetchVariable(source: dataStr.substring(from: offset),
                                            maxChars: fieldEntrySize - offset,
                                            delimiter1: UInt8(DDF_UNIT_TERMINATOR),
                                            delimiter2: UInt8(DDF_FIELD_TERMINATOR))
        offset += result.0
        _fieldName = result.1 ?? ""

        result = DDFUtils.fetchVariable(source: dataStr.substring(from: offset),
                                        maxChars: fieldEntrySize - offset,
                                        delimiter1: UInt8(DDF_UNIT_TERMINATOR),
                                        delimiter2: UInt8(DDF_FIELD_TERMINATOR))
        offset += result.0
        arrayDescription = result.1 ?? ""

        result = DDFUtils.fetchVariable(source: dataStr.substring(from: offset),
                                        maxChars: fieldEntrySize - offset,
                                        delimiter1: UInt8(DDF_UNIT_TERMINATOR),
                                        delimiter2: UInt8(DDF_FIELD_TERMINATOR))
        formatControls = result.1 ?? ""

        // Parse the subfield info.
        if dataStructCode != .elementary {
            if buildSubfields() == false {
                return false
            }


            if applyFormats() == false {
                return false
            }
        }
        return true
    }

    /** Fetch a pointer to the field name (tag).
     * - Returns this is an internal copy and shouldn't be freed.
     */
    var fieldName: String { return tag }

    /** Fetch a longer description of this field. */
    var fieldDescription: String { return _fieldName }

    /**
     * Fetch a subfield by index.
     *
     * - Parameter i The index subfield index. (Between 0 and GetSubfieldCount()-1)
     *
     * - Returns The subfield, or nil if the index is out of range.
     */
    public func getSubfield(at i: Int) -> DDFSubfieldDefinition? {
        if i < 0 || i >= subfieldCount {
            return nil
        }
        return subfieldDefinitions[i]
    }

    /**
     * Fetch repeating flag.
     * - Returns `true` if the field is marked as repeating.
     */
    func isRepeating() -> Bool { return repeatingSubfields }

    /** this is just for an S-57 hack for swedish data */
    mutating func setRepeatingFlag(_ n: Bool) { repeatingSubfields = n }

    /**
     * Based on the `_arrayDescr` build a set of subfields.
     */
    private mutating func buildSubfields() -> Bool {
        var subfieldNames: [String]
        var pszSublist = arrayDescription

        /* -------------------------------------------------------------------- */
        /*      It is valid to define a field with _arrayDesc                   */
        /*      '*STPT!CTPT!ENPT*YCOO!XCOO' and formatControls '(2b24)'.        */
        /*      This basically indicates that there are 3 (YCOO,XCOO)           */
        /*      structures named STPT, CTPT and ENPT.  But we can't handle      */
        /*      such a case gracefully here, so we just ignore the              */
        /*      "structure names" and treat such a thing as a repeating         */
        /*      YCOO/XCOO array.  This occurs with the AR2D field of some       */
        /*      AML S-57 files for instance.                                    */
        /*                                                                      */
        /*      We accomplish this by ignoring everything before the last       */
        /*      '*' in the subfield list.                                       */
        /* -------------------------------------------------------------------- */

        let last = pszSublist.lastIndex(of: "*")
        if last != nil {
            pszSublist = String(pszSublist[last!...])
        }
        
        // Strip off the repeating marker, when it occurs, but mark our field as repeating.
        if pszSublist.hasPrefix("*") {
            repeatingSubfields = true
            pszSublist = String(pszSublist.dropFirst())
        }

        // Split list of fields.
        subfieldNames = pszSublist.components(separatedBy: "!")

        // Minimally initialize the subfields.
        let nSFCount = subfieldNames.count
        for iSF in 0..<nSFCount {
            var poSFDefn = DDFSubfieldDefinition()
            poSFDefn.setName(subfieldNames[iSF])
            addSubfield(poSFDefn, dontAddToFormat: true)
        }
        subfieldNames.removeAll()
        return true
    }

    /**
     * This method parses the format string partially, and then
     *  applies a subfield format string to each subfield object.
     *  It in turn does final parsing of the subfield formats.
     */
    private mutating func applyFormats() -> Bool {
        var formatList = ""

        // Verify that the format string is contained within brackets.
        if formatControls.count < 2
            || !formatControls.hasPrefix("(")
            || !formatControls.hasSuffix(")") {
            print("Format controls for \(tag) field missing brackets: \(formatControls)")
            return false
        }

        // Duplicate the string, and strip off the brackets.
        formatList = expandFormat(source: formatControls)

        // Tokenize based on commas.
        var formatItems = formatList.components(separatedBy: ",")
        formatList.removeAll()

        // Apply the format items to subfields.
        var formatItemIndex = 0
        for formatItem in formatItems {
            var pastPrefix = formatItem //paformatItems[iFormatItem]

            // Skip over any leading numbers
            var n = 0
            while pastPrefix[n].asciiValue! >= "0".byte && pastPrefix[n].asciiValue! <= "9".byte && n < pastPrefix.count {
                n += 1
            }
            if n > 0 {
                pastPrefix = pastPrefix.substring(from: n)
            }

            // Did we get too many formats for the subfields created by names?
            // This may be legal by the 8211 specification, but isn't encountered
            // in any formats we care about so we just blow.
            if formatItemIndex >= subfieldCount {
                print("Got more formats than subfields for field \(tag).")
                break
            }
            if !subfieldDefinitions[formatItemIndex].setFormat(pastPrefix) {
                return false
            }
            formatItemIndex += 1
        }

        // Verify that we got enough formats, cleanup and return.
        formatItems.removeAll()
        if formatItemIndex < subfieldCount-1 {
            print("Got less formats than subfields for field \(tag).");
            return false
        }

        // If all the fields are fixed width, then we are fixed width too.
        // This is important for repeating fields.
        fixedWidth = 0
        for i in 0..<subfieldCount {
            if subfieldDefinitions[i].formatWidth == 0 {
                fixedWidth = 0
                break
            } else {
                fixedWidth += subfieldDefinitions[i].formatWidth
            }
        }
        return true
    }

    private mutating func addSubfield(_ newSubfieldDefinition: DDFSubfieldDefinition,
                              dontAddToFormat: Bool) {
        subfieldCount += 1
        subfieldDefinitions.append(newSubfieldDefinition)
        if dontAddToFormat {
            return
        }

    // Add this format to the format list.  We don't bother aggregating formats here.
        if formatControls.isEmpty {
            formatControls = "()"
        }

        let oldCount = formatControls.count
        var newFormatControls = formatControls

        if newFormatControls[oldCount-2] != "(" {
            newFormatControls.append(",")
        }

        newFormatControls.append(contentsOf: newSubfieldDefinition.getFormat())
        newFormatControls.append(")")
        formatControls.removeAll()
        formatControls = newFormatControls

        // Add the subfield name to the list.
        arrayDescription.removeAll()
        if arrayDescription.count > 0 {
            arrayDescription.append("!")
        }
        arrayDescription.append(contentsOf: newSubfieldDefinition.getName())
    }

    let comma = ",".byte
    let openingParenthesis = "(".byte
    let closingParenthesis = ")".byte

    /**
     * Extract a substring terminated by a comma (or end of string).
     * Commas in brackets are ignored as terminated with bracket
     * nesting understood gracefully. If the returned string would
     * being and end with a bracket then strip off the brackets.
     * <P>
     * Given a string like "(A,3(B,C),D),X,Y)" return "A,3(B,C),D".
     * Give a string like "3A,2C" return "3A".
     */
    func extractSubstring(source: String) -> String {
        let sourceBytes: [UInt8] = Array(source.utf8)
        var bracketCount = 0
        var returnBytes: [UInt8] = []
        var i = 0
        while (i < sourceBytes.count) && (bracketCount > 0 || sourceBytes[i] != comma) {
            if sourceBytes[i] == openingParenthesis {
                bracketCount += 1
            } else if sourceBytes[i] == closingParenthesis {
                bracketCount -= 1
            }
            i += 1
        }
        if sourceBytes[0] == openingParenthesis {
            returnBytes = Array(sourceBytes[1...(i - 2)])
        } else {
            if i < sourceBytes.count {
                returnBytes = Array(sourceBytes[0...i])
            } else {
                returnBytes = sourceBytes
            }
        }
        if returnBytes.last == comma {
            return String(bytes: Array(returnBytes.dropLast()), encoding: .utf8) ?? ""
        }
        return String(bytes: returnBytes, encoding: .utf8) ?? ""
    }

    /**
     * Given a string that contains a coded size symbol, expand it
     * out.
     */
    func expandFormat(source: String) -> String {
        let sourceBytes: [UInt8] = Array(source.utf8)
        var destinationBytes: [UInt8] = []
        var sourceIndex = 0
        var repeatCount = 0

        while sourceIndex < sourceBytes.count {
            /*
             * This is presumably an extra level of brackets around
             * some binary stuff related to rescanning which we don't
             * care to do (see 6.4.3.3 of the standard. We just strip
             * off the extra layer of brackets
             */
            if ((sourceIndex == 0 || sourceBytes[sourceIndex - 1] == comma) && sourceBytes[sourceIndex] == openingParenthesis) {
                let pszContents = extractSubstring(source: String(bytes: Array(sourceBytes[sourceIndex...]), encoding: .utf8) ?? "")
                let expandedContents = expandFormat(source: pszContents)
                destinationBytes.append(contentsOf: Array(expandedContents.utf8))
                sourceIndex = sourceIndex + pszContents.count + 2

            } else if (sourceIndex == 0 || sourceBytes[sourceIndex - 1] == comma) && sourceBytes[sourceIndex].isNumber {
                // This is a repeated subclause

                // Retain the origional source index
                let index = sourceIndex
                // Then skip over repeat count (digits)
                while sourceBytes[sourceIndex].isNumber {
                    sourceIndex += 1
                }
                // Extracting the data after the digits
                let repeatString = Array(sourceBytes[index..<sourceIndex]).string // 3A
                repeatCount = Int(repeatString) ?? 0
                let contents = extractSubstring(source: String(bytes: Array(sourceBytes[sourceIndex...]), encoding: .utf8) ?? "")
                let expandedContents = Array(expandFormat(source: contents).utf8)
                for i in 0..<repeatCount {
                    destinationBytes.append(contentsOf: expandedContents)
                    if (i < repeatCount - 1) {
                        destinationBytes.append(comma)
                    }
                }
                if sourceIndex == openingParenthesis {
                    sourceIndex += contents.count + 2
                } else {
                    sourceIndex += contents.count
                }
            } else {
                destinationBytes.append(sourceBytes[sourceIndex])
                sourceIndex += 1
            }
        }
        return String(bytes: destinationBytes, encoding: .utf8) ?? ""
    }
}
