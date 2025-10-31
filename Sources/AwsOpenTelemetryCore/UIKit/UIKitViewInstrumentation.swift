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
  import ObjectiveC.runtime

  /**
   * Main orchestrator for automatic UIKit view controller lifecycle instrumentation.
   * UIKitViewInstrumentation is automatically created and installed when the AWS OpenTelemetry SDK
   * is initialized with UIKit instrumentation enabled (default behavior).
   *
   * This class provides comprehensive instrumentation of UIViewController lifecycle events,
   * automatically creating OpenTelemetry spans to track view performance and user navigation
   * patterns without requiring manual instrumentation code.
   *
   * For advanced use cases, you can create and configure the instrumentation manually.
   * View controllers can implement `ViewControllerCustomization`
   * to control instrumentation.
   */

  public final class UIKitViewInstrumentation {
    /// The handler responsible for processing view controller lifecycle events
    /// This component manages the actual span creation and lifecycle tracking
    let handler: ViewControllerHandler

    /// The bundle path used for filtering view controllers
    /// Only view controllers from this bundle path will be instrumented by default
    let bundlePath: String

    /// Thread synchronization lock for installation state
    /// Ensures thread-safe installation and prevents duplicate method swizzling
    private let lock: NSLock

    /// Flag indicating whether method swizzling has been installed
    /// Prevents duplicate installation which could cause runtime issues
    private var isInstalled = false

    /**
     * Creates a new UIKit instrumentation instance with the main bundle.
     *
     * This convenience initializer uses the main application bundle for filtering,
     * which is appropriate for most applications.
     *
     * @param tracer The OpenTelemetry tracer to use for span creation
     */
    public convenience init() {
      self.init(
        bundle: .main
      )
    }

    /**
     * Creates a new UIKit instrumentation instance with a specific bundle.
     *
     * This initializer allows you to specify a custom bundle for filtering
     * view controllers. Only view controllers from the specified bundle
     * will be instrumented by default.
     *
     * @param bundle The bundle to use for filtering view controllers
     */
    init(bundle: Bundle) {
      bundlePath = bundle.bundlePath
      lock = NSLock()
      handler = ViewControllerHandler()

      // Set the circular reference after initialization to enable parent span lookup
      handler.setUIKitViewInstrumentation(self)
    }

    /**
     * Installs the UIKit view controller instrumentation.
     *
     * This method performs runtime method swizzling to intercept UIViewController
     * lifecycle methods and automatically create OpenTelemetry spans. The installation
     * is thread-safe and idempotent - calling it multiple times has no additional effect.
     *
     * ## What Gets Installed
     *
     * - Method swizzling for `viewDidLoad` and `viewDidAppear`
     * - Static handler registration for span management
     * - Bundle-based filtering for automatic view controller detection
     */
    public func install() {
      lock.lock()
      defer { lock.unlock() }

      guard !isInstalled else {
        AwsInternalLogger.debug("[UIKitViewInstrumentation] Already installed")
        return
      }

      // Install method swizzling for view controller lifecycle methods
      UIViewController.installViewInstrumentation(handler: handler)

      isInstalled = true
      AwsInternalLogger.debug("[UIKitViewInstrumentation] Successfully installed view instrumentation")
    }
  }

#endif
