import Darwin
import Foundation

enum ShellCommandEnvironment {
    private static let shellPathQueue = DispatchQueue(label: "com.prakashjoshipax.voiceink.shell.path")
    private static var cachedPreferredPATH: String?
    private static let inheritedEnvironmentKeys = [
        "HOME",
        "USER",
        "LOGNAME",
        "SHELL",
        "TMPDIR",
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
    ]

    static func preferredPATH(fallback: String?) -> String {
        fallback ?? "/usr/bin:/bin:/usr/sbin:/sbin"
    }

    static func commandEnvironment(
        inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        additionalEnvironment: [String: String] = [:]
    ) -> [String: String] {
        var environment = inheritedEnvironmentKeys.reduce(into: [String: String]()) { result, key in
            if let value = inheritedEnvironment[key], !value.isEmpty {
                result[key] = value
            }
        }

        environment["PATH"] = preferredPATH(fallback: inheritedEnvironment["PATH"])
        setDefault("HOME", NSHomeDirectory(), in: &environment)
        setDefault("USER", NSUserName(), in: &environment)
        setDefault("LOGNAME", NSUserName(), in: &environment)
        setDefault("SHELL", "/bin/zsh", in: &environment)
        setDefault("TMPDIR", NSTemporaryDirectory(), in: &environment)

        additionalEnvironment.forEach { key, value in
            environment[key] = value
        }

        return environment
    }

    private static func setDefault(_ key: String, _ value: String, in environment: inout [String: String]) {
        guard environment[key]?.isEmpty ?? true else { return }
        environment[key] = value
    }



}
