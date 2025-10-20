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

import SwiftUI
import AwsOpenTelemetryCore
import OpenTelemetryApi

struct SettingsView: View {
  @State private var sessionData: [(String, String)] = []
  @State private var configData: [(String, String)] = []
  @State private var troubleshootingData: [(String, String)] = []
  @State private var showingToast = false
  @State private var showingHangPicker = false
  @State private var showingCrashPicker = false
  @State private var timer: Timer?

  var body: some View {
    List {
      Section("AWS Config") {
        ForEach(configData, id: \.0) { item in
          SettingsRow(title: item.0, value: item.1, isCopyable: true)
        }
      }

      Section("User Session") {
        ForEach(sessionData, id: \.0) { item in
          SettingsRow(title: item.0, value: item.1, isCopyable: item.0 != "Session Expiry")
        }
      }

      Section("Troubleshooting") {
        ForEach(troubleshootingData, id: \.0) { item in
          Button(action: {
            if item.0 == "Trigger App Hang" {
              showingHangPicker = true
            } else if item.0 == "Trigger App Crash" {
              showingCrashPicker = true
            }
          }) {
            HStack {
              Text(item.0)
                .foregroundColor(.primary)
              Spacer()
              Text(item.1)
                .foregroundColor(.secondary)
              Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
        }
      }
    }
    .navigationTitle("Settings")
    .onAppear {
      loadSessionData()
      startTimer()
    }
    .onDisappear {
      timer?.invalidate()
      timer = nil
    }
    .sheet(isPresented: $showingHangPicker) {
      HangPickerView()
    }
    .sheet(isPresented: $showingCrashPicker) {
      CrashPickerView()
    }
    .overlay(
      ToastView(isShowing: $showingToast)
    )
  }

  private func loadSessionData() {
    configData = [
      ("App Monitor ID", "33868e1a-72af-4815-8605-46f5dc76c91b"),
      ("Region", "us-west-2"),
      ("Logs Endpoint", "http://localhost:4318/v1/logs"),
      ("Traces Endpoint", "http://localhost:4318/v1/traces")
    ]

    troubleshootingData = [
      ("Trigger App Hang", "Tap to configure"),
      ("Trigger App Crash", "Tap to configure")
    ]

    guard let currentSession = AwsSessionManagerProvider.getInstance().peekSession() else {
      sessionData = [
        ("User ID", "nil"),
        ("Previous Session", "nil"),
        ("Current Session", "nil"),
        ("Session Expiry", "nil")
      ]
      return
    }

    let expireTime = currentSession.expireTime
    let userId = AwsUIDManagerProvider.getInstance().getUID()
    let timeToExpiry = expireTime.timeIntervalSinceNow
    let previousSessionId = AwsSessionManagerProvider.getInstance().peekSession()?.previousId ?? "nil"

    sessionData = [
      ("User ID", userId),
      ("Previous Session", previousSessionId),
      ("Current Session", currentSession.id),
      ("Session Expiry", "\(Int(timeToExpiry)) seconds")
    ]
  }

  private func startTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      updateExpiryTime()
    }
  }

  private func updateExpiryTime() {
    guard let currentSession = AwsSessionManagerProvider.getInstance().peekSession() else {
      return
    }

    let expireTime = currentSession.expireTime
    let timeToExpiry = expireTime.timeIntervalSinceNow
    let expiryText = timeToExpiry <= 0 ? "Expired" : "\(Int(timeToExpiry)) seconds"

    if let index = sessionData.firstIndex(where: { $0.0 == "Session Expiry" }) {
      sessionData[index] = ("Session Expiry", expiryText)
    }
  }
}

struct SettingsRow: View {
  let title: String
  let value: String
  let isCopyable: Bool
  @State private var showingToast = false

  var body: some View {
    Button(action: {
      if isCopyable {
        UIPasteboard.general.string = value
        showingToast = true
      }
    }) {
      HStack {
        Text(title)
          .font(.system(.caption, design: .monospaced, weight: .medium))
          .foregroundColor(.primary)
        Spacer(minLength: 20)
        Text(value)
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 200, alignment: .trailing)
          .lineLimit(nil)
      }
    }
    .disabled(!isCopyable)
    .overlay(
      ToastView(isShowing: $showingToast)
    )
  }
}

