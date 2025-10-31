/*
 * Copyright Amazon.com, Inc. or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

/// Constants for MetricKit instrumentation.
///
/// Provides standardized attribute names and event types following MetricKit naming convention.
///
public class AwsMetricKitConstants {
  // MARK: - Hang constants

  /// Attribute name for hang duration
  public static let hangDuration = "hang.hang_duration"

  /// Attribute name for hang `callStackTree`
  public static let hangCallStack = "exception.stacktrace"

  // MARK: - App launch constants

  /// Attribute name for app launch duration
  public static let appLaunchDuration = "app_launch.launch_duration"

  /// Attribute name for app launch type
  public static let appLaunchType = "app_launch.launch_type"
}
