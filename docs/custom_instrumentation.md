# Custom Instrumentation

This guide shows you how to add custom telemetry to your iOS app using the AWS Distro for OpenTelemetry Swift.

## Custom Spans

Spans track operations in your app. Use them to measure how long something takes.

### Basic Span

```swift
import OpenTelemetryApi

let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "my-app")

let span = tracer.spanBuilder(spanName: "load_user_profile").startSpan()
defer { span.end() }

let user = database.getUser(userId: userId)
processUser(user)
```

### Span with Attributes

Add context to your spans with attributes:

```swift
let span = tracer.spanBuilder(spanName: "checkout")
    .setAttribute(key: "cart.items", value: 3)
    .setAttribute(key: "cart.total", value: 49.99)
    .setAttribute(key: "payment.method", value: "credit_card")
    .startSpan()
defer { span.end() }

processCheckout()
```

### Nested Spans

Track sub-operations within a larger operation:

```swift
let parentSpan = tracer.spanBuilder(spanName: "load_dashboard").startSpan()
OpenTelemetry.instance.contextProvider.setActiveSpan(parentSpan)

loadUserData()

let notificationsSpan = tracer.spanBuilder(spanName: "load_notifications").startSpan()
fetchNotifications()
notificationsSpan.end()

let feedSpan = tracer.spanBuilder(spanName: "load_feed").startSpan()
fetchFeed()
feedSpan.end()

parentSpan.end()
```

### Async Span Control

For async operations:

```swift
func performBackgroundTask() async {
    let span = tracer.spanBuilder(spanName: "background_task").startSpan()

    do {
        try await doWork()
    } catch {
        span.recordException(error)
    }

    span.end()
}
```

## Custom Events

Events are point-in-time occurrences. Use them to track user actions or important moments.

### Basic Event

```swift
import OpenTelemetryApi

let logger = OpenTelemetry.instance.loggerProvider.get(instrumentationScopeName: "my-app")

logger.eventBuilder(name: "button_clicked")
    .emit()
```

### Event with Details

```swift
logger.eventBuilder(name: "purchase_completed")
    .setBody(AttributeValue.string("User completed checkout"))
    .setAttributes([
        "order.id": AttributeValue.string("12345"),
        "order.total": AttributeValue.double(99.99)
    ])
    .emit()
```

## SwiftUI View Instrumentation

Track view appearance with the built-in `AwsOTelTraceView` wrapper:

```swift
import SwiftUI
import AwsOpenTelemetryCore

struct ContentView: View {
    var body: some View {
        AwsOTelTraceView("HomeScreen") {
            VStack {
                Text("Welcome")
            }
        }
    }
}
```

With custom attributes:

```swift
AwsOTelTraceView("ProductDetail", attributes: ["product.id": "12345"]) {
    ProductDetailContent()
}
```

## Global Attributes

Add attributes to all telemetry data:

```swift
import AwsOpenTelemetryCore

let manager = AwsGlobalAttributesProvider.getInstance()
manager.setAttribute(key: "user.tier", value: AttributeValue.string("premium"))
manager.setAttribute(key: "app.variant", value: AttributeValue.string("beta"))
```

## Common Patterns

### Tracking API Calls

```swift
func fetchProducts() async throws -> [Product] {
    let span = tracer.spanBuilder(spanName: "api_fetch_products").startSpan()
    defer { span.end() }

    do {
        let response = try await apiClient.getProducts()
        span.setAttribute(key: "response.status", value: response.statusCode)
        span.setAttribute(key: "response.items", value: response.items.count)
        return response.items
    } catch {
        span.recordException(error)
        throw error
    }
}
```

### Tracking User Actions

```swift
@IBAction func submitButtonTapped(_ sender: UIButton) {
    logger.eventBuilder(name: "form_submitted")
        .setAttributes([
            "form.type": AttributeValue.string("registration"),
            "form.fields": AttributeValue.int(5)
        ])
        .emit()

    submitForm()
}
```

### Tracking Background Work

```swift
Task {
    let span = tracer.spanBuilder(spanName: "sync_data").startSpan()

    let result = await syncRepository.sync()
    span.setAttribute(key: "sync.records", value: result.count)

    span.end()
}
```
