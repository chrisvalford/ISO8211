//
//  Data+Values.swift
//  ISO8211
//
//  Created by Christopher Alford on 8/1/24.
//

import Foundation

extension Data {
    func intValue() throws -> Int {
        guard let str = String(bytes: self, encoding: .ascii) else {
            throw ISO8211Error.nilString
        }
        let trimmed = str.trimmed
        if trimmed == "" {
            return 0
        }
        guard let intValue = Int(str.trimmed) else {
            throw ISO8211Error.nilInteger
        }
        return intValue
    }

    func stringValue() throws -> String {
        guard let str = String(bytes: self, encoding: .ascii) else {
            throw ISO8211Error.nilString
        }
        return str
    }
}
