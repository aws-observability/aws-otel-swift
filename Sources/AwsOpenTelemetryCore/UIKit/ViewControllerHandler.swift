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

  // MARK: - Constants

  /**
   * Core handler for managing OpenTelemetry spans during UIViewController lifecycle events.
   *
   * This class serves as the central coordinator for span creation, management, and cleanup
   * during view controller lifecycle events. It maintains the complex state required to
   * create meaningful span hierarchies and handle edge cases like app backgrounding.
   *
   * ## Responsibilities
   *
   * - **Span Creation**: Creates appropriately named spans for each lifecycle event
   * - **Span Hierarchy**: Maintains parent-child relationships between related spans
   * - **State Management**: Tracks view controller states and span lifecycles
   * - **Background Handling**: Properly handles app backgrounding and foregrounding
   * - **Memory Management**: Ensures spans are properly cleaned up to prevent leaks
   * - **Error Handling**: Gracefully handles edge cases and unexpected states
   *
   * ## Span Architecture
   *
   * The handler creates two types of root spans for each view controller:
   *
   * ```
   * TimeToFirstAppear (Root Span)
   * ├── viewDidLoad
   * ├── viewWillAppear
   * ├── viewIsAppearing
   * └── viewDidAppear
   *
   * view.duration (Root Span)
   * └── (measures time from viewDidAppear to viewDidDisappear)
   * ```
   *
   * ## Thread Safety
   *
   * This class uses a dedicated serial dispatch queue to ensure thread safety.
   * All operations on internal state (span dictionaries) are performed on this queue,
   * which serializes access and prevents race conditions. While UIKit lifecycle events
   * typically occur on the main thread, this approach ensures safety even when the handler
   * is accessed from background threads.
   *
   * The `parentSpan` method uses a synchronous queue operation to safely retrieve
   * span information while maintaining thread safety.
   *
   * ## Integration
   *
   * This handler is automatically created and managed by `UIKitViewInstrumentation`.
   * It should not be instantiated directly in typical usage scenarios.
   */
  class ViewControllerHandler {
    // MARK: - Constants

    /// Queue label for ViewControllerHandler operations
    /// Used to create a dedicated serial queue for thread-safe span operations
    private static let queueLabel = "software.amazon.opentelemetry.ViewControllerHandler"

    // MARK: - Instance Properties

    /// The OpenTelemetry tracer used for creating spans
    /// This tracer is configured with appropriate instrumentation metadata
    private static var logger: Logger {
      return OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: AwsInstrumentationScopes.UIKIT_VIEW)
    }

    private static var tracer: Tracer {
      return OpenTelemetry.instance.tracerProvider.get(instrumentationName: AwsInstrumentationScopes.UIKIT_VIEW)
    }

    /// Weak reference to the parent UIKitViewInstrumentation instance
    /// Used for parent span lookup and avoiding retain cycles
    private weak var uiKitViewInstrumentation: UIKitViewInstrumentation?

    /// Serial dispatch queue for thread-safe span operations
    /// All span state modifications are performed on this queue
    private let queue: DispatchQueue

    // MARK: - Span Storage

    // Dictionaries for tracking spans by view controller identifier
    // All access to these dictionaries is performed on the serial queue for thread safety

    /// Parent spans for the TimeToFirstAppear lifecycle (viewDidLoad → viewDidAppear)
    private var parentSpans: [String: Span] = [:]

    /// Individual lifecycle method spans
    private var viewDidLoadSpans: [String: Span] = [:]
    private var viewWillAppearSpans: [String: Span] = [:]
    private var viewIsAppearingSpans: [String: Span] = [:]
    private var viewDidAppearSpans: [String: Span] = [:]

    /// Duration spans for tracking view visibility (viewDidAppear → viewDidDisappear)
    private var visibilitySpans: [String: Span] = [:]

    // MARK: - Initialization

    /**
     * Creates a new ViewControllerHandler with the specified tracer and queue.
     *
     * The handler automatically registers for application lifecycle notifications
     * to properly handle span cleanup when the app is backgrounded.
     *
     * @param tracer The OpenTelemetry tracer to use for span creation
     * @param queue The dispatch queue for span operations
     */
    init(queue: DispatchQueue = DispatchQueue(label: ViewControllerHandler.queueLabel, qos: .utility)) {
      self.queue = queue

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationDidEnterBackground),
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
      )

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationWillEnterForeground),
        name: UIApplication.willEnterForegroundNotification,
        object: nil
      )
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    func setUIKitViewInstrumentation(_ uiKitViewInstrumentation: UIKitViewInstrumentation) {
      self.uiKitViewInstrumentation = uiKitViewInstrumentation
    }

    /**
     * Retrieves the parent span for a given view controller.
     *
     * This method is used to establish span hierarchies and ensure proper parent-child
     * relationships between spans created for the same view controller's lifecycle events.
     *
     * Note: This method performs a synchronous operation on the queue to ensure thread safety.
     *
     * @param viewController The view controller to get the parent span for
     * @return The parent span if one exists, nil otherwise
     */
    func parentSpan(for viewController: UIViewController) -> Span? {
      guard let id = viewController.instrumentationState?.identifier else {
        return nil
      }

      // Use sync to perform a thread-safe read operation
      var result: Span?
      queue.sync {
        result = self.parentSpans[id]
      }
      return result
    }

    @objc func applicationDidEnterBackground(_ notification: Notification? = nil) {
      let now = Date()

      queue.async {
        AwsOpenTelemetryLogger.debug("[ViewControllerHandler] Cleaned up spans due to app backgrounding")
      }
    }

    @objc func applicationWillEnterForeground(_ notification: Notification? = nil) {
      queue.async {
        // Reset any remaining state when returning to foreground
        // self.clearAllSpans()

        AwsOpenTelemetryLogger.debug("[ViewControllerHandler] Reset state due to app foregrounding")
      }
    }

    // MARK: - Lifecycle Event Handlers

    func onViewDidLoad(_ viewController: UIViewController, now: Date = Date()) {
      guard let uiKitViewInstrumentation,
            viewController.shouldCaptureView(using: uiKitViewInstrumentation) else {
        return
      }

      queue.async {
        viewController.instrumentationState = ViewInstrumentationState()
        viewController.instrumentationState?.loadTime = now
      }
    }

    func onViewWillAppear(_ viewController: UIViewController, now: Date = Date()) {
      guard let uiKitViewInstrumentation,
            viewController.shouldCaptureView(using: uiKitViewInstrumentation) else {
        return
      }
    }

    func onViewDidAppear(_ viewController: UIViewController, now: Date = Date()) {
      guard let uiKitViewInstrumentation,
            viewController.shouldCaptureView(using: uiKitViewInstrumentation) else {
        return
      }

      queue.async {
        guard let state = viewController.instrumentationState else {
          return
        }
        // create TimeToFirstAppear span
        if !state.didAppear,
           let loadTime = state.loadTime {
          state.didAppear = true
          Self.tracer.spanBuilder(spanName: "TimeToFirstAppear")
            .setStartTime(time: loadTime)
            .setAttribute(key: AwsViewConstants.attributeScreenName, value: viewController.screenName)
            .setAttribute(key: AwsViewConstants.attributeViewType, value: AwsViewConstants.valueUIKit)
            .startSpan()
            .end(time: now)
        }
        // create ViewDidAppear log event
        Self.logger.logRecordBuilder()
          .setEventName("ViewDidAppear")
          .setTimestamp(now)
          .setAttributes([
            AwsViewConstants.attributeScreenName: AttributeValue.string(viewController.screenName),
            AwsViewConstants.attributeViewType: AttributeValue.string(AwsViewConstants.valueUIKit)
          ])
          .emit()
      }
    }

    func onViewDidDisappear(_ viewController: UIViewController, now: Date = Date()) {
      guard let uiKitViewInstrumentation,
            viewController.shouldCaptureView(using: uiKitViewInstrumentation) else {
        return
      }

      queue.async {
        guard let state = viewController.instrumentationState else {
          return
        }
      }
    }
  }
#endif
