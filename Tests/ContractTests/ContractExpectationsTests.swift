import XCTest

// Resolution rules for the values `ResourceAttributesTests` expects to find in the round-tripped
// resource attributes. Tested against an injected dictionary rather than the real process
// environment: `setenv` would leak across test cases in the same process, and the point of the type
// is the resolution, not the lookup.
class ContractExpectationsTests: XCTestCase {
  func testDefaultsToHermeticValuesWhenNothingIsSet() {
    let expectations = ContractExpectations.resolved(from: [:])

    XCTAssertEqual(expectations.appMonitorId, "test-app-monitor-id")
    XCTAssertEqual(expectations.region, "us-east-1")
  }

  func testUsesSuppliedValues() {
    let expectations = ContractExpectations.resolved(from: [
      "AWS_OTEL_CONTRACT_APP_MONITOR_ID": "11111111-2222-3333-4444-555555555555",
      "AWS_OTEL_CONTRACT_REGION": "eu-west-1"
    ])

    XCTAssertEqual(expectations.appMonitorId, "11111111-2222-3333-4444-555555555555")
    XCTAssertEqual(expectations.region, "eu-west-1")
  }

  // Empty must behave exactly like absent, matching `ContractTestConfig`. An unset GitHub secret
  // expands to the empty string, so the two cases are indistinguishable in CI — and defaulting is
  // the only safe reading: asserting against "" would fail every assertion with a confusing message.
  func testTreatsEmptyAsAbsent() {
    let expectations = ContractExpectations.resolved(from: [
      "AWS_OTEL_CONTRACT_APP_MONITOR_ID": "",
      "AWS_OTEL_CONTRACT_REGION": ""
    ])

    XCTAssertEqual(expectations.appMonitorId, "test-app-monitor-id")
    XCTAssertEqual(expectations.region, "us-east-1")
  }

  func testTreatsWhitespaceOnlyAsAbsent() {
    let expectations = ContractExpectations.resolved(from: [
      "AWS_OTEL_CONTRACT_APP_MONITOR_ID": "   ",
      "AWS_OTEL_CONTRACT_REGION": "\n\t "
    ])

    XCTAssertEqual(expectations.appMonitorId, "test-app-monitor-id")
    XCTAssertEqual(expectations.region, "us-east-1")
  }

  // The harness trims before handing values to the app, so the expectation has to trim too or a
  // stray newline in a secret would produce a mismatch against a value that did round-trip fine.
  func testTrimsSurroundingWhitespace() {
    let expectations = ContractExpectations.resolved(from: [
      "AWS_OTEL_CONTRACT_APP_MONITOR_ID": "  real-id\n",
      "AWS_OTEL_CONTRACT_REGION": " us-west-2 "
    ])

    XCTAssertEqual(expectations.appMonitorId, "real-id")
    XCTAssertEqual(expectations.region, "us-west-2")
  }

  func testResolvesEachValueIndependently() {
    let expectations = ContractExpectations.resolved(from: [
      "AWS_OTEL_CONTRACT_REGION": "ap-southeast-2"
    ])

    XCTAssertEqual(expectations.appMonitorId, "test-app-monitor-id")
    XCTAssertEqual(expectations.region, "ap-southeast-2")
  }

  // Guards the wiring, not the resolution: `current` must read the process environment through the
  // same rules. With no AWS_OTEL_CONTRACT_* set (the hermetic default) it has to produce the
  // hermetic literals, or the hermetic suite would start asserting against something else.
  func testCurrentReadsTheProcessEnvironment() {
    let environment = ProcessInfo.processInfo.environment
    let expectations = ContractExpectations.current

    XCTAssertEqual(expectations.appMonitorId, ContractExpectations.resolved(from: environment).appMonitorId)
    XCTAssertEqual(expectations.region, ContractExpectations.resolved(from: environment).region)
  }
}
