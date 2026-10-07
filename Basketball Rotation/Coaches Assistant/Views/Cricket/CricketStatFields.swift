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
            // Text-backed so a zero shows as the "0" placeholder: typing replaces
            // it instead of appending (tapping a literal "0" then typing 45 gave 450).
            TextField("0", text: textBinding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .monospacedDigit()
            Stepper(title, value: clampedBinding, in: range)
                .labelsHidden()
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { value == 0 ? "" : String(value) },
            set: { text in
                let parsed = Int(text.filter(\.isNumber)) ?? 0
                value = min(max(parsed, range.lowerBound), range.upperBound)
            }
        )
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
