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

  /// Status description when spans are cancelled due to app backgrounding
  private let statusAppBackgrounded = "app_backgrounded"

  /// Status description when spans are cancelled due to view disappearing
  private let statusViewDisappeared = "view_disappeared"

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
   * view.load (Root Span)
   * ├── viewDidLoad
   * ├── viewWillAppear
   * ├── viewIsAppearing (iOS 13+)
   * └── viewDidAppear
   *
   * view.duration (Root Span)
   * └── (measures time from viewDidAppear to viewDidDisappear)
   * ```
   *
   * ## Thread Safety
   *
   * This class is designed to be thread-safe for the specific use case of UIKit
   * lifecycle events, which always occur on the main thread. Internal state
   * is protected where necessary.
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
    private static let queueLabel = "com.aws.otel.ViewControllerHandler"

    /// Span names for different lifecycle events
    /// These names follow OpenTelemetry semantic conventions for UI instrumentation
    private let spanNameViewLoad = "view.load"
    private let spanNameViewDuration = "view.duration"
    private let spanNameViewDidLoad = "viewDidLoad"
    private let spanNameViewWillAppear = "viewWillAppear"
    private let spanNameViewIsAppearing = "viewIsAppearing"
    private let spanNameViewDidAppear = "viewDidAppear"

    /// Attribute keys for span metadata
    /// Used to add contextual information to spans for better observability
    private let attributeKeyViewName = "view.name"
    private let attributeKeyViewClass = "view.class"

    // MARK: - Instance Properties

    /// The OpenTelemetry tracer used for creating spans
    /// This tracer is configured with appropriate instrumentation metadata
    private let tracer: Tracer

    /// Weak reference to the parent UIKitViewInstrumentation instance
    /// Used for parent span lookup and avoiding retain cycles
    private weak var uiKitViewInstrumentation: UIKitViewInstrumentation?

    /// Serial dispatch queue for thread-safe span operations
    /// All span state modifications are performed on this queue
    private let queue: DispatchQueue

    // MARK: - Span Storage

    // Thread-safe dictionaries for tracking spans by view controller identifier

    /// Parent spans for the view.load lifecycle (viewDidLoad → viewDidAppear)
    @ThreadSafe var parentSpans: [String: Span] = [:]

    /// Individual lifecycle method spans
    @ThreadSafe var viewDidLoadSpans: [String: Span] = [:]
    @ThreadSafe var viewWillAppearSpans: [String: Span] = [:]
    @ThreadSafe var viewIsAppearingSpans: [String: Span] = [:]
    @ThreadSafe var viewDidAppearSpans: [String: Span] = [:]

    /// Duration spans for tracking view visibility (viewDidAppear → viewDidDisappear)
    @ThreadSafe var visibilitySpans: [String: Span] = [:]

    // MARK: - Initialization

    /**
     * Creates a new ViewControllerHandler with the specified tracer and queue.
     *
     * The handler automatically registers for application lifecycle notifications
     * to properly handle span cleanup when the app is backgrounded.
     *
     * @param tracer The OpenTelemetry tracer to use for span creation
     * @param queue The dispatch queue for span operations (defaults to a utility queue)
     */
    init(tracer: Tracer, queue: DispatchQueue = DispatchQueue(label: ViewControllerHandler.queueLabel, qos: .utility)) {
      self.tracer = tracer
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

    func parentSpan(for viewController: UIViewController) -> Span? {
      guard let id = viewController.instrumentationState?.identifier else {
        return nil
      }
      return parentSpans[id]
    }

    @objc func applicationDidEnterBackground(_ notification: Notification? = nil) {
      let now = Date()

      queue.async {
        // End visibility spans gracefully (these are expected to end)
        for span in self.visibilitySpans.values {
          span.status = .ok // Visibility ending due to background is normal
          span.end(time: now)
        }

        // End incomplete lifecycle spans with cancelled status
        for id in self.parentSpans.keys {
          self.endAllSpans(for: id, time: now, status: .error(description: statusAppBackgrounded))
        }

        // Clear all cached spans
        self.clearAllSpans()

        print("[ViewControllerHandler] Cleaned up spans due to app backgrounding")
      }
    }

    @objc func applicationWillEnterForeground(_ notification: Notification? = nil) {
      queue.async {
        // Reset any remaining state when returning to foreground
        self.clearAllSpans()

        print("[ViewControllerHandler] Reset state due to app foregrounding")
      }
    }

    // MARK: - Lifecycle Event Handlers

    func onViewDidLoadStart(_ viewController: UIViewController, now: Date = Date()) {
      guard let uiKitViewInstrumentation = uiKitViewInstrumentation,
            viewController.shouldCaptureView(using: uiKitViewInstrumentation) else {
        return
      }

      let id = UUID().uuidString
      let state = ViewInstrumentationState(identifier: id)
      state.viewDidLoadSpanCreated = true
      viewController.instrumentationState = state

      let className = viewController.className
      let viewName = viewController.viewName

      let parentSpanName = spanNameViewLoad // Single parent span for all views

      queue.async {
        // Create parent span
        let parentSpan = self.createSpan(
          name: parentSpanName,
          viewName: viewName,
          className: className,
          startTime: now
        )

        // Create viewDidLoad child span
        let viewDidLoadSpan = self.createSpan(
          name: self.spanNameViewDidLoad,
          parent: parentSpan,
          viewName: viewName,
          className: className,
          startTime: now
        )

        self.parentSpans[id] = parentSpan
        self.viewDidLoadSpans[id] = viewDidLoadSpan
      }
    }

    func onViewDidLoadEnd(_ viewController: UIViewController, now: Date = Date()) {
      guard let id = viewController.instrumentationState?.identifier else {
        return
      }

      queue.async {
        if let span = self.viewDidLoadSpans.removeValue(forKey: id) {
          span.end(time: now)
        }
      }
    }

    func onViewWillAppearStart(_ viewController: UIViewController, now: Date = Date()) {
      guard let id = viewController.instrumentationState?.identifier else {
        return
      }

      viewController.instrumentationState?.viewWillAppearSpanCreated = true

      let className = viewController.className
      let viewName = viewController.viewName

      queue.async {
        guard let parentSpan = self.parentSpans[id] else {
          return
        }

        let span = self.createSpan(
          name: self.spanNameViewWillAppear,
          parent: parentSpan,
          viewName: viewName,
          className: className,
          startTime: now
        )

        self.viewWillAppearSpans[id] = span
      }
    }

    func onViewWillAppearEnd(_ viewController: UIViewController, now: Date = Date()) {
      guard let id = viewController.instrumentationState?.identifier else {
        return
      }

      let className = viewController.className
      let viewName = viewController.viewName

      queue.async {
        // End viewWillAppear span
        if let span = self.viewWillAppearSpans.removeValue(forKey: id) {
          span.end(time: now)
        }

        // Start viewIsAppearing span to measure animation time
        guard let parentSpan = self.parentSpans[id] else {
          return
        }

        let span = self.createSpan(
          name: self.spanNameViewIsAppearing,
          parent: parentSpan,
          viewName: viewName,
          className: className,
          startTime: now
        )

        self.viewIsAppearingSpans[id] = span
        viewController.instrumentationState?.viewIsAppearingSpanCreated = true
      }
    }

    func onViewDidAppearStart(_ viewController: UIViewController, now: Date = Date()) {
      guard let id = viewController.instrumentationState?.identifier else {
        return
      }

      viewController.instrumentationState?.viewDidAppearSpanCreated = true

      let className = viewController.className
      let viewName = viewController.viewName

      queue.async {
        guard let parentSpan = self.parentSpans[id] else {
          return
        }

        let span = self.createSpan(
          name: self.spanNameViewDidAppear,
          parent: parentSpan,
          viewName: viewName,
          className: className,
          startTime: now
        )

        self.viewDidAppearSpans[id] = span
      }
    }

    func onViewDidAppearEnd(_ viewController: UIViewController, now: Date = Date()) {
      guard let id = viewController.instrumentationState?.identifier else {
        return
      }

      let className = viewController.className
      let viewName = viewController.viewName

      queue.async {
        // End viewIsAppearing span if it exists
        if let span = self.viewIsAppearingSpans.removeValue(forKey: id) {
          span.end(time: now)
        }

        // End viewDidAppear span
        if let span = self.viewDidAppearSpans.removeValue(forKey: id) {
          span.end(time: now)
        }

        // Start visibility span
        let visibilitySpan = self.createSpan(
          name: self.spanNameViewDuration,
          viewName: viewName,
          className: className,
          startTime: now
        )

        self.visibilitySpans[id] = visibilitySpan

        guard let parentSpan = self.parentSpans[id] else {
          return
        }

        // End the parent span when viewDidAppear completes
        parentSpan.end(time: now)
        self.clearSpans(for: id)
      }
    }

    func onViewDidDisappear(_ viewController: UIViewController, now: Date = Date()) {
      guard let id = viewController.instrumentationState?.identifier else {
        return
      }

      queue.async {
        // End visibility span
        if let span = self.visibilitySpans.removeValue(forKey: id) {
          span.end(time: now)
        }

        // Force end all remaining spans
        self.endAllSpans(for: id, time: now, status: .error(description: statusViewDisappeared))
      }
    }

    // MARK: - Helper Methods

    /// Creates a span with common attributes for view controller instrumentation
    private func createSpan(name: String,
                            parent: Span? = nil,
                            viewName: String,
                            className: String,
                            startTime: Date) -> Span {
      let builder = tracer.spanBuilder(spanName: name)
        .setSpanKind(spanKind: .client)
        .setAttribute(key: attributeKeyViewName, value: viewName)
        .setAttribute(key: attributeKeyViewClass, value: className)
        .setStartTime(time: startTime)

      if let parent = parent {
        builder.setParent(parent)
      }

      return builder.startSpan()
    }

    private func endAllSpans(for id: String, time: Date, status: Status) {
      if let span = viewDidLoadSpans.removeValue(forKey: id) {
        span.status = status
        span.end(time: time)
      }

      if let span = viewWillAppearSpans.removeValue(forKey: id) {
        span.status = status
        span.end(time: time)
      }

      if let span = viewIsAppearingSpans.removeValue(forKey: id) {
        span.status = status
        span.end(time: time)
      }

      if let span = viewDidAppearSpans.removeValue(forKey: id) {
        span.status = status
        span.end(time: time)
      }

      if let span = parentSpans.removeValue(forKey: id) {
        span.status = status
        span.end(time: time)
      }

      clearSpans(for: id)
    }

    private func clearSpans(for id: String) {
      parentSpans.removeValue(forKey: id)
      viewDidLoadSpans.removeValue(forKey: id)
      viewWillAppearSpans.removeValue(forKey: id)
      viewIsAppearingSpans.removeValue(forKey: id)
      viewDidAppearSpans.removeValue(forKey: id)
    }

    private func clearAllSpans() {
      parentSpans.removeAll()
      viewDidLoadSpans.removeAll()
      viewWillAppearSpans.removeAll()
      viewIsAppearingSpans.removeAll()
      viewDidAppearSpans.removeAll()
      visibilitySpans.removeAll()
    }
  }

#endif
