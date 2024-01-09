//
//  DDFField.swift
//  ISO8211
//
//  Created by Christopher Alford on 27/12/23.
//

import Foundation

public struct DDFField {

    private var poDefn: DDFFieldDefinition?
    private var nDataSize: Int = 0
    private var asciiData: Data


    public mutating func initialize(poDefnIn: DDFFieldDefinition,
                           asciiDataIn: Data,
                        nDataSizeIn: Int) {
        asciiData = asciiDataIn
        nDataSize = nDataSizeIn
        poDefn = poDefnIn
    }

    public init(poDefnIn: DDFFieldDefinition,
                           asciiDataIn: Data,
                        nDataSizeIn: Int) {
        asciiData = asciiDataIn
        nDataSize = nDataSizeIn
        poDefn = poDefnIn
    }

    /**
     * Return the pointer to the entire data block for this record. This
     * is an internal copy, and shouldn't be freed by the application.
     */
    public func getData() -> Data {
        return asciiData
    }

    /** Return the number of bytes in the data block returned by getData(). */
    public func getDataSize() -> Int {
        return nDataSize
    }

    /** Fetch the corresponding DDFFieldDefinition. */
    public func getFieldDefinition() -> DDFFieldDefinition? {
        return poDefn
    }

    /**
     * How many times do the subfields of this record repeat?  This
     * will always be one for non-repeating fields.
     *
     * - Returns The number of times that the subfields of this record occur
     * in this record.  This will be one for non-repeating fields.
     *
     */
    public func getRepeatCount() -> Int {
        guard let poDefn = poDefn else {
            return 0
        }

        if poDefn.isRepeating() == false {
            return 1
        }

    // The occurance count depends on how many copies of this
    // field's list of subfields can fit into the data space.
        if poDefn.getFixedWidth() != 0 {
            return nDataSize / poDefn.getFixedWidth()
        }

    // Note that it may be legal to have repeating variable width
    // subfields, but I don't have any samples, so I ignore it for
    // now.
        var iOffset = 0
        var iRepeatCount = 1

        while(true) {
            for iSF in 0..<poDefn.subfieldCount {
                var nBytesConsumed: Int? = 0
                guard let poThisSFDefn: DDFSubfieldDefinition = poDefn.getSubfield(at: iSF) else {
                    print("Didn't find dubfield definition, looping")
                    continue
                }

                if poThisSFDefn.formatWidth > nDataSize - iOffset {
                    nBytesConsumed = poThisSFDefn.formatWidth
                } else {
                    let bytes: [UInt8] = Array(asciiData)
                    let subBytes = bytes[iOffset...]
                    _ = poThisSFDefn.getDataLength(pachSourceData: Data(subBytes),
                                               nMaxBytes: nDataSize - iOffset,
                                               pnConsumedBytes: &nBytesConsumed)
                }
                iOffset += nBytesConsumed!
                if iOffset > nDataSize {
                    return iRepeatCount - 1
                }
            }
            if iOffset > nDataSize - 2 {
                return iRepeatCount
            }
            iRepeatCount += 1
        }
    }

}
