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

/**
 * Tracks the instrumentation state for individual view controller instances.
 *
 * This class maintains the state of span creation for each view controller lifecycle
 * event to prevent duplicate span creation and ensure proper instrumentation flow.
 * Each view controller instance gets its own state object stored as an associated object.
 *
 * ## Purpose
 *
 * - **Duplicate Prevention**: Ensures each lifecycle event creates only one span
 * - **State Tracking**: Maintains which lifecycle events have been instrumented
 * - **Debugging Support**: Provides identifier for troubleshooting instrumentation issues
 * - **Memory Management**: Automatically cleaned up when view controller is deallocated
 *
 * ## Lifecycle Tracking
 *
 * The state tracks span creation for these lifecycle events:
 * - `viewDidLoad` - Initial view setup
 * - `viewWillAppear` - Pre-appearance preparation
 * - `viewIsAppearing` - Appearance animation (iOS 13+)
 * - `viewDidAppear` - View fully visible
 * - `viewDidDisappear` - View no longer visible
 *
 * ## Usage
 *
 * This class is used internally by the instrumentation system and should not
 * be instantiated directly by application code. It's automatically created
 * and managed by the `UIViewControllerExtensions`.
 */
class ViewInstrumentationState: NSObject {
  /// Optional identifier for debugging and troubleshooting
  /// Typically set to the view controller's class name or custom name
  var identifier: String?

  /// Tracks whether a span has been created for viewDidLoad
  var viewDidLoadSpanCreated = false

  /// Tracks whether a span has been created for viewWillAppear
  var viewWillAppearSpanCreated = false

  /// Tracks whether a span has been created for viewIsAppearing (iOS 13+)
  var viewIsAppearingSpanCreated = false

  /// Tracks whether a span has been created for viewDidAppear
  var viewDidAppearSpanCreated = false

  /// Tracks whether a span has been created for viewDidDisappear
  var viewDidDisappearSpanCreated = false

  /**
   * Creates a new instrumentation state instance.
   *
   * @param identifier Optional identifier for debugging purposes
   */
  init(identifier: String? = nil) {
    self.identifier = identifier
  }
}
