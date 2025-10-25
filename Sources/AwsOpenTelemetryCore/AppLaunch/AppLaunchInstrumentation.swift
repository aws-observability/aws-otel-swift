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

// Capture prewarm flag as early as possible - global initialization happens before class loading
let hasActivePrewarmFlag: Bool = ProcessInfo.processInfo.environment["ActivePrewarm"] != nil

protocol AppLaunchProtocol {
  func onWarmStart()
  func onLaunchEnd()
  func onLifecycleEvent(name: String)
  func onHidden()
}

public class AppLaunchInstrumentation: NSObject, AppLaunchProtocol {
  private static var provider: AppLaunchProvider?
  private static let lock: NSLock = .init()

  // lifecycle event de-dupping map
  var lifecycleObservers: [String: NSObjectProtocol] = [:]

  static var instrumentationKey: String {
    return AwsInstrumentationScopes.APP_START
  }

  private static var tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AppLaunchInstrumentation.instrumentationKey)
  private static var logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AppLaunchInstrumentation.instrumentationKey)

  // Launch detectors - using global variable for earliest capture

  private static var hasLaunched = false
  private static var hasLostFocusBefore = false
  private static var lastWarmLaunchStart: Date?

  func isPrewarmLaunch(duration: TimeInterval) -> Bool {
    return Self.isPrewarmLaunch(duration: duration)
  }

  static func isPrewarmLaunch(duration: TimeInterval) -> Bool {
    guard let provider else { return false }
    return hasActivePrewarmFlag || (provider.preWarmFallbackThreshold > 0 && duration > provider.preWarmFallbackThreshold)
  }

  public init(provider: AppLaunchProvider = DefaultAppLaunchProvider.shared) {
    super.init()

    Self.provider = provider
    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation initializing with provider: \(type(of: provider))")

    // Setup launch end handler
    AwsOpenTelemetryLogger.debug("Setting up launch end observer for: \(provider.launchEndNotification.rawValue)")
    NotificationCenter.default.addObserver(
      forName: provider.launchEndNotification,
      object: nil,
      queue: OperationQueue()
    ) { _ in
      Self.onLaunchEnd()
    }

    // Setup warm launch start handler
    AwsOpenTelemetryLogger.debug("Setting up warm start observer for: \(provider.warmStartNotification.rawValue)")
    NotificationCenter.default.addObserver(
      forName: provider.warmStartNotification,
      object: nil,
      queue: OperationQueue()
    ) { _ in
      Self.onWarmStart()
    }

    // Setup hidden event handler
    AwsOpenTelemetryLogger.debug("Setting up onHidden observer for: \(provider.hiddenNotification.rawValue)")
    NotificationCenter.default.addObserver(
      forName: provider.hiddenNotification,
      object: nil,
      queue: OperationQueue()
    ) { _ in
      Self.onHidden()
    }

    // Setup observers
    AwsOpenTelemetryLogger.debug("Setting up \(provider.additionalLifecycleEvents.count) additional lifecycle observers")
    for event in provider.additionalLifecycleEvents {
      guard lifecycleObservers[event.rawValue] == nil else {
        AwsOpenTelemetryLogger.debug("Skipping duplicate observer for: \(event.rawValue)")
        continue
      }

      AwsOpenTelemetryLogger.debug("Setting up lifecycle observer for: \(event.rawValue)")
      lifecycleObservers[event.rawValue] = NotificationCenter.default.addObserver(
        forName: event,
        object: nil,
        queue: OperationQueue()
      ) { notification in
        Self.onLifecycleEvent(name: notification.name.rawValue)
      }
    }
    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation initialized with \(lifecycleObservers.count) observers")
  }

  func onLaunchEnd() {
    Self.onLaunchEnd()
  }

  @objc static func onLaunchEnd() {
    AwsOpenTelemetryLogger.debug("onColdEnd called")
    lock.withLock {
      guard let provider else { return }
      let endTime = Date()

      // Handle cold launch
      if !hasLaunched, let startTime = provider.coldLaunchStartTime {
        let duration = endTime.timeIntervalSince(startTime)
        let isPrewarm = isPrewarmLaunch(duration: duration)

        AwsOpenTelemetryLogger.debug("Recording cold launch: duration=\(duration)s, isPrewarm=\(isPrewarm)")

        tracer.spanBuilder(spanName: "AppStart")
          .setStartTime(time: startTime)
          .setAttribute(key: "start.type", value: isPrewarm ? "prewarm" : "cold")
          .setAttribute(key: "active_prewarm", value: hasActivePrewarmFlag)
          .setAttribute(key: "launch_start_name", value: provider.coldStartName)
          .setAttribute(key: "launch_end_name", value: provider.launchEndNotification.rawValue)
          .startSpan()
          .end(time: endTime)
        lastWarmLaunchStart = nil // clear stale warm start timestamps
        hasLaunched = true // only record one cold launch per application lifecycle
        return
      }

      // Handle warm launch
      if hasLostFocusBefore, let startTime = lastWarmLaunchStart {
        lastWarmLaunchStart = nil
        let duration = endTime.timeIntervalSince(startTime)

        AwsOpenTelemetryLogger.debug("Recording warm launch: duration=\(duration)s")

        tracer.spanBuilder(spanName: "AppStart")
          .setStartTime(time: startTime)
          .setAttribute(key: "start.type", value: "warm")
          .setAttribute(key: "active_prewarm", value: false)
          .setAttribute(key: "launch_start_name", value: provider.warmStartNotification.rawValue)
          .setAttribute(key: "launch_end_name", value: provider.launchEndNotification.rawValue)
          .startSpan()
          .end(time: endTime)
      }
    }
  }

  func onWarmStart() {
    Self.onWarmStart()
  }

  @objc static func onWarmStart() {
    AwsOpenTelemetryLogger.debug("onWarmStart called")
    lock.withLock {
      let now = Date()
      lastWarmLaunchStart = now
    }
  }

  func onLifecycleEvent(name: String) {
    Self.onLifecycleEvent(name: name)
  }

  @objc static func onLifecycleEvent(name: String) {
    AwsOpenTelemetryLogger.debug("onLifecycleEvent called: \(name)")

    logger.logRecordBuilder()
      .setEventName(name)
      .emit()
  }

  func onHidden() {
    Self.onHidden()
  }

  @objc static func onHidden() {
    lock.withLock {
      hasLostFocusBefore = true
    }
  }
}
