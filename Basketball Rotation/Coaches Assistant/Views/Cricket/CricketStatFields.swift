import SwiftUI

/// A labelled whole-number field with a stepper — type a big number (runs) or tap
/// for small adjustments (wickets, maidens).
struct CricketStatField: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: clampedBinding, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .monospacedDigit()
            Stepper(title, value: clampedBinding, in: range)
                .labelsHidden()
        }
    }

    private var clampedBinding: Binding<Int> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}

/// Overs entered as "overs" + "balls (0–5)", stored as total legal balls.
struct CricketOversField: View {
    let title: LocalizedStringKey
    @Binding var balls: Int
    var maxOvers: Int = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(CricketOvers.format(balls: balls))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(CricketOvers.format(balls: balls)) overs")
            }
            CricketStatField(title: "Overs", value: oversBinding, range: 0...maxOvers)
                .font(.subheadline)
            CricketStatField(title: "Balls", value: ballsBinding, range: 0...(CricketOvers.ballsPerOver - 1))
                .font(.subheadline)
        }
    }

    private var oversBinding: Binding<Int> {
        Binding(
            get: { balls / CricketOvers.ballsPerOver },
            set: { balls = CricketOvers.balls(overs: $0, extraBalls: balls % CricketOvers.ballsPerOver) }
        )
    }

    private var ballsBinding: Binding<Int> {
        Binding(
            get: { balls % CricketOvers.ballsPerOver },
            set: { balls = CricketOvers.balls(overs: balls / CricketOvers.ballsPerOver, extraBalls: $0) }
        )
    }
}