struct ToastView: View {
  @Binding var isShowing: Bool

  var body: some View {
    if isShowing {
      VStack {
        Spacer()
        Text("Copied to Clipboard")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(Color.black.opacity(0.8))
          .cornerRadius(8)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              isShowing = false
            }
          }
          .padding(.bottom, 20)
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
  }
}

struct HangPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedHangType: HangType = .threadSleep
  @State private var seconds: Int = 1
  @State private var centiseconds: Int = 0

  var selectedDuration: TimeInterval {
    TimeInterval(seconds) + TimeInterval(centiseconds) / 100.0
  }

  var body: some View {
    AwsOTelTraceView("HangPickerView") {
      NavigationView {
        VStack {
          Text("Select hang type and duration (seconds)")
            .font(.headline)
            .padding()

          Text("Note: Only hangs longer than 250ms are reported")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)

          HStack(spacing: 0) {
            Picker("Hang Type", selection: $selectedHangType) {
              ForEach(HangType.allCases, id: \.self) { type in
                HStack {
                  Text(type.displayName)
                    .lineLimit(nil)
                  Spacer()
                }
                .tag(type)
              }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: 180)

            Picker("Seconds", selection: $seconds) {
              ForEach(0 ..< 60, id: \.self) { sec in
                Text("\(sec)").tag(sec)
              }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: 80)

            Picker("Centiseconds", selection: $centiseconds) {
              ForEach(0 ..< 100, id: \.self) { cs in
                Text(String(format: ".%02d", cs)).tag(cs)
              }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: 60)
          }
          .padding()

          Button("Trigger Hang") {
            triggerAppHang(type: selectedHangType, duration: selectedDuration)
            dismiss()
          }
          .foregroundColor(.white)
          .padding()
          .background(Color.red)
          .cornerRadius(8)
          .padding()

          Spacer()
        }
        .navigationTitle("Trigger App Hang")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
              dismiss()
            }
          }
        }
      }
    }
  }

  private func triggerAppHang(type: HangType, duration: TimeInterval) {
    let durationText = String(format: "%.2fs", duration)

    showCountdownToast(durationText: durationText, type: type, duration: duration)
  }

  private func showCountdownToast(durationText: String, type: HangType, duration: TimeInterval) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return }

    let toast = createToast(text: "Hang Starting in 3...", in: window)

    var countdown = 3
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      countdown -= 1
      if countdown > 0 {
        toast.text = "Hang Starting in \(countdown)..."
      } else {
        timer.invalidate()
        toast.text = "\(type.displayName) for \(durationText)"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          let start = Date()

          switch type {
          case .threadSleep:
            Thread.sleep(forTimeInterval: duration)
          case .syncNetworkCall:
            performSyncNetworkCall(duration: duration)
          case .cpuIntensiveTask:
            performCpuIntensiveTask(duration: duration)
          }

          let end = Date()
          let span = OpenTelemetry.instance.tracerProvider.get(instrumentationName: debugScope)
            .spanBuilder(spanName: "[DEBUG] Triggered Hang - \(type.displayName)")
            .setStartTime(time: start)
            .startSpan()
          span.end(time: end)

          toast.text = "Hang Completed!"

          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            toast.removeFromSuperview()
          }
        }
      }
    }
  }

  private func createToast(text: String, in window: UIWindow) -> UILabel {
    let toast = UILabel()
    toast.text = text
    toast.font = .systemFont(ofSize: 16, weight: .medium)
    toast.textColor = .white
    toast.backgroundColor = .systemRed.withAlphaComponent(0.9)
    toast.textAlignment = .center
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false

    window.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      toast.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 20),
      toast.widthAnchor.constraint(equalToConstant: 200),
      toast.heightAnchor.constraint(equalToConstant: 40)
    ])

    return toast
  }

  private func performSyncNetworkCall(duration: TimeInterval) {
    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: "https://httpbin.org/delay/\(Int(duration))")!

    let task = URLSession.shared.dataTask(with: url) { _, _, _ in
      semaphore.signal()
    }
    task.resume()
    semaphore.wait()
  }

  private func performCpuIntensiveTask(duration: TimeInterval) {
    let endTime = Date().addingTimeInterval(duration)
    var counter = 0

    while Date() < endTime {
      for i in 0 ..< 100000 {
        counter += i * i
      }
    }
  }
}

