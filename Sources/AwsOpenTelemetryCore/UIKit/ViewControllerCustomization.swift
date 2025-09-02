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

  /**
   * Protocol for customizing automatic UIKit view controller instrumentation.
   *
   * Implement this protocol on your view controllers to control how they are
   * instrumented by the AWS OpenTelemetry SDK. This allows you to:
   *
   * - Provide custom names for better observability
   * - Opt out of instrumentation for specific view controllers
   * - Override default instrumentation behavior
   *
   * ## Default Behavior
   *
   * If you don't implement this protocol, the instrumentation will:
   * - Use the view controller's class name as the span name
   * - Automatically instrument all view controllers from your app bundle
   * - Apply standard filtering rules (system VCs are excluded)
   */
  public protocol ViewControllerCustomization {
    /**
     * Optional custom name for the view controller in telemetry spans.
     *
     * When provided, this name will be used instead of the class name for
     * span names and the `view.name` attribute. This is useful for:
     *
     * - Providing user-friendly names (e.g., "Login Screen" vs "LoginViewController")
     * - Grouping similar view controllers under a common name
     * - Maintaining consistent naming across different implementations
     *
     * @return A custom name for telemetry, or nil to use the class name
     */
    var customScreenName: String? { get }

    /**
     * Whether this view controller should be included in telemetry.
     *
     * Return `false` to completely opt out of instrumentation for this
     * view controller. This is useful for:
     *
     * - Debug or development-only view controllers
     * - View controllers that contain sensitive information
     * - Temporary or transitional view controllers
     * - View controllers with very short lifecycles
     *
     * @return `true` to enable instrumentation, `false` to disable it
     */
    var shouldCaptureView: Bool { get }
  }

  /**
   * Default implementation providing sensible defaults for optional protocol methods.
   *
   * These defaults ensure that view controllers work correctly even if they
   * only partially implement the ViewControllerCustomization protocol.
   */
  public extension ViewControllerCustomization where Self: UIViewController {
    /// Default: Use the class name for telemetry
    var customScreenName: String? { nil }

    /// Default: Enable instrumentation for all view controllers
    var shouldCaptureView: Bool { true }
  }

#endif
