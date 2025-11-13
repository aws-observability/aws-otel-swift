import XCTest
@testable import AwsOpenTelemetryCore

final class AwsGlobalAttributesProviderTests: XCTestCase {
  func testGetInstance() {
    let instance1 = AwsGlobalAttributesProvider.getInstance()
    let instance2 = AwsGlobalAttributesProvider.getInstance()
    XCTAssertTrue(instance1 === instance2)
  }

  func testConcurrentGetInstance() {
    let group = DispatchGroup()
    var instances: [AwsGlobalAttributesManager] = []
    let syncQueue = DispatchQueue(label: "test.sync")

    for _ in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        let instance = AwsGlobalAttributesProvider.getInstance()
        syncQueue.async {
          instances.append(instance)
        }
        group.leave()
      }
    }

    group.wait()

    syncQueue.sync {
      XCTAssertEqual(instances.count, 100)
      let firstInstance = instances[0]
      for instance in instances {
        XCTAssertTrue(instance === firstInstance)
      }
    }
  }
}
