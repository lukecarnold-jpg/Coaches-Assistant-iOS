import SwiftUI

extension Sport {
    var tint: Color {
        switch self {
        case .basketball:  return .orange
        case .netball:      return .pink
        case .soccer:       return .green
        case .afl:          return .red
        case .rugbyUnion:   return .indigo
        case .rugbyLeague:  return .blue
        }
    }
}

extension EnvironmentValues {
    /// Only for shared leaf components (event rows, player pickers) that need
    /// terminology but not a `@Query` predicate. Query-owning views take `sport`
    /// as an explicit `init` parameter instead. The `.basketball` default is a
    /// previews-only fallback — Basketball's own views never read this.
    @Entry var sport: Sport = .basketball
}
