import Foundation

struct LogRoot: Codable {
  let resourceLogs: [ResourceLog]
}

struct ResourceLog: Codable {
  let resource: Resource
  let scopeLogs: [ScopeLog]
}

struct ScopeLog: Codable {
  let scope: Scope
  let logRecords: [LogRecord]
}

struct LogRecord: Codable {
  let timeUnixNano: String
  let observedTimeUnixNano: String?
  let attributes: [Attribute]
  let traceId: String
  let spanId: String
  let eventName: String?

  enum CodingKeys: String, CodingKey {
    case timeUnixNano
    case observedTimeUnixNano
    case attributes
    case traceId
    case spanId
    case eventName
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    timeUnixNano = try container.decodeIfPresent(String.self, forKey: .timeUnixNano) ?? ""
    observedTimeUnixNano = try container.decodeIfPresent(String.self, forKey: .observedTimeUnixNano) ?? ""
    attributes = try container.decode([Attribute].self, forKey: .attributes)
    traceId = try container.decodeIfPresent(String.self, forKey: .traceId) ?? ""
    spanId = try container.decodeIfPresent(String.self, forKey: .spanId) ?? ""
    eventName = try container.decodeIfPresent(String.self, forKey: .eventName) ?? ""
  }
}
