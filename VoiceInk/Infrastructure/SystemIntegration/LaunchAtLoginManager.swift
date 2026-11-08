import Combine
import Foundation
import ServiceManagement
import os

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled = false
    @Published private(set) var isUpdating = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var lastError: String?

    var isRequested: Bool { isEnabled || requiresApproval }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "LaunchAtLogin")
    private var isRefreshing = false
    private var operationGeneration = 0
    private var pendingEnabledState: Bool?
    private var updateTask: Task<Void, Never>?

    private init() {
        refresh()
    }

    func refresh() {
        guard !isRefreshing, !isUpdating else { return }

        isRefreshing = true
        let generation = operationGeneration

        Task {
            let state = await Self.readRegistrationState()
            isRefreshing = false

            guard generation == operationGeneration else { return }
            isEnabled = state.isEnabled
            requiresApproval = state.requiresApproval
        }
    }

    func setEnabled(_ enabled: Bool) {
        operationGeneration += 1
        lastError = nil
        requiresApproval = false
        isEnabled = enabled
        pendingEnabledState = enabled

        guard updateTask == nil else { return }

        isUpdating = true
        updateTask = Task { [weak self] in
            await self?.applyPendingEnabledStates()
        }
    }

    func currentEnabledStatus() async -> Bool {
        operationGeneration += 1

        while true {
            let generation = operationGeneration

            if let updateTask {
                await updateTask.value
                continue
            }

            let state = await Self.readRegistrationState()
            guard generation == operationGeneration, updateTask == nil else {
                continue
            }

            isEnabled = state.isEnabled
            requiresApproval = state.requiresApproval
            return isRequested
        }
    }

    private func applyPendingEnabledStates() async {
        while let enabled = pendingEnabledState {
            pendingEnabledState = nil
            let result = await Self.updateRegistration(enabled: enabled)

            if pendingEnabledState == nil {
                isEnabled = result.isEnabled
                requiresApproval = result.requiresApproval
                lastError = result.errorDescription
            }

            if let errorDescription = result.errorDescription {
                logger.error(
                    "Failed to \(enabled ? "enable" : "disable", privacy: .public) launch at login: \(errorDescription, privacy: .public)"
                )
            }
        }

        isUpdating = false
        updateTask = nil
    }

    private nonisolated static func readRegistrationState() async -> UpdateResult {
        await Task.detached(priority: .utility) {
            let status = SMAppService.mainApp.status
            return UpdateResult(isEnabled: status == .enabled, requiresApproval: status == .requiresApproval,
                                errorDescription: nil)
        }.value
    }

    private nonisolated static func updateRegistration(enabled: Bool) async -> UpdateResult {
        await Task.detached(priority: .utility) {
            let service = SMAppService.mainApp

            do {
                if enabled {
                    if service.status != .enabled && service.status != .requiresApproval {
                        try service.register()
                    }
                } else if service.status != .notRegistered {
                    try service.unregister()
                }
            } catch {
                return UpdateResult(
                    isEnabled: service.status == .enabled,
                    requiresApproval: service.status == .requiresApproval,
                    errorDescription: error.localizedDescription
                )
            }

            return UpdateResult(
                isEnabled: service.status == .enabled,
                requiresApproval: service.status == .requiresApproval,
                errorDescription: nil
            )
        }.value
    }

    private struct UpdateResult: Sendable {
        let isEnabled: Bool
        let requiresApproval: Bool
        let errorDescription: String?
    }
}
