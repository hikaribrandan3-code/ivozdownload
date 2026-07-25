import SwiftUI

/// Two states: Recording (mic + waveform) or Result (message).
struct OverlayView: View {
    @ObservedObject var controller: DictationController

    var body: some View {
        Group {
            switch controller.overlayPhase {
            case .hidden:
                EmptyView()

            case .listening, .transcribing:
                // Recording state: mic + waveform (no overlap)
                onePill {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 12)

                    LiveWaveform(levels: controller.levelHistory)
                        .frame(width: 30, height: 14)
                }

            case .success, .notice, .failure:
                // Result state: message only
                onePill {
                    resultText
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        }
        .onTapGesture { controller.dismissOverlay() }
    }

    private var resultText: Text {
        switch controller.overlayPhase {
        case .success:
            return Text("✓")
        case .notice(let message):
            return Text(message)
        case .failure(let message):
            return Text(message)
        default:
            return Text("")
        }
    }

    @ViewBuilder
    private func onePill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            content()
        }
        .frame(width: 62)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.gold)
        .cornerRadius(12)
    }
}

/// Waveform animation — responds to audio levels.
struct LiveWaveform: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 0.6) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.6)
                    .fill(Color.white)
                    .frame(width: 1.4, height: instantHeight(for: levels[index]))
                    .scaleEffect(y: scaleFactor(for: levels[index]), anchor: .center)
                    .animation(.easeInOut(duration: 0.08), value: levels[index])
            }
        }
    }

    private func instantHeight(for level: Float) -> CGFloat {
        return 1 + CGFloat(level) * 12
    }

    private func scaleFactor(for level: Float) -> CGFloat {
        return 0.8 + CGFloat(level) * 0.4
    }
}
