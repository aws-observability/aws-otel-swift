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

import SwiftUI

/**
 * Entry point view responsible for initializing AWS and passing dependencies to child views.
 *
 * Displays a progress indicator while initializing, an error message on failure,
 * or the main content on successful AWS setup.
 */
@MainActor
struct LoaderView: View {
  @StateObject private var viewModel: LoaderViewModel

  /// Initializes the loader
  init() {
    _viewModel = StateObject(wrappedValue: LoaderViewModel())
  }

  var body: some View {
    ContentView(viewModel: viewModel)
  }
}
