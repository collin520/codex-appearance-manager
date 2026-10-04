import Foundation

public struct ThemeManifest: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let version: Int
    public let palette: [String]
    public let requiredSelectors: [String]

    public init(
        id: String,
        name: String,
        description: String,
        version: Int,
        palette: [String],
        requiredSelectors: [String]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.palette = palette
        self.requiredSelectors = requiredSelectors
    }

    public func validated() throws -> ThemeManifest {
        guard id.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil else {
            throw ThemeValidationError.invalidIdentifier(id)
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ThemeValidationError.emptyName
        }
        guard version > 0 else {
            throw ThemeValidationError.invalidVersion(version)
        }
        guard (2...6).contains(palette.count), palette.allSatisfy(Self.isValidHexColor) else {
            throw ThemeValidationError.invalidPalette
        }
        guard !requiredSelectors.isEmpty, requiredSelectors.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ThemeValidationError.invalidSelectors
        }
        return self
    }

    private static func isValidHexColor(_ color: String) -> Bool {
        color.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }
}

public struct ThemePackage: Equatable, Sendable {
    public let manifest: ThemeManifest
    public let directoryURL: URL
    public let stylesheetURL: URL

    public init(manifest: ThemeManifest, directoryURL: URL, stylesheetURL: URL) {
        self.manifest = manifest
        self.directoryURL = directoryURL
        self.stylesheetURL = stylesheetURL
    }
}

public enum ThemeValidationError: Error, Equatable, LocalizedError, Sendable {
    case invalidIdentifier(String)
    case emptyName
    case invalidVersion(Int)
    case invalidPalette
    case invalidSelectors
    case missingStylesheet

    public var errorDescription: String? {
        switch self {
        case .invalidIdentifier(let id): return "Theme identifier is invalid: \(id)"
        case .emptyName: return "Theme name cannot be empty."
        case .invalidVersion: return "Theme version must be positive."
        case .invalidPalette: return "Theme palette must contain two to six #RRGGBB colors."
        case .invalidSelectors: return "Theme must include at least one nonblank required selector."
        case .missingStylesheet: return "Theme stylesheet is missing."
        }
    }
}
