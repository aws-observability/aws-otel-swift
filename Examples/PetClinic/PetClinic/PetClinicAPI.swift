import Foundation

class PetClinicAPI: ObservableObject {
  private let baseURL: String
  private let session = URLSession.shared
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(baseURL: String = "http://a61dafdaceaa340d5b3fc9d3a00f71c6-746455772.us-east-1.elb.amazonaws.com") {
    self.baseURL = baseURL
  }

  // MARK: - Owner Endpoints

  func getOwners() async -> APIResult<[Owner]> {
    return await performRequest(endpoint: "/api/customer/owners", method: "GET")
  }

  func getOwner(id: Int) async -> APIResult<Owner> {
    return await performRequest(endpoint: "/api/customer/owners/\(id)", method: "GET")
  }

  func getOwnerWithVisits(id: Int) async -> APIResult<Owner> {
    return await performRequest(endpoint: "/api/gateway/owners/\(id)", method: "GET")
  }

  func updateOwner(id: Int, owner: OwnerRequest) async -> APIResult<Void> {
    return await performVoidRequest(endpoint: "/api/customer/owners/\(id)", method: "PUT", body: owner)
  }

  func addOwner(_ owner: OwnerRequest) async -> APIResult<Void> {
    return await performVoidRequest(endpoint: "/api/customer/owners", method: "POST", body: owner)
  }

  // MARK: - Pet Endpoints

  func getPetTypes() async -> APIResult<[PetType]> {
    return await performRequest(endpoint: "/api/customer/petTypes", method: "GET")
  }

  func getPet(ownerId: Int, petId: Int) async -> APIResult<Pet> {
    return await performRequest(endpoint: "/api/customer/owners/\(ownerId)/pets/\(petId)", method: "GET")
  }

  func updatePet(ownerId: Int, petId: Int, pet: PetRequest) async -> APIResult<Void> {
    return await performVoidRequest(endpoint: "/api/customer/owners/\(ownerId)/pets/\(petId)", method: "PUT", body: pet)
  }

  func addPet(ownerId: Int, pet: PetRequest) async -> APIResult<Pet> {
    print("API: Adding pet \(pet) to owner \(ownerId)")
    let endpoint = "/api/customer/owners/\(ownerId)/pets"
    print("API: Endpoint: \(baseURL)\(endpoint)")
    return await performRequest(endpoint: endpoint, method: "POST", body: pet)
  }

  // MARK: - Visit Endpoints

  func getVisits(ownerId: Int, petId: Int) async -> APIResult<[Visit]> {
    return await performRequest(endpoint: "/api/visit/owners/\(ownerId)/pets/\(petId)/visits", method: "GET")
  }

  func addVisit(ownerId: Int, petId: Int, visit: Visit) async -> APIResult<Visit> {
    return await performRequest(endpoint: "/api/visit/owners/\(ownerId)/pets/\(petId)/visits", method: "POST", body: visit)
  }

  // MARK: - Vet Endpoints

  func getVets() async -> APIResult<[Vet]> {
    return await performRequest(endpoint: "/api/vet/vets", method: "GET")
  }

  // MARK: - Testing Endpoints

  func simulateNetworkError() async -> APIResult<Void> {
    return await performVoidRequest(endpoint: "/api/nonexistent/error", method: "GET")
  }

  func triggerCrash() {
    fatalError("Intentional crash for Application Signals testing")
  }

  func triggerANR() {
    Thread.sleep(forTimeInterval: 10.0)
  }

  // MARK: - Private Helper Methods

  private func performRequest<T: Codable>(endpoint: String, method: String, body: Codable? = nil) async -> APIResult<T> {
    guard let url = URL(string: baseURL + endpoint) else {
      return .failure(.unknown)
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let body {
      do {
        request.httpBody = try encoder.encode(body)
      } catch {
        return .failure(.decodingError(error))
      }
    }

    do {
      let (data, response) = try await session.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        guard 200 ... 299 ~= httpResponse.statusCode else {
          return .failure(.httpError(httpResponse.statusCode))
        }
      }

      let result = try decoder.decode(T.self, from: data)
      return .success(result)
    } catch {
      if error is DecodingError {
        return .failure(.decodingError(error))
      } else {
        return .failure(.networkError(error))
      }
    }
  }

  private func performVoidRequest(endpoint: String, method: String, body: Codable? = nil) async -> APIResult<Void> {
    guard let url = URL(string: baseURL + endpoint) else {
      return .failure(.unknown)
    }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let body {
      do {
        request.httpBody = try encoder.encode(body)
      } catch {
        return .failure(.decodingError(error))
      }
    }

    do {
      let (_, response) = try await session.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        guard 200 ... 299 ~= httpResponse.statusCode else {
          return .failure(.httpError(httpResponse.statusCode))
        }
      }

      return .success(())
    } catch {
      return .failure(.networkError(error))
    }
  }
}
