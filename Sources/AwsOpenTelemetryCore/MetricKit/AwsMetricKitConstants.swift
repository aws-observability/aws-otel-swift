/// Constants for MetricKit instrumentation.
///
/// Provides standardized attribute names and event types following MetricKit naming convention.
///
public class AwsMetricKitConstants {
  // MARK: - Hang constants

  /// Attribute name for hang duration
  public static let hangDuration = "hang.hang_duration"

  /// Attribute name for hang `callStackTree`
  public static let hangCallStack = "hang.stacktrace"

  // MARK: - App launch constants

  /// Attribute name for app launch duration
  public static let appLaunchDuration = "app_launch.launch_duration"

  /// Attribute name for app launch type
  public static let appLaunchType = "app_launch.launch_type"
}
