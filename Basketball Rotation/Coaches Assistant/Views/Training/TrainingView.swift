import SwiftUI

struct TrainingView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var keyStore = AIAPIKeyStore.shared
    @AppStorage("selectedAIProvider") private var selectedProviderRaw = AIProvider.gemini.rawValue
    @State private var selectedAgeGroup = "U12"
    @State private var drills: [String] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?

    let ageGroups = ["U8", "U10", "U12", "U14", "U16", "U18", "Senior"]

    private var selectedProvider: AIProvider {
        AIProvider(rawValue: selectedProviderRaw) ?? .gemini
    }

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
    }

    // MARK: - Drill Generator

    var drillGeneratorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Drill Generator")
                    .font(.title2.bold())
            }

            Text("Generate age-appropriate basketball drills using \(selectedProvider.displayName).")
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
            .disabled(isGenerating || !keyStore.isConfigured(selectedProvider))

            if !keyStore.isConfigured(selectedProvider) {
                Text("Set up \(selectedProvider.displayName) in Settings to use drill generation.")
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

    // MARK: - Drill Generation

    @MainActor
    func generateDrills() async {
        isGenerating = true
        errorMessage = nil
        drills = []

        do {
            drills = try await selectedProvider.drillService.generateDrills(
                ageGroup: selectedAgeGroup,
                apiKey: keyStore.apiKey(for: selectedProvider)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }
}
