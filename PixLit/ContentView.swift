import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel
    @State private var showCopyConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            lastCapturedSection
            Divider()
            footerSection
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PixLit")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(HotkeyShortcut.load().displayString)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.quaternaryLabelColor))
                    .cornerRadius(4)
            }

            Button(action: {
                AppDelegate.shared?.triggerCapture()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 13))
                    Text("Capture Text")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isCapturing)

            statusView
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusView: some View {
        if viewModel.isCapturing {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Capturing...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        } else if let error = viewModel.error {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Last Captured

    private var lastCapturedSection: some View {
        Group {
            if let text = viewModel.lastExtractedText {
                VStack(alignment: .leading, spacing: 6) {
                    // Section header
                    HStack {
                        Image(systemName: "doc.plaintext")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Last Capture")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        if let date = viewModel.lastCaptureDate {
                            Text(Self.relativeString(from: date))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    // Card container
                    ZStack(alignment: .topTrailing) {
                        ScrollView {
                            Text(text)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .padding(.trailing, 16)
                                .textSelection(.enabled)
                        }

                        copyButton
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            } else {
                emptyStateView
            }
        }
        .frame(maxHeight: 308)
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button {
            if let text = viewModel.lastExtractedText {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                showCopyConfirmation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopyConfirmation = false
                }
            }
        } label: {
            Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10))
                .foregroundColor(showCopyConfirmation ? .green : .secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(4)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No captures yet")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.8))
            Text("Press \(HotkeyShortcut.load().displayString) to capture text")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    // MARK: - Helpers

    private static func relativeString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes == 1 { return "1 minute ago" }
        if minutes < 60 { return "\(minutes) minutes ago" }
        let hours = minutes / 60
        if hours == 1 { return "1 hour ago" }
        if hours < 24 { return "\(hours) hours ago" }
        let days = hours / 24
        if days == 1 { return "1 day ago" }
        return "\(days) days ago"
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 0) {
            Button(action: {
                AppDelegate.shared?.showSettings()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("Settings")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

