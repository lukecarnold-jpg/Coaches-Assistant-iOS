import SwiftUI

/// Slim header (sport name + back chevron) wrapped around any sport home,
/// including Basketball's untouched `ContentView()`. This is how a "Change Sport"
/// affordance exists at all without editing `ContentView` — the header sits above
/// it rather than inside it, so Basketball's own navigation is untouched.
struct SportChrome<Content: View>: View {
    let sport: Sport
    let onChangeSport: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content()
        }
    }

    private var header: some View {
        HStack {
            Button(action: onChangeSport) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Sports")
                }
                .font(.subheadline)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: sport.rules.systemImage)
                    .foregroundStyle(sport.tint)
                Text(sport.rules.displayName)
                    .font(.subheadline.bold())
            }
            Spacer()
            // Balances the leading button so the title stays centered.
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Sports")
            }
            .font(.subheadline)
            .hidden()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
