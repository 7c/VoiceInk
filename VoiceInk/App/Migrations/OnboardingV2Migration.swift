import Foundation
enum OnboardingV2Migration {
    static let completedKey = OnboardingSettings.completedV2Key
    static func prepareIfNeeded(defaults: UserDefaults = .standard) {}
}
