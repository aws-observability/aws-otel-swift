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

  // MARK: - Crash constants

  /// Attribute name for crash exception type
  public static let crashExceptionType = "crash.exception_type"

  /// Attribute name for crash exception code
  public static let crashExceptionCode = "crash.exception_code"

  /// Attribute name for crash signal
  public static let crashSignal = "crash.signal"

  /// Attribute name for crash termination reason
  public static let crashTerminationReason = "crash.termination_reason"

  /// Attribute name for crash exception reason type
  public static let crashExceptionReasonType = "crash.exception_reason.type"

  /// Attribute name for crash exception reason name
  public static let crashExceptionReasonName = "crash.exception_reason.name"

  /// Attribute name for crash exception reason message
  public static let crashExceptionReasonMessage = "crash.exception_reason.message"

  /// Attribute name for crash exception reason class name
  public static let crashExceptionReasonClassName = "crash.exception_reason.class_name"

  /// Attribute name for crash VM region info
  public static let crashVmRegionInfo = "crash.vm_region.info"

  /// Attribute name for crash stacktrace
  public static let crashStacktrace = "crash.stacktrace"

  // event names
  public static let appHang = "device.hang"
  public static let crash = "device.crash"
}
