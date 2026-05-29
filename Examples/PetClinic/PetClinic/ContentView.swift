import SwiftUI
import AwsOpenTelemetryCore

struct ContentView: View {
  @StateObject private var api = PetClinicAPI()
  @State private var owners: [Owner] = []
  @State private var vets: [Vet] = []
  @State private var petTypes: [PetType] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var selectedTab = 0
  @State private var isJanking = false
  @State private var showingAddOwner = false
  @State private var searchText = ""

  // Pet Clinic Colors
  private let primaryGreen = Color(red: 0.427, green: 0.702, blue: 0.247) // #6DB33F
  private let secondaryBrown = Color(red: 0.204, green: 0.188, blue: 0.176) // #34302D
  private let backgroundColor = Color(red: 0.945, green: 0.945, blue: 0.945) // #F1F1F1

  // Computed property for filtered owners
  private var filteredOwners: [Owner] {
    if searchText.isEmpty {
      return owners
    } else {
      return owners.filter { owner in
        owner.firstName.localizedCaseInsensitiveContains(searchText) ||
          owner.lastName.localizedCaseInsensitiveContains(searchText) ||
          owner.address.localizedCaseInsensitiveContains(searchText) ||
          owner.city.localizedCaseInsensitiveContains(searchText)
      }
    }
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      // Home Tab
      NavigationView {
        ScrollView {
          VStack(spacing: 20) {
            Spacer(minLength: 32)

            Text("Welcome to Pet Clinic")
              .font(.largeTitle)
              .fontWeight(.bold)
              .foregroundColor(primaryGreen)
              .multilineTextAlignment(.center)

            Text("Application Signals Demo App")
              .font(.title2)

//            // Debug: Show command line arguments
//            Text("Args: \(ProcessInfo.processInfo.arguments.joined(separator: ", "))")
//              .font(.caption)
//              .foregroundColor(.gray)
//              .accessibilityIdentifier("commandLineArgs")
//              .foregroundColor(.secondary)
//              .multilineTextAlignment(.center)

            Spacer(minLength: 32)

            // About Card
            VStack(alignment: .leading, spacing: 16) {
              Text("About This App")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryGreen)

              Text("This Pet Clinic mobile app demonstrates AWS Application Signals capabilities. You can manage pet owners, view veterinarians, and track pet visits - all while Application Signals monitors the performance and health of the underlying microservices.")
                .font(.body)
                .foregroundColor(.primary)

              Text("Features:")
                .font(.headline)
                .fontWeight(.medium)
                .padding(.top, 8)

              VStack(alignment: .leading, spacing: 4) {
                Text("• Browse and search pet owners")
                Text("• View owner details and pet information")
                Text("• Add new owners and pets")
                Text("• View veterinarian information")
                Text("• Track pet visits and medical history")
              }
              .font(.body)
              .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer(minLength: 32)

            // Testing Section
            VStack(alignment: .leading, spacing: 16) {
              Text("⚠️ Testing & Monitoring")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)

              Text("These buttons demonstrate different types of issues for Application Signals monitoring:")
                .font(.body)
                .foregroundColor(.primary)

              VStack(spacing: 12) {
                // API Test Button
                Button(action: {
                  Task { await loadOwners() }
                }) {
                  HStack {
                    Image(systemName: "network")
                    Text("🌐 Test API Call")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(primaryGreen)
                  .foregroundColor(.white)
                  .cornerRadius(8)
                }

                // Network Error Button 404
                Button(action: {
                  Task {
                    let result = await api.simulateNetworkError404()
                    if case let .failure(error) = result {
                      errorMessage = error.localizedDescription
                    }
                  }
                }) {
                  HStack {
                    Image(systemName: "wifi.slash")
                    Text("🚫 Simulate Network Error 404")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color.orange)
                  .foregroundColor(.white)
                  .cornerRadius(8)
                }

                // Network Error Button 500
                Button(action: {
                  Task {
                    let result = await api.simulateNetworkError500()
                    if case let .failure(error) = result {
                      errorMessage = error.localizedDescription
                    }
                  }
                }) {
                  HStack {
                    Image(systemName: "wifi.slash")
                    Text("🚫 Simulate Network Error 500")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color.orange)
                  .foregroundColor(.white)
                  .cornerRadius(8)
                }

                // Crash Button
                Button(action: {
                  api.triggerCrash()
                }) {
                  HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("💥 Trigger App Crash")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color.red)
                  .foregroundColor(.white)
                  .cornerRadius(8)
                }

                // ANR Button
                Button(action: {
                  api.triggerANR()
                }) {
                  HStack {
                    Image(systemName: "clock.fill")
                    Text("⏰ Trigger ANR (10s block)")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color(red: 1.0, green: 0.42, blue: 0.0))
                  .foregroundColor(.white)
                  .cornerRadius(8)
                }

                // UI Jank Button
                Button(action: {
                  isJanking.toggle()
                  if isJanking {
                    startJankSimulation()
                  }
                }) {
                  HStack {
                    Image(systemName: isJanking ? "pause.fill" : "play.fill")
                    Text(isJanking ? "🟢 Stop UI Jank" : "🟡 Start UI Jank")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(isJanking ? Color.green : Color.orange)
                  .foregroundColor(.white)
                  .cornerRadius(8)
                }
              }
            }
            .padding()
            .background(Color(.systemRed).opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer(minLength: 32)
          }
        }
        .navigationTitle("Home")
        .background(backgroundColor)
      }
      .tabItem {
        Image(systemName: "house.fill")
        Text("Home")
      }
      .tag(0)

      // Owners Tab - SwiftUI
      NavigationView {
        VStack {
          if isLoading {
            ProgressView("Loading...")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            List(filteredOwners) { owner in
              NavigationLink(destination: OwnerDetailView(owner: owner)) {
                OwnerCardView(owner: owner)
              }
            }
            .searchable(text: $searchText, prompt: "Search owners...")
            .refreshable {
              await loadOwners()
            }
          }
        }
        .navigationTitle("Pet Owners")
        .navigationBarItems(
          trailing: Button(action: {
            showingAddOwner = true
          }) {
            Image(systemName: "plus")
              .foregroundColor(primaryGreen)
          }
        )
        .background(backgroundColor)
        .task {
          await loadOwners()
        }
        .sheet(isPresented: $showingAddOwner) {
          AddOwnerView()
            .onDisappear {
              Task {
                await loadOwners()
              }
            }
        }
      }
      .awsOpenTelemetryTrace("OwnersList", attributes: [
        "category": "owners"
      ])
      .tabItem {
        Image(systemName: "person.2.fill")
        Text("Owners")
      }
      .tag(1)

      // Vets Tab
      NavigationView {
        VStack {
          if isLoading {
            ProgressView("Loading...")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            List(vets) { vet in
              VetRowView(vet: vet)
            }
            .refreshable {
              await loadVets()
            }
          }
        }
        .navigationTitle("Veterinarians")
        .background(backgroundColor)
        .task {
          await loadVets()
        }
      }
      .tabItem {
        Image(systemName: "stethoscope")
        Text("Vets")
      }
      .tag(2)

      // Testing Tab
      NavigationView {
        ScrollView {
          VStack(spacing: 20) {
            Text("Application Signals Testing")
              .font(.title)
              .fontWeight(.bold)
              .foregroundColor(secondaryBrown)
              .padding(.top)

            Text("Test buttons to generate telemetry events for AWS Application Signals monitoring")
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)

            VStack(spacing: 12) {
              // API Test Button
              Button(action: {
                Task { await loadOwners() }
              }) {
                HStack {
                  Image(systemName: "network")
                  Text("🌐 Test API Call")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(primaryGreen)
                .foregroundColor(.white)
                .cornerRadius(8)
              }

              // Network Error Button - 404
              Button(action: {
                Task {
                  let result = await api.simulateNetworkError404()
                  if case let .failure(error) = result {
                    errorMessage = error.localizedDescription
                  }
                }
              }) {
                HStack {
                  Image(systemName: "wifi.slash")
                  Text("🚫 Simulate Network Error 404")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
              }

              // Network Error Button - 500
              Button(action: {
                Task {
                  let result = await api.simulateNetworkError500()
                  if case let .failure(error) = result {
                    errorMessage = error.localizedDescription
                  }
                }
              }) {
                HStack {
                  Image(systemName: "wifi.slash")
                  Text("🚫 Simulate Network Error 500")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
              }

              // Crash Button
              Button(action: {
                api.triggerCrash()
              }) {
                HStack {
                  Image(systemName: "exclamationmark.triangle.fill")
                  Text("💥 Trigger App Crash")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
              }

              // ANR Button
              Button(action: {
                api.triggerANR()
              }) {
                HStack {
                  Image(systemName: "clock.fill")
                  Text("⏰ Trigger ANR (10s block)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 1.0, green: 0.42, blue: 0.0)) // Orange
                .foregroundColor(.white)
                .cornerRadius(8)
              }

              // UI Jank Button
              Button(action: {
                isJanking.toggle()
                if isJanking {
                  startJankSimulation()
                }
              }) {
                HStack {
                  Image(systemName: isJanking ? "pause.fill" : "play.fill")
                  Text(isJanking ? "🟢 Stop UI Jank" : "🟡 Start UI Jank")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isJanking ? Color.green : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
              }
            }
            .padding(.horizontal)

            Spacer()
          }
        }
        .navigationTitle("Testing")
        .background(backgroundColor)
      }
      .tabItem {
        Image(systemName: "hammer.fill")
        Text("Testing")
      }
      .tag(2)
    }
    .accentColor(primaryGreen)
    .alert("Error", isPresented: .constant(errorMessage != nil)) {
      Button("OK") {
        errorMessage = nil
      }
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func loadOwners() async {
    isLoading = true
    let result = await api.getOwners()

    await MainActor.run {
      isLoading = false
      switch result {
      case let .success(fetchedOwners):
        owners = fetchedOwners
      case let .failure(error):
        errorMessage = error.localizedDescription
      }
    }
  }

  private func loadVets() async {
    isLoading = true
    let result = await api.getVets()

    await MainActor.run {
      isLoading = false
      switch result {
      case let .success(fetchedVets):
        vets = fetchedVets
      case let .failure(error):
        errorMessage = error.localizedDescription
      }
    }
  }

  private func startJankSimulation() {
    // Simulate UI jank by blocking the main thread periodically
    DispatchQueue.main.async {
      performJankOperation()
    }
  }

  private func performJankOperation() {
    if isJanking {
      // Block main thread for 100ms to cause frame drops
      let startTime = Date()
      while Date().timeIntervalSince(startTime) < 0.1 {
        // Busy wait
      }

      // Schedule next jank operation
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        performJankOperation()
      }
    }
  }
}

// MARK: - Owner Card View (Better styling like Android)

struct OwnerCardView: View {
  let owner: Owner
  private let primaryGreen = Color(red: 0.427, green: 0.702, blue: 0.247)

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(owner.firstName) \(owner.lastName)")
            .font(.headline)
            .fontWeight(.semibold)

          Text(owner.address)
            .font(.subheadline)
            .foregroundColor(.secondary)

          Text("\(owner.city) • \(owner.telephone)")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        if let pets = owner.pets, !pets.isEmpty {
          VStack {
            Image(systemName: "pawprint.fill")
              .foregroundColor(primaryGreen)
            Text("\(pets.count)")
              .font(.caption)
              .fontWeight(.medium)
          }
        }
      }

      if let pets = owner.pets, !pets.isEmpty {
        HStack {
          Text("Pets:")
            .font(.caption)
            .fontWeight(.medium)
          Text(pets.map(\.name).joined(separator: ", "))
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
  }
}

// MARK: - Owner Detail View

struct OwnerDetailView: View {
  let owner: Owner
  @StateObject private var api = PetClinicAPI()
  @State private var showingAddPet = false
  @State private var petTypes: [PetType] = []
  @State private var refreshedOwner: Owner?

  private let primaryGreen = Color(red: 0.427, green: 0.702, blue: 0.247)

  var currentOwner: Owner {
    refreshedOwner ?? owner
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Owner Info Card
        VStack(alignment: .leading, spacing: 12) {
          Text("Owner Information")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(primaryGreen)

          VStack(alignment: .leading, spacing: 8) {
            InfoRow(label: "Name", value: "\(currentOwner.firstName) \(currentOwner.lastName)")
            InfoRow(label: "Address", value: currentOwner.address)
            InfoRow(label: "City", value: currentOwner.city)
            InfoRow(label: "Phone", value: currentOwner.telephone)
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)

        // Pets Section
        HStack {
          Text("Pets (\(currentOwner.pets?.count ?? 0))")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(primaryGreen)

          Spacer()

          Button(action: {
            showingAddPet = true
          }) {
            Image(systemName: "plus.circle.fill")
              .font(.title2)
              .foregroundColor(primaryGreen)
          }
        }

        if let pets = currentOwner.pets, !pets.isEmpty {
          ForEach(pets) { pet in
            PetCardView(pet: pet)
          }
        } else {
          Text("No pets registered")
            .font(.body)
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
      }
      .padding()
    }
    .navigationTitle("Owner Details")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadPetTypes()
    }
    .sheet(isPresented: $showingAddPet) {
      AddPetView(ownerId: currentOwner.id, petTypes: petTypes) {
        await refreshOwnerData()
      }
    }
  }

  private func loadPetTypes() async {
    print("Loading pet types...")
    let result = await api.getPetTypes()
    print("Pet types result: \(result)")

    switch result {
    case let .success(types):
      print("Loaded \(types.count) pet types: \(types)")
      await MainActor.run {
        petTypes = types
      }
    case let .failure(error):
      print("Failed to load pet types: \(error)")
    }
  }

  private func refreshOwnerData() async {
    let result = await api.getOwnerWithVisits(id: currentOwner.id)
    if case let .success(updatedOwner) = result {
      await MainActor.run {
        refreshedOwner = updatedOwner
      }
    }
  }
}

// MARK: - Pet Card View

struct PetCardView: View {
  let pet: Pet

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(pet.name)
          .font(.headline)
          .fontWeight(.medium)

        Text(pet.type.name.capitalized)
          .font(.subheadline)
          .foregroundColor(.secondary)

        Text("Born: \(pet.birthDate)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Image(systemName: petIcon(for: pet.type.name))
        .font(.title2)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(8)
    .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
  }

  private func petIcon(for petType: String) -> String {
    switch petType.lowercased() {
    case "dog": return "dog.fill"
    case "cat": return "cat.fill"
    case "bird": return "bird.fill"
    case "hamster": return "hare.fill"
    case "snake": return "lizard.fill"
    case "lizard": return "lizard.fill"
    case "horse": return "horse.fill"
    default: return "pawprint.fill"
    }
  }
}

// MARK: - Info Row View

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label + ":")
        .font(.subheadline)
        .fontWeight(.medium)
        .frame(width: 80, alignment: .leading)

      Text(value)
        .font(.subheadline)
        .foregroundColor(.primary)

      Spacer()
    }
  }
}

// MARK: - Add Owner View - SwiftUI

struct AddOwnerView: View {
  @Environment(\.presentationMode) var presentationMode
  @StateObject private var api = PetClinicAPI()

  @State private var firstName = ""
  @State private var lastName = ""
  @State private var address = ""
  @State private var city = ""
  @State private var telephone = ""
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showingAlert = false

  private let primaryGreen = Color(red: 0.427, green: 0.702, blue: 0.247)

  var body: some View {
    AwsOTelTraceView("Owners") {
      NavigationView {
        Form {
          Section(header: Text("Owner Information")) {
            TextField("First Name", text: $firstName)
            TextField("Last Name", text: $lastName)
            TextField("Address", text: $address)
            TextField("City", text: $city)
            TextField("Telephone", text: $telephone)
              .keyboardType(.phonePad)
          }

          Section {
            Button(action: addOwner) {
              HStack {
                if isLoading {
                  ProgressView()
                    .scaleEffect(0.8)
                }
                Text(isLoading ? "Adding..." : "Add Owner")
              }
              .frame(maxWidth: .infinity)
              .foregroundColor(.white)
            }
            .disabled(isLoading || !isFormValid)
            .listRowBackground(
              RoundedRectangle(cornerRadius: 8)
                .fill(isFormValid ? primaryGreen : Color.gray)
            )
          }
        }
        .navigationTitle("Add Owner")
        .navigationBarItems(
          leading: Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
          }
        )
        .alert("Error", isPresented: $showingAlert) {
          Button("OK") {
            errorMessage = nil
          }
        } message: {
          Text(errorMessage ?? "Unknown error")
        }
      }
    }
  }

  private var isFormValid: Bool {
    !firstName.isEmpty && !lastName.isEmpty && !address.isEmpty && !city.isEmpty && !telephone.isEmpty
  }

  private func addOwner() {
    guard isFormValid else { return }

    isLoading = true

    Task {
      let newOwner = OwnerRequest(
        firstName: firstName,
        lastName: lastName,
        address: address,
        city: city,
        telephone: telephone
      )

      let result = await api.addOwner(newOwner)

      await MainActor.run {
        isLoading = false

        switch result {
        case .success:
          presentationMode.wrappedValue.dismiss()
        case let .failure(error):
          errorMessage = error.localizedDescription
          showingAlert = true
        }
      }
    }
  }
}

// MARK: - Add Pet View

struct AddPetView: View {
  let ownerId: Int
  let petTypes: [PetType]
  let onPetAdded: () async -> Void

