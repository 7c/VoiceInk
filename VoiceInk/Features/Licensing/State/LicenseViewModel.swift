import Foundation
import Combine
@MainActor
final class LicenseViewModel: ObservableObject {
    enum LicenseState: Equatable { case unlicensed, trial(daysRemaining: Int), trialExpired, licensed }
    static let shared = LicenseViewModel()
    let licenseState: LicenseState = .licensed
    let licenseKey = ""
    let isLicensed = true
    let hasVerifiedLicense = true
    let canUseApp = true
    let activationsLimit = 0
    let diagnosticLicenseStatus = "Offline edition"
    let usageRestrictionMessage: String? = nil
    @Published var isValidating = false
    @Published var isDeactivating = false
    @Published var validationMessage: String?
    @Published var validationSuccess = false
    func startTrial() -> Bool { true }
    func refreshLicenseState() {}
    func retryPersistentStateLoad() {}
    func refreshTimeDependentState() {}
    func openPurchaseLink() {}
    func validateLicense(_ key: String) async { validationMessage = "No license is needed for this offline edition." }
    func deactivateLicense() async {}
}
