import SwiftUI

/// Shared "Unassigned + positions" picker used by both the roster editor and the
/// in-game lineup. Only shown for sports where `rules.hasPositions` — Basketball's
/// rules have an empty position list, so it never appears there.
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
