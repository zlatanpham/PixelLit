import Foundation

/// Central configuration for the app.
enum AppConfig {
    /// GitHub repository owner
    static let githubOwner = "zlatanpham"

    /// GitHub repository name
    static let githubRepo = "PixLit"

    /// GitHub API URL for the latest release
    static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!
    }
}
