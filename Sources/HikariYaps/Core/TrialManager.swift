import Foundation

@MainActor
final class TrialManager: ObservableObject {
    static let shared = TrialManager()

    @Published var wordCount = 0
    @Published var monthlyLimit = 3500
    @Published var isTrialActive = false
    @Published var trialDaysRemaining = 5
    @Published var shouldShowLimitPopup = false

    private let userDefaults = UserDefaults.standard
    private let trialStartDateKey = "ivoz_trial_start_date"
    private let wordCountKey = "ivoz_word_count"
    private let wordCountDateKey = "ivoz_word_count_date"
    private let hasActivatedTrialKey = "ivoz_trial_activated"

    private init() {
        loadState()
    }

    // MARK: - Public API

    func recordWordCount(_ count: Int) {
        // Pro license: no trial window, no monthly limit, ever.
        guard !LicenseManager.shared.isActivated else { return }

        wordCount += count
        userDefaults.set(wordCount, forKey: wordCountKey)

        // The 5-day trial is full access — only enforce the monthly
        // limit once the trial window has elapsed.
        guard !isTrialActive else { return }

        if wordCount >= monthlyLimit {
            shouldShowLimitPopup = true
        }
    }

    func startTrial() {
        guard !userDefaults.bool(forKey: hasActivatedTrialKey) else { return }

        let now = Date()
        userDefaults.set(now, forKey: trialStartDateKey)
        userDefaults.set(true, forKey: hasActivatedTrialKey)
        userDefaults.set(0, forKey: wordCountKey)
        userDefaults.set(now, forKey: wordCountDateKey)

        isTrialActive = true
        wordCount = 0
    }

    func dismissLimitPopup() {
        shouldShowLimitPopup = false
    }

    // MARK: - Private

    private func loadState() {
        // Check if trial was started
        if let trialStart = userDefaults.object(forKey: trialStartDateKey) as? Date {
            let daysSinceStart = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
            isTrialActive = daysSinceStart < 5
            trialDaysRemaining = max(0, 5 - daysSinceStart)
        } else if !userDefaults.bool(forKey: hasActivatedTrialKey) {
            // First launch - start trial
            startTrial()
        }

        // Load word count
        wordCount = userDefaults.integer(forKey: wordCountKey)

        // Reset word count monthly
        if let lastDate = userDefaults.object(forKey: wordCountDateKey) as? Date {
            if !Calendar.current.isDateInThisMonth(lastDate) {
                wordCount = 0
                userDefaults.set(Date(), forKey: wordCountDateKey)
            }
        }
    }
}

extension Calendar {
    func isDateInThisMonth(_ date: Date) -> Bool {
        let now = Date()
        let components1 = dateComponents([.year, .month], from: date)
        let components2 = dateComponents([.year, .month], from: now)
        return components1.year == components2.year && components1.month == components2.month
    }
}
