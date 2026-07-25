import SwiftUI

struct VocabularyView: View {
    @EnvironmentObject private var vocabulary: VocabularyStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var newWord = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("nav.vocabulary"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L("vocabulary.page_subtitle"))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 10) {
                    TextField(L("vocabulary.add_placeholder"), text: $newWord)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Theme.cardStroke, lineWidth: 1)
                                )
                        )
                        .onSubmit(add)
                    Button(L("common.add"), action: add)
                        .buttonStyle(PillButtonStyle(prominent: true))
                }

                if vocabulary.entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "character.book.closed")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textTertiary)
                        Text(L("vocabulary.empty_title"))
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text(L("vocabulary.empty_hint"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                    .card()
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(vocabulary.entries) { entry in
                            HStack(spacing: 8) {
                                Text(entry.word)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Button {
                                    vocabulary.remove(entry)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
                            )
                        }
                    }
                }
            }
            .padding(28)
            .padding(.top, 16)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(Theme.windowBackground)
    }

    private func add() {
        vocabulary.add(newWord)
        newWord = ""
    }
}

/// Simple wrapping layout for vocabulary chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
