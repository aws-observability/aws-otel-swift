import Foundation

// MARK: - Owner Models

struct Owner: Codable, Identifiable {
  let id: Int
  let firstName: String
  let lastName: String
  let address: String
  let city: String
  let telephone: String
  let pets: [Pet]?

  // Custom decoding to handle different API response formats
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(Int.self, forKey: .id)
    firstName = try container.decode(String.self, forKey: .firstName)
    lastName = try container.decode(String.self, forKey: .lastName)
    address = try container.decode(String.self, forKey: .address)
    city = try container.decode(String.self, forKey: .city)
    telephone = try container.decode(String.self, forKey: .telephone)

    // Handle pets array that might be null or missing
    pets = try container.decodeIfPresent([Pet].self, forKey: .pets)
  }

  private enum CodingKeys: String, CodingKey {
    case id, firstName, lastName, address, city, telephone, pets
  }
}

struct OwnerRequest: Codable {
  let firstName: String
  let lastName: String
  let address: String
  let city: String
  let telephone: String
}

// MARK: - Pet Models

struct Pet: Codable, Identifiable {
  let id: Int
  let name: String
  let birthDate: String
  let type: PetType
  let visits: [Visit]?
}

struct PetRequest: Codable {
  let name: String
  let birthDate: String
  let typeId: Int
}

struct PetType: Codable, Identifiable, Hashable {
  let id: Int
  let name: String

  // Custom decoding to handle string ID from API
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    name = try container.decode(String.self, forKey: .name)

    // Handle ID that comes as string but we need as Int
    if let idString = try? container.decode(String.self, forKey: .id) {
      id = Int(idString) ?? 0
    } else {
      id = try container.decode(Int.self, forKey: .id)
    }
  }

  // Hashable conformance
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(name)
  }

  static func == (lhs: PetType, rhs: PetType) -> Bool {
    lhs.id == rhs.id && lhs.name == rhs.name
  }

  private enum CodingKeys: String, CodingKey {
    case id, name
  }
}

// MARK: - Visit Models

struct Visit: Codable, Identifiable {
  let id: Int?
  let date: String
  let description: String
}

struct Visits: Codable {
  let items: [Visit]
}

// MARK: - Vet Models

struct Vet: Codable, Identifiable {
  let id: Int
  let firstName: String
  let lastName: String
  let specialties: [Specialty]?
}

struct Specialty: Codable, Identifiable {
  let id: Int
  let name: String
}

// MARK: - API Response Types

enum APIResult<T> {
  case success(T)
  case failure(APIError)
}

enum APIError: Error, LocalizedError {
  case networkError(Error)
  case decodingError(Error)
  case httpError(Int)
  case unknown

  var errorDescription: String? {
    switch self {
    case let .networkError(error):
      return "Network error: \(error.localizedDescription)"
    case let .decodingError(error):
      if let decodingError = error as? DecodingError {
        switch decodingError {
        case let .keyNotFound(key, context):
          return "Missing key '\(key.stringValue)' in JSON response"
        case let .typeMismatch(type, context):
          return "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case let .valueNotFound(type, context):
          return "Missing value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case let .dataCorrupted(context):
          return "Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
        @unknown default:
          return "Decoding error: \(error.localizedDescription)"
        }
      }
      return "Decoding error: \(error.localizedDescription)"
    case let .httpError(code):
      return "HTTP error: \(code)"
    case .unknown:
      return "Unknown error occurred"
    }
  }
}
