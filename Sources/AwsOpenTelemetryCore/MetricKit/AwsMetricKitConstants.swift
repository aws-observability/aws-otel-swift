/// Constants for MetricKit instrumentation.
///
/// Provides standardized attribute names and event types following MetricKit naming convention.
///
public class AwsMetricKitConstants {
  // MARK: - Hang constants

  /// Attribute name for hang duration
  public static let hangDuration = "hang.hang_duration"

  /// Attribute name for hang `callStackTree`
  public static let hangCallStackTree = "hang.call_stack_tree"
}
