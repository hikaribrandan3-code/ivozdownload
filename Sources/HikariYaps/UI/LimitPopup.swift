import SwiftUI

struct LimitPopup: View {
    @ObservedObject var trialManager: TrialManager
    @ObservedObject private var license = LicenseManager.shared
    @Environment(\.openURL) private var openURL
    @State private var code = ""

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.gold)

                Text(L("license.limit_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text(L("license.limit_subtitle"))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                TextField(L("license.code_placeholder"), text: $code)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                    .onSubmit { redeem() }

                if let error = license.redeemError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                }

                Button(action: redeem) {
                    HStack {
                        if license.isRedeeming {
                            ProgressView().controlSize(.small)
                        }
                        Text(L("license.activate_button"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.gold)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(license.isRedeeming)
            }

            VStack(spacing: 12) {
                Button(action: openPaymentPage) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text(L("license.buy_button"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.07))
                    .foregroundStyle(Theme.textPrimary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: trialManager.dismissLimitPopup) {
                    Text(L("common.dismiss"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(L("license.limit_footer"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(Theme.card)
        .cornerRadius(16)
        .frame(maxWidth: 420)
        .padding(24)
        .onChange(of: license.isActivated) {
            if license.isActivated {
                trialManager.dismissLimitPopup()
            }
        }
    }

    private func redeem() {
        Task { await license.redeem(code: code) }
    }

    private func openPaymentPage() {
        // Checkout (Mercado Pago + PayPal) lives on the website, not in-app.
        if let url = URL(string: "https://ivoz.vercel.app/#pricing") {
            openURL(url)
        }
    }
}
