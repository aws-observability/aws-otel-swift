import Foundation

/// The two resource-attribute values that depend on *how the harness was pointed*, rather than on
/// the SDK's behaviour.
///
/// Every other assertion in this suite is a fact about the SDK and is the same wherever the
/// telemetry was exported to. These two are not: `aws.rum.appmonitor.id` and `cloud.region` are
/// whatever the harness configured. The hermetic run configures the placeholders below; the
/// put-to-get run configures a real app monitor in a real region.
///
/// Resolving them from the environment is what lets `ResourceAttributesTests` run in **both** modes
/// instead of being skipped in one of them. It is also a stronger check than a literal, because it
/// asserts the identity the harness asked for is the identity that came back — under a literal, a
/// round trip that silently retargeted a different app monitor would still pass.
///
/// The variable names are deliberately the same ones the harness uses to configure the app
/// (`Examples/SimpleAwsDemo/SimpleAwsDemo/ContractTest/ContractTestConfig.swift`), so there is one
/// source of truth per value rather than a separate "expected" copy that could drift out of step
/// with what was actually sent.
struct ContractExpectations {
  static let appMonitorIdKey = "AWS_OTEL_CONTRACT_APP_MONITOR_ID"
  static let regionKey = "AWS_OTEL_CONTRACT_REGION"

  /// The values the hermetic run configures. These are the literals this suite asserted
  /// unconditionally before it could also run against a real endpoint, so an unset environment
  /// leaves the hermetic behaviour exactly as it was.
  static let defaultAppMonitorId = "test-app-monitor-id"
  static let defaultRegion = "us-east-1"

  let appMonitorId: String
  let region: String

  static var current: ContractExpectations {
    resolved(from: ProcessInfo.processInfo.environment)
  }

  static func resolved(from environment: [String: String]) -> ContractExpectations {
    ContractExpectations(
      appMonitorId: resolve(environment[appMonitorIdKey], fallback: defaultAppMonitorId),
      region: resolve(environment[regionKey], fallback: defaultRegion)
    )
  }

  /// Trims, and treats empty as absent — the same rule `ContractTestConfig` applies on the way in.
  /// It has to match: an unset GitHub secret expands to the empty string, and the harness trims
  /// before configuring the app, so anything else here would compare a trimmed value that was
  /// exported against an untrimmed one that was expected.
  private static func resolve(_ raw: String?, fallback: String) -> String {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
      return fallback
    }
    return trimmed
  }
}
