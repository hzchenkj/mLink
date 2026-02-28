import Foundation

final class SplitLayoutStore {
    private let defaults: UserDefaults
    private let ratioKey = "split_ratio"
    private let userAdjustedKey = "split_ratio_user_adjusted"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var ratio: Double {
        get {
            let stored = defaults.object(forKey: ratioKey) as? Double
            return clamp(stored ?? 0.5)
        }
        set {
            defaults.set(clamp(newValue), forKey: ratioKey)
        }
    }

    var launchRatio: Double {
        0.5
    }

    func markUserAdjusted() {
        defaults.set(true, forKey: userAdjustedKey)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.2), 0.8)
    }
}
