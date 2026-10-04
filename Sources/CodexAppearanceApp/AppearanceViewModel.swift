import Foundation
import SwiftUI
import CodexAppearanceCore

public protocol ThemeManaging {
    var themesURL: URL { get }
    func bootstrap() throws
    func loadThemes() throws -> [ThemePackage]
    func save(css: String, for theme: ThemePackage) throws
}

extension ThemeRepository: ThemeManaging {}

public protocol ThemeInjecting: Sendable {
    func apply(_ theme: ThemePackage, using connection: CDPConnecting) async throws -> ThemeInjectionResult
    func restore(using connection: CDPConnecting) async throws
}

extension ThemeInjector: ThemeInjecting {}

public protocol CDPConnectionProviding: Sendable {
    func makeConnection() -> CDPConnecting
}

public struct LoopbackCDPConnectionProvider: CDPConnectionProviding {
    public init() {}

    public func makeConnection() -> CDPConnecting {
        CDPClient()
    }
}

public protocol CodexResolving {
    func resolve(preferredPath: URL?) -> CodexResolution
}

extension CodexResolver: CodexResolving {}

public enum AppearanceStatus: Equatable, Sendable {
    case idle
    case ready
    case injected(String)
    case incompatible([String])
    case restored
    case restartNeeded
    case quitCodexFirst
    case debugLaunchStarted
    case debugConnectionReady
    case missingApplication
    case failure(String)
}

@MainActor
public final class AppearanceViewModel: ObservableObject {
    @Published public private(set) var themes: [ThemePackage] = []
    @Published public var selectedThemeID: String?
    @Published public var cssDraft = ""
    @Published public private(set) var status: AppearanceStatus = .idle
    @Published public var preferredAppURL: URL?
    @Published public var restartConfirmationPresented = false

    private let themeStore: ThemeManaging
    private let injector: ThemeInjecting
    private let connectionProvider: CDPConnectionProviding
    private let launcher: CodexLaunching
    private let resolver: CodexResolving

    public init(
        themeStore: ThemeManaging,
        injector: ThemeInjecting,
        connectionProvider: CDPConnectionProviding,
        launcher: CodexLaunching,
        resolver: CodexResolving
    ) {
        self.themeStore = themeStore
        self.injector = injector
        self.connectionProvider = connectionProvider
        self.launcher = launcher
        self.resolver = resolver
    }

    public var selectedTheme: ThemePackage? {
        guard let selectedThemeID else { return nil }
        return themes.first { $0.manifest.id == selectedThemeID }
    }

    public var themesFolderURL: URL {
        themeStore.themesURL
    }

    public func load() {
        do {
            try themeStore.bootstrap()
            themes = try themeStore.loadThemes()
            guard let firstTheme = themes.first else {
                status = .failure("没有可用主题。")
                return
            }
            if selectedTheme == nil {
                selectedThemeID = firstTheme.manifest.id
            }
            try loadDraftForSelectedTheme()
            status = .ready
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    public func selectTheme(id: String?) {
        selectedThemeID = id
        do {
            try loadDraftForSelectedTheme()
            status = .ready
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    public func saveDraft() {
        guard let theme = selectedTheme else {
            status = .failure("请先选择一个主题。")
            return
        }
        do {
            try themeStore.save(css: cssDraft, for: theme)
            status = .ready
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    public func injectSelectedTheme() async {
        guard let theme = selectedTheme else {
            status = .failure("请先选择一个主题。")
            return
        }
        do {
            try themeStore.save(css: cssDraft, for: theme)
            let result = try await injector.apply(theme, using: connectionProvider.makeConnection())
            status = result.didInject ? .injected(result.themeID) : .incompatible(result.missingSelectors)
        } catch {
            status = needsRestart(for: error) ? .restartNeeded : .failure(error.localizedDescription)
        }
    }

    public func restoreOriginal() async {
        do {
            try await injector.restore(using: connectionProvider.makeConnection())
            status = .restored
        } catch {
            status = needsRestart(for: error) ? .restartNeeded : .failure(error.localizedDescription)
        }
    }

    public func restartAndInject() async {
        switch resolver.resolve(preferredPath: preferredAppURL) {
        case .resolved(let appURL):
            do {
                try await launcher.relaunchForInjection(appURL: appURL)
                status = .debugLaunchStarted
            } catch let error as CodexLauncherError where error == .applicationStillRunning {
                status = .quitCodexFirst
            } catch {
                status = .failure(error.localizedDescription)
            }
        case .missing, .invalidPreferredPath:
            status = .missingApplication
        }
    }

    public func checkCodexConnection() async {
        do {
            _ = try await connectionProvider.makeConnection().mainTarget()
            status = .debugConnectionReady
        } catch {
            status = needsRestart(for: error) ? .restartNeeded : .failure(error.localizedDescription)
        }
    }

    private func loadDraftForSelectedTheme() throws {
        guard let theme = selectedTheme else {
            cssDraft = ""
            return
        }
        cssDraft = try String(contentsOf: theme.stylesheetURL, encoding: .utf8)
    }

    private func needsRestart(for error: Error) -> Bool {
        if let error = error as? CDPClientError, error == .mainTargetUnavailable {
            return true
        }
        return error is URLError
    }
}

@MainActor
public extension AppearanceViewModel {
    static func makeDefault() -> AppearanceViewModel {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let packagedThemesURL = Bundle.main.resourceURL?
            .appendingPathComponent("CodexAppearanceManager_CodexAppearanceUI.bundle/Resources/StarterThemes", isDirectory: true)
        let bundledThemesURL: URL
        if let packagedThemesURL, FileManager.default.fileExists(atPath: packagedThemesURL.path) {
            bundledThemesURL = packagedThemesURL
        } else {
            bundledThemesURL = Bundle.module.url(forResource: "Resources/StarterThemes", withExtension: nil)!
        }
        return AppearanceViewModel(
            themeStore: ThemeRepository(applicationSupportURL: applicationSupportURL, bundledThemesURL: bundledThemesURL),
            injector: ThemeInjector(),
            connectionProvider: LoopbackCDPConnectionProvider(),
            launcher: CodexLauncher(),
            resolver: CodexResolver()
        )
    }
}
