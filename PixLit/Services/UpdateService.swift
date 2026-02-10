import Foundation

actor UpdateService {
    static let shared = UpdateService()

    private var releasesURL: URL { AppConfig.latestReleaseURL }

    private init() {}

    enum UpdateStatus {
        case upToDate
        case available(version: String, url: URL)
    }

    enum UpdateError: LocalizedError {
        case invalidResponse
        case noVersionFound

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Could not reach GitHub. Please check your connection."
            case .noVersionFound:
                return "No release version found."
            }
        }
    }

    func checkForUpdate() async throws -> UpdateStatus {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw UpdateError.invalidResponse
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        guard let remoteVersion = release.tagName.strippingVPrefix else {
            throw UpdateError.noVersionFound
        }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        if compareVersions(remoteVersion, isNewerThan: currentVersion) {
            guard let url = URL(string: release.htmlURL) else {
                throw UpdateError.invalidResponse
            }
            return .available(version: remoteVersion, url: url)
        }

        return .upToDate
    }

    // MARK: - Private

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private func compareVersions(_ remote: String, isNewerThan current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0 ..< max(remoteParts.count, currentParts.count) {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}

private extension String {
    var strippingVPrefix: String? {
        let stripped = hasPrefix("v") ? String(dropFirst()) : self
        return stripped.isEmpty ? nil : stripped
    }
}
