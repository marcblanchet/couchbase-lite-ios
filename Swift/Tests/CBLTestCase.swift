//
//  CBLTestCase.swift
//  CouchbaseLite
//
//  Copyright (c) 2017 Couchbase, Inc All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
import Foundation
import CouchbaseLiteSwift

extension String {
    func toJSONObj() -> Any {
        let d = self.data(using: .utf8)!
        return try! JSONSerialization.jsonObject(with: d, options: [])
    }
}

class CBLTestCase: XCTestCase {

    /// Opened when setting up each test case.
    var db: Database!
    
    /// Need to explicitly open by calling openOtherDB() function.
    var otherDB: Database?
    
    let databaseName = "testdb"
    
    let otherDatabaseName = "otherdb"
    
    #if COUCHBASE_ENTERPRISE
        let directory = NSTemporaryDirectory().appending("CouchbaseLite-EE")
    #else
        let directory = NSTemporaryDirectory().appending("CouchbaseLite")
    #endif
    
    var isHostApp: Bool {
    #if os(iOS)
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "hostApp")
    #else
        return true
    #endif
    }
    
    var keyChainAccessAllowed: Bool {
    #if os(iOS)
        return self.isHostApp
    #else
        return true
    #endif
    }
    
    /// This expectation will allow overfill expectation.
    /// CBL-2363: Replicator might send extra idle status when its being stopped, which is not a bug
    func allowOverfillExpectation(description: String) -> XCTestExpectation {
        let e = super.expectation(description: description)
        e.assertForOverFulfill = false
        return e
    }
    
    override func setUp() {
        super.setUp()
        
        try? deleteDB(name: databaseName);
        
        try? deleteDB(name: otherDatabaseName);
        
        if FileManager.default.fileExists(atPath: self.directory) {
            try! FileManager.default.removeItem(atPath: self.directory)
        }
        XCTAssertTrue(!FileManager.default.fileExists(atPath: self.directory))
        
        try! openDB()
    }
    
    override func tearDown() {
        try! db.close()
        try! otherDB?.close()
        super.tearDown()
    }
    
    func openDB(name: String) throws -> Database {
        var config = DatabaseConfiguration()
        config.directory = self.directory
        return try Database(name: name, config: config)
    }
    
    func openDB() throws {
        db = try openDB(name: databaseName)
    }
    
    func reopenDB() throws {
        try db.close()
        db = nil
        try openDB()
    }
    
    func cleanDB() throws {
        try db.delete()
        try reopenDB()
    }
    
    func openOtherDB() throws {
        otherDB = try openDB(name: otherDatabaseName)
    }
    
    func reopenOtherDB() throws {
        try otherDB?.close()
        otherDB = nil
        try openOtherDB()
    }
    
    func deleteDB(name: String) throws {
        try Database.delete(withName: name, inDirectory: self.directory)
    }
    
    func createDocument() -> MutableDocument {
        return MutableDocument()
    }
    
    func createDocument(_ id: String?) -> MutableDocument {
        return MutableDocument(id: id)
    }
    
    func createDocument(_ id: String?, data: [String:Any]) -> MutableDocument {
        return MutableDocument(id: id, data: data)
    }
    
    @discardableResult
    func generateDocument(withID id: String?) throws -> MutableDocument {
        let doc = createDocument(id);
        doc.setValue(1, forKey: "key")
        try saveDocument(doc)
        XCTAssertEqual(doc.sequence, 1)
        XCTAssertNotNil(doc.id)
        if id != nil {
            XCTAssertEqual(doc.id, id)
        }
        return doc
    }
    
    func saveDocument(_ document: MutableDocument) throws {
        try db.saveDocument(document)
        let savedDoc = db.document(withID: document.id)
        XCTAssertNotNil(savedDoc)
        XCTAssertEqual(savedDoc!.id, document.id)
    }
    
    func saveDocument(_ document: MutableDocument, eval: (Document) -> Void) throws {
        eval(document)
        try saveDocument(document)
        eval(document)
        let savedDoc = db.document(withID: document.id)!
        eval(savedDoc)
    }
    
    func urlForResource(name: String, ofType type: String) -> URL? {
        let res = ("Support" as NSString).appendingPathComponent(name)
        return Bundle(for: Swift.type(of:self)).url(forResource: res, withExtension: type)
    }
    
    func dataFromResource(name: String, ofType type: String) throws -> Data {
        let res = ("Support" as NSString).appendingPathComponent(name)
        let path = Bundle(for: Swift.type(of:self)).path(forResource: res, ofType: type)
        return try! NSData(contentsOfFile: path!, options: []) as Data
    }

    func stringFromResource(name: String, ofType type: String) throws -> String {
        let res = ("Support" as NSString).appendingPathComponent(name)
        let path = Bundle(for: Swift.type(of:self)).path(forResource: res, ofType: type)
        return try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
    }
    
    func loadJSONResource(name: String) throws {
        try autoreleasepool {
            let contents = try stringFromResource(name: name, ofType: "json")
            var n = 0
            try db.inBatch {
                contents.enumerateLines(invoking: { (line: String, stop: inout Bool) in
                    n += 1
                    let json = line.data(using: String.Encoding.utf8, allowLossyConversion: false)
                    let dict = try! JSONSerialization.jsonObject(with: json!, options: []) as! [String:Any]
                    let docID = String(format: "doc-%03llu", n)
                    let doc = MutableDocument(id: docID, data: dict)
                    try! self.db.saveDocument(doc)
                })
            }
        }
    }
    
    func jsonFromDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.timeZone = NSTimeZone(abbreviation: "UTC")! as TimeZone
        return formatter.string(from: date).appending("Z")
    }
    
    func dateFromJson(_ date: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = NSTimeZone.local
        return formatter.date(from: date)!
    }
    
    func blobForString(_ string: String) -> Blob {
        let data = string.data(using: .utf8)!
        return Blob(contentType: "text/plain", data: data)
    }
    
    func expectError(domain: String, code: Int, block: @escaping () throws -> Void) {
        CBLTestHelper.allowException {
            var error: NSError?
            do {
                try block()
            }
            catch let e as NSError {
                error = e
            }
            
            XCTAssertNotNil(error, "Block expected to fail but didn't")
            XCTAssertEqual(error?.domain, domain)
            XCTAssertEqual(error?.code, code)
        }
    }
    
    func expectExcepion(exception: NSExceptionName, block: @escaping () -> Void) {
        var exceptionThrown = false
        do {
            try CBLTestHelper.catchException {
                block()
            }
        } catch {
            XCTAssertEqual((error as NSError).domain, exception.rawValue)
            exceptionThrown = true
        }
        
        XCTAssert(exceptionThrown, "No exception thrown")
    }
    
    func ignoreException(block: @escaping () throws -> Void) {
        CBLTestHelper.allowException {
            try? block()
        }
    }
    
    @discardableResult
    func verifyQuery(_ query: Query, block: (UInt64, Result) throws ->Void) throws -> UInt64 {
        var n: UInt64 = 0
        for row in try query.execute() {
            n += 1
            try block(n, row)
        }
        return n
    }
    
    func getRickAndMortyJSON() throws -> String {
        var content = "Earth(C-137)".data(using: .utf8)!
        var blob = Blob(contentType: "text/plain", data: content)
        try self.db.saveBlob(blob: blob)
        
        content = "Grandpa Rick".data(using: .utf8)!
        blob = Blob(contentType: "text/plain", data: content)
        try self.db.saveBlob(blob: blob)
        
        return try stringFromResource(name: "rick_morty", ofType: "json")
    }
    
}

/** Comparing JSON Dictionary */
public func ==(lhs: [String: Any], rhs: [String: Any] ) -> Bool {
    return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

/** Comparing JSON Array */
public func ==(lhs: [Any], rhs: [Any] ) -> Bool {
    return NSArray(array: lhs).isEqual(to: rhs)
}
