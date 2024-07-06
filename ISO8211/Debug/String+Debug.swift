//
//  String+Debug.swift
//  ISO8211
//
//  Created by Christopher Alford on 6/7/24.
//

import Foundation

enum PrintStyle {
    case info
    case warning
    case error
}

extension String {
    func printd(_ style: PrintStyle? = .info) {
#if DEBUG
        print("[\(style!)] \(self)")
#endif
    }
}
