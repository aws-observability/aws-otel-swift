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

// We want to capture active prewarm flag as early as possible, since it allegedly gets cleared
// after `UIApplication.didFinishLaunchingNotification`
let isActivePrewarm: Bool = ProcessInfo.processInfo.environment["ActivePrewarm"] != nil

protocol AppLaunchProtocol {
  func onWarmStart()
  func onLaunchEnd()
  func onLifecycleEvent(name: String)
  func onHidden()
}

public class AwsAppLaunchInstrumentation: NSObject, AppLaunchProtocol {
  static var provider: AppLaunchProvider?
  private static let lock: NSLock = .init()

  // We need static reference to persist the observers
  static var shared: AwsAppLaunchInstrumentation?

  // Observer references for cleanup
  var launchEndObserver: NSObjectProtocol?
  var warmStartObserver: NSObjectProtocol?
  var hiddenObserver: NSObjectProtocol?
  var lifecycleObservers: [String: NSObjectProtocol] = [:]

  static var instrumentationKey: String {
    return AwsInstrumentationScopes.APP_START
  }

  static var tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsAppLaunchInstrumentation.instrumentationKey)
  static var logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsAppLaunchInstrumentation.instrumentationKey)

  // Launch detectors
  static var hasLaunched = false
  static var hasLostFocusBefore = false
  static var lastWarmLaunchStart: Date?

  static func isPrewarm(duration: TimeInterval) -> Bool {
    guard let provider else { return false }
    return isActivePrewarm || (provider.preWarmFallbackThreshold > 0 && duration > provider.preWarmFallbackThreshold)
  }

  public init(provider: AppLaunchProvider = DefaultAppLaunchProvider.shared) {
    super.init()

    Self.provider = provider
    AwsInternalLogger.debug("AwsAppLaunchInstrumentation initializing with provider: \(type(of: provider))")

    // Setup launch end handler
    AwsInternalLogger.debug("Setting up launch end observer for: \(provider.launchEndNotification.rawValue)")
    launchEndObserver = NotificationCenter.default.addObserver(
      forName: provider.launchEndNotification,
      object: nil,
      queue: OperationQueue()
    ) { _ in
      Self.onLaunchEnd()
    }

    // Setup warm launch start handler
    AwsInternalLogger.debug("Setting up warm start observer for: \(provider.warmStartNotification.rawValue)")
    warmStartObserver = NotificationCenter.default.addObserver(
      forName: provider.warmStartNotification,
      object: nil,
      queue: OperationQueue()
    ) { _ in
      Self.onWarmStart()
    }

    // Setup hidden event handler - only needed until first background event
    AwsInternalLogger.debug("Setting up onHidden observer for: \(provider.hiddenNotification.rawValue)")
    hiddenObserver = NotificationCenter.default.addObserver(
      forName: provider.hiddenNotification,
      object: nil,
      queue: OperationQueue()
    ) { [weak self] _ in
      Self.onHidden()
      // Remove observer after first use since we only need to know app was backgrounded once
      if let observer = self?.hiddenObserver {
        NotificationCenter.default.removeObserver(observer)
        self?.hiddenObserver = nil
        AwsInternalLogger.debug("Removed onHidden observer after first background event")
      }
    }

    // Setup observers
    AwsInternalLogger.debug("Setting up \(provider.additionalLifecycleEvents.count) additional lifecycle observers")
    for event in provider.additionalLifecycleEvents {
      guard lifecycleObservers[event.rawValue] == nil else {
        AwsInternalLogger.debug("Skipping duplicate observer for: \(event.rawValue)")
        continue
      }

      AwsInternalLogger.debug("Setting up lifecycle observer for: \(event.rawValue)")
      lifecycleObservers[event.rawValue] = NotificationCenter.default.addObserver(
        forName: event,
        object: nil,
        queue: OperationQueue()
      ) { notification in
        Self.onLifecycleEvent(name: notification.name.rawValue)
      }
    }
    AwsInternalLogger.debug("AwsAppLaunchInstrumentation initialized with \(lifecycleObservers.count) observers")
  }

  func onLaunchEnd() {
    Self.onLaunchEnd()
  }

  @objc static func onLaunchEnd() {
    AwsInternalLogger.debug("onColdEnd called")
    lock.withLock {
      guard let provider else { return }
      let endTime = Date()

      // Handle cold launch
      if !hasLaunched, let startTime = provider.coldLaunchStartTime {
        let duration = endTime.timeIntervalSince(startTime)
        let isPrewarm = isPrewarm(duration: duration)

        AwsInternalLogger.debug("Recording cold launch: duration=\(duration)s, isPrewarm=\(isPrewarm)")

        tracer.spanBuilder(spanName: "AppStart")
          .setStartTime(time: startTime)
          .setAttribute(key: "start.type", value: isPrewarm ? "prewarm" : "cold")
          .setAttribute(key: "active_prewarm", value: isActivePrewarm)
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

        AwsInternalLogger.debug("Recording warm launch: duration=\(duration)s")

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
    AwsInternalLogger.debug("onWarmStart called")
    lock.withLock {
      let now = Date()
      lastWarmLaunchStart = now
    }
  }

  func onLifecycleEvent(name: String) {
    Self.onLifecycleEvent(name: name)
  }

  @objc static func onLifecycleEvent(name: String) {
    AwsInternalLogger.debug("onLifecycleEvent called: \(name)")

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

  deinit {
    // Clean up all observers
    if let observer = launchEndObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    if let observer = warmStartObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    if let observer = hiddenObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    for observer in lifecycleObservers.values {
      NotificationCenter.default.removeObserver(observer)
    }
  }
}
