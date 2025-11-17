import XCTest
import OpenTelemetryApi
import OpenTelemetrySdk
@testable import AwsOpenTelemetryCore

final class AwsSessionSpanSamplerTests: XCTestCase {
  var mockSessionManager: MockSpanSamplerSessionManager!
  var sampler: AwsSessionSpanSampler!

  override func setUp() {
    super.setUp()
    mockSessionManager = MockSpanSamplerSessionManager()
    sampler = AwsSessionSpanSampler(sessionManager: mockSessionManager)
  }

  func testShouldSampleWithSampledSession() {
    mockSessionManager.setSessionSampled(true)

    let decision = sampler.shouldSample(
      parentContext: nil,
      traceId: TraceId.random(),
      name: "test-span",
      kind: .client,
      attributes: [:],
      parentLinks: []
    )

    XCTAssertTrue(decision.isSampled)
    XCTAssertTrue(decision.attributes.isEmpty)
  }

  func testShouldSampleWithUnsampledSession() {
    mockSessionManager.setSessionSampled(false)

    let decision = sampler.shouldSample(
      parentContext: nil,
      traceId: TraceId.random(),
      name: "test-span",
      kind: .server,
      attributes: ["key": AttributeValue.string("value")],
      parentLinks: []
    )

    XCTAssertFalse(decision.isSampled)
    XCTAssertTrue(decision.attributes.isEmpty)
  }

  func testDescription() {
    XCTAssertEqual(sampler.description, "AwsSessionSpanSampler")
  }

  func testSessionSamplingDecisionStruct() {
    let sampledDecision = AwsSessionSamplingDecision(isSampled: true)
    XCTAssertTrue(sampledDecision.isSampled)
    XCTAssertTrue(sampledDecision.attributes.isEmpty)

    let unsampledDecision = AwsSessionSamplingDecision(isSampled: false)
    XCTAssertFalse(unsampledDecision.isSampled)
    XCTAssertTrue(unsampledDecision.attributes.isEmpty)
  }

  func testSamplerUsesDefaultSessionManager() {
    // Test that sampler can be created without explicit session manager
    let defaultSampler = AwsSessionSpanSampler()
    XCTAssertNotNil(defaultSampler)
    XCTAssertEqual(defaultSampler.description, "AwsSessionSpanSampler")
  }
}

// MARK: - Mock Classes

class MockSpanSamplerSessionManager: AwsSessionManager {
  private var _isSessionSampled: Bool = true

  override var isSessionSampled: Bool {
    return _isSessionSampled
  }

  func setSessionSampled(_ sampled: Bool) {
    _isSessionSampled = sampled
  }

  override init(configuration: AwsSessionConfig = .default) {
    super.init(configuration: configuration)
  }
}
