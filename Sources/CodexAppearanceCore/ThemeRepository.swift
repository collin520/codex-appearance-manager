import Foundation

public enum ThemeRepositoryError: Error, LocalizedError, Equatable, Sendable {
    case emptyStylesheet

    public var errorDescription: String? {
        switch self {
        case .emptyStylesheet: return "Theme stylesheet cannot be empty."
        }
    }
}

public final class ThemeRepository {
    public typealias ExistingFileReplacer = (URL, URL) throws -> Void

    private let fileManager: FileManager
    private let applicationSupportURL: URL
    private let bundledThemesURL: URL
    private let replaceExistingFile: ExistingFileReplacer?

    public init(
        fileManager: FileManager = .default,
        applicationSupportURL: URL,
        bundledThemesURL: URL,
        replaceExistingFile: ExistingFileReplacer? = nil
    ) {
        self.fileManager = fileManager
        self.applicationSupportURL = applicationSupportURL
        self.bundledThemesURL = bundledThemesURL
        self.replaceExistingFile = replaceExistingFile
    }

    public var themesURL: URL {
        applicationSupportURL
            .appendingPathComponent("CodexAppearanceManager", isDirectory: true)
            .appendingPathComponent("themes", isDirectory: true)
    }

    public func bootstrap() throws {
        try fileManager.createDirectory(at: themesURL, withIntermediateDirectories: true)
        for bundledThemeURL in try themeDirectories(in: bundledThemesURL) {
            guard let manifest = try? decodeManifest(at: bundledThemeURL) else { continue }
            let destination = themesURL.appendingPathComponent(manifest.id, isDirectory: true)
            if fileManager.fileExists(atPath: destination.path) {
                try synchronizeMissingItems(from: bundledThemeURL, to: destination)
            } else {
                try fileManager.copyItem(at: bundledThemeURL, to: destination)
            }
        }
    }

    public func loadThemes() throws -> [ThemePackage] {
        var seenIDs = Set<String>()
        var packages: [ThemePackage] = []

        for directoryURL in try themeDirectories(in: themesURL) {
            guard let manifest = try? decodeManifest(at: directoryURL), !seenIDs.contains(manifest.id) else { continue }
            let stylesheetURL = directoryURL.appendingPathComponent("style.css")
            guard fileManager.fileExists(atPath: stylesheetURL.path) else { continue }
            seenIDs.insert(manifest.id)
            packages.append(ThemePackage(manifest: manifest, directoryURL: directoryURL, stylesheetURL: stylesheetURL))
        }

        return packages.sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
    }

    public func save(css: String, for theme: ThemePackage) throws {
        guard !css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ThemeRepositoryError.emptyStylesheet
        }

        let destination = theme.stylesheetURL
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(".style-\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporary) }
        try Data(css.utf8).write(to: temporary, options: .withoutOverwriting)

        if fileManager.fileExists(atPath: destination.path) {
            if let replaceExistingFile {
                try replaceExistingFile(destination, temporary)
            } else {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
            }
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    private func themeDirectories(in parentURL: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: parentURL.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Copies only new packaged files into an existing user theme directory.
    /// This lets a theme gain background assets without replacing user-edited CSS.
    private func synchronizeMissingItems(from source: URL, to destination: URL) throws {
        for sourceItem in try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            let destinationItem = destination.appendingPathComponent(sourceItem.lastPathComponent)
            guard !fileManager.fileExists(atPath: destinationItem.path) else {
                let isDirectory = (try? sourceItem.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isDirectory {
                    try synchronizeMissingItems(from: sourceItem, to: destinationItem)
                }
                continue
            }
            try fileManager.copyItem(at: sourceItem, to: destinationItem)
        }
    }

    private func decodeManifest(at directoryURL: URL) throws -> ThemeManifest {
        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(ThemeManifest.self, from: data).validated()
    }
}
