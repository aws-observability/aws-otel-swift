import XCTest
import AwsCommonRuntimeKit
@testable import AwsOpenTelemetryAuth

class AwsSigV4AuthenticatorTests: AuthTestBase {
    
    func testGetSignedHeadersWithMinimalValidInputReturnsExpectedHeaders() async throws {
        
        // Use async/await instead of runBlocking
        let headers = try await AwsSigV4Authenticator.signHeaders(
            endpoint: "https://dataplane.rum.us-east-1.amazonaws.com",
            credentialsProvider: credentialsProvider as! CredentialsProviding as! CredentialsProvider,
            region: "us-east-1",
            serviceName: "rum",
            body: "test".data(using: .utf8)!
        )
        
        XCTAssertNotNil(headers["x-amz-date"])
        XCTAssertNotNil(headers["authorization"])
        XCTAssertEqual("application/x-protobuf", headers["content-type"])
    }
    
//    func testGetSignedHeadersWithFailedCredentialsResolutionThrowsException() async {
//        // Use Swift's do-catch with async/await instead of assertThrows
//        do {
//            _ = try await AwsSigV4Authenticator.signHeaders(
//                endpoint: "https://dataplane.rum.us-east-1.amazonaws.com",
//                credentialsProvider: failingCredentialsProvider as! CredentialsProvider,                region: "us-east-1",
//                serviceName: "rum",
//                body: "test".data(using: .utf8)!
//            )
//            XCTFail("Expected error was not thrown")
//        } catch {
//            XCTAssertTrue(true)
//        }
//    }
    
}
