//
//  DDFFieldDefinition.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public struct DDFFieldDefinition {
    private var poModule: DDFModule?
    private var tag = ""
    private var _fieldName = ""
    private var _arrayDescr = ""
    private var _formatControls = ""
    private var repeatingSubfields = false
    private var fixedWidth = 0    // zero if variable.
    private var _data_struct_code: DDF_data_struct_code = .dsc_elementary
    private var _data_type_code: DDF_data_type_code = .dtc_char_string
    private(set) var subfieldCount = 0
    private(set) var ddfSubfieldDefinitions: [DDFSubfieldDefinition] = []

    public mutating func initialize(poModuleIn: DDFModule,
                                    tagIn: String,
                                    nFieldEntrySize: Int,
                                    pachFieldArea: Data) -> Bool {
        var iFDOffset = poModuleIn.fieldControlLength
        var nCharsConsumed = 0
        poModule = poModuleIn
        tag = tagIn

        guard let dataStr = String(data: pachFieldArea, encoding: .utf8) else {
            print("Failed to get string from pachFieldData")
            return false
        }

        // Set the data struct and type codes.
        switch dataStr[0] {
        case "0":
            _data_struct_code = .dsc_elementary

        case "1":
            _data_struct_code = .dsc_vector

        case "2":
            _data_struct_code = .dsc_array

        case "3":
            _data_struct_code = .dsc_concatenated

        default:
            print("Unrecognised data_struct_code value \(pachFieldArea[0]).")
            print("Field \(tag) initialization incorrect.")
            _data_struct_code = .dsc_elementary
        }

        switch(dataStr[1]) {
        case "0":
            _data_type_code = .dtc_char_string

        case "1":
            _data_type_code = .dtc_implicit_point

        case "2":
            _data_type_code = .dtc_explicit_point

        case "3":
            _data_type_code = .dtc_explicit_point_scaled

        case "4":
            _data_type_code = .dtc_char_bit_string

        case "5":
            _data_type_code = .dtc_bit_string

        case "6":
            _data_type_code = .dtc_mixed_data_type

        default:
            print("Unrecognised data_type_code value \(pachFieldArea[1]).")
            print("Field \(tag) initialization incorrect.")
            _data_type_code = .dtc_char_string
        }

        // Capture the field name, description (sub field names), and format statements.
        var result = DDFUtils.fetchVariable(source: dataStr.substring(from: iFDOffset),
                                            maxChars: nFieldEntrySize - iFDOffset,
                                            delimiter1: UInt8(DDF_UNIT_TERMINATOR),
                                            delimiter2: UInt8(DDF_FIELD_TERMINATOR),
                                            consumedChars: nCharsConsumed)
        nCharsConsumed += result.0
        iFDOffset += result.0
        _fieldName = result.1 ?? ""

        result = DDFUtils.fetchVariable(source: dataStr.substring(from: iFDOffset),
                                        maxChars: nFieldEntrySize - iFDOffset,
                                        delimiter1: UInt8(DDF_UNIT_TERMINATOR),
                                        delimiter2: UInt8(DDF_FIELD_TERMINATOR),
                                        consumedChars: nCharsConsumed)
        nCharsConsumed += result.0
        iFDOffset += result.0
        _arrayDescr = result.1 ?? ""

        result = DDFUtils.fetchVariable(source: dataStr.substring(from: iFDOffset),
                                        maxChars: nFieldEntrySize - iFDOffset,
                                        delimiter1: UInt8(DDF_UNIT_TERMINATOR),
                                        delimiter2: UInt8(DDF_FIELD_TERMINATOR),
                                        consumedChars: nCharsConsumed)
        _formatControls = result.1 ?? ""

        // Parse the subfield info.
        if _data_struct_code != .dsc_elementary {
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
        return ddfSubfieldDefinitions[i]
    }

    /**
     * Get the width of this field.  This function isn't normally used
     * by applications.
     *
     * - Returns The width of the field in bytes, or zero if the field is not
     * apparently of a fixed width.
     */
    func getFixedWidth() -> Int { return fixedWidth }

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
        var papszSubfieldNames: [String]
        var pszSublist = _arrayDescr

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
        papszSubfieldNames = pszSublist.components(separatedBy: "!")

        // Minimally initialize the subfields.
        let nSFCount = papszSubfieldNames.count
        for iSF in 0..<nSFCount {
            var poSFDefn = DDFSubfieldDefinition()
            poSFDefn.setName(papszSubfieldNames[iSF])
            addSubfield(poSFDefn, dontAddToFormat: true)
        }
        papszSubfieldNames.removeAll()
        return true
    }

    /**
     * This method parses the format string partially, and then
     *  applies a subfield format string to each subfield object.
     *  It in turn does final parsing of the subfield formats.
     */
    private mutating func applyFormats() -> Bool {
        var formatList = ""
        var paformatItems: [String]

        // Verify that the format string is contained within brackets.
        if _formatControls.count < 2
            || !_formatControls.hasPrefix("(")
            || !_formatControls.hasSuffix(")") {
            print("Format controls for \(tag) field missing brackets: \(_formatControls)")
            return false
        }

        // Duplicate the string, and strip off the brackets.
        formatList = expandFormat(source: _formatControls)

        // Tokenize based on commas.
        paformatItems = formatList.components(separatedBy: ",")
        formatList.removeAll()

        // Apply the format items to subfields.
        var iFormatItem = 0
        for formatItem in paformatItems {
            var pszPastPrefix = formatItem //paformatItems[iFormatItem]

            // Skip over any leading numbers
            var n = 0
            while pszPastPrefix[n].asciiValue! >= "0".byte && pszPastPrefix[n].asciiValue! <= "9".byte && n < pszPastPrefix.count {
                n += 1
            }
            if n > 0 {
                pszPastPrefix = pszPastPrefix.substring(from: n)
            }

            // Did we get too many formats for the subfields created by names?
            // This may be legal by the 8211 specification, but isn't encountered
            // in any formats we care about so we just blow.
            if iFormatItem >= subfieldCount {
                print("Got more formats than subfields for field \(tag).")
                break
            }
            if !ddfSubfieldDefinitions[iFormatItem].setFormat(pszPastPrefix) {
                return false
            }
            iFormatItem += 1
        }

        // Verify that we got enough formats, cleanup and return.
        paformatItems.removeAll()
        if iFormatItem < subfieldCount-1 {
            print("Got less formats than subfields for field \(tag).");
            return false
        }

        // If all the fields are fixed width, then we are fixed width too.
        // This is important for repeating fields.
        fixedWidth = 0
        for i in 0..<subfieldCount {
            if ddfSubfieldDefinitions[i].formatWidth == 0 {
                fixedWidth = 0
                break
            } else {
                fixedWidth += ddfSubfieldDefinitions[i].formatWidth
            }
        }
        return true
    }

    private mutating func addSubfield(_ newSubfieldDefinition: DDFSubfieldDefinition,
                              dontAddToFormat: Bool) {
        subfieldCount += 1
        ddfSubfieldDefinitions.append(newSubfieldDefinition)
        if dontAddToFormat {
            return
        }

    // Add this format to the format list.  We don't bother aggregating formats here.
        if _formatControls.isEmpty {
            _formatControls = "()"
        }

        let nOldLen = _formatControls.count
        var pszNewFormatControls = _formatControls

        if pszNewFormatControls[nOldLen-2] != "(" {
            pszNewFormatControls.append(",")
        }

        pszNewFormatControls.append(contentsOf: newSubfieldDefinition.getFormat())
        pszNewFormatControls.append(")")
        _formatControls.removeAll()
        _formatControls = pszNewFormatControls

        // Add the subfield name to the list.
        _arrayDescr.removeAll()
        if _arrayDescr.count > 0 {
            _arrayDescr.append("!")
        }
        _arrayDescr.append(contentsOf: newSubfieldDefinition.getName())
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
        let pszSrc: [UInt8] = Array(source.utf8)
        var nBracket = 0
        var pszReturn: [UInt8] = []
        var i = 0
        while (i < pszSrc.count) && (nBracket > 0 || pszSrc[i] != comma) {
            if pszSrc[i] == openingParenthesis {
                nBracket += 1
            } else if pszSrc[i] == closingParenthesis {
                nBracket -= 1
            }
            i += 1
        }
        if pszSrc[0] == openingParenthesis {
            pszReturn = Array(pszSrc[1...(i - 2)])
        } else {
            if i < pszSrc.count {
                pszReturn = Array(pszSrc[0...i])
            } else {
                pszReturn = pszSrc
            }
        }
        if pszReturn.last == comma {
            return String(bytes: Array(pszReturn.dropLast()), encoding: .utf8) ?? ""
        }
        return String(bytes: pszReturn, encoding: .utf8) ?? ""
    }

    /**
     * Given a string that contains a coded size symbol, expand it
     * out.
     */
    func expandFormat(source: String) -> String {
        let pszSrc: [UInt8] = Array(source.utf8)
        var szDest: [UInt8] = []
        var iSrc = 0
        var nRepeat = 0

        while iSrc < pszSrc.count {
            /*
             * This is presumably an extra level of brackets around
             * some binary stuff related to rescanning which we don't
             * care to do (see 6.4.3.3 of the standard. We just strip
             * off the extra layer of brackets
             */
            if ((iSrc == 0 || pszSrc[iSrc - 1] == comma) && pszSrc[iSrc] == openingParenthesis) {
                let pszContents = extractSubstring(source: String(bytes: Array(pszSrc[iSrc...]), encoding: .utf8) ?? "")
                let pszExpandedContents = expandFormat(source: pszContents)
                szDest.append(contentsOf: Array(pszExpandedContents.utf8))
                iSrc = iSrc + pszContents.count + 2

            } else if (iSrc == 0 || pszSrc[iSrc - 1] == comma) && pszSrc[iSrc].isNumber {
                // this is a repeated subclause
                let orig_iSrc = iSrc
                // skip over repeat count.
                while pszSrc[iSrc].isNumber {
                    iSrc += 1
                }
                let nRepeatString = Array(pszSrc[orig_iSrc..<iSrc]).string // 3A
                nRepeat = Int(nRepeatString) ?? 0
                let pszContents = extractSubstring(source: String(bytes: Array(pszSrc[iSrc...]), encoding: .utf8) ?? "")
                let pszExpandedContents = Array(expandFormat(source: pszContents).utf8)
                for i in 0..<nRepeat {
                    szDest.append(contentsOf: pszExpandedContents)
                    if (i < nRepeat - 1) {
                        szDest.append(comma)
                    }
                }
                if iSrc == openingParenthesis { // Open parentheis "("
                    iSrc += pszContents.count + 2
                } else {
                    iSrc += pszContents.count
                }
            } else {
                szDest.append(pszSrc[iSrc])
                iSrc += 1
            }
        }
        return String(bytes: szDest, encoding: .utf8) ?? ""
    }
}
