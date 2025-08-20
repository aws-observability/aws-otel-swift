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
import OpenTelemetryApi

/// Internal state container for tracking SwiftUI View lifecycle events.
///
/// This class uses reference semantics to persist state across SwiftUI View updates
/// without triggering additional redraws. By using a class instead of a struct,
/// SwiftUI only observes the reference to this object, not its internal property changes,
/// preventing infinite update cycles.
///
/// ## Thread Safety
///
/// This class is not thread-safe. Ensure all access occurs on the main thread, which is
/// typical for SwiftUI View lifecycle events.
///
/// ## Architecture Note
///
/// **Important**: This must remain a `class`, not a `struct`. Converting to a struct would
/// cause SwiftUI to trigger View updates whenever properties change, leading to infinite
/// update cycles or performance issues.
@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6.0, *)
final class ViewTraceState {
  // MARK: - Initialization Tracking

  /// The timestamp when the view was first initialized
  let initializationTime = Date()

  // MARK: - Span Management

  /// The root span that contains all child spans for this view
  var rootSpan: Span?

  // MARK: - Lifecycle Counters

  /// Count of how many times the view has appeared
  var appearCount: Int = 0

  /// Count of how many times the view has disappeared
  var disappearCount: Int = 0

  // MARK: - Debugging

  /// Returns a formatted string representation of the current state.
  ///
  /// Useful for debugging and logging purposes.
  ///
  /// - Returns: A multi-line string containing all tracked metrics
  func debugDescription() -> String {
    return """
    ViewTraceState Debug Info:
    ├─ Initialize: \(initializationTime.description)
    ├─ Appear: \(appearCount) times
    ├─ Disappear: \(disappearCount) times
    └─ Root Span: \(rootSpan != nil ? "active" : "nil")
    """
  }
}
