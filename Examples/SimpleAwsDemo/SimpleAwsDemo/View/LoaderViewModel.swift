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
import SwiftUI
import AwsOpenTelemetryCore
import Combine
import OpenTelemetryApi

/**
 * View model responsible for handling demo operations and telemetry.
 *
 * This class owns all observable UI state such as loading indicators, errors,
 * and result messages.
 */
@MainActor
class LoaderViewModel: ObservableObject {
  /// Indicates whether an operation is in progress
  @Published var isLoading = true

  /// Stores any error encountered during operations
  @Published var error: Error?

  /// Message displayed to the user representing the result of operations
  @Published var resultMessage: String = "Demo results will appear here"

  @Published var showingCustomLogForm = false
  @Published var showingCustomSpanForm = false
  @Published var showingGlobalAttributesView = false

  /// Timer for updating the digital clock
  private var clockTimer: AnyCancellable?

  /// Date formatter for the digital clock
  private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    return formatter
  }()

  /**
   * Initializes the view model
   */
  init() {
    isLoading = false
  }

  func showSessionDetails() {
    resultMessage = "Session Details\n\n"

    // Start the digital clock
    startClock()
  }

  func renewSession() {
    AwsSessionManagerProvider.getInstance().getSession()
  }

  func showUserInfo() {
    stopClock()
    let uidManager = AwsUIDManagerProvider.getInstance()
    let currentUID = uidManager.getUID()
    resultMessage = "UID: \(currentUID)"
  }

  func showCustomLogForm() {
    showingCustomLogForm = true
  }

  func createCustomLog(message: String, attributes: [String: String]) {
    stopClock()

    let logger = OpenTelemetry.instance.loggerProvider.loggerBuilder(instrumentationScopeName: "custom.log").build()
    let logBuilder = logger.logRecordBuilder()
      .setBody(AttributeValue.string(message))

    var attributeValues: [String: AttributeValue] = [:]
    for (key, value) in attributes {
      attributeValues[key] = AttributeValue.string(value)
    }

    logBuilder.setAttributes(attributeValues).emit()

    resultMessage = "Custom log created:\nMessage: \(message)\nAttributes: \(attributes)"
  }

  func showCustomSpanForm() {
    showingCustomSpanForm = true
  }

  func showGlobalAttributesView() {
    showingGlobalAttributesView = true
  }

  func createCustomSpan(name: String, attributes: [String: String]) {
    stopClock()

    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "custom.span")
    let span = tracer.spanBuilder(spanName: name).startSpan()

    for (key, value) in attributes {
      span.setAttribute(key: key, value: AttributeValue.string(value))
    }

    span.end()

    resultMessage = "Custom span created:\nName: \(name)\nAttributes: \(attributes)"
  }

  /// Makes a 200 HTTP request to demonstrate network error instrumentation
  func make200Request() async {
    stopClock()
    resultMessage = "Making 200 HTTP request..."
    do {
      var url = URL(string: "https://httpbin.org/status/200")!
      if isContractTest() {
        url = URL(string: "http://localhost:8181/200")!
      }
      let (_, response) = try await URLSession.shared.data(from: url)

      if let httpResponse = response as? HTTPURLResponse {
        resultMessage = "HTTP Request completed with status: \(httpResponse.statusCode)"
      } else {
        resultMessage = "HTTP Request completed but no status code available"
      }
    } catch {
      resultMessage = "HTTP Request failed: \(error.localizedDescription)"
    }
  }

  /// Makes a 4xx HTTP request to demonstrate network error instrumentation
  func make4xxRequest() async {
    stopClock()
    resultMessage = "Making 4xx HTTP request..."
    do {
      var url = URL(string: "https://httpbin.org/status/404")!
      if isContractTest() {
        url = URL(string: "http://localhost:8181/404")!
      }
      let (_, response) = try await URLSession.shared.data(from: url)

      if let httpResponse = response as? HTTPURLResponse {
        resultMessage = "HTTP Request completed with status: \(httpResponse.statusCode)"
      } else {
        resultMessage = "HTTP Request completed but no status code available"
      }
    } catch {
      resultMessage = "HTTP Request failed: \(error.localizedDescription)"
    }
  }

  /// Makes a 5xx HTTP request to demonstrate network server error instrumentation
  func make5xxRequest() async {
    stopClock()
    resultMessage = "Making 5xx HTTP request..."
    do {
      var url = URL(string: "https://httpbin.org/status/500")!
      if isContractTest() {
        url = URL(string: "http://localhost:8181/500")!
      }
      let (_, response) = try await URLSession.shared.data(from: url)

      if let httpResponse = response as? HTTPURLResponse {
        resultMessage = "HTTP Request completed with status: \(httpResponse.statusCode)"
      } else {
        resultMessage = "HTTP Request completed but no status code available"
      }
    } catch {
      resultMessage = "HTTP Request failed: \(error.localizedDescription)"
    }
  }

  /// Simulates a hang
  func hangApplication(seconds: UInt8) {
    /// Most of Apple’s developer tools start reporting issues when the period of unresponsiveness for the main run loop exceeds 250 ms. [source](https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app#Understand-hangs)
    ///
    DispatchQueue.main.async {
      // Intentionally block the main thread for a duration
      Thread.sleep(forTimeInterval: Double(seconds) as TimeInterval)
    }
  }

  func isContractTest() -> Bool {
    return ProcessInfo.processInfo.arguments.contains("--contractTestMode")
  }

  func isNotContractTest() -> Bool {
    return !isContractTest()
  }

  /// Starts the digital clock timer
  private func startClock() {
    // Update time immediately
    updateSessionDetails()

    // Cancel existing timer if it exists
    clockTimer?.cancel()

    // Create a new timer that fires every second
    clockTimer = Timer.publish(every: 1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.updateSessionDetails()
      }
  }

  /// Updates the current time string
  private func updateSessionDetails() {
    let currentTime = timeFormatter.string(from: Date())
    guard let session = AwsSessionManagerProvider.getInstance().peekSession() else {
      resultMessage = "no session"
      return
    }
    let sessionId = session.id
    let sessionPrevId = session.previousId ?? "nil"
    let sessionExpires = timeFormatter.string(from: session.expireTime)
    let sessionIsExpired = session.isExpired()
    let startTime = timeFormatter.string(from: session.startTime)
    let duration = session.duration == nil ? "nil" : String(format: "%.2f seconds", session.duration!)
    let endTime = session.endTime == nil ? "nil" : timeFormatter.string(from: session.endTime!)

    let lines = [
      "current_time=: \(currentTime)",
      "session.expireTime=\(sessionExpires)",
      "session.isExpired=\(sessionIsExpired)",
      "session.startTime=\(startTime)",
      "session.id=\(sessionId)",
      "session.previous_id=\(sessionPrevId)",
      "session.duration=\(duration)",
      "session.endTime=\(endTime)"
    ]

    resultMessage = lines.joined(separator: "\n")
  }

  /// Stops the digital clock timer
  func stopClock() {
    clockTimer?.cancel()
    clockTimer = nil
  }

  // Teardown
  deinit {
    // Use Task to call MainActor-isolated method from deinit
    Task { @MainActor in
      clockTimer?.cancel()
      clockTimer = nil
    }
  }
}
