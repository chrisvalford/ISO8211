//
//  Array+.swift
//  ISO8211
//
//  Created by Christopher Alford on 27/4/22.
//

import Foundation

extension Array where Element == UInt8 {

    func components(seperatedBy: UInt8) -> [[UInt8]] {

        var components = [[UInt8]]()
        var row = [UInt8]()

        for i in 0..<self.count {
            if self[i] != seperatedBy {
                row.append(self[i])
            } else {
                components.append(row)
                row.removeAll()
            }
        }
        components.append(row)
        return components
    }
    
    // DDFFetchVariable()
    /// fetchArray()
    /// Fetch a variable length array from a record, and allocate it as a new array.
    func fetchArray(maximumLength: Int,
                    firstDelimiter: UInt8,
                    secondDelimiter: UInt8,
                    completion: (_ count: Int, _ value: [UInt8]) -> Void) {
        var i = 0
        var consumedCount = 0

        // Find any delimiter
        while i < maximumLength - 1 && self[i] != firstDelimiter && self[i] != secondDelimiter {
            i += 1
        }
        consumedCount = i
        if i < maximumLength && (self[i] == firstDelimiter || self[i] == secondDelimiter) {
            consumedCount += 1
        }
        completion(consumedCount, Array(self[0..<i])) // Skip the delimiter
    }

    public func fetchString(maximumLength: Int,
                            firstDelimiter: UInt8,
                            secondDelimiter: UInt8,
                            completion: (_ count: Int, _ value: String) -> Void)  {
        fetchArray(maximumLength: maximumLength,
                   firstDelimiter: firstDelimiter,
                   secondDelimiter: secondDelimiter,
                   completion: { count, value in
            completion(count, value.string)
        })
    }
    
    //let sample: [UInt8] = [32,48,48,48,48,50]
    //let i = sample.int(start: 1, end: sample.count-1)
    
    func int(start: Int, end: Int) throws -> Int {
        let flArray = Array(self[start...end])
        let flString = String(bytes: flArray, encoding: .utf8)
        let trimmedflString = flString?.replacingOccurrences(of: "^0+", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedflString != "" else {
            return 0
        }
        guard let value = Int(trimmedflString!) else {
            throw ISO8211Error.invalidIntegerValue
        }
        return value
    }
}

