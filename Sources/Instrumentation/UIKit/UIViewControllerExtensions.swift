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

  // MARK: - UIViewController Extensions

  extension UIViewController {
    private enum AssociatedKeys {
      static var instrumentationState: UInt8 = 0
    }

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

    private static var currentHandler: ViewControllerHandler?

    static func setInstrumentationHandler(_ handler: ViewControllerHandler) {
      currentHandler = handler
    }

    private static var instrumentationHandler: ViewControllerHandler? {
      return currentHandler
    }

    // MARK: - Installation

    /// Install view instrumentation with the provided handler
    static func installViewInstrumentation(handler: ViewControllerHandler) {
      setInstrumentationHandler(handler)
      swizzleLifecycleMethods()
    }

    private static func swizzleLifecycleMethods() {
      swizzleViewDidLoad()
      swizzleViewWillAppear()
      swizzleViewDidAppear()
      swizzleViewDidDisappear()
    }

    private static func swizzleViewDidLoad() {
      let originalSelector = #selector(UIViewController.viewDidLoad)
      let swizzledSelector = #selector(UIViewController.traceViewDidLoad)

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        print("[UIViewController] Error: Could not find viewDidLoad methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    private static func swizzleViewWillAppear() {
      let originalSelector = #selector(UIViewController.viewWillAppear(_:))
      let swizzledSelector = #selector(UIViewController.traceViewWillAppear(_:))

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        print("[UIViewController] Error: Could not find viewWillAppear methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    private static func swizzleViewDidAppear() {
      let originalSelector = #selector(UIViewController.viewDidAppear(_:))
      let swizzledSelector = #selector(UIViewController.traceViewDidAppear(_:))

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        print("[UIViewController] Error: Could not find viewDidAppear methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    private static func swizzleViewDidDisappear() {
      let originalSelector = #selector(UIViewController.viewDidDisappear(_:))
      let swizzledSelector = #selector(UIViewController.traceViewDidDisappear(_:))

      guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else {
        print("[UIViewController] Error: Could not find viewDidDisappear methods for swizzling")
        return
      }

      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    var viewName: String {
      if let customized = self as? ViewControllerCustomization,
         let customName = customized.customViewName {
        return customName
      }

      return className
    }

    func shouldCaptureView(using uiKitViewInstrumentation: UIKitViewInstrumentation) -> Bool {
      // First check if the view controller explicitly opts out via customization
      if let customized = self as? ViewControllerCustomization {
        return customized.shouldCaptureView
      }

      // Apply bundle filtering to exclude system/framework view controllers
      return shouldCaptureViewBasedOnBundle(using: uiKitViewInstrumentation)
    }

    /// Determines if a view controller should be captured based on its bundle path.
    /// Only captures view controllers that belong to the main app bundle,
    /// filtering out system UIKit and SwiftUI framework controllers.
    func shouldCaptureViewBasedOnBundle(using uiKitViewInstrumentation: UIKitViewInstrumentation) -> Bool {
      let viewControllerClass = type(of: self)
      let viewControllerBundlePath = Bundle(for: viewControllerClass).bundlePath

      // Only instrument view controllers from the main app bundle
      // This excludes system controllers like NotifyingMulticolumnSplitViewController
      return viewControllerBundlePath.contains(uiKitViewInstrumentation.bundlePath)
    }

    var className: String {
      return String(describing: type(of: self))
    }

    // MARK: - Swizzled Method Implementations

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
