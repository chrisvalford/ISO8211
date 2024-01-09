//
//  DDFRecord.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public class DDFRecord {
    //TODO: Look at where module is used, possibly change this to a struct
    private var module: DDFModule
    private var reuseHeader: Bool
    private var fieldDataOffset: Int   // field data area, not dir entries.
    private var sizeofFieldTag: Int
    private var sizeofFieldPos: Int
    private var sizeofFieldLength: Int
    private(set) var dataSize: Int     // Whole record except leader with header
    private var asciiData: Data = Data()
    private(set) var fieldCount: Int
    private(set) var fields: [DDFField] = []
    private var bIsClone: Bool

    public init(_ module: DDFModule) {
        self.module = module
        reuseHeader = false
        fieldDataOffset = 0
        dataSize = 0
        fieldCount = 0
        bIsClone = false
        sizeofFieldTag = 4
        sizeofFieldPos = 0
        sizeofFieldLength = 0
    }

    /**
     * Fetch field object based on index.
     *
     * - Parameter i The index of the field to fetch.  Between 0 and getFieldCount()-1.
     *
     * - Returns A DDFField, or nil if the index is out of range.
     */
    public func getField(at i: Int) -> DDFField? {
        if i < 0 || i >= fieldCount {
            return nil
        } else {
            return fields[i]
        }
    }

    /**
     * Read a record of data from the file, and parse the header to
     * build a field list for the record (or reuse the existing one
     * if reusing headers).  It is expected that the file pointer
     * will be positioned at the beginning of a data record.  It is
     * the DDFModule's responsibility to do so.
     *
     * This method should only be called by the DDFModule class.
     */
    func read() -> Bool {
        // Redefine the record on the basis of the header if needed.
        // As a side effect this will read the data for the record as well.
        if reuseHeader == false {
            return readHeader()
        }

        // Otherwise we read just the data and carefully overlay it on
        // the previous records data without disturbing the rest of the
        // record.
        var data: Data?
        guard let fp = module.fileHandle else {
            return false
        }
        do {
            data = try fp.read(upToCount: dataSize - fieldDataOffset)
        } catch {
            print(error.localizedDescription)
            return false
        }
        guard let data = data else { return false }
        asciiData.insert(contentsOf: data, at: fieldDataOffset)
        if data.count != (dataSize - fieldDataOffset)
            && data.count == 0
            && fp.availableData.count == 0 {
            return false
        } else if data.count != (dataSize - fieldDataOffset) {
            print("Data record is short on DDF file.")
            return false
        }

        // Possible TODO Notify the DDFField's that their data values have changed?
        return true
    }

    /**
     * This perform the header reading and parsing job for the
     * read() method.  It reads the header, and builds a field
     * list.
     */
    private func readHeader() -> Bool {
        //TODO: How is this different than the other header reading code?

        // clear any existing information.
        fields.removeAll()
        fieldCount = 0
        asciiData.removeAll()
        dataSize = 0
        reuseHeader = false

        // read the 24 byte leader.
        var achLeader: Data
        var data: Data?
        guard let fileHandle = module.fileHandle else {
            return false
        }
        do {
            data = try fileHandle.read(upToCount: LEADER_SIZE)
        } catch {
            print(error.localizedDescription)
            return false
        }

        if data?.count == 0 && fileHandle.availableData.count == 0 {
            return false
        } else if data?.count != LEADER_SIZE {
            print("Leader is short on DDF file.")
            return false
        }
        achLeader = data!

        // Extract information from leader.
        var recordLength: Int
        var fieldAreaStart: Int
        var leaderIdentifier: UInt8
        recordLength = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 0, maxChars: 5) ?? 0
        leaderIdentifier = achLeader[6]
        fieldAreaStart = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 12, maxChars: 5) ?? 0
        sizeofFieldLength = Int(achLeader[20] - "0".byte)
        sizeofFieldPos = Int(achLeader[21] - "0".byte)
        sizeofFieldTag = Int(achLeader[23] - "0".byte)

        if sizeofFieldLength < 0 || sizeofFieldLength > 9
            || sizeofFieldPos < 0 || sizeofFieldPos > 9
            || sizeofFieldTag < 0 || sizeofFieldTag > 9 {
            print("ISO8211 record leader appears to be corrupt.")
            return false
        }

        if leaderIdentifier == "R".byte {
            reuseHeader = true
        }
        fieldDataOffset = fieldAreaStart - LEADER_SIZE;

        // Simple checks
        if (recordLength < 24 || recordLength > 100000000 || fieldAreaStart < 24 || fieldAreaStart > 100000)
            && (recordLength != 0) {
            print("Data record appears to be corrupt on DDF file.")
            return false
        }

        // Handle the normal case with the record length available.
        if recordLength != 0 {
            // read the remainder of the record.
            dataSize = recordLength - LEADER_SIZE
            do {
                data = try fileHandle.read(upToCount: dataSize)
            } catch {
                print(error.localizedDescription)
                return false
            }
            guard let data = data else { return false }
            if data.count != dataSize {
                print("Data record is short on DDF file.")
                return false
            }
            asciiData = data

            // If there is no field terminator at the end of the record
            // read additional bytes till one is found.
            while(asciiData[dataSize-1] != DDF_FIELD_TERMINATOR) {
                dataSize += 1
                do {
                    let newData = try fileHandle.read(upToCount: 1)
                    asciiData += newData!
                } catch {
                    print(error.localizedDescription)
                    return false
                }
            }

            // Count the directory entries.
            let fieldEntryWidth = sizeofFieldLength + sizeofFieldPos + sizeofFieldTag
            fieldCount = 0
            for i in stride(from: 0, to: dataSize, by: fieldEntryWidth) {
                if asciiData[i] == DDF_FIELD_TERMINATOR {
                    break
                }
                fieldCount += 1
            }

            // Allocate, and read field definitions.
            for i in 0..<fieldCount {
                var tag: String
                var entryOffset = i*fieldEntryWidth
                var fieldLength: Int
                var fieldPosition: Int

                // read the position information and tag.
                tag = String(bytes: Array(asciiData[entryOffset...(entryOffset+sizeofFieldTag-1)]), encoding: .utf8) ?? ""
                entryOffset += sizeofFieldTag
                fieldLength = DDFUtils.DDFScanInt(source: asciiData, fromIndex: entryOffset, maxChars: sizeofFieldLength) ?? 0
                entryOffset += sizeofFieldLength;
                fieldPosition = DDFUtils.DDFScanInt(source: asciiData, fromIndex: entryOffset, maxChars: sizeofFieldPos) ?? 0

                // Find the corresponding field in the module directory.
                guard let fieldDefinition = module.findFieldDefinition(tag: tag) else {
                    print("(1) Undefined field named: \(tag) encountered in data record.")
                    return false
                }

                // Create the DDFField
                let startIndex = fieldAreaStart + fieldPosition - LEADER_SIZE
                let endIndex = asciiData.count-1
                let bytes = data[startIndex...endIndex]
                fields.append(DDFField(poDefnIn: fieldDefinition,
                                       asciiDataIn: bytes,
                                       dataSize: fieldLength))
            }
            return true
        }

        // Handle the exceptional case where the record length is
        // zero. In this case we have to read all the data based on
        // the size of data items as per ISO8211 spec Annex C, 1.5.1.
        else {
            print("Record with zero length, use variant (C.1.5.1) logic.")

            //   _recLength == 0, handle the large record.
            //   read the remainder of the record.

            dataSize = 0
            asciiData.removeAll()

            //   Loop over the directory entries, making a pass counting them.
            let nFieldEntryWidth = sizeofFieldLength + sizeofFieldPos + sizeofFieldTag
            fieldCount = 0
            var tmpBuf: Data

            // while we're not at the end, store this entry, and keep on reading...
            repeat {
                do {
                    data = try fileHandle.read(upToCount: nFieldEntryWidth)
                    tmpBuf = data!
                } catch {
                    print(error.localizedDescription)
                    return false
                }

                if tmpBuf.count != nFieldEntryWidth {
                    print("Data record is short on DDF file.")
                    return false
                }

                // move this temp buffer into more permanent storage:
                var newBuf = asciiData[...dataSize]
                asciiData.removeAll()
                newBuf.append(contentsOf: tmpBuf[...nFieldEntryWidth])
                asciiData = newBuf
                dataSize += nFieldEntryWidth

                if DDF_FIELD_TERMINATOR != tmpBuf[0] {
                    fieldCount += 1
                }
            } while DDF_FIELD_TERMINATOR != tmpBuf[0]

            // Now, rewind a little. Only the TERMINATOR should have been read:
            let rewindSize = nFieldEntryWidth - 1
            guard let fp = module.fileHandle else {
                return false
            }
            do {
                let pos = try fp.offset() - UInt64(rewindSize)
                try fp.seek(toOffset: pos)
            } catch {
                print(error.localizedDescription)
                return false
            }
            dataSize -= rewindSize

            // Okay, now populate from asciiData...
            for i in 0..<fieldCount {
                let nEntryOffset = (i*nFieldEntryWidth) + sizeofFieldTag
                let nFieldLength = DDFUtils.DDFScanInt(source: asciiData,
                                                       fromIndex: nEntryOffset,
                                                       maxChars: sizeofFieldLength) ?? 0
                var tmpBuf: Data

                // read an Entry:
                do {
                    data = try fp.read(upToCount: nFieldLength)
                } catch {
                    print(error.localizedDescription)
                    return false
                }

                tmpBuf = data!

                if tmpBuf.count != nFieldLength {
                    print("Data record is short on DDF file.")
                    return false
                }

                // Move this temp buffer into more permanent storage:
                //var newBuf = asciiData[...dataSize]
                var newBuf = asciiData.subdata(in: Range(0...dataSize))
                asciiData.removeAll()
                //newBuf += tmpBuf[...nFieldLength]
                newBuf.append(tmpBuf.subdata(in: Range(0...nFieldLength)))
                tmpBuf.removeAll()
                asciiData = newBuf
                dataSize += nFieldLength
            }

            // Allocate, and read field definitions.
            //fields = new DDFField[nFieldCount];
            for i in 0..<fieldCount {
                var tag = ""
                var entryOffset = i*nFieldEntryWidth
                var fieldLength: Int
                var fieldPosition: Int

                // read the position information and tag.
                tag = String(data: asciiData[entryOffset...(entryOffset+sizeofFieldTag-1)], encoding: .utf8) ?? ""

                entryOffset += sizeofFieldTag
                fieldLength = DDFUtils.DDFScanInt(source: asciiData, fromIndex: entryOffset, maxChars: sizeofFieldLength) ?? 0

                entryOffset += sizeofFieldLength
                fieldPosition = DDFUtils.DDFScanInt(source: asciiData, fromIndex: entryOffset, maxChars: sizeofFieldPos) ?? 0

                // Find the corresponding field in the module directory.
                guard let fieldDefinition = module.findFieldDefinition(tag: tag) else {
                    print("(2) Undefined field named: \(tag) encountered in data record.")
                    return false
                }

                // Assign info the DDFField.
                fields[i].initialize(fieldDefinition: fieldDefinition,
                                     asciiDataIn: asciiData[(fieldAreaStart + fieldPosition - LEADER_SIZE)...],
                                     dataSize: fieldLength)
            }
            return true
        }
    }
}
