import XCTest
import OpenTelemetryApi
@testable import AwsOpenTelemetryCore

final class GlobalAttributesManagerTests: XCTestCase {
  var manager: GlobalAttributesManager!

  override func setUp() {
    super.setUp()
    manager = GlobalAttributesManager()
  }

  func testSetAndGetAttribute() {
    manager.setAttribute(key: "test.key", value: .string("test.value"))
    let value = manager.getAttribute(key: "test.key")
    XCTAssertEqual(value, .string("test.value"))
  }

  func testGetNonExistentAttribute() {
    let value = manager.getAttribute(key: "nonexistent")
    XCTAssertNil(value)
  }

  func testGetAllAttributes() {
    manager.setAttribute(key: "key1", value: .string("value1"))
    manager.setAttribute(key: "key2", value: .int(42))

    let attributes = manager.getAttributes()
    XCTAssertEqual(attributes.count, 2)
    XCTAssertEqual(attributes["key1"], .string("value1"))
    XCTAssertEqual(attributes["key2"], .int(42))
  }

  func testRemoveAttribute() {
    manager.setAttribute(key: "test.key", value: .string("test.value"))
    manager.removeAttribute(key: "test.key")

    let value = manager.getAttribute(key: "test.key")
    XCTAssertNil(value)
  }

  func testClearAttributes() {
    manager.setAttribute(key: "key1", value: .string("value1"))
    manager.setAttribute(key: "key2", value: .int(42))
    manager.clearAttributes()

    let attributes = manager.getAttributes()
    XCTAssertTrue(attributes.isEmpty)
  }

  func testOverwriteAttribute() {
    manager.setAttribute(key: "test.key", value: .string("old.value"))
    manager.setAttribute(key: "test.key", value: .string("new.value"))

    let value = manager.getAttribute(key: "test.key")
    XCTAssertEqual(value, .string("new.value"))
  }

  func testConcurrentSetAttribute() {
    let group = DispatchGroup()

    for i in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        self.manager.setAttribute(key: "key\(i)", value: .string("value\(i)"))
        group.leave()
      }
    }

    group.wait()

    let attributes = manager.getAttributes()
    XCTAssertEqual(attributes.count, 100)
  }

  func testConcurrentGetAndSetAttribute() {
    manager.setAttribute(key: "shared.key", value: .string("initial"))

    let group = DispatchGroup()
    var readValues: [AttributeValue?] = []
    let syncQueue = DispatchQueue(label: "test.sync")

    for i in 0 ..< 50 {
      group.enter()
      DispatchQueue.global().async {
        if i % 2 == 0 {
          self.manager.setAttribute(key: "shared.key", value: .string("updated\(i)"))
        } else {
          let value = self.manager.getAttribute(key: "shared.key")
          syncQueue.async {
            readValues.append(value)
          }
        }
        group.leave()
      }
    }

    group.wait()

    syncQueue.sync {
      XCTAssertFalse(readValues.isEmpty)
      for value in readValues {
        XCTAssertNotNil(value)
      }
    }
  }
}
