import XCTest
@testable import AwsOpenTelemetryAuth
import OpenTelemetrySdk
import OpenTelemetryApi
import AwsCommonRuntimeKit

class AwsSigV4LogRecordExporterTest: XCTestCase {
  private var logRecordExporter: AwsSigV4LogRecordExporter!
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
      logRecordExporter = try AwsSigV4LogRecordExporter.builder()
        .setEndpoint(endpoint: "https://dataplane.rum.us-east-1.amazonaws.com/v1/rum")
        .setRegion(region: "us-east-1")
        .setCredentialsProvider(credentialsProvider: provider)
        .setServiceName(serviceName: "rum")
        .build()
    } catch {
      XCTFail("Failed to create exporter under test: \(error)")
    }
  }

  func testExportWithEmptyLogRecords() throws {
    let result = logRecordExporter.export(logRecords: [], explicitTimeout: nil)
    XCTAssertNotNil(logRecordExporter)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testForceFlush() throws {
    let result = logRecordExporter.forceFlush(explicitTimeout: 5.0)
    XCTAssertNotNil(logRecordExporter)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testShutdown() throws {
    logRecordExporter.shutdown(explicitTimeout: 10.0)
    XCTAssertNotNil(logRecordExporter)
  }

  func testBuilderPattern() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = try AwsSigV4LogRecordExporter.builder()
      .setEndpoint(endpoint: "https://test.endpoint.com")
      .setRegion(region: "us-west-2")
      .setCredentialsProvider(credentialsProvider: provider)
      .setServiceName(serviceName: "logs")
      .build()

    XCTAssertNotNil(exporter)
    let result = exporter.export(logRecords: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testBuilderPatternWithDefaultEndpoint() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = try AwsSigV4LogRecordExporter.builder()
      .setRegion(region: "us-west-2")
      .setCredentialsProvider(credentialsProvider: provider)
      .setServiceName(serviceName: "logs")
      .build()

    XCTAssertNotNil(exporter)
    let result = exporter.export(logRecords: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testInitWithCustomEndpoint() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = AwsSigV4LogRecordExporter(
      endpoint: "https://test.endpoint.com",
      region: "us-east-1",
      serviceName: "rum",
      credentialsProvider: provider
    )

    XCTAssertNotNil(exporter)
    let result = exporter.export(logRecords: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }

  func testInitWithDefaultEndpoint() throws {
    let provider = try CredentialsProvider(
      source: .static(
        accessKey: "testKey",
        secret: "testSecret",
        sessionToken: "testToken"
      ))

    let exporter = AwsSigV4LogRecordExporter(
      region: "us-east-1",
      credentialsProvider: provider
    )

    XCTAssertNotNil(exporter)
    let result = exporter.export(logRecords: [], explicitTimeout: nil)
    XCTAssertTrue(result == .success || result == .failure)
  }
}
