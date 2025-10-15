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
import AwsOpenTelemetryAuth
import AWSCognitoIdentity
import AwsOpenTelemetryCore
import Combine
import OpenTelemetryApi

/**
 * View model responsible for initializing AWS services and handling API calls.
 *
 * This class owns all observable UI state such as loading indicators, errors,
 * and result messages. It acts as the bridge between the UI and AWS service logic.
 */
@MainActor
class LoaderViewModel: ObservableObject {
  /// Indicates whether an AWS operation is in progress
  @Published var isLoading = true

  /// Stores any error encountered during AWS setup or operations
  @Published var error: Error?

  /// Message displayed to the user representing the result of AWS operations
  @Published var resultMessage: String = "AWS API results will appear here"

  @Published var showingCustomLogForm = false
  @Published var showingCustomSpanForm = false
  @Published var showingGlobalAttributesView = false
  @Published var isJanking = false
  private var jankStartTime: Date?
  private var jankDuration: Double = 0

  /// Timer for updating the digital clock
  private var clockTimer: AnyCancellable?

  /// Instance of the AWS service handler (non-observable)
  private(set) var awsServiceHandler: AwsServiceHandler?

  private let cognitoPoolId: String
  private let region: String

  /// Date formatter for the digital clock
  private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    return formatter
  }()

  /**
   * Initializes the view model with required AWS configuration
   *
   * - Parameters:
   *   - cognitoPoolId: The Cognito Identity Pool ID
   *   - region: AWS region string (e.g., "us-west-2")
   */
  init(cognitoPoolId: String, region: String) {
    self.cognitoPoolId = cognitoPoolId
    self.region = region
  }

  /// Initializes the `AwsServiceHandler` instance and prepares AWS SDK for use
  func initialize() async {
    do {
      // Configure and initialize the Cognito Identity client
      let cognitoConfig = try await CognitoIdentityClient.CognitoIdentityClientConfiguration(region: region)
      let cognitoIdentityClient = CognitoIdentityClient(config: cognitoConfig)

      let credentialsProvider = CognitoCachedCredentialsProvider(
        cognitoPoolId: cognitoPoolId, cognitoClient: cognitoIdentityClient
      )

      awsServiceHandler = try await AwsServiceHandler(
        region: region,
        awsCredentialsProvider: credentialsProvider,
        cognitoIdentityClient: cognitoIdentityClient,
        cognitoPoolId: cognitoPoolId
      )

      isLoading = false
    } catch {
      isLoading = false
    }
  }

  /// Performs the "List S3 Buckets" operation and updates UI state
  func listS3Buckets() async {
    stopClock()
    isLoading = true
    resultMessage = "Loading S3 buckets..."

    guard let awsServiceHandler else { return }
    defer { isLoading = false }
    // Call list buckets
    do {
      let buckets = try await awsServiceHandler.listS3Buckets()
      resultMessage = buckets.isEmpty
        ? "No buckets found"
        : "S3 Buckets:\n\n" + buckets.map { "- \($0.name) (Created: \($0.creationDate))" }.joined(separator: "\n")
    } catch {
      resultMessage = "Error listing S3 buckets: \(error.localizedDescription)"
    }
  }

  /// Performs the "Get Cognito Identity" operation and updates UI state
  func getCognitoIdentityId() async {
    stopClock()
    guard let awsServiceHandler else { return }

    isLoading = true
    resultMessage = "Fetching Cognito identity..."
    defer { isLoading = false }

    do {
      let identityId = try await awsServiceHandler.getCognitoIdentityId()
      resultMessage = "Cognito Identity ID: \(identityId)"
    } catch {
      resultMessage = "Error getting Cognito identity: \(error.localizedDescription)"
    }
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

  func createCustomLog(eventName: String, message: String, attributes: [String: String]) {
    stopClock()

    let logger = OpenTelemetry.instance.loggerProvider.loggerBuilder(instrumentationScopeName: "custom.log").build()
    let logBuilder = logger.logRecordBuilder()
      .setEventName(eventName)
      .setTimestamp(Date())
      .setBody(AttributeValue.string(message))

    var attributeValues: [String: AttributeValue] = [:]
    for (key, value) in attributes {
      attributeValues[key] = AttributeValue.string(value)
    }

    logBuilder.setAttributes(attributeValues).emit()

    resultMessage = "Custom log created:\nEvent: \(eventName)\nMessage: \(message)\nAttributes: \(attributes)"
  }

  func showCustomSpanForm() {
    showingCustomSpanForm = true
  }

  func showGlobalAttributesView() {
    showingGlobalAttributesView = true
  }

  func createCustomSpan(name: String, startTime: Date, endTime: Date, attributes: [String: String]) {
    stopClock()

    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "custom.span")
    let span = tracer.spanBuilder(spanName: name).setStartTime(time: startTime).startSpan()

    for (key, value) in attributes {
      span.setAttribute(key: key, value: AttributeValue.string(value))
    }

    span.end(time: endTime)

    let duration = endTime.timeIntervalSince(startTime)
    resultMessage = "Custom span created:\nName: \(name)\nDuration: \(String(format: "%.2f", duration))s\nAttributes: \(attributes)"
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

  enum HangType: String, CaseIterable {
    case threadSleep = "Thread.sleep"
    case networkCall = "Network Call"
    case heavyComputation = "Heavy Computation"
    case fileIO = "File I/O"

    var description: String {
      switch self {
      case .threadSleep:
        return "Blocks thread completely using Thread.sleep"
      case .networkCall:
        return "Synchronous network request with delay"
      case .heavyComputation:
        return "CPU-intensive work without yielding"
      case .fileIO:
        return "Synchronous file operations"
      }
    }
  }

  /// Simulates a hang
  func hangApplication(seconds: UInt8) {
    hangApplication(seconds: Double(seconds), type: .threadSleep)
  }

  func hangApplication(seconds: Double, type: HangType) {
    /// Most of Apple’s developer tools start reporting issues when the period of unresponsiveness for the main run loop exceeds 250 ms. [source](https://developer.apple.com/documentation/xcode/understanding-hangs-in-your-app#Understand-hangs)
    ///
    let startTime = Date()
    let duration = seconds

    switch type {
    case .threadSleep:
      print("LoaderViewModel: Starting Thread.sleep at \(startTime)")
      Thread.sleep(forTimeInterval: duration)

    case .networkCall:
      print("LoaderViewModel: Starting network call at \(startTime)")
      let delaySeconds = Int(duration)
      let url = URL(string: "https://httpbin.org/delay/\(delaySeconds)")!
      _ = try? Data(contentsOf: url)

    case .heavyComputation:
      print("LoaderViewModel: Starting heavy computation at \(startTime)")
      let endTime = startTime.addingTimeInterval(duration)
      while Date() < endTime {
        // CPU-intensive work that blocks RunLoop
        _ = (0 ... 1000).map { $0 * $0 }.reduce(0, +)
      }

    case .fileIO:
      print("LoaderViewModel: Starting file I/O at \(startTime)")
      let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("hang_test.txt")
      let endTime = startTime.addingTimeInterval(duration)
      var i = 0
      while Date() < endTime {
        try? "\(i)\n".data(using: .utf8)?.write(to: tempFile, options: .atomic)
        i += 1
      }
    }

    let actualEndTime = Date()
    print("LoaderViewModel: Finished hang simulation at \(actualEndTime), duration: \(actualEndTime.timeIntervalSince(startTime) * 1000)ms")

    let (typeName, typeDescription) = switch type {
    case .threadSleep: ("Thread.Sleep", "Blocks thread completely")
    case .networkCall: ("Network.Call", "Synchronous network request")
    case .heavyComputation: ("Heavy.Computation", "CPU-intensive work")
    case .fileIO: ("File.IO", "Synchronous file operations")
    }

    createCustomSpan(name: "[DEBUG]\(typeName)", startTime: startTime, endTime: actualEndTime, attributes: [
      "duration_seconds": String(format: "%.1f", seconds),
      "type": typeName,
      "description": typeDescription
    ])
  }

  func isContractTest() -> Bool {
    return ProcessInfo.processInfo.arguments.contains("--contractTestMode")
  }

  func isNotContractTest() -> Bool {
    return !isContractTest()
  }

  func toggleUIJank() {
    toggleUIJank(duration: 10.0)
  }

  func toggleUIJank(duration: Double) {
    stopClock()
    isJanking.toggle()
    if isJanking {
      jankStartTime = Date()
      jankDuration = duration
      startJankSimulation()
      resultMessage = "🟡 Started UI jank simulation for \(String(format: "%.1f", duration))s"
    } else {
      if let startTime = jankStartTime {
        let endTime = Date()
        createCustomSpan(name: "[DEBUG]UIJank", startTime: startTime, endTime: endTime, attributes: [
          "duration_seconds": String(format: "%.1f", endTime.timeIntervalSince(startTime)),
          "type": "UIJank",
          "description": "Continuous frame drops (100ms blocks every 50ms)"
        ])
      }
      jankStartTime = nil
      resultMessage = "🟢 Stopped UI jank simulation"
    }
  }

  private func startJankSimulation() {
    performJankOperation()

    // Auto-stop after specified duration
    DispatchQueue.main.asyncAfter(deadline: .now() + jankDuration) {
      if self.isJanking {
        self.toggleUIJank(duration: 0)
      }
    }
  }

  private func performJankOperation() {
    guard isJanking else { return }

    // Block main thread for 100ms to cause frame drops
    let startTime = Date()
    while Date().timeIntervalSince(startTime) < 0.1 {
      // Busy wait
    }

    // Schedule next jank operation
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      self.performJankOperation()
    }
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
