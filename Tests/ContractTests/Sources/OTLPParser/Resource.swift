import Foundation

struct Resource: Codable {
  let attributes: [Attribute]
}

struct Attribute: Codable {
  let key: String
  let value: Value
}

struct Value: Codable {
  let stringValue: String?
  let doubleValue: Double?
  let intValue: String?
  let boolValue: Bool?

  enum CodingKeys: String, CodingKey {
    case stringValue
    case doubleValue
    case intValue
    case boolValue
  }
}

struct Scope: Codable {
  let name: String

  private enum CodingKeys: String, CodingKey {
    case name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    // This implements @JsonIgnoreUnknownKeys functionality by only decoding the required fields
  }
}
