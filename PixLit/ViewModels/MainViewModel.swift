import AppKit

@MainActor
class MainViewModel: ObservableObject {
    @Published var lastExtractedText: String?
    @Published var isCapturing = false
    @Published var error: String?
    @Published var statusMessage: String?

    private let captureService = ScreenCaptureService.shared

    func captureAndExtract() {
        guard !isCapturing else { return }

        isCapturing = true
        error = nil
        statusMessage = nil

        Task {
            do {
                let text = try await captureService.captureAndExtractText()
                lastExtractedText = text
                statusMessage = "Text copied to clipboard!"
                NSSound(named: "Pop")?.play()
            } catch let captureError as CaptureError {
                switch captureError {
                case .cancelled:
                    // User cancelled — stay silent
                    break
                default:
                    self.error = captureError.localizedDescription
                    NSSound.beep()
                }
            } catch {
                self.error = error.localizedDescription
                NSSound.beep()
            }

            isCapturing = false
        }
    }
}
