//
//  CatalogProvider.swift
//  ISO8211
//
//  Created by Christopher Alford on 27/12/23.
//

import SwiftUI
import System

class CatalogProvider: ObservableObject {

    @Published var message = ""
    @Published var recordCount = 0
    @Published var fileSize: UInt64 = 0

    private var module = DDFModule()
    private var url: URL = URL(fileURLWithPath: "")

    func open(filePath: String) {
        url = URL(fileURLWithPath: filePath)
        fileSize = url.fileSize
        do {
            try module.open(url: url)
        } catch {
            message = error.localizedDescription
            return
        }
        readRecords()
        module.close()
    }

    /**
     * Loop reading records till there are none left.
     */
    func readRecords() {
        var record: DDFRecord?
        var count = 0

        repeat {
            record = module.readRecord()
            guard let record = record else {
                break
            }
            count += 1
            let recordSize = record.dataSize
            print("Record \(count) (\(recordSize) bytes)")

            // Loop over each field in this particular record    
            for index in 0..<record.fieldCount {
                if let field = record.getField(at: index) {
                    viewRecordField(field)
                }
            }
        } while record != nil
        recordCount = count
    }

    func viewRecordField(_ field: DDFField) {
        var fieldData: Data
        guard let fieldDefinition = field.fieldDefinition else {
            print("Cannot find field definition.")
            return
        }

        // Report general information about the field.
        print("(GI)    Field name: \(fieldDefinition.fieldName): description: \(fieldDefinition.fieldDescription)")

        // Get this fields raw data.  We will move through
        // it consuming data as we report subfield values.
        fieldData = field.data
        var bytesRemaining = field.dataSize

        // Loop over the repeat count for this fields
        // subfields.  The repeat count will almost
        // always be one.
        for _ in 0..<field.repeatCount {
            // Loop over all the subfields of this field, advancing
            // the data pointer as we consume data.
            for subfieldDefinition in fieldDefinition.subfieldDefinitions {
                let consumed = viewSubfield(subfieldDefinition: subfieldDefinition,
                                            pachFieldData: fieldData,
                                            bytesRemaining: bytesRemaining)
                bytesRemaining -= consumed
                if consumed > 0 {
                    let bytes: [UInt8] = Array(fieldData)
                    let subBytes = Array(bytes[consumed...])
                    fieldData.removeAll(keepingCapacity: true)
                    fieldData = Data(subBytes)
                }
            }
        }
    }

    private func viewSubfield(subfieldDefinition sfDefn: DDFSubfieldDefinition,
                              pachFieldData: Data,
                              bytesRemaining: Int) -> Int {
        var bytesConsumed: Int? = 0
        var subfieldDefinition = sfDefn

        switch subfieldDefinition.dataType {
        case .intType:
            if subfieldDefinition.binaryFormat == .unsignedInteger {
                let value = subfieldDefinition.extractIntData(data: pachFieldData,
                                                              maximumBytes: bytesRemaining,
                                                              bytesConsumed: &bytesConsumed)
                print("(VS)        \(subfieldDefinition.getName()) = \(value)")
            } else {
                let value = subfieldDefinition.extractIntData(data: pachFieldData,
                                                              maximumBytes: bytesRemaining,
                                                              bytesConsumed: &bytesConsumed)
                print("(VS)        \(subfieldDefinition.getName()) = \(value)")
            }

        case .floatType:
            let value = subfieldDefinition.extractFloatData(data: pachFieldData,
                                                            maximumBytes: bytesRemaining,
                                                            bytesConsumed: &bytesConsumed)
            print("(VS)        \(subfieldDefinition.getName()) = \(value)")

        case .stringType:
            let bytes = subfieldDefinition.extractStringData(data: pachFieldData,
                                                             maximumBytes: bytesRemaining,
                                                             bytesConsumed: &bytesConsumed)
            let string = String(bytes: bytes, encoding: .utf8) ?? ""
            print("(VS)        \(subfieldDefinition.getName()) = \(string)")

        case .binaryStringType:
            //rjensen 19-Feb-2002 5 integer variables to decode NAME and LNAM
            var vrid_rcnm: Int = 0
            var vrid_rcid: Int = 0
            var foid_agen: Int = 0
            var foid_find: Int = 0
            var foid_fids: Int = 0

            //GByte *pabyBString = (GByte *)
            let pabyBString = subfieldDefinition.extractStringData(data: pachFieldData,
                                                                   maximumBytes: bytesRemaining,
                                                                   bytesConsumed: &bytesConsumed)

            print("(VS)        \(subfieldDefinition.getName()) = 0x")
            for i in 0..<min(bytesConsumed!, 24) {
                print(String(format: "(VS) %02X", pabyBString[i]))
            }

            if (bytesConsumed! > 24 ) {
                print("(VS) %s", "...");
            }

            // rjensen 19-Feb-2002 S57 quick hack. decode NAME and LNAM bitfields
            if subfieldDefinition.getName() == "NAME" {
                vrid_rcnm = Int(pabyBString[0])

                let v1 = Int(pabyBString[1])
                let v2 = Int(pabyBString[2]) * 256
                let v3 = Int(pabyBString[3]) * 65536
                let v4 = Int(pabyBString[4]) * 16777216
                vrid_rcid = v1 + v2 + v3 + v4
                print(String(format: "(VS)\tVRID RCNM = %d,RCID = %u", vrid_rcnm, vrid_rcid))
            } else if subfieldDefinition.getName() == "LNAM" {
                let v1 = Int(pabyBString[0])
                let v2 = Int(pabyBString[1]) * 256
                let v3 = Int(pabyBString[2])
                let v4 = Int(pabyBString[3]) * 256
                let v5 = Int(pabyBString[4]) * 65536
                let v6 = Int(pabyBString[5]) * 16777216
                let v7 = Int(pabyBString[6])
                let v8 = Int(pabyBString[7]) * 256
                foid_agen = v1 + v2
                foid_find = v3 + v4 + v5 + v6
                foid_fids = v7 + v8
                print(String(format: "(VS)\tFOID AGEN = %u,FIDN = %u,FIDS = %u", foid_agen, foid_find, foid_fids))
            }
        }
        return bytesConsumed!
    }
}
