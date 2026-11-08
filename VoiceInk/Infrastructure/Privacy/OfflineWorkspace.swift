import AppKit
/// External URLs could delegate networking to a browser or email app; never open them.
enum OfflineWorkspace {
    @discardableResult
    static func open(_ url: URL) -> Bool {
        guard url.scheme == "x-apple.systempreferences" else { return false }
        return NSWorkspace.shared.open(url)
    }
}
