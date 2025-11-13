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

import Foundation

/// Constants for OpenTelemetry device instrumentation.
///
/// Provides standardized attribute names following OpenTelemetry
/// semantic conventions for hardware and process metrics. These are
/// typically recorded as metrics, but we will record them as log/span attributes
/// given that metrics are typically not individually recorded client-side.
public class AwsDeviceKitSemConv {
  // battery - https://opentelemetry.io/docs/specs/semconv/hardware/battery/
  public static let batteryCharge = "hw.battery.charge"
  // cpu - https://opentelemetry.io/docs/specs/semconv/system/process-metrics/
  public static let cpuUtilization = "process.cpu.utilization"
  // mem - https://opentelemetry.io/docs/specs/semconv/system/process-metrics/#metric-processmemoryusage
  public static let memoryUsage = "process.memory.usage"
}
