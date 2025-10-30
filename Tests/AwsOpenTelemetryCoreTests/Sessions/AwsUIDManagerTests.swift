import XCTest
@testable import AwsOpenTelemetryCore

final class AwsUIDManagerTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Clear any existing UID for clean tests
    UserDefaults.standard.removeObject(forKey: "aws-rum-user-id")
  }

  func testUIDGeneration() {
    let manager = AwsUIDManager()
    let uid = manager.getUID()

    XCTAssertFalse(uid.isEmpty)
    XCTAssertTrue(uid.contains("-")) // UUID format check
  }

  func testUIDPersistence() {
    // Test that a fresh manager saves UID to UserDefaults
    let manager = AwsUIDManager()
    let firstUID = manager.getUID()

    // Verify it's saved to UserDefaults
    let savedUID = UserDefaults.standard.string(forKey: "aws-rum-user-id")
    XCTAssertEqual(firstUID, savedUID)
  }

  func testUIDConsistency() {
    let manager = AwsUIDManager()
    let firstCall = manager.getUID()
    let secondCall = manager.getUID()

    XCTAssertEqual(firstCall, secondCall)
  }

  func testSetUIDUpdate() {
    let manager = AwsUIDManager()
    let originalUID = manager.getUID()
    let customUID = "custom-test-uid-123"

    manager.setUID(uid: customUID)
    let updatedUID = manager.getUID()

    XCTAssertNotEqual(originalUID, updatedUID)
    XCTAssertEqual(customUID, updatedUID)
  }

  func testSetUIDPersistence() {
    let manager = AwsUIDManager()
    let customUID = "persistent-test-uid-456"

    manager.setUID(uid: customUID)

    // Verify it's saved to UserDefaults
    let savedUID = UserDefaults.standard.string(forKey: "aws-rum-user-id")
    XCTAssertEqual(customUID, savedUID)

    // Create new manager to test persistence across instances
    let newManager = AwsUIDManager()
    XCTAssertEqual(customUID, newManager.getUID())
  }

  func testThreadSafety() {
    let manager = AwsUIDManager()
    let expectation = XCTestExpectation(description: "Thread safety test")
    let iterations = 100
    var results: [String] = []
    let resultsLock = NSLock()

    // Launch multiple concurrent operations
    for i in 0 ..< iterations {
      DispatchQueue.global().async {
        if i % 2 == 0 {
          // Half the operations read UID
          let uid = manager.getUID()
          resultsLock.withLock {
            results.append(uid)
          }
        } else {
          // Half the operations set UID
          manager.setUID(uid: "thread-test-\(i)")
        }

        if results.count + (iterations / 2) >= iterations {
          expectation.fulfill()
        }
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Verify no crashes occurred and operations completed
    XCTAssertGreaterThan(results.count, 0)
  }
}
