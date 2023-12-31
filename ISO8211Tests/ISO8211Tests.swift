//
//  ISO8211Tests.swift
//  ISO8211Tests
//
//  Created by Christopher Alford on 26/12/23.
//

import XCTest
@testable import ISO8211

final class ISO8211Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testExpandFormat() throws {
        let ddf = DDFFieldDefinition()
        // extractSubstring(pszSrc: [UInt8]) -> [UInt8]
//        let r1 = ddf.extractSubstring(pszSrc: str1.byteArray)
//        print(r1.string)
//        let r2 = ddf.extractSubstring(pszSrc: str2.byteArray)
//        print(r2.string)

        let str1 = "(A,3(B,C),D),X,Y)" // return "A,3(B,C),D".
        let r1 = ddf.expandFormat(source: str1)
        XCTAssertTrue(r1 == "A,3(B,C),D")
        print(r1)

        let str2 = "3A,2C" //return "3A".
        let r2 = ddf.expandFormat(source: str2)
        XCTAssertTrue(r2 == "A,A,A,C,C")
        print(r2)

        let str0 = "(A(2),I(10),3A,A(3),4R,2A)"
        let r3 = ddf.expandFormat(source: str0)
        XCTAssertTrue(r3 == "A(2),I(10),A,A,A,A(3),R,R,R,R,A,A")
        print(r3)
    }

//    func testScanVariable() throws {
//        let data: [UInt8] = [31, 48, 48, 48, 49, 67, 65, 84, 68, 30]
//        let result = scanVariable(data: data, maxLength: data.count - 1, delimiter: fieldTerminator)
//        XCTAssertTrue(result == 8)
//    }

//    func testFetchVariable() throws {
//        let data: [UInt8] = [31, 48, 48, 48, 49, 67, 65, 84, 68, 30]
//        let consumed = 0
//        let result = fetchVariable(data: data,
//                                   maxLength: data.count - 1,
//                                   delimiter1: unitTerminator,
//                                   delimiter2: fieldTerminator,
//                                   consumed: consumed)
//        XCTAssertTrue(result.0 == "0001CATD" && result.1 == 9)
//
//    }

//    func testExpandFormat() throws {
//        let formatControls = "(A(2),I(10),3A,A(3),4R,2A)"
//        let result = formatControls.expandFormat()
//        XCTAssertTrue(result == "A(2),I(10),A,A,A,A(3),R,R,R,R,A,A")
//    }

//    func testExtractions() throws {
//        var data1 = Array("CD0000000001CATALOG.031\u{1f}\u{1f}V01X01vASC\u{1f}9.87654321\u{1f}\u{1f}\u{1f}\u{1f}\u{1e}".utf8)
//        var bytesConsumed = 0
//        var maxBytes = 42
//        var formatWidth = 2
//
//        // Get the "CD"
//        let result1 = data1.extractStringData(maxLength: maxBytes, isVariable: false, formatWidth: formatWidth, consumed: 0)
//        XCTAssert(result1.value == "CD")
//        XCTAssert(result1.consumed == 2)
//
//        bytesConsumed = result1.consumed
//        data1 = Array(data1[bytesConsumed...])
//
//        // Get the ...0001
//        let formatString = "I(10)"
//        formatWidth = 10
//        let result2 = data1.extractIntData(maxLength: maxBytes,
//                                           isVariable: false,
//                                           formatString: formatString,
//                                           formatWidth: formatWidth,
//                                           binaryFormat: .notBinary,
//                                           consumed: 0)
//        XCTAssert(result2.value == 1)
//        XCTAssert(result2.consumed == 10)
//
//        bytesConsumed = result2.consumed
//        data1 = Array(data1[bytesConsumed...])
//
//        // Get the file name
//        let bytesRemaining = 30
//        let result3 = data1.extractStringData(maxLength: bytesRemaining, isVariable: false, formatWidth: 11, consumed: bytesConsumed)
//        XCTAssert(result3.value == "CATALOG.031")
//
//    }

//    func testInits() throws {
//        let data = Array("002623LE1 0900073   6604".utf8)
//        let fieldAreaStart = Int(bytes: Array(data[12...16]))
//        let recordLength = Int(bytes: Array(data[...4]))
//        let sizeFieldLength = Int(bytes: Array(arrayLiteral: data[20]))
//        XCTAssert(fieldAreaStart == 73)
//        XCTAssert(recordLength == 262)
//        XCTAssert(sizeFieldLength == 6)
//    }

}
