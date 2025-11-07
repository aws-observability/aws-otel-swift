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

  func testSetUIDPostsNotification() {
    let manager = AwsUIDManager()
    let expectation = XCTestExpectation(description: "UID change notification")
    var receivedUID: String?

    let observer = NotificationCenter.default.addObserver(
      forName: AwsUserIdChangeNotification,
      object: nil,
      queue: nil
    ) { notification in
      receivedUID = notification.object as? String
      expectation.fulfill()
    }

    let testUID = "test-uid-123"
    manager.setUID(uid: testUID)

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedUID, testUID)

    NotificationCenter.default.removeObserver(observer)
  }

  func testMultipleSetUIDCallsPostMultipleNotifications() {
    let manager = AwsUIDManager()
    var receivedUIDs: [String] = []
    let expectation = XCTestExpectation(description: "Multiple UID notifications")
    expectation.expectedFulfillmentCount = 3

    let observer = NotificationCenter.default.addObserver(
      forName: AwsUserIdChangeNotification,
      object: nil,
      queue: nil
    ) { notification in
      if let uid = notification.object as? String {
        receivedUIDs.append(uid)
      }
      expectation.fulfill()
    }

    manager.setUID(uid: "uid1")
    manager.setUID(uid: "uid2")
    manager.setUID(uid: "uid3")

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedUIDs, ["uid1", "uid2", "uid3"])

    NotificationCenter.default.removeObserver(observer)
  }
}
