import Foundation

public enum CodexResolution: Equatable, Sendable {
    case resolved(URL)
    case missing
    case invalidPreferredPath(URL)
}

public struct CodexResolver {
    private let fileManager: FileManager
    private let standardCandidates: [URL]

    public init(
        fileManager: FileManager = .default,
        standardCandidates: [URL] = [
            URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
            URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
        ]
    ) {
        self.fileManager = fileManager
        self.standardCandidates = standardCandidates
    }

    public func resolve(preferredPath: URL?) -> CodexResolution {
        if let preferredPath {
            return isApplicationBundle(preferredPath) ? .resolved(preferredPath) : .invalidPreferredPath(preferredPath)
        }

        if let candidate = standardCandidates.first(where: isApplicationBundle) {
            return .resolved(candidate)
        }
        return .missing
    }

    private func isApplicationBundle(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return url.pathExtension == "app" && fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
