import SwiftUI

/// Non-Basketball equivalent of `TrainingView`. Replaces the Phase 1 placeholder.
/// Passes `sport` through to `generateDrills`, which Basketball's own call site
/// never does (it relies on the `.basketball` default on `DrillGenerating`).
struct SportTrainingView: View {
    let sport: Sport

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

            Text("Generate age-appropriate \(sport.rules.drillNoun) drills using \(selectedProvider.displayName).")
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
            .tint(sport.tint)
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
                                .foregroundStyle(sport.tint)
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

    // MARK: - Drill Generation

    @MainActor
    func generateDrills() async {
        isGenerating = true
        errorMessage = nil
        drills = []

        do {
            drills = try await selectedProvider.drillService.generateDrills(
                ageGroup: selectedAgeGroup,
                apiKey: keyStore.apiKey(for: selectedProvider),
                sport: sport
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }
}
