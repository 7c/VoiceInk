import SwiftUI

/// Shows whether an Apple Speech language is installed and offers to download a missing one.
/// macOS fetches the assets through its own system services; this process stays network-denied.
/// A download starts only when the user presses the button, and keeps running if this view goes away.
struct NativeAppleLanguageAssetControl: View {
    let localeIdentifier: String

    @State private var state: NativeAppleSpeechAssetState = .checking
    @State private var refreshGeneration = 0

    private static let failureDetailMaxWidth: CGFloat = 280
    private static let failureDetailLineLimit = 3
    private static let externalDownloadPollInterval: Duration = .seconds(2)

    private struct RefreshKey: Equatable {
        let localeIdentifier: String
        let generation: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statusRow
            failureDetail
        }
        .help(helpText)
        // Runs on every appearance and language change, and is cancelled when the view goes away.
        .task(id: RefreshKey(localeIdentifier: localeIdentifier, generation: refreshGeneration)) {
            await refreshAssetState()
        }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            indicator
            Text(statusText)
                .foregroundStyle(.secondary)
                .fixedSize()
            if let actionTitle {
                Button(actionTitle, action: startDownload)
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .checking, .downloading:
            ProgressView()
                .controlSize(.small)
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Status.positive)
        case .needsDownload:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.secondary)
        case .notSupported, .assetManagementUnavailable:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .reservationLimitReached:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppTheme.Status.warningStrong)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppTheme.Status.error)
        }
    }

    /// The system's own explanation of a failed download, e.g. that the Mac has no internet connection.
    @ViewBuilder
    private var failureDetail: some View {
        if case .failed(let message) = state {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(Self.failureDetailLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.failureDetailMaxWidth, alignment: .leading)
        }
    }

    private var statusText: String {
        switch state {
        case .checking:
            return String(localized: "Checking language…")
        case .downloaded:
            return String(localized: "Installed — ready for offline use")
        case .needsDownload:
            return String(localized: "Not installed")
        case .downloading:
            return String(localized: "Downloading from Apple…")
        case .notSupported:
            return String(localized: "Not supported on this Mac")
        case .assetManagementUnavailable:
            return String(localized: "Requires macOS 26 or later")
        case .reservationLimitReached:
            return String(localized: "Language slots are full")
        case .failed:
            return String(localized: "Download failed")
        }
    }

    private var actionTitle: String? {
        switch state {
        case .needsDownload:
            return String(localized: "Download")
        case .reservationLimitReached, .failed:
            return String(localized: "Retry")
        case .checking, .downloaded, .downloading, .notSupported, .assetManagementUnavailable:
            return nil
        }
    }

    private var helpText: String {
        switch state {
        case .checking:
            return String(localized: "Checking whether this Apple Speech language is downloaded.")
        case .downloaded:
            return String(localized: "Apple Speech language is downloaded.")
        case .needsDownload:
            return String(localized: "Download this Apple Speech language.")
        case .downloading:
            return String(localized: "Downloading assets for the selected Apple Speech language.")
        case .notSupported:
            return String(localized: "Apple Speech does not support this language.")
        case .assetManagementUnavailable:
            return String(localized: "Apple Speech language downloads are not available on this system.")
        case .reservationLimitReached:
            return String(localized: "Apple Speech could not replace a language reservation automatically. Try again.")
        case .failed(let message):
            return String(
                format: String(localized: "Apple Speech language download failed: %@"),
                message
            )
        }
    }

    private func refreshAssetState() async {
        let localeIdentifier = localeIdentifier
        let coordinator = NativeAppleSpeechAssetInstallCoordinator.shared

        // Follow a download this app already started, including one begun from another screen.
        if coordinator.isInstalling(localeIdentifier) {
            state = .downloading
            let result = await coordinator.install(localeIdentifier)
            guard !Task.isCancelled else { return }
            state = result
            return
        }

        state = .checking
        var resolvedState = await NativeAppleSpeechAssetManager.assetState(for: localeIdentifier)

        // macOS can report a download this app did not start; there is no task to wait on, so poll.
        while resolvedState == .downloading {
            guard !Task.isCancelled else { return }
            state = .downloading
            try? await Task.sleep(for: Self.externalDownloadPollInterval)
            resolvedState = await NativeAppleSpeechAssetManager.assetState(for: localeIdentifier)
        }

        guard !Task.isCancelled else { return }
        state = resolvedState
    }

    private func startDownload() {
        NativeAppleSpeechAssetInstallCoordinator.shared.begin(localeIdentifier)
        state = .downloading
        // Re-run the task so it follows the install that was just started.
        refreshGeneration += 1
    }
}
