//
//  DDFField.swift
//  ISO8211
//
//  Created by Christopher Alford on 27/12/23.
//

import Foundation

public struct DDFField {

    private(set) var fieldDefinition: DDFFieldDefinition?
    private(set) var dataSize: Int = 0
    private(set) var data: Data

    public mutating func initialize(fieldDefinition: DDFFieldDefinition,
                                    asciiDataIn: Data,
                                    dataSize: Int) {
        data = asciiDataIn
        self.dataSize = dataSize
        self.fieldDefinition = fieldDefinition
    }

    public init(poDefnIn: DDFFieldDefinition,
                asciiDataIn: Data,
                dataSize: Int) {
        data = asciiDataIn
        self.dataSize = dataSize
        fieldDefinition = poDefnIn
    }

    /**
     * The number of times that the subfields of this record occur
     * in this record.  This will be one for non-repeating fields.
     */
    public var repeatCount: Int {
        guard let fieldDefinition = fieldDefinition else {
            return 0
        }

        if fieldDefinition.isRepeating() == false {
            return 1
        }

        // The occurance count depends on how many copies of this
        // field's list of subfields can fit into the data space.
        if fieldDefinition.fixedWidth != 0 {
            return dataSize / fieldDefinition.fixedWidth
        }

        // Note that it may be legal to have repeating variable width
        // subfields, but I don't have any samples, so I ignore it for
        // now.
        var offset = 0
        var repeatCount = 1

        while(true) {
            for index in 0..<fieldDefinition.subfieldCount {
                var consumed: Int? = 0
                guard let subfieldDefinition = fieldDefinition.getSubfield(at: index) else {
                    print("Didn't find dubfield definition, looping")
                    continue
                }

                if subfieldDefinition.formatWidth > dataSize - offset {
                    consumed = subfieldDefinition.formatWidth
                } else {
                    let bytes: [UInt8] = Array(data)
                    let subBytes = bytes[offset...]
                    _ = subfieldDefinition.getDataLength(data: Data(subBytes),
                                                         maximumBytes: dataSize - offset,
                                                         bytesConsumed: &consumed)
                }
                offset += consumed!
                if offset > dataSize {
                    return repeatCount - 1
                }
            }
            if offset > dataSize - 2 {
                return repeatCount
            }
            repeatCount += 1
        }
    }
}
