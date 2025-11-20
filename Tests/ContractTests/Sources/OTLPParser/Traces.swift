import Foundation

struct TraceRoot: Codable {
  let resourceSpans: [ResourceSpan]
}

struct ResourceSpan: Codable {
  let resource: Resource
  let scopeSpans: [ScopeSpan]
}

struct ScopeSpan: Codable {
  let scope: Scope
  let spans: [Span]
}

struct Span: Codable {
  let traceId: String
  let spanId: String
  let parentSpanId: String?
  let flags: Int?
  let name: String
  let kind: String
  let startTimeUnixNano: String
  let endTimeUnixNano: String
  let attributes: [Attribute]
  let droppedAttributesCount: Int?
  let events: [SpanEvent]?

  enum CodingKeys: String, CodingKey {
    case traceId
    case spanId
    case parentSpanId
    case flags
    case name
    case kind
    case startTimeUnixNano
    case endTimeUnixNano
    case attributes
    case droppedAttributesCount
    case events
  }

  func hasDuration() -> Bool {
    return startTimeUnixNano != endTimeUnixNano
  }
}

struct SpanEvent: Codable {
  let timeUnixNano: String
  let name: String

  private enum CodingKeys: String, CodingKey {
    case timeUnixNano
    case name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    timeUnixNano = try container.decode(String.self, forKey: .timeUnixNano)
    name = try container.decode(String.self, forKey: .name)
    // This implements @JsonIgnoreUnknownKeys functionality by only decoding the required fields
  }
}
