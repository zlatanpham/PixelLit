import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            mainContent
            Divider()
            footerView
        }
        .frame(width: 350, height: 400)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("PixLit")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 12) {
            Spacer()

            // Capture button
            Button(action: {
                AppDelegate.shared?.triggerCapture()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 16))
                    Text("Capture & Extract Text")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isCapturing)
            .padding(.horizontal, 20)

            Text("or press  \u{2318}\u{21E7}2")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Status area
            statusView

            // Text preview
            if let text = viewModel.lastExtractedText {
                textPreview(text)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusView: some View {
        if viewModel.isCapturing {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Capturing...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        } else if let message = viewModel.statusMessage {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        } else if let error = viewModel.error {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Text Preview

    private func textPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Extracted Text")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 150)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Settings...") {
                AppDelegate.shared?.showSettings()
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
