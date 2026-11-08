import SwiftUI
struct LicenseManagementView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VoiceInk Offline").font(.largeTitle.bold())
            Text("All local features are available. No account, subscription, or license validation is required.")
            Text("Uses Apple Speech with installed language assets. Network access is denied by the operating system before the app starts.")
                .foregroundStyle(.secondary)
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