enum CrashType: CaseIterable {
  case forceUnwrap
  case indexOutOfBounds
  case fatalError
  case divideByZero
  case stackOverflow

  var displayName: String {
    switch self {
    case .indexOutOfBounds: return "Index Out of Bounds"
    case .fatalError: return "Fatal Error"
    case .forceUnwrap: return "Force Unwrap Nil"
    case .divideByZero: return "Divide by Zero"
    case .stackOverflow: return "Stack Overflow"
    }
  }
}

struct CrashPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var selectedCrashType: CrashType = .forceUnwrap

  var body: some View {
    AwsOTelTraceView("CrashPickerView") {
      NavigationView {
        VStack {
          Text("Select crash type")
            .font(.headline)
            .padding()

          Text("Warning: application will force exit after countdown")
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal)

          Picker("Crash Type", selection: $selectedCrashType) {
            ForEach(CrashType.allCases, id: \.self) { type in
              HStack {
                Text(type.displayName)
                  .lineLimit(nil)
                Spacer()
              }
              .tag(type)
            }
          }
          .pickerStyle(.wheel)
          .padding()

          Button("Trigger Crash") {
            triggerCrash(type: selectedCrashType)
            dismiss()
          }
          .foregroundColor(.white)
          .padding()
          .background(Color.red)
          .cornerRadius(8)
          .padding()

          Spacer()
        }
        .navigationTitle("Trigger App Crash")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
              dismiss()
            }
          }
        }
      }
    }
  }

  private func triggerCrash(type: CrashType) {
    let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: debugScope)
    let delay: TimeInterval = 5
    logger.logRecordBuilder()
      .setEventName("[DEBUG] Triggered a \(type.displayName) crash")
      .setTimestamp(Date().addingTimeInterval(delay))
      .emit()

    showCrashCountdownToast(type: type, delay: delay)
  }

  private func showCrashCountdownToast(type: CrashType, delay: TimeInterval) {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else { return }

    var countdown = Int(delay)
    let toast = createToast(text: "Crash Starting in \(countdown)...", in: window)

    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
      countdown -= 1
      if countdown > 0 {
        toast.text = "Crash Starting in \(countdown)..."
      } else {
        timer.invalidate()
        toast.text = "Triggering \(type.displayName)"

        // Log the crash event before it happens

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          switch type {
          case .indexOutOfBounds:
            let array = [1, 2, 3]
            _ = array[10] // Index out of bounds
          case .fatalError:
            fatalError("Intentional crash for testing")
          case .forceUnwrap:
            let nilValue: String? = nil
            _ = nilValue! // Force unwrap nil
          case .divideByZero:
            let zero = Int.random(in: 0 ... 0) // Runtime zero
            _ = 42 / zero // Division by zero
          case .stackOverflow:
            func recursiveFunction() {
              recursiveFunction() // Infinite recursion
            }
            recursiveFunction()
          }
        }
      }
    }
  }

  private func createToast(text: String, in window: UIWindow) -> UILabel {
    let toast = UILabel()
    toast.text = text
    toast.font = .systemFont(ofSize: 16, weight: .medium)
    toast.textColor = .white
    toast.backgroundColor = .systemRed.withAlphaComponent(0.9)
    toast.textAlignment = .center
    toast.layer.cornerRadius = 8
    toast.clipsToBounds = true
    toast.translatesAutoresizingMaskIntoConstraints = false

    window.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      toast.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 20),
      toast.widthAnchor.constraint(equalToConstant: 200),
      toast.heightAnchor.constraint(equalToConstant: 40)
    ])

    return toast
  }
}

#Preview {
  SettingsView()
}
