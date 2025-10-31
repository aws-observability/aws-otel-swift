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

#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import MetricKit

  /**
   * Filters MXCallStackTree to specified depth per thread.
   *
   * @param callStackTree The call stack tree to filter to address size limits.
   * @param maxDepth Maximum depth of frames per thread (default: 5)
   * @return Filtered JSON string or nil if filtering fails
   */
  @available(iOS 15.0, *)
  public func filterCallStackDepth(_ callStackTree: MXCallStackTree, maxDepth: Int = 5) -> String? {
    let jsonData = callStackTree.jsonRepresentation()
    guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          var callStacks = jsonObject["callStacks"] as? [[String: Any]] else {
      return nil
    }

    for i in 0 ..< callStacks.count {
      if let rootFrames = callStacks[i]["callStackRootFrames"] as? [[String: Any]] {
        callStacks[i]["callStackRootFrames"] = rootFrames.map { frame in
          filterFrameDepth(frame, currentDepth: 0, maxDepth: maxDepth)
        }
      }
    }

    var filteredJson = jsonObject
    filteredJson["callStacks"] = callStacks

    guard let filteredData = try? JSONSerialization.data(withJSONObject: filteredJson),
          let filteredString = String(data: filteredData, encoding: .utf8) else {
      return nil
    }

    return filteredString
  }

  private func filterFrameDepth(_ frame: [String: Any], currentDepth: Int, maxDepth: Int) -> [String: Any] {
    var filteredFrame = frame

    if currentDepth >= maxDepth {
      if frame["subFrames"] != nil {
        filteredFrame["exceededMaxDepth"] = true
      }
      filteredFrame.removeValue(forKey: "subFrames")
    } else if let subFrames = frame["subFrames"] as? [[String: Any]] {
      filteredFrame["subFrames"] = subFrames.map { subFrame in
        filterFrameDepth(subFrame, currentDepth: currentDepth + 1, maxDepth: maxDepth)
      }
    }

    return filteredFrame
  }

#endif
