import XCTest
@testable import AwsOpenTelemetryCore

final class AwsUIDManagerTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Clear any existing UID for clean tests
    UserDefaults.standard.removeObject(forKey: "aws-rum-user-id")
  }

  func testUIDGeneration() {
    let manager = AwsUIDManager.shared
    let uid = manager.getUID()

    XCTAssertFalse(uid.isEmpty)
    XCTAssertTrue(uid.contains("-")) // UUID format check
  }

  func testUIDPersistence() {
    // Test that a fresh manager saves UID to UserDefaults
    let manager = MockUIDManager()
    let firstUID = manager.getUID()

    // Verify it's saved to UserDefaults
    let savedUID = UserDefaults.standard.string(forKey: "aws-rum-user-id")
    XCTAssertEqual(firstUID, savedUID)
  }

  func testUIDConsistency() {
    let manager = AwsUIDManager.shared
    let firstCall = manager.getUID()
    let secondCall = manager.getUID()

    XCTAssertEqual(firstCall, secondCall)
  }
}

// MARK: - Mock Classes

class MockUIDManager: AwsUIDManager {
  // Override to create a fresh instance for testing persistence
}
