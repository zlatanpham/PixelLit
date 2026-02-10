import AppKit

enum CaptureError: LocalizedError {
    case cancelled
    case noImageInClipboard
    case captureProcessFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Screen capture was cancelled."
        case .noImageInClipboard:
            return "No image found in clipboard after capture."
        case .captureProcessFailed(let code):
            return "Screen capture failed with exit code \(code)."
        }
    }
}

actor ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private let ocrService = OCRService.shared

    func captureAndExtractText() async throws -> String {
        // Step 1: Run screencapture -ic (interactive, to clipboard)
        let exitCode = try await runScreenCapture()

        // Exit code 1 means user cancelled
        if exitCode != 0 {
            throw CaptureError.cancelled
        }

        // Step 2: Read image from clipboard
        let image = try await readImageFromClipboard()

        // Step 3: OCR the image
        let text = try await ocrService.recognizeText(from: image)

        // Step 4: Write extracted text to clipboard
        await writeTextToClipboard(text)

        return text
    }

    private func runScreenCapture() async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-ic"]

            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: CaptureError.captureProcessFailed(-1))
            }
        }
    }

    @MainActor
    private func readImageFromClipboard() throws -> NSImage {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard) else {
            throw CaptureError.noImageInClipboard
        }
        return image
    }

    @MainActor
    private func writeTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
