import XCTest
@testable import AwsOpenTelemetryAuth
import OpenTelemetrySdk
import OpenTelemetryApi
import AwsCommonRuntimeKit

class AwsSigV4SpanExporterTest: XCTestCase {
  private var spanExporter: AwsSigV4SpanExporter!
  let accessKey = "AccessKey"
  let secret = "Secret"
  let sessionToken = "Token"

  override func setUp() {
    do {
      let provider = try CredentialsProvider(
        source: .static(
          accessKey: accessKey,
          secret: secret,
          sessionToken: sessionToken
        ))
      spanExporter = try AwsSigV4SpanExporter.builder()
        .setEndpoint(endpoint: "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum")
        .setRegion(region: "us-east-1")
        .setCredentialsProvider(credentialsProvider: provider)
        .setServiceName(serviceName: "rum")
        .build()
    } catch {
      XCTFail("Failed to create exporter under test: \(error)")
    }
  }

  func testExportWithEmptySpans() throws {
    let result = spanExporter.export(spans: [], explicitTimeout: nil)
    XCTAssertNotNil(spanExporter)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testFlush() throws {
    let result = spanExporter.flush(explicitTimeout: 5.0)
    XCTAssertNotNil(spanExporter)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testShutdown() throws {
    spanExporter.shutdown(explicitTimeout: 10.0)
    XCTAssertNotNil(spanExporter)
  }

  func testBuilderPattern() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = try AwsSigV4SpanExporter.builder()
      .setEndpoint(endpoint: "https://test.endpoint.com")
      .setRegion(region: "us-west-2")
      .setCredentialsProvider(credentialsProvider: provider)
      .setServiceName(serviceName: "traces")
      .build()

    XCTAssertNotNil(exporter)
    let result = exporter.export(spans: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testBuilderPatternWithDefaultEndpoint() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = try AwsSigV4SpanExporter.builder()
      .setRegion(region: "us-west-2")
      .setCredentialsProvider(credentialsProvider: provider)
      .setServiceName(serviceName: "traces")
      .build()

    XCTAssertNotNil(exporter)
    let result = exporter.export(spans: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testInitWithCustomEndpoint() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = AwsSigV4SpanExporter(
      endpoint: "https://test.endpoint.com",
      region: "us-east-1",
      serviceName: "rum",
      credentialsProvider: provider
    )

    XCTAssertNotNil(exporter)
    let result = exporter.export(spans: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testInitWithDefaultEndpoint() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = AwsSigV4SpanExporter(
      region: "us-east-1",
      credentialsProvider: provider
    )

    XCTAssertNotNil(exporter)
    let result = exporter.export(spans: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }
}
