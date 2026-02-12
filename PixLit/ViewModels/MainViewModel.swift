import AppKit

@MainActor
class MainViewModel: ObservableObject {
    @Published var lastExtractedText: String?
    @Published var lastCaptureDate: Date?
    @Published var isCapturing = false
    @Published var error: String?

    private let captureService = ScreenCaptureService.shared

    func captureAndExtract() {
        guard !isCapturing else { return }

        isCapturing = true
        error = nil

        Task {
            do {
                let text = try await captureService.captureAndExtractText()
                lastExtractedText = text
                lastCaptureDate = Date()
                NSSound(named: "Pop")?.play()
            } catch let captureError as CaptureError {
                switch captureError {
                case .cancelled:
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
