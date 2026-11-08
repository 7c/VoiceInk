import Darwin
import Foundation
import os

struct CustomCommandDeliveryContext {
    let transcript: String

    var standardInput: String {
        transcript
    }

    var environment: [String: String] {
        [
            "VOICEINK_TRANSCRIPT": transcript
        ]
    }
}

struct CustomCommandDeliveryResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

enum CustomCommandDeliveryError: Error, LocalizedError {
    case commandNotConfigured
    case noTextToDeliver
    case launchFailed(String)
    case timeout(seconds: Double)
    case nonZeroExit(status: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .commandNotConfigured:
            return String(localized: "Custom command is empty.")
        case .noTextToDeliver:
            return String(localized: "No transcription text was available for the custom command.")
        case .launchFailed(let message):
            return String(format: String(localized: "Custom command could not start: %@"), message)
        case .timeout(let seconds):
            return String(format: String(localized: "Custom command timed out after %.0f seconds."), seconds)
        case .nonZeroExit(let status, let stderr):
            let details = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if details.isEmpty {
                return String(format: String(localized: "Custom command exited with status %d."), status)
            }
            return String(
                format: String(localized: "Custom command exited with status %d: %@"), status,
                String(details.prefix(300)))
        }
    }
}

enum CustomCommandDeliveryRunner {
    static func run(command: String, timeout: TimeInterval, context: CustomCommandDeliveryContext) async throws -> CustomCommandDeliveryResult { throw OfflineMode.unavailable }
}
