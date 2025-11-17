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

enum AwsExceptionType: String, CaseIterable {
  case crash
  case hang

  // coming soon:
  // 1. jitter
  // 2. anr
}

public class AwsExceptionSemConv {
  static let message = "exception.message"
  static let type = "exception.type"
  static let stacktrace = "exception.stacktrace"

  // in-house utility field for context recovery
  // when true, then the following fields are recovered
  // 1. `session.id`
  // 2. `session.previous_id`
  // 3. `screen.name`
  // 4. `user.id`
  // 5. original timestamp
  static let recoveredContext = "recovered_context"
}

public class AwsCrashSemConv: AwsExceptionSemConv {
  static let name = "device.crash"
}
