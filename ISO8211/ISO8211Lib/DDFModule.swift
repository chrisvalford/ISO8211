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
    private var header: DDFHeader = DDFHeader()

    // One DirectoryEntry per field.
    private var fieldDefinitionCount = 0
    private var fieldDefinitions: [DDFFieldDefinition] = []

    private var record: DDFRecord?

    private var cloneCount = 0
    private var maximumCloneCount = 0
    private var clones: [DDFRecord] = []

    public mutating func open(url: URL) throws {
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
        var data: Data = fileHandle.readData(ofLength: LEADER_SIZE)
        if data.count != LEADER_SIZE {
            throw ISO8211Error.invalidHeaderLength
        }

        // Create a header from the first 24 bytes
        header = DDFHeader(data: data)

        // Verify that this appears to be a valid DDF file.
        var isValid = header.sourceValid

        if isValid == true {
            // Extract information from leader.
            do {
                try header.parse()
            }
        }
        isValid = header.dataValid

        //  If the header is invalid, then clean up, report the error and return.
        if isValid == false {
            close()
            print("The leader data is not valid!")
            return
        }

        // Read the whole record info memory.
        let moreData = fileHandle.readData(ofLength: header.recordLength-LEADER_SIZE)
        if moreData.count != header.recordLength - LEADER_SIZE {
                throw ISO8211Error.invalidHeaderData
        }
        data.append(contentsOf: moreData)

        // First make a pass counting the directory entries.
        var fieldDefinitionCount = 0
        for i in stride(from: LEADER_SIZE, to: header.recordLength, by: header.fieldEntryWidth) {
            if data[i] == DDF_FIELD_TERMINATOR {
                break
            }
            fieldDefinitionCount += 1
        }

        // Allocate, and read field definitions.
        for i in 0..<fieldDefinitionCount {
            do {
                var entryOffset = LEADER_SIZE + i*header.fieldEntryWidth
                var fieldLength = 0
                var fieldPosition = 0

                let tagBytes = data.subdata(in: Range(entryOffset...(entryOffset+header.sizeFieldTag-1)))
                let szTag = try tagBytes.stringValue()
                entryOffset += header.sizeFieldTag

                let fieldLengthBytes = data.subdata(in: Range(entryOffset...(entryOffset+header.sizeFieldLength-1)))
                fieldLength = try fieldLengthBytes.intValue()
                entryOffset += header.sizeFieldLength

                let fieldPositionBytes = data.subdata(in: Range(entryOffset...(entryOffset+header.sizeFieldPosition-1)))
                fieldPosition = try fieldPositionBytes.intValue()

                var fieldDefinition = DDFFieldDefinition()
                let subBytes = data.suffix(from: header.fieldAreaStart+fieldPosition)
                if fieldDefinition.initialize(module: self,
                                              tag: szTag,
                                              fieldEntrySize: fieldLength,
                                              data: subBytes) == true {
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
        record = nil
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
        if record == nil {
            record = DDFRecord(self)
        }
        if record?.read() == true {
            return record
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

    public func findFieldDefinition(tag: String) -> DDFFieldDefinition? {
        return fieldDefinitions.first(where: { $0.fieldName == tag })
    }
}
