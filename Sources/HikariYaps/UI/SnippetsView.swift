import SwiftUI

struct SnippetsView: View {
    @EnvironmentObject private var snippets: SnippetStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var newTrigger = ""
    @State private var newContent = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("nav.snippets"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(L("snippets.page_subtitle"))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField(L("snippets.trigger_placeholder_full"), text: $newTrigger)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(fieldBackground)
                    TextField(L("snippets.content_placeholder_full"), text: $newContent, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...6)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(fieldBackground)
                    HStack {
                        Spacer()
                        Button(L("snippets.add_button"), action: add)
                            .buttonStyle(PillButtonStyle(prominent: true))
                            .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty ||
                                      newContent.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(20)
                .card()

                if snippets.snippets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bolt")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textTertiary)
                        Text(L("snippets.empty_title"))
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text(L("snippets.empty_hint"))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                    .card()
                } else {
                    ForEach(snippets.snippets) { snippet in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.gold)
                                .padding(.top, 3)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("“\(snippet.trigger)”")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(snippet.content)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(3)
                            }
                            Spacer()
                            Button {
                                snippets.remove(snippet)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .card()
                    }
                }
            }
            .padding(28)
            .padding(.top, 16)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(Theme.windowBackground)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
            )
    }

    private func add() {
        snippets.add(trigger: newTrigger, content: newContent)
        newTrigger = ""
        newContent = ""
    }
}
