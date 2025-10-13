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

/// Constants for OpenTelemetry session instrumentation.
///
/// Provides standardized attribute names and event types following OpenTelemetry
/// semantic conventions for session tracking.
///
/// Reference: https://opentelemetry.io/docs/specs/semconv/general/session/
public class AwsSessionConstants {
  // MARK: - OpenTelemetry Semantic Conventions

  /// Event name for session start events
  public static let sessionStartEvent = "session.start"
  /// Event name for session end events
  public static let sessionEndEvent = "session.end"
  /// Attribute name for session identifier
  public static let id = "session.id"
  /// Attribute name for previous session identifier
  public static let previousId = "session.previous_id"

  // MARK: - Internal Constants

  /// Notification name for session events
  public static let sessionEventNotification = "software.amazon.opentelemetry.AwsSessionEvent"
}
