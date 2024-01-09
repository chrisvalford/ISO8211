//
//  ISO8211Error.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

enum ISO8211Error: Error {
    case invalidFile
    case invalidIntegerValue
    case invalidHeaderLength
    case invalidHeaderData
    case nilString
    case nilInteger
    case nilFloat
}
