//
//  DDFHeader.swift
//  S57Reader
//
//  Created by Christopher Alford on 7/1/24.
//

import Foundation

struct DDFHeader {
    private(set) var interchangeLevel: Int = 0
    private(set) var inlineCodeExtensionIndicator = ""
    private(set) var versionNumber = 0
    private(set) var appIndicator = ""
    private(set) var fieldControlLength = 0
    private(set) var extendedCharSet = " ! "

    private(set) var recordLength = 0
    private(set) var leaderIdentifier = "L"
    private(set) var fieldAreaStart = 0
    private(set) var sizeFieldLength = 0
    private(set) var sizeFieldPosition = 0
    private(set) var sizeFieldTag = 0

    var fieldEntryWidth: Int {
        return sizeFieldLength + sizeFieldPosition + sizeFieldTag
    }

    private var data: Data

    init(data: Data) {
        self.data = data
    }

    mutating func parse() throws {
        if data.count < 24 { return }
        do {
            recordLength                 = try data[0...4].intValue()
            interchangeLevel             = Int(data[5]) - 48
            leaderIdentifier             = String(bytes: [data[6]], encoding: .ascii) ?? ""
            inlineCodeExtensionIndicator = String(bytes: [data[7]], encoding: .ascii) ?? ""
            versionNumber                = Int(data[8]) - 48
            appIndicator                 = String(bytes: [data[9]], encoding: .ascii) ?? ""
            fieldControlLength           = try data[10...11].intValue()
            fieldAreaStart               = try data[12...16].intValue()
            extendedCharSet              = try data[17...19].stringValue()
            sizeFieldLength              = Int(data[20]) - 48
            sizeFieldPosition            = Int(data[21]) - 48
            sizeFieldTag                 = Int(data[23]) - 48
        }
    }

    var sourceValid: Bool {
        var isValid = true
        for byte in data {
            if byte < 32 || byte > 126 {
                isValid = false
            }
        }
        if data[5] != "1".byte && data[5] != "2".byte && data[5] != "3".byte {
            isValid = false
        }
        if data[6] != "L".byte {
            isValid = false
        }
        if data[8] != "1".byte && data[8] != " ".byte {
            isValid = false
        }
        return isValid
    }

    var dataValid: Bool {
        if recordLength < 12 || fieldControlLength == 0
            || fieldAreaStart < 24 || sizeFieldLength == 0
            || sizeFieldPosition == 0 || sizeFieldTag == 0 {
            return false
        }
        return true
    }
}

