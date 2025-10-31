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

#if canImport(UIKit) && !os(watchOS)
  import UIKit
  import OpenTelemetryApi
  import OpenTelemetrySdk

  class ViewControllerHandler {
    /// Weak reference to the parent UIKitViewInstrumentation instance
    private weak var uiKitViewInstrumentation: UIKitViewInstrumentation?

    private static let queueLabel = "software.amazon.opentelemetry.ViewControllerHandler"
    private let queue: DispatchQueue

    private static var logger: Logger {
      return OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsInstrumentationScopes.UIKIT_VIEW)
    }

    private static var tracer: Tracer {
      return OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.UIKIT_VIEW)
    }

    init(queue: DispatchQueue = DispatchQueue(label: ViewControllerHandler.queueLabel, qos: .utility)) {
      self.queue = queue
    }

    func setUIKitViewInstrumentation(_ uiKitViewInstrumentation: UIKitViewInstrumentation) {
      self.uiKitViewInstrumentation = uiKitViewInstrumentation
    }

    // MARK: - Lifecycle Event Handlers

    func onViewDidLoad(_ viewController: UIViewController, now: Date = Date()) {
      guard let uiKitViewInstrumentation,
            viewController.shouldCaptureView(using: uiKitViewInstrumentation) else {
        AwsInternalLogger.debug("skipping \(viewController.screenName) - not capturing")
        return
      }

      // Register new screen so that new events get the most recent `app.screen.name`
      // This needs to be set OnLoad instead of OnAppear because all work associated with building
      // the next view's first appear needs to have the proper context (e.g. dependent HTTP requests)
      AwsScreenManagerProvider.getInstance().setCurrent(screen: viewController.screenName)

      // Set UI state with loadTime=now to measure TimeToFirstAppear later
      viewController.instrumentationState = ViewInstrumentationState()
      viewController.instrumentationState?.loadTime = now
    }

    func onViewDidAppear(_ viewController: UIViewController, now: Date = Date()) {
      guard let uiKitViewInstrumentation,
            viewController.shouldCaptureView(using: uiKitViewInstrumentation) else {
        AwsInternalLogger.debug("skipping \(viewController.screenName) - not capturing")
        return
      }

      // Report ViewDidAppear
      AwsScreenManagerProvider.getInstance().logViewDidAppear(
        screen: viewController.screenName,
        type: .uikit,
        timestamp: now,
        logger: Self.logger
      )

      // Null-check and de-dupping check
      guard let state = viewController.instrumentationState,
            !state.didAppear,
            let loadTime = state.loadTime else {
        AwsInternalLogger.debug("skipping TimeToFirstAppear span for \(viewController.screenName)")
        return
      }

      // Report TimeToFirstAppear
      Self.tracer.spanBuilder(spanName: AwsTimeToFirstAppear.name)
        .setStartTime(time: loadTime)
        .setAttribute(key: AwsTimeToFirstAppear.screenName, value: viewController.screenName)
        .setAttribute(key: AwsTimeToFirstAppear.type, value: AwsViewType.uikit.rawValue)
        .startSpan()
        .end(time: now)

      // Prevent duplicate reports in the future
      state.didAppear = true
    }
  }
#endif

class ViewInstrumentationState: NSObject {
  var loadTime: Date?
  var didAppear = false
}
