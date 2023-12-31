//
//  DDFSubfield.swift
//  CatScan
//
//  Created by Christopher Alford on 28.09.20.
//  Copyright © 2020 Marine+Digital. All rights reserved.
//

import Foundation

public class DDFSubfield {

    /**
     * A DDFSubfieldDefinition defining the admin part of the file
     * that contains the subfield data.
     */
    var defn: DDFSubfieldDefinition?
    /**
     * The object containing the value of the field.
     */
    var value: Any?
    /**
     * The number of bytes the field took up in the data file.
     */
    private(set) var byteSize = 0

    init() {}

    /**
     * Create a subfield with a definition and a value.
     */
    init(ddfsd: DDFSubfieldDefinition, value: Any ) {
        setDefn(ddsfd: ddfsd)
        setValue(o: value)
    }

    /**
     * Create a subfield with a definition and the bytes containing
     * the information for the value. The definition parameters will
     * tell the DDFSubfield what kind of object to create for the
     * data.
     */
    init?(poSFDefn: DDFSubfieldDefinition, pachFieldData: Data,
          nBytesRemaining: Int) {
        defn = poSFDefn
        var nBytesConsumed: Int? = 0

        switch poSFDefn.eType {

        case DDFDataType.DDFInt:
            setValue(o: Int((defn?.extractIntData(pachSourceData: pachFieldData,
                                                  nMaxBytes: nBytesRemaining,
                                                  pnConsumedBytes: &nBytesConsumed))!))

        case DDFDataType.DDFFloat:
            setValue(o: Double((defn?.extractFloatData(pachSourceData: pachFieldData,
                                                       nMaxBytes: nBytesRemaining,
                                                       pnConsumedBytes: &nBytesConsumed))!))

        case DDFDataType.DDFString, DDFDataType.DDFBinaryString:
            guard let bytes = defn?.extractStringData(pachSourceData: pachFieldData,
                                                      nMaxBytes: nBytesRemaining,
                                                      pnConsumedBytes: &nBytesConsumed),
                  let bytesString = String(bytes: bytes, encoding: .utf8) else {
                      return
                  }
            setValue(o: bytesString)
        }

        byteSize = nBytesConsumed!
    }

    func setDefn(ddsfd: DDFSubfieldDefinition) {
        defn = ddsfd;
    }

    func getDefn() -> DDFSubfieldDefinition {
        return defn!
    }

    /**
     * Set the value of the subfield.
     */
    func setValue(o: Any) {
        value = o;
    }

    /**
     * Get the value of the subfield.
     */
    func getValue() -> Any? {
        return value
    }

    /**
     * Get the value of the subfield as an int. Returns 0 if the value
     * is 0 or isn't a number.
     */
    func intValue() -> Int {
        let obj = getValue()
        if obj is Int {
            return obj as! Int
        }
        return 0
    }

    /**
     * Get the value of the subfield as a float. Returns 0f if the
     * value is 0 or isn't a number.
     */
    func floatValue() -> Double {
        let obj = getValue()
        if obj is Double {
            return obj as! Double
        }
        return 0
    }

    func stringValue() -> String {
        let obj = getValue()

        if obj is String {
            return obj as! String
        }
        return ""
    }
}

extension DDFSubfield: CustomStringConvertible {
    public var description: String {
        var value = ""
        value.append("DDFSubfield:\n" )
        value.append("    defn = \(defn?.name ?? "")\n")
        value.append("    value = \(value)\n")

        return value
    }
}
