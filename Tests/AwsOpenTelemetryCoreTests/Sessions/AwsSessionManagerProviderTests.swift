import XCTest
@testable import AwsOpenTelemetryCore

final class AwsSessionManagerProviderTests: XCTestCase {
  override func tearDown() {
    // Reset singleton state for clean tests
    AwsSessionManagerProvider.register(sessionManager: AwsSessionManager())
    super.tearDown()
  }

  func testGetInstanceReturnsDefaultManager() {
    let manager = AwsSessionManagerProvider.getInstance()
    XCTAssertNotNil(manager)
  }

  func testRegisterAndGetInstance() {
    let customManager = AwsSessionManager(configuration: AwsSessionConfig(sessionTimeout: 3600))
    AwsSessionManagerProvider.register(sessionManager: customManager)

    let retrievedManager = AwsSessionManagerProvider.getInstance()
    XCTAssertTrue(retrievedManager === customManager)
  }

  func testSingletonBehavior() {
    let manager1 = AwsSessionManagerProvider.getInstance()
    let manager2 = AwsSessionManagerProvider.getInstance()
    XCTAssertTrue(manager1 === manager2)
  }

  func testThreadSafety() {
    let expectation = XCTestExpectation(description: "Thread safety test")
    expectation.expectedFulfillmentCount = 10

    var managers: [AwsSessionManager] = []
    let queue = DispatchQueue.global(qos: .default)
    let syncQueue = DispatchQueue(label: "test.sync")

    for _ in 0 ..< 10 {
      queue.async {
        let manager = AwsSessionManagerProvider.getInstance()
        syncQueue.async {
          managers.append(manager)
          expectation.fulfill()
        }
      }
    }

    wait(for: [expectation], timeout: 1.0)

    let firstManager = managers.first!
    for manager in managers {
      XCTAssertTrue(manager === firstManager)
    }
  }

  func testConcurrentGetInstanceCreatesOnlyOneInstance() {
    let group = DispatchGroup()
    var instances: [AwsSessionManager] = []
    let syncQueue = DispatchQueue(label: "test.instances")

    for _ in 0 ..< 100 {
      group.enter()
      DispatchQueue.global().async {
        let instance = AwsSessionManagerProvider.getInstance()
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
