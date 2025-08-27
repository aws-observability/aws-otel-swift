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

import XCTest
@testable import AwsOpenTelemetryCore
import Atomics

#if canImport(UIKit) && !os(watchOS)
  import UIKit
  import OpenTelemetryApi
  import OpenTelemetrySdk

  /**
   * Test view controller that conforms to ViewControllerCustomization
   */
  class TestViewController: UIViewController, ViewControllerCustomization {
    var customViewName: String?

    // Implement the protocol method directly, don't override
    var shouldCaptureView: Bool { return true }
  }

  /**
   * Test view controller that opts out of instrumentation
   */
  class OptOutViewController: UIViewController, ViewControllerCustomization {
    var customViewName: String?

    // Implement the protocol method directly, don't override
    var shouldCaptureView: Bool { return false }
  }

  /**
   * Tests for ViewControllerHandler that verify that spans are actually created with correct attributes.
   */
  final class ViewControllerHandlerTests: XCTestCase {
    // MARK: - Test Constants

    // Service and resource attributes
    private static let testServiceName = "test-service"
    private static let testServiceVersion = "1.0.0"
    private static let testAwsRegion = "us-west-2"
    private static let testAppMonitorId = "test-app-monitor"
    private static let testInstrumentationName = "test-instrumentation"
    private static let testInstrumentationVersion = "1.0.0"

    // Span names
    private static let spanNameViewLoad = "view.load"
    private static let spanNameViewDuration = "view.duration"
    private static let spanNameViewDidLoad = "viewDidLoad"
    private static let spanNameViewWillAppear = "viewWillAppear"
    private static let spanNameViewIsAppearing = "viewIsAppearing"
    private static let spanNameViewDidAppear = "viewDidAppear"

    // Attribute keys
    private static let attributeKeyServiceName = "service.name"
    private static let attributeKeyServiceVersion = "service.version"
    private static let attributeKeyAwsRegion = "aws.region"
    private static let attributeKeyAppMonitorId = "rum.app_monitor_id"
    private static let attributeKeyViewName = "view.name"
    private static let attributeKeyViewClass = "view.class"

    // View controller class names
    private static let testViewControllerClassName = "TestViewController"
    private static let customViewControllerClassName = "CustomViewController"

    // Test timeouts and expectations
    private static let defaultTimeout: TimeInterval = 2.0
    private static let minimumSpanDuration: TimeInterval = 0.1
    private static let concurrentTestTimeout: TimeInterval = 5.0
    private static let concurrentOperationCount = 10

    // MARK: - Test Properties

    var mockSpanProcessor: MockSpanProcessor!
    var tracerProvider: TracerProviderSdk!
    var tracer: Tracer!
    var handler: ViewControllerHandler!
    var uiKitViewInstrumentation: UIKitViewInstrumentation!

    override func setUp() {
      super.setUp()

      // Set up OpenTelemetry components with mock span processor
      mockSpanProcessor = MockSpanProcessor()

      // Create a test resource with sample attributes
      let testResource = Resource(attributes: [
        Self.attributeKeyServiceName: AttributeValue.string(Self.testServiceName),
        Self.attributeKeyServiceVersion: AttributeValue.string(Self.testServiceVersion),
        Self.attributeKeyAwsRegion: AttributeValue.string(Self.testAwsRegion),
        Self.attributeKeyAppMonitorId: AttributeValue.string(Self.testAppMonitorId)
      ])

      tracerProvider = TracerProviderBuilder()
        .add(spanProcessor: mockSpanProcessor)
        .with(resource: testResource)
        .build()

      tracer = tracerProvider.get(instrumentationName: Self.testInstrumentationName)

      // Create a UIKitViewInstrumentation with the test bundle to allow test view controllers
      let testBundle = Bundle(for: type(of: self))
      uiKitViewInstrumentation = UIKitViewInstrumentation(tracer: tracer, bundle: testBundle)

      // Get the handler from UIKitViewInstrumentation (it's created internally now)
      handler = uiKitViewInstrumentation.handler
    }

    override func tearDown() {
      mockSpanProcessor.reset()
      tracerProvider.shutdown()
      handler = nil
      uiKitViewInstrumentation = nil
      tracer = nil
      tracerProvider = nil
      mockSpanProcessor = nil
      super.tearDown()
    }

    func testSpansHaveResourceAttributes() {
      let viewController = TestViewController()

      // Start and end a complete lifecycle
      handler.onViewDidLoadStart(viewController)
      handler.onViewDidLoadEnd(viewController)

      // Wait for spans to be created
      wait(timeout: Self.defaultTimeout) {
        let spans = self.mockSpanProcessor.getStartedSpans()
        return !spans.isEmpty
      }

      let spans = mockSpanProcessor.getStartedSpans()
      XCTAssertFalse(spans.isEmpty, "Should have created spans")

      // Check that all spans have the expected resource attributes
      for span in spans {
        let resource = span.resource
        XCTAssertNotNil(resource, "Span should have resource")

        // Verify key resource attributes
        XCTAssertEqual(resource.attributes[Self.attributeKeyServiceName]?.description, Self.testServiceName)
        XCTAssertEqual(resource.attributes[Self.attributeKeyAwsRegion]?.description, Self.testAwsRegion)
        XCTAssertEqual(resource.attributes[Self.attributeKeyAppMonitorId]?.description, Self.testAppMonitorId)
      }
    }

    func testViewDidLoadSpanCreation() {
      let viewController = TestViewController()

      handler.onViewDidLoadStart(viewController)

      // Wait for spans to be created
      wait(timeout: Self.defaultTimeout) {
        let startedSpans = self.mockSpanProcessor.getStartedSpans()
        let spanNames = startedSpans.map(\.name)
        return spanNames.contains(Self.spanNameViewLoad) && spanNames.contains(Self.spanNameViewDidLoad)
      }

      let startedSpans = mockSpanProcessor.getStartedSpans()
      let spanNames = startedSpans.map(\.name)

      XCTAssertTrue(spanNames.contains(Self.spanNameViewDidLoad), "Should create viewDidLoad span")
      XCTAssertTrue(spanNames.contains(Self.spanNameViewLoad), "Should create parent view.load span")

      // Check span attributes
      let viewDidLoadSpan = startedSpans.first { $0.name == Self.spanNameViewDidLoad }
      XCTAssertNotNil(viewDidLoadSpan, "viewDidLoad span should exist")
      if let span = viewDidLoadSpan {
        XCTAssertEqual(span.attributes[Self.attributeKeyViewName]?.description, Self.testViewControllerClassName)
        XCTAssertEqual(span.attributes[Self.attributeKeyViewClass]?.description, Self.testViewControllerClassName)
      }
    }

    func testViewDidLoadSpanEnding() {
      let viewController = TestViewController()

      handler.onViewDidLoadStart(viewController)
      handler.onViewDidLoadEnd(viewController)

      // Wait for spans to be ended
      wait(timeout: Self.defaultTimeout) {
        let endedSpans = self.mockSpanProcessor.getEndedSpans()
        return endedSpans.contains { $0.name == Self.spanNameViewDidLoad }
      }

      let endedSpans = mockSpanProcessor.getEndedSpans()

      XCTAssertTrue(endedSpans.contains { $0.name == Self.spanNameViewDidLoad }, "viewDidLoad span should be ended")
    }

    func testCompleteViewControllerLifecycle() {
      let viewController = TestViewController()

      // Simulate complete lifecycle
      handler.onViewDidLoadStart(viewController)
      handler.onViewDidLoadEnd(viewController)
      handler.onViewWillAppearStart(viewController)
      handler.onViewWillAppearEnd(viewController)
      handler.onViewDidAppearStart(viewController)
      handler.onViewDidAppearEnd(viewController)

      // Wait for all lifecycle spans to be created
      wait(timeout: Self.defaultTimeout) {
        let startedSpans = self.mockSpanProcessor.getStartedSpans()
        let spanNames = startedSpans.map(\.name)
        return spanNames.contains(Self.spanNameViewDidLoad) &&
          spanNames.contains(Self.spanNameViewWillAppear) &&
          spanNames.contains(Self.spanNameViewDidAppear)
      }

      // Wait for view.duration span to be created
      wait(timeout: Self.defaultTimeout) {
        let startedSpans = self.mockSpanProcessor.getStartedSpans()
        let spanNames = startedSpans.map(\.name)
        return spanNames.contains(Self.spanNameViewDuration)
      }

      let startedSpans = mockSpanProcessor.getStartedSpans()
      let endedSpans = mockSpanProcessor.getEndedSpans()
      let startedSpanNames = startedSpans.map(\.name)
      let endedSpanNames = endedSpans.map(\.name)

      XCTAssertTrue(endedSpanNames.contains(Self.spanNameViewDidLoad), "Should create viewDidLoad span")
      XCTAssertTrue(endedSpanNames.contains(Self.spanNameViewWillAppear), "Should create viewWillAppear span")
      XCTAssertTrue(endedSpanNames.contains(Self.spanNameViewIsAppearing), "Should create viewIsAppearing span")
      XCTAssertTrue(endedSpanNames.contains(Self.spanNameViewDidAppear), "Should create viewDidAppear span")
      XCTAssertTrue(startedSpanNames.contains(Self.spanNameViewDuration), "Should create view.duration span")
    }

    func testSpanHierarchy() {
      let viewController = TestViewController()

      handler.onViewDidLoadStart(viewController)

      // Wait for parent and child spans to be created
      wait(timeout: Self.defaultTimeout) {
        let startedSpans = self.mockSpanProcessor.getStartedSpans()
        let parentSpan = startedSpans.first { $0.name == Self.spanNameViewLoad }
        let childSpan = startedSpans.first { $0.name == Self.spanNameViewDidLoad }
        return parentSpan != nil && childSpan != nil
      }

      let startedSpans = mockSpanProcessor.getStartedSpans()
      let parentSpan = startedSpans.first { $0.name == Self.spanNameViewLoad }
      let childSpan = startedSpans.first { $0.name == Self.spanNameViewDidLoad }

      XCTAssertNotNil(parentSpan, "Should create parent span")
      XCTAssertNotNil(childSpan, "Should create child span")

      if let parent = parentSpan, let child = childSpan {
        XCTAssertEqual(child.parentSpanId, parent.spanId, "Child span should have parent span as parent")
      }
    }

    func testSpanTiming() {
      let viewController = TestViewController()

      handler.onViewDidLoadStart(viewController)

      // Add a small delay to ensure measurable duration
      Thread.sleep(forTimeInterval: Self.minimumSpanDuration)

      handler.onViewDidLoadEnd(viewController)

      // Wait for span to be ended
      wait(timeout: Self.defaultTimeout) {
        let endedSpans = self.mockSpanProcessor.getEndedSpans()
        return endedSpans.contains { $0.name == Self.spanNameViewDidLoad }
      }

      let endedSpans = mockSpanProcessor.getEndedSpans()
      let timedSpan = endedSpans.first { $0.name == Self.spanNameViewDidLoad }

      XCTAssertNotNil(timedSpan, "Should create timed span")
      if let span = timedSpan {
        let duration = span.endTime.timeIntervalSince(span.startTime)
        XCTAssertGreaterThanOrEqual(duration, Self.minimumSpanDuration, "Span should have correct duration")
      }
    }

    func testCustomViewControllerName() {
      class CustomViewController: UIViewController, ViewControllerCustomization {
        var customViewName: String? = ViewControllerHandlerTests.customViewControllerClassName
        var shouldCaptureView: Bool { return true }
      }

      let viewController = CustomViewController()

      handler.onViewDidLoadStart(viewController)

      // Wait for spans to be created
      wait(timeout: Self.defaultTimeout) {
        let startedSpans = self.mockSpanProcessor.getStartedSpans()
        return !startedSpans.isEmpty
      }

      let startedSpans = mockSpanProcessor.getStartedSpans()
      let span = startedSpans.first { $0.name == Self.spanNameViewDidLoad }

      XCTAssertNotNil(span, "Should create span for custom view controller")
      if let span {
        XCTAssertEqual(span.attributes[Self.attributeKeyViewClass]?.description, Self.customViewControllerClassName)
      }
    }

    /**
     * Tests that the queue-based thread safety approach correctly handles concurrent access.
     *
     * This test simulates multiple threads accessing the ViewControllerHandler simultaneously
     * and verifies that the handler correctly serializes access to its internal state through
     * the dispatch queue, preventing race conditions and data corruption.
     */
    func testQueueBasedThreadSafety() {
      // Create multiple view controllers to simulate concurrent access
      let viewControllers = (0 ..< Self.concurrentOperationCount).map { _ in TestViewController() }

      // Use an atomic counter to track operation completion
      let operationCounter = ManagedAtomic<Int>(0)

      // Simulate concurrent access from multiple threads
      for i in 0 ..< Self.concurrentOperationCount {
        let viewController = viewControllers[i]

        // Use different queues to ensure true concurrency
        let queue = DispatchQueue(label: "test.queue.\(i)", attributes: .concurrent)

        queue.async {
          // Start the view lifecycle
          self.handler.onViewDidLoadStart(viewController)
          operationCounter.wrappingIncrement(ordering: .relaxed)

          // Small delay to increase chance of thread interleaving
          Thread.sleep(forTimeInterval: 0.001 * Double.random(in: 1 ... 10))

          // End the view lifecycle
          self.handler.onViewDidLoadEnd(viewController)
          operationCounter.wrappingIncrement(ordering: .relaxed)
        }
      }

      // Wait for both operations to complete AND spans to be processed
      wait(timeout: Self.concurrentTestTimeout) {
        // Check if all operations have completed
        let operationsCompleted = operationCounter.load(ordering: .relaxed) == Self.concurrentOperationCount * 2

        // Check if spans have been processed (both started and ended)
        let startedSpans = self.mockSpanProcessor.getStartedSpans()
        let endedSpans = self.mockSpanProcessor.getEndedSpans()
        let spansProcessed = startedSpans.count >= Self.concurrentOperationCount &&
          endedSpans.count >= Self.concurrentOperationCount

        // Only return true when both conditions are met
        return operationsCompleted && spansProcessed
      }

      // Verify that spans were created correctly
      let startedSpans = mockSpanProcessor.getStartedSpans()
      let endedSpans = mockSpanProcessor.getEndedSpans()

      // We should have at least one span per view controller
      XCTAssertGreaterThanOrEqual(startedSpans.count, Self.concurrentOperationCount)
      XCTAssertGreaterThanOrEqual(endedSpans.count, Self.concurrentOperationCount)

      // Verify that we have matching parent-child relationships
      let parentSpans = startedSpans.filter { $0.name == Self.spanNameViewLoad }
      let childSpans = startedSpans.filter { $0.name == Self.spanNameViewDidLoad }

      // Each child span should have a valid parent
      for childSpan in childSpans {
        let hasValidParent = parentSpans.contains { $0.spanId == childSpan.parentSpanId }
        XCTAssertTrue(hasValidParent, "Child span should have a valid parent span")
      }
    }

    func testOptOutViewController() {
      let tracer = tracerProvider.get(instrumentationName: Self.testInstrumentationName, instrumentationVersion: Self.testInstrumentationVersion)
      let uiKitViewInstrumentation = UIKitViewInstrumentation(tracer: tracer)

      let optOutVC = OptOutViewController()

      XCTAssertFalse(optOutVC.shouldCaptureView(using: uiKitViewInstrumentation), "OptOut view controller should be filtered")

      handler.onViewDidLoadStart(optOutVC)
      handler.onViewDidLoadEnd(optOutVC)

      let startedSpans = mockSpanProcessor.getStartedSpans()
      let viewDidLoadSpans = startedSpans.filter { $0.name == Self.spanNameViewDidLoad }

      XCTAssertTrue(viewDidLoadSpans.isEmpty, "Should not create spans for filtered controllers")
    }

    func testAllowedViewController() {
      let tracer = tracerProvider.get(instrumentationName: Self.testInstrumentationName, instrumentationVersion: Self.testInstrumentationVersion)
      let uiKitViewInstrumentation = UIKitViewInstrumentation(tracer: tracer)

      let testVC = TestViewController()

      XCTAssertTrue(testVC.shouldCaptureView(using: uiKitViewInstrumentation), "Test view controller should be captured")

      handler.onViewDidLoadStart(testVC)
      handler.onViewDidLoadEnd(testVC)

      // Wait for spans to be created
      wait {
        let startedSpans = self.mockSpanProcessor.getStartedSpans()
        return startedSpans.contains { $0.name == Self.spanNameViewDidLoad }
      }

      let startedSpans = mockSpanProcessor.getStartedSpans()
      let viewDidLoadSpans = startedSpans.filter { $0.name == Self.spanNameViewDidLoad }

      XCTAssertFalse(viewDidLoadSpans.isEmpty, "Should create spans for allowed controllers")
    }

    func testSystemViewControllerFiltering() {
      let testVC = UIViewController()

      XCTAssertFalse(testVC.shouldCaptureView(using: uiKitViewInstrumentation), "Should filter out system UIViewController")
    }
  }

#endif