  @Environment(\.presentationMode) var presentationMode
  @StateObject private var api = PetClinicAPI()

  @State private var petName = ""
  @State private var birthDate = ""
  @State private var selectedPetType: PetType?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var showingAlert = false
  @State private var availablePetTypes: [PetType] = []

  private let primaryGreen = Color(red: 0.427, green: 0.702, blue: 0.247)

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Pet Information")) {
          TextField("Pet Name", text: $petName)

          TextField("Birth Date (YYYY-MM-DD)", text: $birthDate)
            .placeholder(when: birthDate.isEmpty) {
              Text("2020-01-15").foregroundColor(.gray)
            }

          // Pet Type Picker
          Picker("Pet Type", selection: $selectedPetType) {
            Text("Select Pet Type").tag(nil as PetType?)
            ForEach(availablePetTypes) { petType in
              Text(petType.name.capitalized).tag(petType as PetType?)
            }
          }
          .pickerStyle(MenuPickerStyle())

          if availablePetTypes.isEmpty {
            Text("Loading pet types...")
              .foregroundColor(.secondary)
          }
        }

        Section {
          Button(action: addPet) {
            HStack {
              if isLoading {
                ProgressView()
                  .scaleEffect(0.8)
              }
              Text(isLoading ? "Adding Pet..." : "Add Pet")
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
          }
          .disabled(isLoading || !isFormValid)
          .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
              .fill(isFormValid ? primaryGreen : Color.gray)
          )
        }
      }
      .navigationTitle("Add Pet")
      .navigationBarItems(
        leading: Button("Cancel") {
          presentationMode.wrappedValue.dismiss()
        }
      )
      .task {
        await loadPetTypesIfNeeded()
      }
      .alert("Error", isPresented: $showingAlert) {
        Button("OK") {
          errorMessage = nil
        }
      } message: {
        Text(errorMessage ?? "Unknown error")
      }
    }
  }

  private var isFormValid: Bool {
    !petName.isEmpty && !birthDate.isEmpty && selectedPetType != nil && isValidDate(birthDate)
  }

  private func isValidDate(_ dateString: String) -> Bool {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.date(from: dateString) != nil
  }

  private func loadPetTypesIfNeeded() async {
    if !petTypes.isEmpty {
      await MainActor.run {
        availablePetTypes = petTypes
      }
    } else {
      print("Pet types not provided, loading from API...")
      let result = await api.getPetTypes()
      switch result {
      case let .success(types):
        print("Loaded \(types.count) pet types in AddPetView")
        await MainActor.run {
          availablePetTypes = types
        }
      case let .failure(error):
        print("Failed to load pet types in AddPetView: \(error)")
      }
    }
  }

  private func addPet() {
    guard isFormValid, let petType = selectedPetType else { return }

    isLoading = true

    Task {
      let petRequest = PetRequest(
        name: petName,
        birthDate: birthDate,
        typeId: petType.id
      )

      print("Adding pet: \(petRequest) to owner: \(ownerId)")

      let result = await api.addPet(ownerId: ownerId, pet: petRequest)

      await MainActor.run {
        isLoading = false

        switch result {
        case let .success(pet):
          print("Successfully added pet: \(pet)")
          Task {
            await onPetAdded()
          }
          presentationMode.wrappedValue.dismiss()
        case let .failure(error):
          print("Failed to add pet: \(error)")
          errorMessage = error.localizedDescription
          showingAlert = true
        }
      }
    }
  }
}

// MARK: - TextField Placeholder Extension

extension View {
  func placeholder(when shouldShow: Bool,
                   alignment: Alignment = .leading,
                   @ViewBuilder placeholder: () -> some View) -> some View {
    ZStack(alignment: alignment) {
      placeholder().opacity(shouldShow ? 1 : 0)
      self
    }
  }
}

struct OwnerRowView: View {
  let owner: Owner

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("\(owner.firstName) \(owner.lastName)")
        .font(.headline)
      Text(owner.address)
        .font(.subheadline)
        .foregroundColor(.secondary)
      Text("\(owner.city) • \(owner.telephone)")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 2)
  }
}

struct VetRowView: View {
  let vet: Vet

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Dr. \(vet.firstName) \(vet.lastName)")
        .font(.headline)
      if let specialties = vet.specialties, !specialties.isEmpty {
        Text(specialties.map(\.name).joined(separator: ", "))
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 2)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
