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
        var poRecord: DDFRecord?
        var iRecord = 0

        repeat {
            poRecord = module.readRecord()
            guard let poRecord = poRecord else {
                break
            }
            iRecord += 1
            let recordSize = poRecord.getDataSize()
            print("Record \(iRecord) (\(recordSize) bytes)")

            // Loop over each field in this particular record.
            for iField in 0..<poRecord.getFieldCount() {
                if let poField = poRecord.getField(at: iField) {
                    viewRecordField(poField)
                }
            }
        } while poRecord != nil
        recordCount = iRecord
    }

    func viewRecordField(_ poField: DDFField) {
        var pachFieldData: Data
        guard let poFieldDefn: DDFFieldDefinition = poField.getFieldDefinition() else {
            print("Cannot find field definition.")
            return
        }

        // Report general information about the field.
        print("(GI)    Field name: \(poFieldDefn.fieldName): description: \(poFieldDefn.fieldDescription)")

        // Get this fields raw data.  We will move through
        // it consuming data as we report subfield values.
        pachFieldData = poField.getData()
        var nBytesRemaining = poField.getDataSize()

        // Loop over the repeat count for this fields
        // subfields.  The repeat count will almost
        // always be one.
        for _ in 0..<poField.getRepeatCount() {
            // Loop over all the subfields of this field, advancing
            // the data pointer as we consume data.
            for subfieldDefinition in poFieldDefn.ddfSubfieldDefinitions {
                let nBytesConsumed = viewSubfield(poSFDefn: subfieldDefinition,
                                                  pachFieldData: pachFieldData,
                                                  nBytesRemaining: nBytesRemaining)
                nBytesRemaining -= nBytesConsumed
                if nBytesConsumed > 0 {
                    let bytes: [UInt8] = Array(pachFieldData)
                    let subBytes = Array(bytes[nBytesConsumed...])
                    pachFieldData.removeAll(keepingCapacity: true)
                    pachFieldData = Data(subBytes)
                }
            }
        }
    }

    private func viewSubfield(poSFDefn sfDefn: DDFSubfieldDefinition,
                              pachFieldData: Data,
                              nBytesRemaining: Int) -> Int {
        var bytesConsumed: Int? = 0
        var poSFDefn = sfDefn

        switch poSFDefn.getType() {
        case .DDFInt:
            if poSFDefn.getBinaryFormat() == .unsignedInteger {
                let value = poSFDefn.extractIntData(pachSourceData: pachFieldData,
                                                    nMaxBytes: nBytesRemaining,
                                                    pnConsumedBytes: &bytesConsumed)
                print("(VS)        \(poSFDefn.getName()) = \(value)")
            } else {
                let value = poSFDefn.extractIntData(pachSourceData: pachFieldData,
                                                    nMaxBytes: nBytesRemaining,
                                                    pnConsumedBytes: &bytesConsumed)
                print("(VS)        \(poSFDefn.getName()) = \(value)")
            }

        case .DDFFloat:
            let value = poSFDefn.extractFloatData(pachSourceData: pachFieldData,
                                                  nMaxBytes: nBytesRemaining,
                                                  pnConsumedBytes: &bytesConsumed)
            print("(VS)        \(poSFDefn.getName()) = \(value)")

        case .DDFString:
            let bytes = poSFDefn.extractStringData(pachSourceData: pachFieldData,
                                                   nMaxBytes: nBytesRemaining,
                                                   pnConsumedBytes: &bytesConsumed)
            let string = String(bytes: bytes, encoding: .utf8) ?? ""
            print("(VS)        \(poSFDefn.getName()) = \(string)")

        case .DDFBinaryString:
            //rjensen 19-Feb-2002 5 integer variables to decode NAME and LNAM
            var vrid_rcnm: Int = 0
            var vrid_rcid: Int = 0
            var foid_agen: Int = 0
            var foid_find: Int = 0
            var foid_fids: Int = 0

            //GByte *pabyBString = (GByte *)
            let pabyBString = poSFDefn.extractStringData(pachSourceData: pachFieldData,
                                                         nMaxBytes: nBytesRemaining,
                                                         pnConsumedBytes: &bytesConsumed)

            print("(VS)        \(poSFDefn.getName()) = 0x")
            for i in 0..<min(bytesConsumed!, 24) {
                print(String(format: "(VS) %02X", pabyBString[i]))
            }

            if (bytesConsumed! > 24 ) {
                print("(VS) %s", "...");
            }

            // rjensen 19-Feb-2002 S57 quick hack. decode NAME and LNAM bitfields
            if poSFDefn.getName() == "NAME" {
                vrid_rcnm = Int(pabyBString[0])

                let v1 = Int(pabyBString[1])
                let v2 = Int(pabyBString[2]) * 256
                let v3 = Int(pabyBString[3]) * 65536
                let v4 = Int(pabyBString[4]) * 16777216
                vrid_rcid = v1 + v2 + v3 + v4
                print(String(format: "(VS)\tVRID RCNM = %d,RCID = %u", vrid_rcnm, vrid_rcid))
            } else if poSFDefn.getName() == "LNAM" {
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
