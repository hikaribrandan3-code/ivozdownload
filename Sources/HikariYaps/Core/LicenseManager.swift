import Foundation

/// Tracks whether this Mac has redeemed a paid iVoz Pro activation code.
/// Once activated, `TrialManager` stops enforcing the trial window and the
/// monthly word limit entirely.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var isActivated: Bool
    @Published var isRedeeming = false
    @Published var redeemError: String?

    private let userDefaults = UserDefaults.standard
    private let activatedKey = "ivoz_pro_activated"
    private let redeemURL = URL(string: "https://nfwcquwoyaeqgekncmyc.supabase.co/functions/v1/redeem-license")!

    // Public anon key — safe to embed (same one the website ships). Supabase's
    // gateway requires it in the apikey/Authorization headers, otherwise it
    // rejects the request with 401 before our function code ever runs.
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5md2NxdXdveWFlcWdla25jbXljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4ODYwNDIsImV4cCI6MjA5NzQ2MjA0Mn0._nY420m1fbyfK1hlF-BBYQ2dMjHcvtJjHG2w00NnCLM"

    private init() {
        isActivated = userDefaults.bool(forKey: activatedKey)
    }

    func redeem(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            redeemError = L("license.error_empty")
            return
        }

        isRedeeming = true
        redeemError = nil
        defer { isRedeeming = false }

        var request = URLRequest(url: redeemURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": trimmed])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                redeemError = L("license.error_network")
                return
            }
            guard (200...299).contains(http.statusCode) else {
                let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                redeemError = (payload?["error"] as? String) ?? L("license.error_invalid")
                return
            }
            isActivated = true
            userDefaults.set(true, forKey: activatedKey)
        } catch {
            redeemError = L("license.error_network")
        }
    }
}
