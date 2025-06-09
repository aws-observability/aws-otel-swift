import XCTest
@testable import AwsOpenTelemetryAuth
import OpenTelemetrySdk
import OpenTelemetryApi
import AwsCommonRuntimeKit

class AwsSigV4SpanExporterTest: XCTestCase {
    private var mockParentExporter: SpanExporterMock!
    private var spanExporter: AwsSigV4SpanExporter!
    let accessKey = "AccessKey"
    let secret = "Secret"
    let sessionToken = "Token"
    
    override func setUp() {
        do {
            mockParentExporter = SpanExporterMock()
            let provider = try CredentialsProvider(
                    source: .static(
                      accessKey: accessKey,
                      secret: secret,
                      sessionToken: sessionToken))
            spanExporter = try AwsSigV4SpanExporter.builder()
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
    
    func testExportWithSingleMockedSpanRecord() throws {
        let jsonString = """
        {
            "traceId": {
                "idHi": 12345,
                "idLo": 67890
            },
            "spanId": {
                "id": 12345678
            },
            "traceFlags": {
                "byte": 1,
                "options": 1
            },
            "traceState": {
                "entries": []
            },
            "name": "test-span",
            "kind": "internal",
            "startTime": 1672531200000000000,
            "endTime": 1672531201000000000,
            "attributes": {},
            "events": [],
            "links": [],
            "status": {
                "ok": {
                    "_0": {}
                }
            },
            "hasRemoteParent": false,
            "hasEnded": true,
            "totalRecordedEvents": 0,
            "totalRecordedLinks": 0,
            "totalAttributeCount": 0,
            "resource": {
                "attributes": {
                    "service.name": {
                        "string": {
                            "_0": "test-service"
                        }
                    }
                },
                "schemaUrl": null
            },
            "instrumentationScope": {
                "name": "test-instrumentation",
                "version": "1.0.0",
                "schemaUrl": null,
                "attributes": {}
            }
        }
        """

        let jsonData = jsonString.data(using: .utf8)!
        let spanData = try JSONDecoder().decode(SpanData.self, from: jsonData)
        
        let result: SpanExporterResultCode = spanExporter.export(spans: [spanData], explicitTimeout: nil)
        
        XCTAssertEqual(result, .success)
        XCTAssertEqual(mockParentExporter.exportCalledTimes, 1)
        XCTAssertEqual(mockParentExporter.exportCalledData, [spanData])
    }
    
    func testExportWithParentExporterFailing() throws {
        mockParentExporter.returnValue = .failure
        let result = spanExporter.export(spans: [], explicitTimeout: nil)
        
        XCTAssertEqual(result, .failure)
    }
}
