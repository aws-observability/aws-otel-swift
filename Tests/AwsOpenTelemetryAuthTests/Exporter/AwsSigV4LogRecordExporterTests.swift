import XCTest
import Mockingbird
@testable import AwsOpenTelemetryAuth
import OpenTelemetrySdk
import AwsCommonRuntimeKit

class AwsSigV4LogRecordExporterTest: AuthTestBase {
    // Use a mock framework like Mockingbird or create a manual mock
    private var mockParentExporter: LogRecordExporter!
    private var logRecordExporter: AwsSigV4LogRecordExporter!
    
    override func setUp() {
                
        // Create the exporter under test
        do {
            logRecordExporter = try AwsSigV4LogRecordExporter.builder()
                .setEndpoint(endpoint: "dataplane.rum.us-east-1.amazonaws.com")
                .setRegion(region: "us-east-1")
                .setCredentialsProvider(credentialsProvider: credentialsProvider as! CredentialsProvider) // Cast if needed
                .setServiceName(serviceName: "rum")
                .setParentExporter(parentExporter: mockParentExporter)
                .build()
            
        } catch {
            XCTFail("Failed to create exporter under test: \(error)")
        }
    }
    
//    func testExportWithSingleMockedLogRecord() throws {
//        // Call the method under test
//        let result = logRecordExporter.export(logRecords: logData, explicitTimeout: nil)
//        
//        // Verify the results
//        XCTAssertTrue(result.isSuccess)
//        XCTAssertEqual(result, .success)
//        XCTAssertEqual(mockParentExporter.exportCallCount, 1)
//        XCTAssertEqual(mockParentExporter.exportLogRecordsArgument, logData)
//    }
//    
//    func testExportWithParentExporterFailing() throws {
//        // Configure the mock to return failure
//        mockParentExporter.exportReturnValue = .failure
//        
//        // Call the method under test
//        let result = logRecordExporter.export(logRecords: [], explicitTimeout: nil)
//        
//        // Verify the results
//        XCTAssertFalse(result.isSuccess)
//        XCTAssertEqual(result, .failure)
//    }
}
