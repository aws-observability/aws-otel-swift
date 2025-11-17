#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
  import XCTest
  import MetricKit
  @testable import AwsOpenTelemetryCore

  @available(iOS 15.0, *)
  final class StringUtilsTests: XCTestCase {
    func testFilterCallStackDepthLimitsDeepStack() {
      let mockCallStackTree = MockMXCallStackTreeWithDeepStack()
      let result = filterCallStackDepth(mockCallStackTree, maxDepth: 3)

      guard let resultData = result?.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any],
            let callStacks = json["callStacks"] as? [[String: Any]],
            let firstThread = callStacks.first,
            let rootFrames = firstThread["callStackRootFrames"] as? [[String: Any]] else {
        XCTFail("Failed to parse result")
        return
      }

      // Verify exact depth limit: root + 3 levels = 4 total
      var frame = rootFrames[0]
      for depth in 0 ..< 3 {
        XCTAssertNotNil(frame["subFrames"], "Should have subFrames at depth \(depth)")
        frame = (frame["subFrames"] as! [[String: Any]])[0]
      }
      XCTAssertNil(frame["subFrames"], "Should not have subFrames beyond depth 3")
      XCTAssertEqual(frame["exceededMaxDepth"] as? Bool, true, "Should mark frame as exceeding max depth")
    }

    func testFilterCallStackDepthHandlesInvalidJSON() {
      XCTAssertNil(filterCallStackDepth(MockMXCallStackTreeWithInvalidJSON()))
    }

    func testFilterCallStackDepthHandlesEmptyStack() {
      XCTAssertNotNil(filterCallStackDepth(MockMXCallStackTreeWithEmptyStack()))
    }

    func testFilterCallStackDepthHandlesZeroDepth() {
      let result = filterCallStackDepth(MockMXCallStackTreeWithDeepStack(), maxDepth: 0)
      guard let data = result?.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let callStacks = json["callStacks"] as? [[String: Any]],
            let rootFrames = callStacks[0]["callStackRootFrames"] as? [[String: Any]] else {
        XCTFail("Failed to parse zero depth result")
        return
      }
      XCTAssertNil(rootFrames[0]["subFrames"], "Zero depth should remove all subFrames")
      XCTAssertEqual(rootFrames[0]["exceededMaxDepth"] as? Bool, true, "Should mark root frame as exceeding max depth")
    }

    func testFilterCallStackDepthPreservesFrameData() {
      let result = filterCallStackDepth(MockMXCallStackTreeWithDeepStack(), maxDepth: 2)

      guard let data = result?.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let callStacks = json["callStacks"] as? [[String: Any]] else {
        XCTFail("Failed to parse result")
        return
      }

      // Verify all frame attributes are preserved
      let rootFrame = (callStacks[0]["callStackRootFrames"] as! [[String: Any]])[0]
      XCTAssertEqual(rootFrame["binaryName"] as? String, "TestApp")
      XCTAssertEqual(rootFrame["address"] as? Int, 4295000000)
      XCTAssertEqual(rootFrame["sampleCount"] as? Int, 1)

      // Verify multiple threads preserved
      XCTAssertEqual(callStacks.count, 2)
      XCTAssertEqual(callStacks[1]["threadAttributed"] as? Bool, false)

      // Verify exceededMaxDepth is set on truncated frame
      let secondLevelFrame = (rootFrame["subFrames"] as! [[String: Any]])[0]
      let thirdLevelFrame = (secondLevelFrame["subFrames"] as! [[String: Any]])[0]
      XCTAssertEqual(thirdLevelFrame["exceededMaxDepth"] as? Bool, true, "Should mark truncated frame")
    }
  }

  @available(iOS 15.0, *)
  private class MockMXCrashDiagnosticWithDeepStack: MXCrashDiagnostic {
    override var callStackTree: MXCallStackTree { MockMXCallStackTreeWithDeepStack() }
  }

  @available(iOS 15.0, *)
  private class MockMXCrashDiagnosticWithInvalidJSON: MXCrashDiagnostic {
    override var callStackTree: MXCallStackTree { MockMXCallStackTreeWithInvalidJSON() }
  }

  @available(iOS 15.0, *)
  private class MockMXCrashDiagnosticWithEmptyStack: MXCrashDiagnostic {
    override var callStackTree: MXCallStackTree { MockMXCallStackTreeWithEmptyStack() }
  }

  @available(iOS 15.0, *)
  private class MockMXCallStackTreeWithDeepStack: MXCallStackTree {
    override func jsonRepresentation() -> Data {
      Data("""
      {"callStacks":[{"threadAttributed":true,"callStackRootFrames":[{"binaryName":"TestApp","address":4295000000,"sampleCount":1,"subFrames":[{"address":4295000001,"subFrames":[{"address":4295000002,"subFrames":[{"address":4295000003,"subFrames":[{"address":4295000004,"subFrames":[{"address":4295000005}]}]}]}]}]}]},{"threadAttributed":false,"callStackRootFrames":[{"binaryName":"Foundation","address":4296000000}]}]}
      """.utf8)
    }
  }

  @available(iOS 15.0, *)
  private class MockMXCallStackTreeWithInvalidJSON: MXCallStackTree {
    override func jsonRepresentation() -> Data { Data("invalid".utf8) }
  }

  @available(iOS 15.0, *)
  private class MockMXCallStackTreeWithEmptyStack: MXCallStackTree {
    override func jsonRepresentation() -> Data { Data("{\"callStacks\":[]}".utf8) }
  }
#endif
