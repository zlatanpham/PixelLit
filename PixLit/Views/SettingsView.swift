import SwiftUI

// MARK: - Settings Tab

private enum SettingsTab: String, CaseIterable {
    case general = "General"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gear"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .frame(width: 420, height: 540)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.vertical, 6)
    }

    private func tabButton(for tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22))
                    .frame(width: 24, height: 24)
                Text(tab.rawValue)
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color(nsColor: .separatorColor).opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            GeneralTabView()
        case .about:
            AboutTabView()
        }
    }
}

// MARK: - General Tab

private struct GeneralTabView: View {
    @StateObject private var launchManager = LaunchAtLoginManager()
    @State private var shortcut = HotkeyShortcut.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                settingsSection("SYSTEM") {
                    SettingsToggleRow(
                        title: "Launch at Login",
                        description: "Automatically opens PixLit when you start your Mac.",
                        isOn: $launchManager.isEnabled
                    )
                }

                sectionDivider()

                settingsSection("SHORTCUT") {
                    HStack {
                        Text("Capture Screen Region")
                            .font(.system(size: 13))
                        Spacer()
                        ShortcutRecorderView(shortcut: $shortcut) { newShortcut in
                            newShortcut.save()
                            AppDelegate.shared?.updateHotkey(shortcut: newShortcut)
                        }
                        Button {
                            shortcut = .default
                            HotkeyShortcut.default.save()
                            AppDelegate.shared?.updateHotkey(shortcut: .default)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Reset to default (\(HotkeyShortcut.default.displayString))")
                        .opacity(shortcut != .default ? 1 : 0)
                        .allowsHitTesting(shortcut != .default)
                    }
                }

                sectionDivider()

                Spacer(minLength: 24)

                HStack {
                    Spacer()
                    Button("Quit PixLit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Section Helpers

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 16)
            content()
        }
    }

    private func sectionDivider() -> some View {
        Divider()
            .padding(.top, 14)
    }
}

// MARK: - Settings Toggle Row

private struct SettingsToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.checkbox)
                .font(.system(size: 13))
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - About Tab

private enum UpdateCheckState {
    case idle
    case checking
    case upToDate
    case available(version: String, url: URL)
    case error(String)
}

private struct AboutTabView: View {
    @State private var updateState: UpdateCheckState = .idle

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "text.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("PixLit")
                .font(.system(size: 18, weight: .semibold))

            Text("Version \(appVersion)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Extract text from any screen region")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            updateSection

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var updateSection: some View {
        Group {
            switch updateState {
            case .idle:
                Button("Check for Updates") {
                    checkForUpdate()
                }
                .buttonStyle(.bordered)

            case .checking:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking for updates...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

            case .upToDate:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You're up to date!")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

            case let .available(version, url):
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        Text("Version \(version) is available")
                            .font(.system(size: 12))
                    }
                    Button("Download Update") {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                }

            case let .error(message):
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Button("Retry") {
                        checkForUpdate()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(height: 50, alignment: .center)
    }

    private func checkForUpdate() {
        updateState = .checking
        Task {
            do {
                let status = try await UpdateService.shared.checkForUpdate()
                switch status {
                case .upToDate:
                    updateState = .upToDate
                case let .available(version, url):
                    updateState = .available(version: version, url: url)
                }
            } catch {
                updateState = .error(error.localizedDescription)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

#Preview {
    SettingsView()
}
