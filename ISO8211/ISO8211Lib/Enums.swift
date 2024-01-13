//
//  Enums.swift
//  ISO8211
//
//  Created by Christopher Alford on 31/12/23.
//

import Foundation

public enum DataStructCode {
    case elementary,
         vector,
         array,
         concatenated
}

public enum DataTypeCode {
    case charString,
         implicitPoint,
         explicitPoint,
         explicitPointScaled,
         charBitString,
         bitString,
         mixedDataType
}

public enum DataType {
    case intType,
         floatType,
         stringType,
         binaryStringType
}

public enum BinaryFormat: Int  {
    case notBinary = 0,
         unsignedInteger = 1,
         signedInteger = 2,
         floatingPointReal = 3,
         floatReal = 4,
         floatComplex = 5
}
