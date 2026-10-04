import AppKit

public protocol CodexLaunching: Sendable {
    func relaunchForInjection(appURL: URL) async throws
}

public enum CodexLauncherError: Error, Equatable, LocalizedError, Sendable {
    case applicationStillRunning

    public var errorDescription: String? {
        switch self {
        case .applicationStillRunning:
            return "Quit Codex completely before starting it with debugging enabled."
        }
    }
}

public final class CodexLauncher: CodexLaunching, @unchecked Sendable {
    public typealias ApplicationRunningChecker = @Sendable (String) -> Bool
    public typealias ProcessStarter = @Sendable (URL, [String]) throws -> Void

    public static let debuggingArguments = [
        "--remote-debugging-address=127.0.0.1",
        "--remote-debugging-port=39222",
        "--remote-allow-origins=http://127.0.0.1"
    ]

    private let isApplicationRunning: ApplicationRunningChecker
    private let startProcess: ProcessStarter

    public init(
        isApplicationRunning: @escaping ApplicationRunningChecker = { bundleIdentifier in
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
        },
        startProcess: @escaping ProcessStarter = { executableURL, arguments in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            try process.run()
        }
    ) {
        self.isApplicationRunning = isApplicationRunning
        self.startProcess = startProcess
    }

    public func relaunchForInjection(appURL: URL) async throws {
        let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier ?? "com.openai.codex"
        guard !isApplicationRunning(bundleIdentifier) else {
            throw CodexLauncherError.applicationStillRunning
        }
        try startProcess(executableURL(for: appURL), Self.debuggingArguments)
    }

    private func executableURL(for appURL: URL) -> URL {
        let executableName = Bundle(url: appURL)?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
            ?? appURL.deletingPathExtension().lastPathComponent
        return appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent(executableName)
    }
}
