//
//  DDFRecord.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import Foundation

public class DDFRecord {
    //TODO: Look at where poModule is used, possibly change this to a struct
    private var poModule: DDFModule
    private var nReuseHeader: Bool
    private var nFieldOffset: Int   // field data area, not dir entries.
    private var _sizeFieldTag: Int
    private var _sizeFieldPos: Int
    private var _sizeFieldLength: Int
    private var nDataSize: Int     // Whole record except leader with header
    private var asciiData: Data = Data()
    private var nFieldCount: Int
    private var paoFields: [DDFField] = []
    private var bIsClone: Bool

    private let nLeaderSize = 24

    public init(_ poModuleIn: DDFModule) {
        poModule = poModuleIn
        nReuseHeader = false
        nFieldOffset = 0
        nDataSize = 0
        nFieldCount = 0
        bIsClone = false
        _sizeFieldTag = 4
        _sizeFieldPos = 0
        _sizeFieldLength = 0
    }

    /** Fetch size of records raw data (getData()) in bytes. */
    public func getDataSize() -> Int {
        return nDataSize
    }

    /** Get the number of DDFFields on this record. */
    public func getFieldCount() -> Int {
        return nFieldCount
    }

    /**
     * Fetch field object based on index.
     *
     * - Parameter i The index of the field to fetch.  Between 0 and getFieldCount()-1.
     *
     * - Returns A DDFField, or nil if the index is out of range.
     */
    public func getField(at i: Int) -> DDFField? {
        if i < 0 || i >= nFieldCount {
            return nil
        } else {
            return paoFields[i]
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
        if nReuseHeader == false {
            return readHeader()
        }

        // Otherwise we read just the data and carefully overlay it on
        // the previous records data without disturbing the rest of the
        // record.
        var data: Data?
        guard let fp = poModule.fileHandle else {
            return false
        }
        do {
            data = try fp.read(upToCount: nDataSize - nFieldOffset)
        } catch {
            print(error.localizedDescription)
            return false
        }
        guard let data = data else { return false }
        asciiData.insert(contentsOf: data, at: nFieldOffset)
        if data.count != (nDataSize - nFieldOffset)
            && data.count == 0
            && fp.availableData.count == 0 {
            return false
        } else if data.count != (nDataSize - nFieldOffset) {
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
        paoFields.removeAll()
        nFieldCount = 0
        asciiData.removeAll()
        nDataSize = 0
        nReuseHeader = false
        
        // read the 24 byte leader.
        var achLeader: Data
        var data: Data?
        guard let fp = poModule.fileHandle else {
            return false
        }
        do {
            data = try fp.read(upToCount: nLeaderSize)
        } catch {
            print(error.localizedDescription)
            return false
        }
        
        if data?.count == 0 && fp.availableData.count == 0 {
            return false
        } else if data?.count != nLeaderSize {
            print("Leader is short on DDF file.")
            return false
        }
        achLeader = data!
        
        // Extract information from leader.
        var _recLength: Int
        var _fieldAreaStart: Int
        var _leaderIden: UInt8
        _recLength = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 0, maxChars: 5) ?? 0
        _leaderIden = achLeader[6]
        _fieldAreaStart = DDFUtils.DDFScanInt(source: achLeader, fromIndex: 12, maxChars: 5) ?? 0
        _sizeFieldLength = Int(achLeader[20] - "0".byte)
        _sizeFieldPos = Int(achLeader[21] - "0".byte)
        _sizeFieldTag = Int(achLeader[23] - "0".byte)
        
        if _sizeFieldLength < 0 || _sizeFieldLength > 9
            || _sizeFieldPos < 0 || _sizeFieldPos > 9
            || _sizeFieldTag < 0 || _sizeFieldTag > 9 {
            print("ISO8211 record leader appears to be corrupt.")
            return false
        }
        
        if _leaderIden == "R".byte {
            nReuseHeader = true
        }
        nFieldOffset = _fieldAreaStart - nLeaderSize;
        
        // Simple checks
        if (_recLength < 24 || _recLength > 100000000 || _fieldAreaStart < 24 || _fieldAreaStart > 100000)
            && (_recLength != 0) {
            print("Data record appears to be corrupt on DDF file.")
            return false
        }
        
        // Handle the normal case with the record length available.
        if _recLength != 0 {
            // read the remainder of the record.
            nDataSize = _recLength - nLeaderSize
            do {
                data = try fp.read(upToCount: nDataSize)
            } catch {
                print(error.localizedDescription)
                return false
            }
            guard let data = data else { return false }
            if data.count != nDataSize {
                print("Data record is short on DDF file.")
                return false
            }
            asciiData = data
            
            // If there is no field terminator at the end of the record
            // read additional bytes till one is found.
            while(asciiData[nDataSize-1] != DDF_FIELD_TERMINATOR) {
                nDataSize += 1
                do {
                    let newData = try fp.read(upToCount: 1)
                    asciiData += newData!
                } catch {
                    print(error.localizedDescription)
                    return false
                }
            }
            
            // Count the directory entries.
            let nFieldEntryWidth = _sizeFieldLength + _sizeFieldPos + _sizeFieldTag;
            nFieldCount = 0
            for i in stride(from: 0, to: nDataSize, by: nFieldEntryWidth) {
                if asciiData[i] == DDF_FIELD_TERMINATOR {
                    break
                }
                nFieldCount += 1
            }
            
            // Allocate, and read field definitions.
            for i in 0..<nFieldCount {
                var szTag: String
                var nEntryOffset = i*nFieldEntryWidth
                var nFieldLength: Int
                var nFieldPos: Int
                
                // read the position information and tag.
                szTag = String(bytes: Array(asciiData[nEntryOffset...(nEntryOffset+_sizeFieldTag-1)]), encoding: .utf8) ?? ""
                nEntryOffset += _sizeFieldTag
                nFieldLength = DDFUtils.DDFScanInt(source: asciiData, fromIndex: nEntryOffset, maxChars: _sizeFieldLength) ?? 0
                nEntryOffset += _sizeFieldLength;
                nFieldPos = DDFUtils.DDFScanInt(source: asciiData, fromIndex: nEntryOffset, maxChars: _sizeFieldPos) ?? 0
                
                // Find the corresponding field in the module directory.
                guard let poFieldDefn: DDFFieldDefinition = poModule.findFieldDefinition(fieldName: szTag) else {
                    print("(1) Undefined field named: \(szTag) encountered in data record.")
                    return false
                }
                
                // Create the DDFField
                let startIndex = _fieldAreaStart + nFieldPos - nLeaderSize
                let endIndex = asciiData.count-1
                let bytes = data[startIndex...endIndex]
                paoFields.append(DDFField(poDefnIn: poFieldDefn,
                                             asciiDataIn: bytes,
                                             nDataSizeIn: nFieldLength))
            }
            return true
        }
        
        // Handle the exceptional case where the record length is
        // zero.  In this case we have to read all the data based on
        // the size of data items as per ISO8211 spec Annex C, 1.5.1.
        else {
            print("Record with zero length, use variant (C.1.5.1) logic.")
            
            //   _recLength == 0, handle the large record.
            //   read the remainder of the record.
            
            nDataSize = 0
            asciiData.removeAll()
            
            //   Loop over the directory entries, making a pass counting them.
            let nFieldEntryWidth = _sizeFieldLength + _sizeFieldPos + _sizeFieldTag
            nFieldCount = 0
            var tmpBuf: Data

            // while we're not at the end, store this entry,
            // and keep on reading...
            repeat {
                do {
                    data = try fp.read(upToCount: nFieldEntryWidth)
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
                var newBuf = asciiData[...nDataSize]
                asciiData.removeAll()
                newBuf.append(contentsOf: tmpBuf[...nFieldEntryWidth])
                asciiData = newBuf
                nDataSize += nFieldEntryWidth
                
                if DDF_FIELD_TERMINATOR != tmpBuf[0] {
                    nFieldCount += 1
                }
            } while DDF_FIELD_TERMINATOR != tmpBuf[0]
            
            // Now, rewind a little.  Only the TERMINATOR should have been read:
            let rewindSize = nFieldEntryWidth - 1
            guard let fp = poModule.fileHandle else {
                return false
            }
            do {
                let pos = try fp.offset() - UInt64(rewindSize)
                try fp.seek(toOffset: pos)
            } catch {
                print(error.localizedDescription)
                return false
            }
            nDataSize -= rewindSize;
            
            // Okay, now populate from asciiData...
            for i in 0..<nFieldCount {
                let nEntryOffset = (i*nFieldEntryWidth) + _sizeFieldTag
                let nFieldLength = DDFUtils.DDFScanInt(source: asciiData,
                                                       fromIndex: nEntryOffset,
                                                       maxChars: _sizeFieldLength) ?? 0
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
                var newBuf = asciiData[...nDataSize]
                asciiData.removeAll()
                newBuf += tmpBuf[...nFieldLength]
                tmpBuf.removeAll()
                asciiData = newBuf
                nDataSize += nFieldLength
            }
            
            // Allocate, and read field definitions.
            //paoFields = new DDFField[nFieldCount];
            for i in 0..<nFieldCount {
                var szTag = ""
                var nEntryOffset = i*nFieldEntryWidth
                var nFieldLength: Int
                var nFieldPos: Int
                
                // read the position information and tag.
                szTag = String(data: asciiData[nEntryOffset...(nEntryOffset+_sizeFieldTag-1)], encoding: .utf8) ?? ""

                nEntryOffset += _sizeFieldTag
                nFieldLength = DDFUtils.DDFScanInt(source: asciiData, fromIndex: nEntryOffset, maxChars: _sizeFieldLength) ?? 0
                
                nEntryOffset += _sizeFieldLength
                nFieldPos = DDFUtils.DDFScanInt(source: asciiData, fromIndex: nEntryOffset, maxChars: _sizeFieldPos) ?? 0
                
                // Find the corresponding field in the module directory.
                guard let poFieldDefn: DDFFieldDefinition = poModule.findFieldDefinition(fieldName: szTag) else {
                    print("(2) Undefined field named: \(szTag) encountered in data record.")
                    return false
                }
                
                // Assign info the DDFField.
                paoFields[i].initialize(poDefnIn: poFieldDefn,
                                        asciiDataIn: asciiData[(_fieldAreaStart + nFieldPos - nLeaderSize)...],
                                        nDataSizeIn: nFieldLength)
            }
            return true
        }
    }
}
