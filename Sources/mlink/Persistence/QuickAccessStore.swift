import Foundation

final class QuickAccessStore {
    private enum Keys {
        static let recent = "mlink.quick_access.recent_paths"
        static let favorites = "mlink.quick_access.favorite_paths"
    }

    private let defaults: UserDefaults
    private let maxRecentCount: Int

    init(defaults: UserDefaults = .standard, maxRecentCount: Int = 20) {
        self.defaults = defaults
        self.maxRecentCount = maxRecentCount
    }

    var recentURLs: [URL] {
        (defaults.array(forKey: Keys.recent) as? [String] ?? []).map { URL(fileURLWithPath: $0) }
    }

    var favoriteURLs: [URL] {
        (defaults.array(forKey: Keys.favorites) as? [String] ?? []).map { URL(fileURLWithPath: $0) }
    }

    func addRecent(_ url: URL) {
        let path = normalizedPath(for: url)
        var paths = (defaults.array(forKey: Keys.recent) as? [String] ?? []).filter { $0 != path }
        paths.insert(path, at: 0)
        if paths.count > maxRecentCount {
            paths = Array(paths.prefix(maxRecentCount))
        }
        defaults.set(paths, forKey: Keys.recent)
    }

    func isFavorite(url: URL) -> Bool {
        let path = normalizedPath(for: url)
        return (defaults.array(forKey: Keys.favorites) as? [String] ?? []).contains(path)
    }

    @discardableResult
    func toggleFavorite(url: URL) -> Bool {
        let path = normalizedPath(for: url)
        var paths = defaults.array(forKey: Keys.favorites) as? [String] ?? []
        if let index = paths.firstIndex(of: path) {
            paths.remove(at: index)
            defaults.set(paths, forKey: Keys.favorites)
            return false
        }

        paths.insert(path, at: 0)
        defaults.set(paths, forKey: Keys.favorites)
        return true
    }

    private func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.path
    }
}
