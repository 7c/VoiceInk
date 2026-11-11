// Installs one Apple Speech language through the production asset manager while the production
// network guard is active. Passing proves that macOS, not this process, performs the download.
import Darwin
import Foundation
import Speech
enum LanguageDictionary { static let appleNative: [String: String] = [:] }
@main struct LanguageDownloadCheck {
    static func failure(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "LanguageDownloadCheck", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// True when this process cannot even open a loopback TCP connection.
    static func isOwnNetworkDenied() -> Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return errno == EPERM }
        defer { close(descriptor) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(9).bigEndian
        address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == -1 && errno == EPERM
    }

    static func main() async throws {
        let identifier = CommandLine.arguments[1]
        guard isOwnNetworkDenied() else {
            throw failure(1, "The network guard is not active in this process; refusing to request a download.")
        }
        let before = await NativeAppleSpeechAssetManager.assetState(for: identifier)
        switch before {
        case .notSupported:
            throw failure(2, "Apple Speech does not support \(identifier) on this Mac.")
        case .downloaded:
            print("NOTE: \(identifier) is already installed, so nothing was downloaded. Name a missing language to exercise a download.")
            return
        default:
            break
        }
        let result = await NativeAppleSpeechAssetManager.installAsset(for: identifier)
        guard result == .downloaded else {
            throw failure(3, "Installing \(identifier) ended as \(result). A download needs an internet connection.")
        }
        guard isOwnNetworkDenied() else {
            throw failure(4, "The network guard was no longer active after the download.")
        }
        print("PASS: macOS installed \(identifier) while this process stayed network-denied")
    }
}
