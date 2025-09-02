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
  import ObjectiveC.runtime

  /**
   * UIViewController extensions for automatic OpenTelemetry instrumentation.
   *
   * These extensions enable automatic instrumentation of UIViewController lifecycle methods
   * by using method swizzling to intercept key lifecycle events and create OpenTelemetry spans.
   * The implementation handles edge cases like recursive calls and maintains proper
   * span hierarchies for accurate performance tracking.
   *
   */
  extension UIViewController {
    /**
     * Keys for associated objects used to store instrumentation state.
     * Uses UInt8 values as recommended by Apple for associated object keys.
     */
    private enum AssociatedKeys {
      /// Key for storing the ViewInstrumentationState associated object
      static var instrumentationState: UInt8 = 0
    }

    /**
     * The instrumentation state for this view controller instance.
     *
     * This property stores state information about which lifecycle spans have been created
     * for this view controller instance. It's stored as an associated object to avoid
     * subclassing UIViewController or modifying its memory layout.
     *
     * The state is automatically created during the first instrumented lifecycle event
     * and is used to prevent duplicate span creation if methods are called multiple times.
     */
    var instrumentationState: ViewInstrumentationState? {
      get {
        return objc_getAssociatedObject(self, &AssociatedKeys.instrumentationState) as? ViewInstrumentationState
      }
      set {
        objc_setAssociatedObject(
          self,
          &AssociatedKeys.instrumentationState,
          newValue,
          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
      }
    }

    /**
     * Shared handler for processing view controller lifecycle events.
     * Stored as a static property to avoid creating multiple handlers.
     */
    private static var currentHandler: ViewControllerHandler?

    /**
     * Sets the instrumentation handler for all view controllers.
     *
     * This method is called during installation to configure the handler that will
     * process lifecycle events and create spans. The handler is shared across all
     * view controller instances to maintain consistent span hierarchies.
     *
     * @param handler The ViewControllerHandler to use for span creation
     */
    static func setInstrumentationHandler(_ handler: ViewControllerHandler) {
      currentHandler = handler
    }

    /**
     * Retrieves the current instrumentation handler.
     * Used internally by swizzled methods to access the handler.
     */
    private static var instrumentationHandler: ViewControllerHandler? {
      return currentHandler
    }

    // MARK: - Installation

    /**
     * Installs view instrumentation with the provided handler.
     *
     * This method performs the necessary setup to enable automatic instrumentation
     * of UIViewController lifecycle methods. It configures the handler and performs
     * method swizzling to intercept lifecycle events.
     *
     * @param handler The ViewControllerHandler to use for span creation
     */
    static func installViewInstrumentation(handler: ViewControllerHandler) {
      setInstrumentationHandler(handler)
      swizzleLifecycleMethods()
    }

    /**
     * Swizzles all UIViewController lifecycle methods for instrumentation.
     *
     * This method exchanges the implementations of standard UIViewController lifecycle
     * methods with custom implementations that create spans before and after the
     * original method execution.
     */
    private static func swizzleLifecycleMethods() {
      swizzleViewDidLoad()
      swizzleViewWillAppear()
      swizzleViewDidAppear()
      swizzleViewDidDisappear()
    }

    /**
     * Swizzles the viewDidLoad method for instrumentation.
     *
     * This method exchanges the implementation of viewDidLoad with traceViewDidLoad,
     * which creates spans before and after the original method execution.
     */
    private static func swizzleViewDidLoad() {
      let originalSelector = #selector(UIViewController.viewDidLoad)
      let swizzledSelector = #selector(UIViewController.traceViewDidLoad)

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        AwsOpenTelemetryLogger.error("[UIViewController] Error: Could not find viewDidLoad methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /**
     * Swizzles the viewWillAppear method for instrumentation.
     *
     * This method exchanges the implementation of viewWillAppear with traceViewWillAppear,
     * which creates spans before and after the original method execution.
     */
    private static func swizzleViewWillAppear() {
      let originalSelector = #selector(UIViewController.viewWillAppear(_:))
      let swizzledSelector = #selector(UIViewController.traceViewWillAppear(_:))

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        AwsOpenTelemetryLogger.error("[UIViewController] Error: Could not find viewWillAppear methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /**
     * Swizzles the viewDidAppear method for instrumentation.
     *
     * This method exchanges the implementation of viewDidAppear with traceViewDidAppear,
     * which creates spans before and after the original method execution.
     */
    private static func swizzleViewDidAppear() {
      let originalSelector = #selector(UIViewController.viewDidAppear(_:))
      let swizzledSelector = #selector(UIViewController.traceViewDidAppear(_:))

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        AwsOpenTelemetryLogger.error("[UIViewController] Error: Could not find viewDidAppear methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /**
     * Swizzles the viewDidDisappear method for instrumentation.
     *
     * This method exchanges the implementation of viewDidDisappear with traceViewDidDisappear,
     * which creates spans before and after the original method execution.
     */
    private static func swizzleViewDidDisappear() {
      let originalSelector = #selector(UIViewController.viewDidDisappear(_:))
      let swizzledSelector = #selector(UIViewController.traceViewDidDisappear(_:))

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        AwsOpenTelemetryLogger.error("[UIViewController] Error: Could not find viewDidDisappear methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /**
     * Returns the name to use for this view controller in telemetry spans.
     *
     * This property returns either a custom name provided by the ViewControllerCustomization
     * protocol or falls back to the class name if no custom name is provided.
     *
     * Custom names are useful for:
     * - Providing user-friendly names in telemetry
     * - Grouping similar view controllers under a common name
     * - Maintaining consistent naming across different implementations
     *
     * @return The name to use for this view controller in telemetry spans
     */
    var screenName: String {
      if let customized = self as? ViewControllerCustomization,
         let customName = customized.customScreenName {
        return customName
      }

      return className
    }

    /**
     * Determines if this view controller should be included in telemetry.
     *
     * This method checks if the view controller should be instrumented based on:
     * 1. Whether it implements ViewControllerCustomization and opts out
     * 2. Whether it belongs to the application bundle (vs. system frameworks)
     *
     * @param uiKitViewInstrumentation The instrumentation instance for bundle path comparison
     * @return true if the view controller should be instrumented, false otherwise
     */
    func shouldCaptureView(using uiKitViewInstrumentation: UIKitViewInstrumentation) -> Bool {
      // First check if the view controller explicitly opts out via customization
      if let customized = self as? ViewControllerCustomization {
        return customized.shouldCaptureView
      }

      // Apply bundle filtering to exclude system/framework view controllers
      return shouldCaptureViewBasedOnBundle(using: uiKitViewInstrumentation)
    }

    /**
     * Determines if a view controller should be captured based on its bundle path.
     *
     * This method filters out system view controllers by checking if the view controller's
     * bundle path matches the application bundle path. This prevents instrumentation of
     * system components like UINavigationController, UITabBarController, etc.
     *
     * @param uiKitViewInstrumentation The instrumentation instance for bundle path comparison
     * @return true if the view controller belongs to the application bundle, false otherwise
     */
    func shouldCaptureViewBasedOnBundle(using uiKitViewInstrumentation: UIKitViewInstrumentation) -> Bool {
      let viewControllerClass = type(of: self)
      let viewControllerBundlePath = Bundle(for: viewControllerClass).bundlePath

      // Only instrument view controllers from the main app bundle
      // This excludes system controllers like NotifyingMulticolumnSplitViewController
      return viewControllerBundlePath.contains(uiKitViewInstrumentation.bundlePath)
    }

    /**
     * Returns the class name of this view controller.
     *
     * This property returns the runtime class name of the view controller,
     * which is used as a fallback for the view name if no custom name is provided.
     *
     * @return The class name of this view controller
     */
    var className: String {
      return String(describing: type(of: self))
    }

    // MARK: - Swizzled Method Implementations

    /**
     * Swizzled implementation of viewDidLoad that creates spans.
     *
     * This method is called instead of the original viewDidLoad method when
     * method swizzling is installed. It creates spans before and after calling
     * the original implementation to measure the execution time.
     *
     * The implementation handles recursive calls and prevents duplicate
     * span creation by checking the instrumentation state.
     */
    @objc func traceViewDidLoad() {
      // Get handler directly without singleton
      if let handler = UIViewController.instrumentationHandler {
        // Prevent duplicate instrumentation
        if let state = instrumentationState, state.viewDidLoadSpanCreated {
          traceViewDidLoad() // Call original implementation
          return
        }

        // Start span, call original, end span
        handler.onViewDidLoadStart(self)
        traceViewDidLoad() // Call original implementation
        handler.onViewDidLoadEnd(self)
      } else {
        traceViewDidLoad() // Call original implementation
      }
    }

    /**
     * Swizzled implementation of viewWillAppear that creates spans.
     *
     * This method is called instead of the original viewWillAppear method when
     * method swizzling is installed. It creates spans before and after calling
     * the original implementation to measure the execution time.
     *
     * The implementation handles recursive calls and prevents duplicate
     * span creation by checking the instrumentation state.
     *
     * @param animated Whether the appearance is animated
     */
    @objc func traceViewWillAppear(_ animated: Bool) {
      if let handler = UIViewController.instrumentationHandler {
        // Prevent duplicate instrumentation
        if let state = instrumentationState, state.viewWillAppearSpanCreated {
          traceViewWillAppear(animated) // Call original implementation
          return
        }

        // Start span, call original, end span
        handler.onViewWillAppearStart(self)
        traceViewWillAppear(animated) // Call original implementation
        handler.onViewWillAppearEnd(self)
      } else {
        traceViewWillAppear(animated) // Call original implementation
      }
    }

    /**
     * Swizzled implementation of viewDidAppear that creates spans.
     *
     * This method is called instead of the original viewDidAppear method when
     * method swizzling is installed. It creates spans before and after calling
     * the original implementation to measure the execution time.
     *
     * The implementation handles recursive calls and prevents duplicate
     * span creation by checking the instrumentation state.
     *
     * @param animated Whether the appearance is animated
     */
    @objc func traceViewDidAppear(_ animated: Bool) {
      if let handler = UIViewController.instrumentationHandler {
        // Prevent duplicate instrumentation
        if let state = instrumentationState, state.viewDidAppearSpanCreated {
          traceViewDidAppear(animated) // Call original implementation
          return
        }

        // Start span, call original, end span
        handler.onViewDidAppearStart(self)
        traceViewDidAppear(animated) // Call original implementation
        handler.onViewDidAppearEnd(self)
      } else {
        traceViewDidAppear(animated) // Call original implementation
      }
    }

    /**
     * Swizzled implementation of viewDidDisappear that creates spans.
     *
     * This method is called instead of the original viewDidDisappear method when
     * method swizzling is installed. Unlike the other lifecycle methods, this one
     * only creates a single notification rather than start/end spans.
     *
     * The implementation ensures that visibility spans are properly ended when
     * the view disappears.
     *
     * @param animated Whether the disappearance is animated
     */
    @objc func traceViewDidDisappear(_ animated: Bool) {
      if let handler = UIViewController.instrumentationHandler {
        // Call handler (viewDidDisappear only has one method, not start/end)
        handler.onViewDidDisappear(self)
        traceViewDidDisappear(animated) // Call original implementation
      } else {
        traceViewDidDisappear(animated) // Call original implementation
      }
    }
  }

#endif
