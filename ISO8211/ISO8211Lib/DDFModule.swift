//
//  DDFModule.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public struct DDFModule {

    private var fpDDF: FileHandle?
    private var bReadOnly = true
    private var firstRecordOffset: UInt64 = 0

    private var _interchangeLevel: UInt8 = 0
    private var _inlineCodeExtensionIndicator: UInt8 = 0
    private var _versionNumber: UInt8 = 0
    private var _appIndicator: UInt8 = 0
    private var _fieldControlLength = 0
    private var _extendedCharSet = " ! "

    private var _recordLength = 0
    private var _leaderIdentifier = "L"
    private var _fieldAreaStart = 0
    private var _sizeFieldLength = 0
    private var _sizeFieldPosition = 0
    private var _sizeFieldTag = 0

    // One DirectoryEntry per field.
    private var fieldDefinitionCount = 0
    private var fieldDefinitions: [DDFFieldDefinition] = []

    private var ddfRecord: DDFRecord?

    private var cloneCount = 0
    private var maximumCloneCount = 0
    private var clones: [DDFRecord] = []

    public mutating func open(url: URL) throws {
        let nLeaderSize = 24

        if fpDDF != nil {
            close()
        }
        
        do {
            fpDDF = try FileHandle.init(forReadingFrom: url)
        } catch {
            print(error.localizedDescription)
            throw ISO8211Error.invalidFile
        }
        // Read the first 24 bytes
        var achLeader: Data
        if let data = fpDDF?.readData(ofLength: nLeaderSize) {
            achLeader = data
        } else {
            throw ISO8211Error.invalidFile
        }
        if achLeader.count != nLeaderSize {
            throw ISO8211Error.invalidHeaderLength
        }

        // Verify that this appears to be a valid DDF file.
        var bValid = true
        for byte in achLeader {
            if byte < 32 || byte > 126 {
                bValid = false
            }
        }
        if achLeader[5] != "1".byte
            && achLeader[5] != "2".byte
            && achLeader[5] != "3".byte {
                bValid = false
        }
        if achLeader[6] != "L".byte {
            bValid = false
        }
        if achLeader[8] != "1".byte 
            && achLeader[8] != " ".byte {
                bValid = false
        }

        // Extract information from leader.
        if bValid {
            _recordLength                 = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 0, maxChars: 5) ?? 0
            _interchangeLevel             = achLeader[5]
            _leaderIdentifier             = String(bytes: [achLeader[6]], encoding: .utf8) ?? ""
            _inlineCodeExtensionIndicator = achLeader[7]
            _versionNumber                = achLeader[8]
            _appIndicator                 = achLeader[9]
            _fieldControlLength           = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 10, maxChars: 2) ?? 0
            _fieldAreaStart               = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 12, maxChars: 5) ?? 0
            _extendedCharSet              = String(bytes: achLeader[17...19], encoding: .utf8) ?? ""
            _sizeFieldLength              = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 20 ,maxChars: 1) ?? 0
            _sizeFieldPosition            = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 21 ,maxChars: 1) ?? 0
            _sizeFieldTag                 = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 23 ,maxChars: 1) ?? 0

            if _recordLength < 12 || _fieldControlLength == 0
                || _fieldAreaStart < 24 || _sizeFieldLength == 0
                || _sizeFieldPosition == 0 || _sizeFieldTag == 0 {
                bValid = false
            }
        }
        //  If the header is invalid, then clean up, report the error and return.
        if bValid == false {
            close()
            print("The leader data is not valid!")
            return
        }

        // Read the whole record info memory.
        var pachRecord = achLeader
        
        if let data = fpDDF?.readData(ofLength: _recordLength-nLeaderSize) {
            let bytes = data
            if bytes.count != _recordLength - nLeaderSize {
                throw ISO8211Error.invalidHeaderData
            }
            pachRecord.append(contentsOf: bytes)
        } else {
            throw ISO8211Error.invalidFile
        }

        // First make a pass counting the directory entries.
        var nFieldEntryWidth = 0;
        var nFDCount = 0;
        nFieldEntryWidth = _sizeFieldLength + _sizeFieldPosition + _sizeFieldTag
        for i in stride(from: nLeaderSize, to: _recordLength, by: nFieldEntryWidth) {
            if pachRecord[i] == DDF_FIELD_TERMINATOR {
                break
            }
            nFDCount += 1
        }

        // Allocate, and read field definitions.
        for i in 0..<nFDCount {
            var nEntryOffset = nLeaderSize + i*nFieldEntryWidth;
            var nFieldLength = 0
            var nFieldPos = 0
            //FIXME: Tag is wrong length should be 4 bytes
            let szTag = String(data: pachRecord[nEntryOffset...(nEntryOffset+_sizeFieldTag-1)], encoding: .utf8) ?? ""
            nEntryOffset += _sizeFieldTag
            nFieldLength = DDFUtils.DDFScanInt(source: pachRecord,
                                               fromIndex: nEntryOffset,
                                               maxChars: _sizeFieldLength) ?? 0
            nEntryOffset += _sizeFieldLength
            nFieldPos = DDFUtils.DDFScanInt(source: pachRecord,
                                            fromIndex: nEntryOffset,
                                            maxChars: _sizeFieldPosition) ?? 0
            var poFDefn = DDFFieldDefinition()
            let bytes = pachRecord[(_fieldAreaStart+nFieldPos)...]
            if poFDefn.initialize(poModuleIn: self,
                                   tagIn: szTag,
                                   nFieldEntrySize: nFieldLength, 
                                  pachFieldArea: bytes) == true {
                fieldDefinitions.append(poFDefn)
                fieldDefinitionCount += 1
            }
        }
        pachRecord.removeAll()
        // Record the current file offset, the beginning of the first data record.
        do {
            firstRecordOffset = try fpDDF?.offset() ?? 0
        } catch {
            print(error)
        }
    }

    public func getFieldCount() -> Int { 
        return fieldDefinitionCount
    }

    public func getFieldControlLength() -> Int {
        return _fieldControlLength
    }

    public func getFP() throws -> FileHandle {
        guard let fh = fpDDF else {
            throw ISO8211Error.invalidFile
        }
        return fh
    }

    /**
     Close the file and tidy up.
     */
    public mutating func close() {
        if fpDDF != nil {
            do {
                try fpDDF?.close()
                fpDDF = nil
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
     * @return A pointer to a DDFRecord object is returned, or NULL if a read
     * error, or end of file occurs.  The returned record is owned by the
     * module, and should not be deleted by the application.  The record is
     * only valid untill the next readRecord() at which point it is overwritten.
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
     * @param fieldName The name of the field to search for.  The comparison is
     *                     case insensitive.
     *
     * @return A pointer to the request DDFFieldDefinition object is returned, or NULL
     * if none matching the name are found.  The return object remains owned by
     * the DDFModule, and should not be deleted by application code.
     */

    public func findFieldDefn(fieldName: String) -> DDFFieldDefinition? {
        for i in 0..<fieldDefinitionCount {
            if fieldName == fieldDefinitions[i].getName() {
                return fieldDefinitions[i]
            }
        }
        return nil
    }
}
