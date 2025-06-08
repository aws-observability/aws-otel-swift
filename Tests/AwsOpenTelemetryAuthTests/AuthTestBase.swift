import Foundation
import XCTest
import AwsCommonRuntimeKit

open class AuthTestBase : XCTestCase {

    lazy var credentialsProvider: CredentialsProviding = {
        return TestCredentialsProvider()
    }()
    
    lazy var failingCredentialsProvider: CredentialsProviding = {
        return FailingCredentialsProvider()
    }()
}

class TestCredentialsProvider: CredentialsProviding {
    let credentials: Credentials
    
    init() {
        do {
            self.credentials = try Credentials(
                accessKey: "AKIDEXAMPLE",
                secret: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
            )
        } catch {
            fatalError("Failed to initialize test credentials: \(error)")
        }
    }
    
    func getCredentials() async throws -> Credentials {
        return credentials
    }
}

class FailingCredentialsProvider: CredentialsProviding {
    init() {
    }
    func getCredentials() async throws -> Credentials {
        throw NSError(domain: "CredentialsProviderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get credentials"])
    }
}
