import SwiftUI

struct TrainingView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @State private var selectedAgeGroup = "U12"
    @State private var drills: [String] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showAPIKeyInput = false

    let ageGroups = ["U8", "U10", "U12", "U14", "U16", "U18", "Senior"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                drillGeneratorSection
                Divider()
                upcomingModulesSection
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Training")
        .sheet(isPresented: $showAPIKeyInput) {
            APIKeyInputView(apiKey: $geminiAPIKey)
        }
    }

    // MARK: - Drill Generator

    var drillGeneratorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drill Generator")
                    .font(.title2.bold())
                Spacer()
                Button {
                    showAPIKeyInput = true
                } label: {
                    Label(geminiAPIKey.isEmpty ? "Add API Key" : "API Key", systemImage: "key")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Text("Generate age-appropriate basketball drills using Gemini AI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ageGroupPicker

            Button {
                Task { await generateDrills() }
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isGenerating ? "Generating..." : "Generate Drills")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating || geminiAPIKey.isEmpty)

            if geminiAPIKey.isEmpty {
                Text("Add your Gemini API key to use drill generation.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if !drills.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Drills for \(selectedAgeGroup)")
                        .font(.headline)
                    ForEach(drills.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1).")
                                .font(.subheadline.bold())
                                .foregroundStyle(.blue)
                                .frame(width: 24, alignment: .leading)
                            Text(drills[i])
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Upcoming Modules

    @ViewBuilder
    private var ageGroupPicker: some View {
        if horizontalSizeClass == .compact {
            Picker("Age Group", selection: $selectedAgeGroup) {
                ForEach(ageGroups, id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .pickerStyle(.menu)
        } else {
            Picker("Age Group", selection: $selectedAgeGroup) {
                ForEach(ageGroups, id: \.self) { group in
                    Text(group).tag(group)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    var upcomingModulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coming Soon")
                .font(.title2.bold())

            ForEach(upcomingModules, id: \.title) { module in
                HStack(spacing: 14) {
                    Image(systemName: module.icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.title)
                            .font(.subheadline.bold())
                        Text(module.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Soon")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.15), in: Capsule())
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    var upcomingModules: [(title: String, description: String, icon: String)] {
        [
            ("Practice Planner", "Build and save full practice session plans with drills and timings.", "calendar.badge.plus"),
            ("Player Development", "Track individual player skill progression over time.", "chart.line.uptrend.xyaxis"),
            ("Play Diagrams", "Draw and save set plays and zone formations.", "pencil.and.diagram"),
            ("Season Stats", "Aggregate game stats across the full season.", "trophy"),
            ("Video Notes", "Attach timestamped notes to game film.", "video.badge.waveform"),
        ]
    }

    // MARK: - Gemini API

    @MainActor
    func generateDrills() async {
        isGenerating = true
        errorMessage = nil
        drills = []

        let prompt = "Generate 5 basketball practice drills suitable for \(selectedAgeGroup) players. For each drill, provide a short name followed by a 1-2 sentence description. Format as a numbered list with just the drill name and description, no extra headers."

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(geminiAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                errorMessage = "API error: \(msg.prefix(200))"
                isGenerating = false
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                drills = parseDrills(from: text)
            } else {
                errorMessage = "Could not parse response."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    func parseDrills(from text: String) -> [String] {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var currentDrill = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            // Check if line starts with a number (new drill)
            let isNewDrill = trimmed.first?.isNumber == true && trimmed.contains(".")
            if isNewDrill && !currentDrill.isEmpty {
                result.append(currentDrill.trimmingCharacters(in: .whitespacesAndNewlines))
                currentDrill = trimmed
            } else if isNewDrill {
                currentDrill = trimmed
            } else {
                currentDrill += " " + trimmed
            }
        }
        if !currentDrill.isEmpty {
            result.append(currentDrill.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result.prefix(5).map { drill in
            // Strip leading "1. " numbering
            drill.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
        }
    }
}

struct APIKeyInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Gemini API Key", text: $inputText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    Text("Your API key is stored locally on-device only. Get a key from Google AI Studio.")
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        apiKey = inputText
                        dismiss()
                    }
                }
            }
            .onAppear { inputText = apiKey }
        }
    }
}
