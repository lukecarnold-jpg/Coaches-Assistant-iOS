import SwiftUI

/// Shared "Unassigned + positions" picker used by both the roster editor and the
/// in-game lineup. Only shown for sports where `rules.hasPositions` — Basketball
/// never shows this, since its rules have an empty position list.
struct PositionPicker: View {
    let sport: Sport
    @Binding var selection: String  // "" == unassigned

    var body: some View {
        Picker("Position", selection: $selection) {
            Text("Unassigned").tag("")
            ForEach(sport.rules.positions) { position in
                Text("\(position.code) — \(position.name)").tag(position.code)
            }
        }
    }
}
