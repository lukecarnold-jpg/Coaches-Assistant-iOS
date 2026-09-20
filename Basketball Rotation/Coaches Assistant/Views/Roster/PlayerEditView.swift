import SwiftUI
import SwiftData

struct PlayerEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let player: Player?

    @State private var name = ""
    @State private var jerseyText = ""
    @State private var showDeleteConfirm = false

    var isEditing: Bool { player != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Info") {
                    TextField("Name", text: $name)
                    TextField("Jersey Number (optional)", text: $jerseyText)
                        .keyboardType(.numberPad)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Player")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Player" : "Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let player {
                    name = player.name
                    jerseyText = player.jerseyNumber.map { String($0) } ?? ""
                }
            }
            .confirmationDialog("Delete Player", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let player { modelContext.delete(player) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the player from the roster.")
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let jerseyNum = Int(jerseyText.trimmingCharacters(in: .whitespaces))

        if let player {
            player.name = trimmedName
            player.jerseyNumber = jerseyNum
        } else {
            modelContext.insert(Player(name: trimmedName, jerseyNumber: jerseyNum))
        }
        dismiss()
    }
}
