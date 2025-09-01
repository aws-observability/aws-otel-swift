import XCTest
@testable import AwsOpenTelemetryCore

final class AwsUIDManagerProviderTests: XCTestCase {
  func testGetInstanceReturnsDefaultManager() {
    let manager = AwsUIDManagerProvider.getInstance()
    XCTAssertNotNil(manager)
  }

  func testSingletonBehavior() {
    let manager1 = AwsUIDManagerProvider.getInstance()
    let manager2 = AwsUIDManagerProvider.getInstance()
    XCTAssertTrue(manager1 === manager2)
  }

  func testConcurrentGetInstanceCreatesOnlyOneInstance() {
    let group = DispatchGroup()
    var instances: [AwsUIDManager] = []
    let syncQueue = DispatchQueue(label: "test.instances")

    for _ in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        let instance = AwsUIDManagerProvider.getInstance()
        syncQueue.async {
          instances.append(instance)
          group.leave()
        }
      }
    }

    group.wait()

    XCTAssertEqual(instances.count, 100)
    let firstInstance = instances[0]
    for instance in instances {
      XCTAssertTrue(instance === firstInstance, "All instances should be the same object")
    }
  }
}
