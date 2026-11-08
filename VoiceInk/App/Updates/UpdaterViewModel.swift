import SwiftUI
@MainActor
final class UpdaterViewModel: ObservableObject {
    let canCheckForUpdates = false
    let automaticallyChecksForUpdates = false
    func setAutomaticallyChecksForUpdates(_ value: Bool) {}
    func checkForUpdates() {}
}
struct CheckForUpdatesView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel
    var body: some View { EmptyView() }
}
