import XCTest

class EmptyUITests: XCTestCase {
  var app: XCUIApplication!

  /// Prefix shared by every contract test harness variable. Kept as a literal because a UI test
  /// bundle cannot import the app under test; `ContractTestConfigTests` asserts that every key
  /// `ContractTestConfig` reads carries this prefix, so the two cannot drift silently.
  private static let harnessEnvironmentPrefix = "AWS_OTEL_CONTRACT_"

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments.append("--contractTestMode")
    // Forward harness configuration into the simulator. `xcodebuild` hands these to the test
    // runner via `TEST_RUNNER_`-prefixed variables (the prefix is stripped before we see them);
    // the runner is a different process from the app, so they have to be re-injected here.
    //
    // Launch *environment*, never launch arguments: the app prints its arguments at startup and
    // the app monitor id is a CI secret.
    let harnessEnvironment = Self.harnessEnvironment()
    app.launchEnvironment.merge(harnessEnvironment) { _, forwarded in forwarded }
    // Key names only, and only the ones actually forwarded above. Never log the values — one of
    // them is a secret.
    print("Forwarding harness environment keys: \(harnessEnvironment.keys.sorted())")
    app.launch()
  }

  /// The harness variables visible to this runner process, forwarded by prefix so adding a new
  /// variable needs no change here.
  private static func harnessEnvironment() -> [String: String] {
    ProcessInfo.processInfo.environment.filter { key, value in
      key.hasPrefix(harnessEnvironmentPrefix)
        && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  // Note: the 15 second stall is just to give the github host enough time to do all the mock interactions, and send all the telemetries
  // to the local endpoint. You can reduce this timeout significantly during local development (e.g. 15 seconds is more than enough).
  func testLaunchApp() throws {
    print("Waiting 15 seconds for telemetry generation...")
    Thread.sleep(forTimeInterval: 15)
    print("Test completed")
    XCTAssertTrue(true)
  }
}
