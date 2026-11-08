import Foundation
import os

#if canImport(Speech)
    import Speech
#endif

enum NativeAppleSpeechAssetState: Equatable {
    case checking
    case downloaded
    case needsDownload
    case downloading
    case notSupported
    case assetManagementUnavailable
    case reservationLimitReached
    case failed(String)
}

enum NativeAppleSpeechAssetManager {
    static func languageDisplayName(for identifier: String) -> String {
        LanguageDictionary.appleNative[identifier] ?? identifier
    }
    static func assetState(for localeIdentifier: String) async -> NativeAppleSpeechAssetState {
        guard #available(macOS 26, *) else { return .assetManagementUnavailable }
        return await assetContext(for: localeIdentifier) == nil ? .needsDownload : .downloaded
    }
    static func installAsset(for localeIdentifier: String) async -> NativeAppleSpeechAssetState {
        .failed("Downloads are disabled in the offline edition. Use an already installed language.")
    }
    static func prepareAssetForUse(for localeIdentifier: String) async -> NativeAppleSpeechAssetState {
        await assetState(for: localeIdentifier)
    }
    @available(macOS 26, *)
    struct AssetContext {
        let locale: Locale
        let transcriber: SpeechTranscriber
        var localeIdentifier: String { locale.identifier(.bcp47) }
        var displayName: String { languageDisplayName(for: localeIdentifier) }
        var isInstalled: Bool { true }
        var status: AssetInventory.Status { .installed }
    }
    @available(macOS 26, *)
    static func assetContext(for identifier: String) async -> AssetContext? {
        let requested = Locale(identifier: identifier).identifier(.bcp47)
        guard let locale = await SpeechTranscriber.installedLocales.first(where: {
            $0.identifier(.bcp47) == requested
        }) else { return nil }
        return AssetContext(locale: locale, transcriber: SpeechTranscriber(locale: locale, preset: .transcription))
    }
    @available(macOS 26, *)
    static func reserveLocaleIfNeeded(for context: AssetContext) async -> Bool { true }
}
