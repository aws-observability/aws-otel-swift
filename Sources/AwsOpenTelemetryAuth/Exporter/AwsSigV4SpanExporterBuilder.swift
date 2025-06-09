import Foundation
import AwsCommonRuntimeKit
import OpenTelemetryApi
import OpenTelemetrySdk


public class AwsSigV4SpanExporterBuilder {
    
    private var endpoint: String?
    private var region: String?
    private var serviceName: String?
    private var credentialsProvider: CredentialsProvider?
    private var parentExporter: SpanExporter?
    
    public init() {}
    
    public func setEndpoint(endpoint: String) -> AwsSigV4SpanExporterBuilder {
        self.endpoint = endpoint
        return self
    }
    
    public func setRegion(region: String) -> AwsSigV4SpanExporterBuilder {
        self.region = region
        return self
    }
    
    public func setServiceName(serviceName: String) -> AwsSigV4SpanExporterBuilder {
        self.serviceName = serviceName
        return self
    }
    
    public func setCredentialsProvider(credentialsProvider: CredentialsProvider) -> AwsSigV4SpanExporterBuilder {
        self.credentialsProvider = credentialsProvider
        return self
    }
    
    public func setParentExporter(parentExporter: SpanExporter) -> AwsSigV4SpanExporterBuilder {
        self.parentExporter = parentExporter
        return self
    }

    public func build() throws -> AwsSigV4SpanExporter {
            return AwsSigV4SpanExporter(
                endpoint: endpoint!,
                region: region!,
                serviceName: serviceName!,
                credentialsProvider: credentialsProvider!,
                parentExporter: parentExporter
            )
        }

    
}
