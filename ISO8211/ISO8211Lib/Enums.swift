//
//  Enums.swift
//  ISO8211
//
//  Created by Christopher Alford on 31/12/23.
//

import Foundation

public enum DDF_data_struct_code {
    case dsc_elementary,
         dsc_vector,
         dsc_array,
         dsc_concatenated
}

public enum DDF_data_type_code {
    case dtc_char_string,
         dtc_implicit_point,
         dtc_explicit_point,
         dtc_explicit_point_scaled,
         dtc_char_bit_string,
         dtc_bit_string,
         dtc_mixed_data_type
}

public enum DDFDataType {
    case DDFInt,
         DDFFloat,
         DDFString,
         DDFBinaryString
}

public enum DDFBinaryFormat: Int  {
    case notBinary = 0,
         unsignedInteger = 1,
         signedInteger = 2,
         floatingPointReal = 3,
         floatReal = 4,
         floatComplex = 5
}
