//
//  DDFModule.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public struct DDFModule {

    private(set) var fileHandle: FileHandle?
    private var bReadOnly = true
    private var firstRecordOffset: UInt64 = 0
    private var header: DDFHeader?

    // One DirectoryEntry per field.
    private var fieldDefinitionCount = 0
    private var fieldDefinitions: [DDFFieldDefinition] = []

    private var ddfRecord: DDFRecord?

    private var cloneCount = 0
    private var maximumCloneCount = 0
    private var clones: [DDFRecord] = []

    public mutating func open(url: URL) throws {
        let nLeaderSize = 24

        if fileHandle != nil {
            close()
        }
        
        do {
            fileHandle = try FileHandle.init(forReadingFrom: url)
        } catch {
            print(error.localizedDescription)
            throw ISO8211Error.invalidFile
        }
        guard let fileHandle = fileHandle else {
            throw ISO8211Error.invalidFile
        }

        // Read the first 24 bytes
        var data: Data = fileHandle.readData(ofLength: nLeaderSize)
        if data.count != nLeaderSize {
            throw ISO8211Error.invalidHeaderLength
        }

        // Create a header from the first 24 bytes
        header = DDFHeader(data: data)
        guard var header = header else {
            print("Could not create header.")
            return
        }

        // Verify that this appears to be a valid DDF file.
        var bValid = header.sourceValid

        if bValid == true {
            // Extract information from leader.
            do {
                try header.parse()
            }
        }
        bValid = header.dataValid

        //  If the header is invalid, then clean up, report the error and return.
        if bValid == false {
            close()
            print("The leader data is not valid!")
            return
        }

        // Read the whole record info memory.
        let moreData = fileHandle.readData(ofLength: header.recordLength-nLeaderSize)
        if moreData.count != header.recordLength - nLeaderSize {
                throw ISO8211Error.invalidHeaderData
        }
        data.append(contentsOf: moreData)

        // First make a pass counting the directory entries.
        var fieldDefinitionCount = 0
        for i in stride(from: nLeaderSize, to: header.recordLength, by: header.fieldEntryWidth) {
            if data[i] == DDF_FIELD_TERMINATOR {
                break
            }
            fieldDefinitionCount += 1
        }

        // Allocate, and read field definitions.
        for i in 0..<fieldDefinitionCount {
            do {
                var nEntryOffset = nLeaderSize + i*header.fieldEntryWidth
                var nFieldLength = 0
                var nFieldPos = 0
                let tagBytes = data.subdata(in: Range(nEntryOffset...(nEntryOffset+header.sizeFieldTag-1)))
                let szTag = try tagBytes.stringValue()
                nEntryOffset += header.sizeFieldTag
                let fieldLengthBytes = data.subdata(in: Range(nEntryOffset...(nEntryOffset+header.sizeFieldLength-1)))
                nFieldLength = try fieldLengthBytes.intValue()
                nEntryOffset += header.sizeFieldLength
                let fieldPositionBytes = data.subdata(in: Range(nEntryOffset...(nEntryOffset+header.sizeFieldPosition-1)))
                nFieldPos = try fieldPositionBytes.intValue()
                var fieldDefinition = DDFFieldDefinition()
                let subBytes = data.suffix(from: header.fieldAreaStart+nFieldPos)
                if fieldDefinition.initialize(poModuleIn: self,
                                              tagIn: szTag,
                                              nFieldEntrySize: nFieldLength,
                                              pachFieldArea: subBytes) == true {
                    fieldDefinitions.append(fieldDefinition)
                    fieldDefinitionCount += 1
                }
            } catch {
                print(error)
            }
        }
        data.removeAll()
        // Record the current file offset, the beginning of the first data record.
        do {
            firstRecordOffset = try fileHandle.offset()
        } catch {
            print(error)
        }
    }

    public var fieldCount: Int {
        return fieldDefinitionCount
    }

    public var fieldControlLength: Int {
        guard let header = header else {
            return 0
        }
        return header.fieldControlLength
    }

    /**
     Close the file and tidy up.
     */
    public mutating func close() {
        if fileHandle != nil {
            do {
                try fileHandle?.close()
                fileHandle = nil
            } catch {
                print(error)
            }
        }
        ddfRecord = nil
        clones.removeAll()
        cloneCount = 0
        maximumCloneCount = 0
        fieldDefinitions.removeAll()
        fieldDefinitionCount = 0
    }

    /**
     * read one record from the file.
     *
     * - Returns A DDFRecord, or nil if a read error, or end of file occurs.
     */
    public mutating func readRecord() -> DDFRecord? {
        if ddfRecord == nil {
            ddfRecord = DDFRecord(self)
        }
        if ddfRecord?.read() == true {
            return ddfRecord
        } else {
            return nil
        }
    }

    /**
     * Fetch the definition of the named field.
     *
     * This function will scan the DDFFieldDefinition's on this module, to find
     * one with the indicated field name.
     *
     * - Parameter fieldName The name of the field to search for.  The comparison is
     *                     case insensitive.
     *
     * - Returns A DDFFieldDefinition, or NULL if none matching the name are found.
     */

    public func findFieldDefinition(fieldName: String) -> DDFFieldDefinition? {
        return fieldDefinitions.first(where: { $0.fieldName == fieldName })
//        for i in 0..<fieldDefinitionCount {
//            if fieldName == fieldDefinitions[i].getName() {
//                return fieldDefinitions[i]
//            }
//        }
//        return nil
    }
}
