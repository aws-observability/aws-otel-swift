import XCTest
@testable import AwsOpenTelemetryAuth
import OpenTelemetrySdk
import OpenTelemetryApi
import AwsCommonRuntimeKit

class AwsSigV4LogRecordExporterTest: XCTestCase {
  private var mockParentExporter: LogRecordExporterMock!
  private var logRecordExporter: AwsSigV4LogRecordExporter!
  let accessKey = "AccessKey"
  let secret = "Secret"
  let sessionToken = "Token"

  override func setUp() {
    do {
      mockParentExporter = LogRecordExporterMock()
      let provider = try CredentialsProvider(
        source: .static(
          accessKey: accessKey,
          secret: secret,
          sessionToken: sessionToken
        ))
      logRecordExporter = try AwsSigV4LogRecordExporter.builder()
        .setEndpoint(endpoint: "dataplane.rum.us-east-1.amazonaws.com")
        .setRegion(region: "us-east-1")
        .setCredentialsProvider(credentialsProvider: provider)
        .setServiceName(serviceName: "rum")
        .setParentExporter(parentExporter: mockParentExporter)
        .build()
    } catch {
      XCTFail("Failed to create exporter under test: \(error)")
    }
  }

  func testExportWithSingleMockedLogRecord() throws {
    let logdata = [ReadableLogRecord(resource: Resource(), instrumentationScopeInfo: InstrumentationScopeInfo(name: "default"), timestamp: Date(), attributes: [String: AttributeValue]())]
    let result = logRecordExporter.export(logRecords: logdata, explicitTimeout: nil)

    XCTAssertEqual(result, .success)
    XCTAssertEqual(mockParentExporter.exportCalledTimes, 1)
    XCTAssertEqual(mockParentExporter.exportCalledData!.count, logdata.count)
  }

  func testExportWithParentExporterFailing() throws {
    mockParentExporter.returnValue = .failure
    let result = logRecordExporter.export(logRecords: [], explicitTimeout: nil)

    XCTAssertEqual(result, .failure)
  }
}
