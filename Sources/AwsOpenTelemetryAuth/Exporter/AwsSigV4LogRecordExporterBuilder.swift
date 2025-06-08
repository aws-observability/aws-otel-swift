import Foundation
import AwsCommonRuntimeKit
import OpenTelemetryApi
import OpenTelemetrySdk


public class AwsSigV4LogRecordExporterBuilder {
    
    private var endpoint: String?
    private var region: String?
    private var serviceName: String = "logs"
    private var credentialsProvider: CredentialsProvider?
    private var parentExporter: LogRecordExporter?
    
    public init() {}
    
    public func setEndpoint(endpoint: String) -> AwsSigV4LogRecordExporterBuilder {
        self.endpoint = endpoint
        return self
    }
    
    public func setRegion(region: String) -> AwsSigV4LogRecordExporterBuilder {
        self.region = region
        return self
    }
    
    public func setServiceName(serviceName: String) -> AwsSigV4LogRecordExporterBuilder {
        self.serviceName = serviceName
        return self
    }
    
    public func setCredentialsProvider(credentialsProvider: CredentialsProvider) -> AwsSigV4LogRecordExporterBuilder {
        self.credentialsProvider = credentialsProvider
        return self
    }
    
    public func setParentExporter(parentExporter: LogRecordExporter) -> AwsSigV4LogRecordExporterBuilder {
        self.parentExporter = parentExporter
        return self
    }

    public func build() throws -> AwsSigV4LogRecordExporter {
            return AwsSigV4LogRecordExporter(
                endpoint: endpoint!,
                region: region!,
                serviceName: serviceName,
                credentialsProvider: credentialsProvider!,
                parentExporter: parentExporter
            )
        }

    
}
