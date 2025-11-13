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
/// semantic conventions for hardware and process metrics.
public class AwsDeviceKitSemConv {
  public static let batteryCharge = "hw.battery.charge"
  public static let cpuUtilization = "process.cpu.utilization"
  public static let memoryUsage = "process.memory.usage"
}
