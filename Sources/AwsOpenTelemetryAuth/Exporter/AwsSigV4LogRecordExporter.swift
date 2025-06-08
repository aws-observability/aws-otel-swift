import Foundation
import AwsCommonRuntimeKit
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterHttp

public class AwsSigV4LogRecordExporter: LogRecordExporter {
    private var endpoint: String
    private var region: String
    private var serviceName: String
    private var credentialsProvider: CredentialsProvider
    private var parentExporter: LogRecordExporter? = nil
    
    private let queue = DispatchQueue(label: "com.aws.opentelemetry.logDataQueue")
    private var logData: [ReadableLogRecord] = []
    
    public init(
        endpoint: String,
        region: String,
        serviceName: String,
        credentialsProvider: CredentialsProvider,
        parentExporter: LogRecordExporter? = nil
    ) {
        self.endpoint = endpoint
        self.region = region
        self.serviceName = serviceName
        self.credentialsProvider = credentialsProvider
        self.parentExporter = parentExporter
        if self.parentExporter == nil {
                Task {
                    self.parentExporter = await createDefaultExporter()
                }
            }
    }
    
    public func export(logRecords: [ReadableLogRecord], explicitTimeout: TimeInterval?) -> ExportResult {
        queue.sync { self.logData = logRecords }
        return parentExporter!.export(logRecords: logRecords, explicitTimeout: explicitTimeout)
    }

    public func forceFlush(explicitTimeout: TimeInterval?) -> ExportResult {
        return parentExporter!.forceFlush(explicitTimeout: explicitTimeout)
    }

    public func shutdown(explicitTimeout: TimeInterval?) {
        parentExporter!.shutdown(explicitTimeout: explicitTimeout)
    }

    public static func builder() -> AwsSigV4LogRecordExporterBuilder {
            return AwsSigV4LogRecordExporterBuilder()
    }
    
    private func createDefaultExporter() async -> LogRecordExporter {
        let endpointURL = URL(string: endpoint)!
        
        // Await the async function
        let headers = await getHeaders()
        let headerTuples = headers.map { ($0.key, $0.value) }
        
        return OtlpHttpLogExporter(endpoint: endpointURL, envVarHeaders: headerTuples)
    }
    
    private func getHeaders() async -> [String: String] {
        let body = queue.sync { self.logData }
        var jsonData: Data
        
        do {
          jsonData = try JSONEncoder().encode(body)
          if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
          }
        } catch {
          print("Failed to serialize LogRecord as JSON: \(error)")
            return [:]
        }
        
        return await AwsSigV4Authenticator.signHeaders(endpoint: endpoint, credentialsProvider: credentialsProvider, region: region, serviceName: serviceName, body: jsonData)
    }
}
