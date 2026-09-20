import SwiftUI

/// Landing page shown on every launch — no persisted "last sport". Six tiles,
/// including Basketball, which routes to the untouched `ContentView`.
struct SportSelectionView: View {
    let onSelect: (Sport) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Sport.allCases) { sport in
                        Button {
                            onSelect(sport)
                        } label: {
                            SportTile(sport: sport)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose a Sport")
        }
    }
}

struct SportTile: View {
    let sport: Sport

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: sport.rules.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(sport.tint)
            Text(sport.rules.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(sport.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}
