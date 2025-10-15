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

protocol AppLaunchProtocol {
  func onColdEnd()
  func onWarmStart()
  func onWarmEnd()
  func onLifecycleEvent(name: String)
  func onHidden()
}

/// Instrumentation for tracking app launch performance
public class AppLaunchInstrumentation: NSObject, AppLaunchProtocol {
  private static var provider: AppLaunchProvider?
  private static let lock: NSLock = .init()

  // observers map
  var observers: [String: NSObjectProtocol] = [:]

  // monitoring reporters
  static var instrumentationKey: String {
    return AwsInstrumentationScopes.APP_START
  }

  private static var tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: AppLaunchInstrumentation.instrumentationKey)
  private static var logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AppLaunchInstrumentation.instrumentationKey)

  // launch detetors
  var hasActivePrewarmFlag: Bool {
    return Self.hasActivePrewarmFlag
  }

  static var hasActivePrewarmFlag: Bool {
    return ProcessInfo.processInfo.environment["ActivePrewarm"] != nil
  }

  private static var hasLaunched = false
  private static var hasLostFocusBefore = false
  private static var lastWarmLaunchStart: Date?
  private static var shouldReportHiddenEvent = false

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

    // Setup cold launch end handler
    AwsOpenTelemetryLogger.debug("Setting up cold end observer for: \(provider.coldEndNotification.rawValue)")
    observers[provider.coldEndNotification.rawValue] = NotificationCenter.default.addObserver(
      forName: provider.coldEndNotification,
      object: nil,
      queue: nil
    ) { _ in
      Self.onColdEnd()
    }

    // Setup warm launch start handler
    AwsOpenTelemetryLogger.debug("Setting up warm start observer for: \(provider.warmStartNotification.rawValue)")
    observers[provider.warmStartNotification.rawValue] = NotificationCenter.default.addObserver(
      forName: provider.warmStartNotification,
      object: nil,
      queue: nil
    ) { _ in
      Self.onWarmStart()
    }

    // Setup warm launch end handler
    AwsOpenTelemetryLogger.debug("Setting up warm end observer for: \(provider.warmEndNotification.rawValue)")
    observers[provider.warmEndNotification.rawValue] = NotificationCenter.default.addObserver(
      forName: provider.warmEndNotification,
      object: nil,
      queue: nil
    ) { _ in
      Self.onWarmEnd()
    }

    // Setup hidden event handler
    AwsOpenTelemetryLogger.debug("Setting up onHidden observer for: \(provider.hiddenNotification.rawValue)")
    observers[provider.hiddenNotification.rawValue] = NotificationCenter.default.addObserver(
      forName: provider.hiddenNotification,
      object: nil,
      queue: nil
    ) { _ in
      Self.onHidden()
    }
    Self.shouldReportHiddenEvent = provider.additionalLifecycleEvents.contains(provider.hiddenNotification)

    // Setup observers
    AwsOpenTelemetryLogger.debug("Setting up \(provider.additionalLifecycleEvents.count) additional lifecycle observers")
    for event in provider.additionalLifecycleEvents {
      guard observers[event.rawValue] == nil else {
        AwsOpenTelemetryLogger.debug("Skipping duplicate observer for: \(event.rawValue)")
        continue
      }
      AwsOpenTelemetryLogger.debug("Setting up lifecycle observer for: \(event.rawValue)")
      observers[event.rawValue] = NotificationCenter.default.addObserver(
        forName: event,
        object: nil,
        queue: nil
      ) { notification in
        Self.onLifecycleEvent(name: notification.name.rawValue)
      }
    }

    AwsOpenTelemetryLogger.debug("AppLaunchInstrumentation initialized with \(observers.count) observers")
  }

  func onColdEnd() {
    Self.onColdEnd()
  }

  @objc static func onColdEnd() {
    AwsOpenTelemetryLogger.debug("onColdEnd called")
    lock.withLock {
      guard let provider else { return }

      let endTime = Date()

      logger.logRecordBuilder()
        .setTimestamp(endTime)
        .setEventName(provider.coldEndNotification.rawValue)
        .emit()

      guard !hasLaunched, let startTime = provider.coldLaunchStartTime else {
        AwsOpenTelemetryLogger.debug("Cold launch already recorded or no start time available")
        return
      }

      logger.logRecordBuilder()
        .setTimestamp(startTime)
        .setEventName(provider.coldStartName)
        .emit()

      let duration = endTime.timeIntervalSince(startTime)
      let isPrewarm = isPrewarmLaunch(duration: duration)

      AwsOpenTelemetryLogger.debug("Recording cold launch: duration=\(duration)s, isPrewarm=\(isPrewarm)")

      tracer.spanBuilder(spanName: "AppStart")
        .setStartTime(time: startTime)
        .setAttribute(key: "start.type", value: isPrewarm ? "prewarm" : "cold")
        .setAttribute(key: "active_prewarm", value: hasActivePrewarmFlag)
        .setAttribute(key: "launch_start_name", value: provider.coldStartName)
        .setAttribute(key: "launch_end_name", value: provider.coldEndNotification.rawValue)
        .startSpan()
        .end(time: endTime)

      hasLaunched = true
    }
  }

  func onWarmStart() {
    Self.onWarmStart()
  }

  @objc static func onWarmStart() {
    AwsOpenTelemetryLogger.debug("onWarmStart called")
    lock.withLock {
      guard let provider else { return }

      let now = Date()
      lastWarmLaunchStart = now
      logger.logRecordBuilder()
        .setTimestamp(now)
        .setEventName(provider.warmStartNotification.rawValue)
        .emit()
    }
  }

  func onWarmEnd() {
    Self.onWarmEnd()
  }

  @objc static func onWarmEnd() {
    AwsOpenTelemetryLogger.debug("onWarmEnd called")
    lock.withLock {
      guard let provider else { return }

      let endTime = Date()

      logger.logRecordBuilder()
        .setTimestamp(endTime)
        .setEventName(provider.warmEndNotification.rawValue)
        .emit()

      guard hasLostFocusBefore, hasLaunched, let startTime = lastWarmLaunchStart else {
        AwsOpenTelemetryLogger.debug("Cold launch not recorded or no warm start time available")
        return
      }

      lastWarmLaunchStart = nil
      let duration = endTime.timeIntervalSince(startTime)
      let isPrewarm = isPrewarmLaunch(duration: duration)

      AwsOpenTelemetryLogger.debug("Recording warm launch: duration=\(duration)s, isPrewarm=\(isPrewarm)")

      tracer.spanBuilder(spanName: "AppStart")
        .setStartTime(time: startTime)
        .setAttribute(key: "start.type", value: isPrewarm ? "prewarm" : "warm")
        .setAttribute(key: "active_prewarm", value: hasActivePrewarmFlag)
        .setAttribute(key: "launch_start_name", value: provider.warmStartNotification.rawValue)
        .setAttribute(key: "launch_end_name", value: provider.warmEndNotification.rawValue)
        .startSpan()
        .end(time: endTime)
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
      guard let provider else { return }
      if shouldReportHiddenEvent {
        logger.logRecordBuilder()
          .setEventName(provider.hiddenNotification.rawValue)
          .emit()
      }
    }
  }
}
