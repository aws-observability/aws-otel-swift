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

enum AwsViewType: String, CaseIterable {
  case uikit
  case swiftui
}

class AwsView {
  static let screenName = "screen.name"
  static let type = "app.screen.type"
}

class AwsViewDidAppear: AwsView {
  static let name = "app.screen.view_did_appear"
  static let interaction = "app.screen.interaction"
  static let parentName = "app.screen.parent_screen.name"
}

class AwsTimeToFirstAppear: AwsView {
  static let name = "app.screen.time_to_first_appear"
}
