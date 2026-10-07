import SwiftUI

extension Sport {
    var tint: Color {
        switch self {
        case .basketball:     return .orange
        case .netball:        return .pink
        case .soccer:         return .green
        case .afl:            return .red
        case .rugbyUnion:     return .indigo
        case .rugbyLeague:    return .blue
        case .iceHockey:      return .cyan
        case .fieldHockey:    return .mint
        case .teamHandball:   return .purple
        case .waterPolo:      return .teal
        case .lacrosse:       return .brown
        case .flagFootball:   return .yellow
        case .futsal:         return Color(red: 0.1, green: 0.7, blue: 0.5)
        case .volleyball:     return Color(red: 0.9, green: 0.5, blue: 0.1)
        case .touchFootball:  return Color(red: 0.8, green: 0.2, blue: 0.4)
        case .cricket:        return Color(red: 0.15, green: 0.5, blue: 0.3)
        }
    }
}

extension EnvironmentValues {
    /// Only for shared leaf components (event rows, player pickers) that need
    /// terminology but not a `@Query` predicate. Query-owning views take `sport`
    /// as an explicit `init` parameter instead. The `.basketball` default is a
    /// previews-only fallback; `SportHomeView` always injects the real sport.
    @Entry var sport: Sport = .basketball
}
