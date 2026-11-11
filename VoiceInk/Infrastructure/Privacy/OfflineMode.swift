import Foundation

enum OfflineMode: LocalizedError {
    case unavailable
    var errorDescription: String? {
        "This feature was removed from the offline edition. Use Apple Speech with an installed language."
    }
}
