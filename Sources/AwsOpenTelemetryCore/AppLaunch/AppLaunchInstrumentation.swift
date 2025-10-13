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
import OpenTelemetryApi

#if canImport(UIKit) && !os(watchOS)
  import UIKit
#endif

/// Instrumentation for tracking app launch performance
public class AppLaunchInstrumentation {
  private let tracer: Tracer
  private let provider: AppLaunchProvider
  static var initialLaunchRecorded = false
  static var warmLaunchStartTime: Date?
  static let lock = NSLock()

  static var instrumentationKey: String {
    return AwsInstrumentationScopes.APP_START
  }

  var hasActivePrewarm: Bool {
    return ProcessInfo.processInfo.environment["ActivePrewarm"] != nil
  }

  func isPrewarmLaunch(duration: TimeInterval) -> Bool {
    return hasActivePrewarm || (provider.preWarmFallbackThreshold > 0 && duration > provider.preWarmFallbackThreshold)
  }

  public init(provider: AppLaunchProvider = DefaultAppLaunchProvider.shared) {
    self.provider = provider
    tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AppLaunchInstrumentation.instrumentationKey)

    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation enabled with coldEndNotification: \(provider.coldLaunchEndNotification.rawValue), warmStartNotification: \(provider.warmLaunchStartNotification.rawValue)")

    // Continuously track warm launch times
    NotificationCenter.default.addObserver(
      forName: provider.warmLaunchStartNotification,
      object: nil,
      queue: nil
    ) { _ in
      Self.lock.lock()
      Self.warmLaunchStartTime = Date()
      Self.lock.unlock()
    }

    NotificationCenter.default.addObserver(
      forName: provider.coldLaunchEndNotification,
      object: nil,
      queue: nil
    ) { _ in
      self.createInitialLaunchSpan()
    }

    NotificationCenter.default.addObserver(
      forName: provider.warmLaunchEndNotification,
      object: nil,
      queue: nil
    ) { _ in
      self.createWarmLaunchSpan()
    }
    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation registered observers")
  }

  @objc func createInitialLaunchSpan() {
    Self.lock.lock()
    defer { Self.lock.unlock() }

    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation.createInitialLaunchSpan called")

    let endTime = Date()
    let startTime: Date = provider.coldLaunchStartTime
    var launchType = "cold"
    var startNotification = "ColdLaunchStartTime"

    if isPrewarmLaunch(duration: endTime.timeIntervalSince(startTime)) {
      launchType = "prewarm"
      startNotification = provider.warmLaunchStartNotification.rawValue
    }

    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation creating initial launch span with type: \(launchType), startTime: \(startTime), endTime: \(endTime)")

    let span = tracer.spanBuilder(spanName: "AppStart")
      .setStartTime(time: startTime)
      .startSpan()

    span.setAttribute(key: "launch.type", value: launchType)
    span.setAttribute(key: "app.launch.start_notification", value: startNotification)
    span.setAttribute(key: "app.launch.end_notification", value: provider.coldLaunchEndNotification.rawValue)
    span.setAttribute(key: "active_prewarm", value: hasActivePrewarm)

    span.end(time: endTime)
    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation cold launch span created and ended")

    Self.initialLaunchRecorded = true
  }

  @objc func createWarmLaunchSpan() {
    Self.lock.lock()
    defer { Self.lock.unlock() }

    let endTime = Date()
    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation.createWarmLaunchSpan called")

    // Only record warm/prewarm launches after cold launch has been recorded or skipped, in case there is not cold launch.
    guard Self.initialLaunchRecorded else {
      AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation.createWarmLaunchSpan skipped - cold launch not recorded yet")
      return
    }

    guard let startTime = Self.warmLaunchStartTime else {
      AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation.createWarmLaunchSpan skipped - no warm start time available")
      return
    }

    // Determine launch type for warm launches
    let launchDuration = endTime.timeIntervalSince(startTime)
    let launchType = isPrewarmLaunch(duration: launchDuration) ? "prewarm" : "warm"
    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation creating warm launch span with type: \(launchType), startTime: \(startTime), endTime: \(endTime)")

    let span = tracer.spanBuilder(spanName: "AppStart")
      .setStartTime(time: startTime)
      .startSpan()

    span.setAttribute(key: "app.launch.end_notification", value: provider.warmLaunchEndNotification.rawValue)
    span.setAttribute(key: "launch.type", value: launchType)
    span.setAttribute(key: "active_prewarm", value: hasActivePrewarm)
    span.setAttribute(key: "app.launch.start_notification", value: provider.warmLaunchStartNotification.rawValue)

    span.end(time: endTime)
    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation warm launch span created and ended with launch type: \(launchType)")
  }
}
