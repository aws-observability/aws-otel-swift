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

#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import Foundation
  import MetricKit
  import OpenTelemetryApi

  /*
   * MetriKit is supported in iOSv14, but only iOSv15 support real time monitoring for MXDiagnosticPaylods.
   * From documentation, MetrcKit "delivers diagnostic reports immediately in iOS 15 and later and macOS 12 and later".
   * https://developer.apple.com/documentation/metrickit?language=objc
   */
  @available(iOS 15.0, *)
  class AwsMetricKitSubscriber: NSObject, MXMetricManagerSubscriber {
    private let config: AwsMetricKitConfig

    init(config: AwsMetricKitConfig = .default) {
      self.config = config
      super.init()
      if #available(iOS 16.0, *), config.startup {
        AwsMetricKitAppLaunchProcessor.initialize()
      } else {
        AwsInternalLogger.error("ADOT Swift only officially supports iOS 16")
      }
    }

    func subscribe() {
      MXMetricManager.shared.add(self)
    }

    deinit {
      MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
      for _ in payloads {
        // Disable MXCrashDiagnostic for beta scope
        // if config.crashes {
        //   processCrashDiagnostics(payload.crashDiagnostics)
        // }
      }
    }

    private func processCrashDiagnostics(_ diagnostics: [MXCrashDiagnostic]?) {
      AwsMetricKitCrashProcessor.processCrashDiagnostics(diagnostics)
    }
  }
#endif
