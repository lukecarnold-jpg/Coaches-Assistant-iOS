import SwiftUI
import SwiftData

/// Edits one player's batting, bowling and fielding line for a match. Changes are
/// written straight to the model, so there's no separate save step.
struct CricketPlayerStatsEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var stats: CricketPlayerStats
    /// Used when "Batted" is switched on for a player with no position yet.
    let nextBattingPosition: Int

    private var didBatBinding: Binding<Bool> {
        Binding(
            get: { stats.didBat },
            set: { batted in
                stats.battingPosition = batted ? (stats.battingPosition ?? nextBattingPosition) : nil
                if !batted {
                    stats.isOut = false
                    stats.dismissalCode = ""
                }
            }
        )
    }

    private var battingPositionBinding: Binding<Int> {
        Binding(
            get: { stats.battingPosition ?? nextBattingPosition },
            set: { stats.battingPosition = $0 }
        )
    }

    private var isOutBinding: Binding<Bool> {
        Binding(
            get: { stats.isOut },
            set: { out in
                stats.isOut = out
                if out && stats.dismissalCode.isEmpty {
                    stats.dismissalCode = CricketDismissal.caught.rawValue
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Batted", isOn: didBatBinding)
                    if stats.didBat {
                        CricketStatField(title: "Batting Position", value: battingPositionBinding, range: 1...20)
                        CricketStatField(title: "Runs", value: $stats.runs)
                        CricketStatField(title: "Balls Faced", value: $stats.ballsFaced)
                        CricketStatField(title: "Fours", value: $stats.fours, range: 0...200)
                        CricketStatField(title: "Sixes", value: $stats.sixes, range: 0...200)
                        Toggle("Out", isOn: isOutBinding)
                        if stats.isOut {
                            Picker("How Out", selection: $stats.dismissalCode) {
                                ForEach(CricketDismissal.allCases) { dismissal in
                                    Text(dismissal.label).tag(dismissal.rawValue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Batting")
                } footer: {
                    if stats.didBat, let strikeRate = stats.strikeRate {
                        Text("Strike rate \(strikeRate.cricketStatText)")
                    }
                }

                Section {
                    CricketOversField(title: "Overs Bowled", balls: $stats.ballsBowled, maxOvers: 100)
                    CricketStatField(title: "Maidens", value: $stats.maidens, range: 0...100)
                    CricketStatField(title: "Runs Conceded", value: $stats.runsConceded)
                    CricketStatField(title: "Wickets", value: $stats.wicketsTaken, range: 0...10)
                    CricketStatField(title: "Wides", value: $stats.wides, range: 0...100)
                    CricketStatField(title: "No Balls", value: $stats.noBalls, range: 0...100)
                } header: {
                    Text("Bowling")
                } footer: {
                    if let economy = stats.economy {
                        Text("Figures \(stats.bowlingLine) · Economy \(economy.cricketStatText)")
                    }
                }

                Section("Fielding") {
                    CricketStatField(title: "Catches", value: $stats.catches, range: 0...20)
                    CricketStatField(title: "Run Outs", value: $stats.runOuts, range: 0...20)
                    CricketStatField(title: "Stumpings", value: $stats.stumpings, range: 0...20)
                }
            }
            .navigationTitle(stats.playerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
