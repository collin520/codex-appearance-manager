import Foundation
import CodexAppearanceCore
import CodexAppearanceUI

enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message): return message
        }
    }
}

@discardableResult
func test(_ name: String, _ body: () throws -> Void) -> Bool {
    do {
        try body()
        print("PASS \(name)")
        return true
    } catch {
        print("FAIL \(name): \(error)")
        return false
    }
}

func expectThrows(_ body: () throws -> Void) throws {
    do {
        try body()
        throw TestFailure.assertion("expected an error")
    } catch is TestFailure {
        throw TestFailure.assertion("expected an error")
    } catch {
        return
    }
}

@discardableResult
func asyncTest(_ name: String, _ body: () async throws -> Void) async -> Bool {
    do {
        try await body()
        print("PASS \(name)")
        return true
    } catch {
        print("FAIL \(name): \(error)")
        return false
    }
}

func expectAsyncThrows(_ body: @escaping @Sendable () async throws -> Void) async throws {
    do {
        try await body()
        throw TestFailure.assertion("expected an error")
    } catch is TestFailure {
        throw TestFailure.assertion("expected an error")
    } catch {
        return
    }
}

func runtimeValue(_ value: JSONValue) -> JSONValue {
    .object(["result": .object(["value": value])])
}

actor RecordingCDP: CDPConnecting {
    private let target = CDPTarget(
        id: "main",
        type: "page",
        url: "app://-/index.html",
        webSocketDebuggerURL: "ws://127.0.0.1/devtools/page/main"
    )
    private var responses: [JSONValue]
    private var expressions: [String] = []

    init(responses: [JSONValue]) {
        self.responses = responses
    }

    func mainTarget() async throws -> CDPTarget {
        target
    }

    func evaluate(_ expression: String, on target: CDPTarget) async throws -> JSONValue {
        expressions.append(expression)
        guard !responses.isEmpty else {
            throw TestFailure.assertion("unexpected CDP evaluation")
        }
        return responses.removeFirst()
    }

    func capturedExpressions() -> [String] {
        expressions
    }
}

actor RecordingApplicationOpener {
    private var calls: [(URL, [String])] = []

    func record(appURL: URL, arguments: [String]) {
        calls.append((appURL, arguments))
    }

    func snapshot() -> [(URL, [String])] {
        calls
    }
}

final class ProcessRecorder: @unchecked Sendable {
    private(set) var calls: [(URL, [String])] = []

    func record(executableURL: URL, arguments: [String]) {
        calls.append((executableURL, arguments))
    }
}

actor UnavailableCDP: CDPConnecting {
    func mainTarget() async throws -> CDPTarget {
        throw CDPClientError.mainTargetUnavailable
    }

    func evaluate(_ expression: String, on target: CDPTarget) async throws -> JSONValue {
        throw CDPClientError.mainTargetUnavailable
    }
}

final class FixtureThemeStore: ThemeManaging {
    var themes: [ThemePackage]
    let themesURL: URL

    init(theme: ThemePackage) {
        themes = [theme]
        themesURL = theme.directoryURL
    }

    func bootstrap() throws {}

    func loadThemes() throws -> [ThemePackage] {
        themes
    }

    func save(css: String, for theme: ThemePackage) throws {
        try Data(css.utf8).write(to: theme.stylesheetURL)
    }
}

final class FixtureInjector: ThemeInjecting, @unchecked Sendable {
    var applyResult: Result<ThemeInjectionResult, Error>

    init(applyResult: Result<ThemeInjectionResult, Error>) {
        self.applyResult = applyResult
    }

    func apply(_ theme: ThemePackage, using connection: CDPConnecting) async throws -> ThemeInjectionResult {
        try applyResult.get()
    }

    func restore(using connection: CDPConnecting) async throws {}
}

struct FixtureConnectionProvider: CDPConnectionProviding {
    func makeConnection() -> CDPConnecting {
        RecordingCDP(responses: [])
    }
}

struct UnavailableConnectionProvider: CDPConnectionProviding {
    func makeConnection() -> CDPConnecting {
        UnavailableCDP()
    }
}

final class FixtureLauncher: CodexLaunching, @unchecked Sendable {
    private(set) var calls = 0

    func relaunchForInjection(appURL: URL) async throws {
        calls += 1
    }
}

struct FixtureResolver: CodexResolving {
    let resolution: CodexResolution

    func resolve(preferredPath: URL?) -> CodexResolution {
        resolution
    }
}

func starterThemeURL(id: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/CodexAppearanceApp/Resources/StarterThemes/\(id)")
}

func projectRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}

func writeTheme(id: String, at root: URL, css: String = "body { color: white; }") throws -> URL {
    let directory = root.appendingPathComponent(id, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let manifest = ThemeManifest(id: id, name: id, description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"])
    let manifestData = try JSONEncoder().encode(manifest)
    try manifestData.write(to: directory.appendingPathComponent("manifest.json"))
    try css.data(using: .utf8)!.write(to: directory.appendingPathComponent("style.css"))
    return directory
}

let results = [
    test("manifest rejects an invalid identifier") {
        let manifest = ThemeManifest(id: "Aurora Neon", name: "Aurora", description: "Test theme", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-project-row]"])
        try expectThrows { _ = try manifest.validated() }
    },
    test("manifest rejects an invalid palette") {
        let manifest = ThemeManifest(id: "aurora-neon", name: "Aurora", description: "Test theme", version: 1, palette: ["cyan", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-project-row]"])
        try expectThrows { _ = try manifest.validated() }
    },
    test("manifest rejects blank required selectors") {
        let manifest = ThemeManifest(id: "aurora-neon", name: "Aurora", description: "Test theme", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["  "])
        try expectThrows { _ = try manifest.validated() }
    },
    test("starter manifests decode as distinct valid themes") {
        let themeIDs = ["aurora-neon", "rainy-neon"]
        let manifests = try themeIDs.map { id in
            let data = try Data(contentsOf: starterThemeURL(id: id).appendingPathComponent("manifest.json"))
            return try JSONDecoder().decode(ThemeManifest.self, from: data).validated()
        }
        guard Set(manifests.map(\.id)) == Set(themeIDs) else {
            throw TestFailure.assertion("starter theme IDs were not distinct")
        }
    },
    test("rainy neon stylesheet defines readable neon typography") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "font-family",
            "textarea",
            "[contenteditable=\"true\"]",
            "#f7fbff",
            "::placeholder",
            "data-user-message-bubble",
            "#fff36d",
            "data-markdown-text-style=\"assistant-message\"",
            "#ff9edb"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing its readable typography rules")
        }
    },
    test("rainy neon styles edited-file results as blue neon cards") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        guard stylesheet.contains("turn-diff-header"),
              stylesheet.contains("rgba(81, 220, 255"),
              stylesheet.contains("bg-surface/70"),
              stylesheet.contains("bg-surface-secondary/92") else {
            throw TestFailure.assertion("Rainy Neon is missing the edited-file result card treatment")
        }
    },
    test("rainy neon styles live activity status, summaries, and file cues") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "activity-header",
            "_cadencedShimmer_",
            "_summary_",
            "data-in-progress-fixed-content",
            "bg-background-primary-soft/70",
            "bg-background-primary-soft/70\"] [class*=\"text-codex-git-added\"]",
            "#7cecff",
            "#b7eaff",
            "rgba(27, 48, 111"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing readable live activity styling")
        }
    },
    test("rainy neon styles settings and profile menu surfaces") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "input[placeholder*=\"搜索\"]",
            "打开个人资料菜单",
            "[role=\"menu\"]",
            "--app-color-background-surface",
            "--color-background-primary-soft",
            "#d8f6ff",
            "button[aria-label=\"停止\"]",
            "--color-background-composer-primary",
            "[data-composer-footer-responsive]",
            "[data-codex-composer]",
            "[role=\"tooltip\"]",
            ":root[data-codex-appearance-manager-theme=\"rainy-neon\"] [role=\"menu\"][data-radix-menu-content]",
            "button[aria-label=\"显示标签页\"]",
            "[role=\"dialog\"][data-slot=\"popover-content\"]",
            "[data-explore-row]",
            "data-app-shell-tab-controller",
            "_SelectedSurface_",
            "--color-background-primary-solid",
            "button.bg-primary-solid"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing settings and profile-menu styling")
        }
    },
    test("rainy neon styles selected app tabs without depending on a controller wrapper") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            ":root[data-codex-appearance-manager-theme=\"rainy-neon\"] [data-tab-id]:has(> [role=\"tab\"][aria-selected=\"true\"]) > div[class*=\"_SelectedSurface_\"]",
            "rgba(25, 86, 121, 0.94)",
            "rgba(37, 18, 78, 0.96)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the controller-independent selected-tab surface treatment")
        }
    },
    test("rainy neon styles the selected-text action toolbar as dark neon glass") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "div.pointer-events-none.w-max.fixed.z-50 [role=\"presentation\"][class*=\"bg-surface-elevated-secondary/90\"]",
            "bg-surface-elevated-secondary/90",
            "rgba(5, 23, 54, 0.98)",
            "rgba(48, 14, 78, 0.96)",
            "border-right-color: rgba(106, 228, 255, 0.22)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the selected-text action-toolbar treatment")
        }
    },
    test("rainy neon styles the current conversation selected-text action panel") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "div.pointer-events-none.w-max.fixed.z-50 [role=\"presentation\"][class~=\"bg-surface-elevated-secondary\"]",
            "bg-surface-elevated-secondary\"] > button",
            "bg-surface-elevated-secondary\"] > div[aria-hidden=\"true\"][class~=\"bg-border\"]",
            "rgba(5, 23, 54, 0.98)",
            "#dff8ff"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the current conversation selected-text action-panel treatment")
        }
    },
    test("rainy neon styles project management dialogs and history hover cards") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[role=\"alertdialog\"]",
            ":not([data-slot=\"popover-content\"])",
            "[data-slot=\"hover-card-content\"]",
            "[data-radix-hover-card-content]",
            "rgba(5, 20, 49, 0.98)",
            "rgba(5, 21, 50, 0.98)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing project-dialog and history-hover-card styling")
        }
    },
    test("rainy neon styles the create-project symbol picker inner surface") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-symbol-picker]",
            "[data-symbol-picker-header]",
            "rgba(5, 23, 54, 0.98)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style the create-project symbol picker inner surface")
        }
    },
    test("rainy neon styles approval requests and file-diff hover previews as neon glass") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-codex-approval-surface]",
            "rgba(5, 22, 54, 0.985)",
            "[role=\"tooltip\"][class~=\"group/diff-preview\"]",
            "[data-testid=\"diff-preview-scroll\"]",
            "rgba(7, 27, 62, 0.97)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing approval-request and file-diff-preview styling")
        }
    },
    test("rainy neon passes dark diff palette tokens into file-preview renderers") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "composer-diff-simple-line",
            "--color-surface: rgba(7, 27, 62, 0.97)",
            "--color-codex-diff-surface: rgba(7, 27, 62, 0.97)",
            "--diffs-light-bg: rgba(7, 27, 62, 0.97)",
            "--diffs-dark-bg: rgba(7, 27, 62, 0.97)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the inherited dark palette for file-diff renderers")
        }
    },
    test("rainy neon gives the current-thread timeline preview its own neon card") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "button[aria-label^=\"跳转到用户消息\"]:hover",
            "padding: 14px 16px !important;",
            "border-left-color: #6ae4ff !important;",
            "border-right-color: #ff8bd6 !important;",
            "[class*=\"bg-surface-elevated-secondary\"]",
            "background: rgba(7, 25, 58, 0.94) !important;"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the current-thread timeline preview-card treatment")
        }
    },
    test("rainy neon styles code-review comment resource cards as dark neon surfaces") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "bg-surface-elevated-secondary/50",
            "extension:bg-background-primary-soft/50",
            "background: linear-gradient(135deg, rgba(6, 25, 56, 0.96)",
            "bg-surface-secondary/92",
            "#ff9edb"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing dark styling for code-review comment resource cards")
        }
    },
    test("rainy neon styles document resource cards with an open-method control as dark neon surfaces") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            ".end-resource-open-button",
            ".group\\/resource-card",
            "@layer utilities",
            "background: linear-gradient(135deg, rgba(5, 25, 56, 0.96)",
            "rgba(7, 37, 76, 0.92)",
            "#dff8ff"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing dark styling for document resource cards and their open-method controls")
        }
    },
    test("rainy neon styles the image prompt composer as a dark glass surface") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "aria-label=\"描述要创建的图像\"",
            "data-composer-placement=\"home\"",
            "--cam-image-composer-surface",
            "rgba(7, 26, 56"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the image prompt composer treatment")
        }
    },
    test("rainy neon gives the utility sidebar destinations including Your dot phased neon lighting") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "cam-rail-neon-cycle",
            "builtin:home",
            "builtin:automations",
            "builtin:library",
            "builtin:images",
            "builtin:customize",
            "builtin:orbit",
            "img.icon-leading",
            "data-slot=\"popover-trigger\"",
            "prefers-reduced-motion",
            "button[data-selected]"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing phased lighting for the sidebar destinations including Your dot")
        }
        guard !stylesheet.contains("color: var(--cam-rain-cyan) !important;") else {
            throw TestFailure.assertion("an important sidebar color prevents the neon animation from changing color")
        }
    },
    test("rainy neon uses the distant skyline duel scene as its current background asset") {
        let themeDirectory = starterThemeURL(id: "rainy-neon")
        let stylesheet = try String(contentsOf: themeDirectory.appendingPathComponent("style.css"), encoding: .utf8)
        let asset = themeDirectory.appendingPathComponent("rainy-skyline-duel-v1.png")
        guard stylesheet.contains("__CAM_THEME_ASSET__/rainy-skyline-duel-v1.png"),
              FileManager.default.fileExists(atPath: asset.path) else {
            throw TestFailure.assertion("Rainy Neon is missing its distant skyline duel-scene background asset")
        }
    },
    test("rainy neon styles the thread summary panel as a glass overlay") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-summary-panel-variant]",
            "thread-summary-panel-item",
            "thread-summary-panel-icon-button",
            "summary-panel-item-button"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing thread summary-panel styling")
        }
    },
    test("rainy neon makes the project sidebar fully transparent") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "#app-shell-sidebar .sidebar-navigation",
            "background: transparent !important;",
            "backdrop-filter: none;"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing its fully transparent project-sidebar treatment")
        }
    },
    test("rainy neon leaves ordinary sidebar rows transparent") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        guard !stylesheet.contains("background: rgba(8, 17, 41, 0.42);") else {
            throw TestFailure.assertion("the default sidebar rows still obscure the background")
        }
    },
    test("rainy neon leaves the conversation turn shell transparent") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let opaqueTurnSurfaces = [
            "rgba(10, 13, 37, 0.8)",
            "rgba(8, 13, 33, 0.7)"
        ]
        guard opaqueTurnSurfaces.allSatisfy({ !stylesheet.contains($0) }) else {
            throw TestFailure.assertion("the conversation turn shell still obscures the background")
        }
    },
    test("rainy neon styles plain-text code block headers as neon glass") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-markdown-copy=\"code-block\"] > [data-markdown-copy=\"exclude\"]",
            "rgba(5, 23, 54, 0.98)",
            "code-block\"] > [data-markdown-copy=\"exclude\"] :is(span, button, svg)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the plain-text code block title-bar treatment")
        }
    },
    test("rainy neon replaces the current light Bash code surface") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-markdown-copy=\"code-block\"][data-theme=\"light\"]",
            "rgba(5, 23, 54, 0.98)",
            "#dff8ff"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not replace the current renderer's light Bash code surface")
        }
    },
    test("rainy neon styles ChatGPT chat and work composer surfaces") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "form[data-composer-placement]:has([data-composer-markdown])",
            "[data-composer-footer-responsive]",
            "[data-composer-markdown]"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the shared ChatGPT chat/work composer treatment")
        }
    },
    test("rainy neon styles the ChatGPT Work home composer without markdown editor metadata") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "form[data-composer-placement=\"home\"]:not(:has([aria-label=\"描述要创建的图像\"]))",
            "[data-composer-footer-responsive]",
            "rgba(4, 13, 32, 0.97)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the metadata-independent ChatGPT Work home-composer treatment")
        }
    },
    test("rainy neon gives Your dot outgoing messages a pale-blue surface with warm-yellow text") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "main.thread-pane[style*=\"--messaging-outgoing-background\"]",
            "article.message-row.self",
            "rgba(16, 74, 119, 0.86)",
            "#ffe46b"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style Your dot outgoing messages as pale-blue cards with warm-yellow text")
        }
    },
    test("rainy neon gives the Your dot thread the shared skyline backdrop") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "main.thread-pane[style*=\"--messaging-outgoing-background\"] {",
            "url(\"__CAM_THEME_ASSET__/rainy-skyline-duel-v1.png\") center / cover fixed",
            "rgba(5, 10, 27, 0.48)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not give the Your dot thread the shared skyline backdrop")
        }
    },
    test("rainy neon clears the native Work home body after switching modes") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-codex-composer-root][data-composer-placement=\"home\"]:has([data-composer-input-variant=\"work-home\"])",
            "[data-composer-body]",
            "background: transparent !important"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not clear ChatGPT Work's native white home composer body")
        }
    },
    test("rainy neon styles the Work-only home utility rail below the composer") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-composer-rail-item][data-composer-rail-placement=\"below\"]",
            "bg-background-composer-action-bar",
            "rgba(5, 21, 49, 0.9)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style ChatGPT Work's below-composer utility rail")
        }
    },
    test("rainy neon clears the native Codex project-home composer body and project rail") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-codex-composer-root][data-composer-placement=\"home\"]:has([data-composer-input-variant=\"default\"])",
            "[data-composer-body]",
            "[data-composer-rail-placement=\"above\"]",
            "rgba(5, 21, 49, 0.9)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style Codex project-home's white composer body and project rail")
        }
    },
    test("rainy neon styles the ChatGPT selected-text formatting toolbar") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[aria-label=\"文本格式\"]",
            "[aria-label=\"Text formatting\"]",
            "[aria-label=\"文字格式設定\"]"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon is missing the selected-text formatting-toolbar treatment")
        }
    },
    test("rainy neon styles the inner surface of ChatGPT's text-formatting popover") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[role=\"dialog\"][aria-label=\"文本格式\"][data-slot=\"popover-content\"] > [role=\"presentation\"]",
            "bg-surface-elevated-secondary",
            "rgba(5, 23, 54, 0.98)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style the white inner surface of ChatGPT's text-formatting popover")
        }
    },
    test("rainy neon styles the top archive toast as dark neon glass") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-sonner-toast][data-y-position=\"top\"][data-x-position=\"center\"] .alert-root.bg-surface-elevated-secondary",
            "data-sonner-toast",
            "rgba(5, 23, 54, 0.98)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style the archive toast's white inner alert surface")
        }
    },
    test("rainy neon styles bottom file-update toasts as dark neon glass") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-sonner-toast][data-y-position=\"bottom\"][data-x-position=\"center\"]",
            "rgba(5, 23, 54, 0.98)",
            "#dff8ff"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style the bottom file-update toast")
        }
    },
    test("rainy neon styles notifications rendered in the current Codex toast area") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            ".codex-toast-area section[aria-label^=\"通知\"]",
            "rgba(5, 23, 54, 0.98)",
            "#dff8ff"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style notifications emitted in Codex's current toast area")
        }
    },
    test("rainy neon styles the fixed file-change card above the composer") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "[data-in-progress-fixed-content] .bg-surface-elevated-secondary",
            "rgba(5, 23, 54, 0.98)",
            "#dff8ff"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style the fixed file-change card above the composer")
        }
    },
    test("rainy neon styles auto-resolving inline MCP question cards above the composer") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "form[data-user-input-auto-resolution]",
            "[data-codex-composer-request-navigation][data-user-input-auto-resolution]",
            "[data-mcp-form-choices]",
            "rgba(5, 23, 54, 0.98)",
            "#dff8ff"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style the transient inline MCP question card and its selectable answers")
        }
    },
    test("rainy neon styles standard inline MCP reply forms without auto-resolution") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "form[data-codex-character-input-boundary][data-codex-escape-boundary]",
            "form[data-codex-character-input-boundary][data-codex-escape-boundary] :is(textarea, input)",
            "rgba(5, 23, 54, 0.98)",
            "rgba(7, 32, 69, 0.9)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not style inline MCP reply forms without an auto-resolution marker")
        }
    },
    test("rainy neon replaces light inner surfaces in inline question forms") {
        let stylesheet = try String(contentsOf: starterThemeURL(id: "rainy-neon").appendingPathComponent("style.css"), encoding: .utf8)
        let requiredRules = [
            "form[data-codex-character-input-boundary][data-codex-escape-boundary] :is([class~=\"bg-surface\"], [class~=\"bg-surface-elevated-secondary\"])",
            "rgba(5, 23, 54, 0.98)"
        ]
        guard requiredRules.allSatisfy(stylesheet.contains) else {
            throw TestFailure.assertion("Rainy Neon does not replace light inner surfaces in inline question forms")
        }
    },
    test("application package includes the dedicated neon app icon") {
        let root = projectRootURL()
        let iconURL = root.appendingPathComponent("assets/AppIcon.icns")
        let packageScript = try String(contentsOf: root.appendingPathComponent("scripts/package-app.sh"), encoding: .utf8)
        let infoPlist = try String(contentsOf: root.appendingPathComponent("scripts/CodexAppearanceManager-Info.plist"), encoding: .utf8)
        guard FileManager.default.fileExists(atPath: iconURL.path),
              packageScript.contains("AppIcon.icns"),
              infoPlist.contains("CFBundleIconFile") else {
            throw TestFailure.assertion("the packaged app is missing its dedicated icon")
        }
    },
    test("appearance controls are placed above the CSS editor") {
        let viewSource = try String(contentsOf: projectRootURL().appendingPathComponent("Sources/CodexAppearanceApp/ContentView.swift"), encoding: .utf8)
        guard let controlsRange = viewSource.range(of: "                        controls"),
              let editorRange = viewSource.range(of: "                        cssEditor"),
              controlsRange.lowerBound < editorRange.lowerBound else {
            throw TestFailure.assertion("the action controls must precede the long CSS editor")
        }
    },
    test("bootstrap preserves an edited starter stylesheet") {
        try withTemporaryDirectory { root in
            let bundledThemes = root.appendingPathComponent("bundled")
            let appSupport = root.appendingPathComponent("support")
            try FileManager.default.createDirectory(at: bundledThemes, withIntermediateDirectories: true)
            _ = try writeTheme(id: "aurora-neon", at: bundledThemes, css: "body { color: cyan; }")
            let repository = ThemeRepository(applicationSupportURL: appSupport, bundledThemesURL: bundledThemes)
            try repository.bootstrap()
            let installedCSS = appSupport.appendingPathComponent("CodexAppearanceManager/themes/aurora-neon/style.css")
            try "body { color: magenta; }".data(using: .utf8)!.write(to: installedCSS)
            try repository.bootstrap()
            let savedCSS = try String(contentsOf: installedCSS)
            guard savedCSS == "body { color: magenta; }" else {
                throw TestFailure.assertion("bootstrap overwrote an edited stylesheet")
            }
        }
    },
    test("bootstrap adds a missing bundled asset without overwriting edited CSS") {
        try withTemporaryDirectory { root in
            let bundledThemes = root.appendingPathComponent("bundled")
            let appSupport = root.appendingPathComponent("support")
            try FileManager.default.createDirectory(at: bundledThemes, withIntermediateDirectories: true)
            let bundledTheme = try writeTheme(id: "rainy-neon", at: bundledThemes, css: "body { color: cyan; }")
            let repository = ThemeRepository(applicationSupportURL: appSupport, bundledThemesURL: bundledThemes)
            try repository.bootstrap()

            let installedTheme = appSupport.appendingPathComponent("CodexAppearanceManager/themes/rainy-neon")
            let installedCSS = installedTheme.appendingPathComponent("style.css")
            try "body { color: magenta; }".data(using: .utf8)!.write(to: installedCSS)
            let backgroundName = "rainy-city-v1.png"
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: bundledTheme.appendingPathComponent(backgroundName))

            try repository.bootstrap()

            guard FileManager.default.fileExists(atPath: installedTheme.appendingPathComponent(backgroundName).path) else {
                throw TestFailure.assertion("bootstrap did not install the missing bundled asset")
            }
            let savedCSS = try String(contentsOf: installedCSS)
            guard savedCSS == "body { color: magenta; }" else {
                throw TestFailure.assertion("bootstrap overwrote an edited stylesheet while syncing assets")
            }
        }
    },
    test("failed stylesheet replacement preserves the previous stylesheet") {
        try withTemporaryDirectory { root in
            let bundledThemes = root.appendingPathComponent("bundled")
            let appSupport = root.appendingPathComponent("support")
            try FileManager.default.createDirectory(at: bundledThemes, withIntermediateDirectories: true)
            _ = try writeTheme(id: "aurora-neon", at: bundledThemes, css: "body { color: cyan; }")
            let repository = ThemeRepository(
                applicationSupportURL: appSupport,
                bundledThemesURL: bundledThemes,
                replaceExistingFile: { _, _ in throw CocoaError(.fileWriteUnknown) }
            )
            try repository.bootstrap()
            let theme = try repository.loadThemes().singleValue()
            try expectThrows { try repository.save(css: "body { color: magenta; }", for: theme) }
            let savedCSS = try String(contentsOf: theme.stylesheetURL)
            guard savedCSS == "body { color: cyan; }" else {
                throw TestFailure.assertion("failed save replaced the existing stylesheet")
            }
        }
    },
    test("repository skips malformed and duplicate theme packages") {
        try withTemporaryDirectory { root in
            let bundledThemes = root.appendingPathComponent("bundled")
            let appSupport = root.appendingPathComponent("support")
            try FileManager.default.createDirectory(at: bundledThemes, withIntermediateDirectories: true)
            _ = try writeTheme(id: "aurora-neon", at: bundledThemes)
            _ = try writeTheme(id: "second-copy", at: bundledThemes)
            let duplicateManifestURL = bundledThemes.appendingPathComponent("second-copy/manifest.json")
            let duplicate = ThemeManifest(id: "aurora-neon", name: "Duplicate", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"])
            try JSONEncoder().encode(duplicate).write(to: duplicateManifestURL)
            let malformed = bundledThemes.appendingPathComponent("broken", isDirectory: true)
            try FileManager.default.createDirectory(at: malformed, withIntermediateDirectories: true)
            try Data("{invalid".utf8).write(to: malformed.appendingPathComponent("manifest.json"))
            try Data("body {}".utf8).write(to: malformed.appendingPathComponent("style.css"))
            let repository = ThemeRepository(applicationSupportURL: appSupport, bundledThemesURL: bundledThemes)
            try repository.bootstrap()
            let themes = try repository.loadThemes()
            guard themes.map(\.manifest.id) == ["aurora-neon"] else {
                throw TestFailure.assertion("invalid or duplicate themes were loaded")
            }
        }
    },
    test("resolver prefers saved Codex path before standard candidates") {
        try withTemporaryDirectory { root in
            let explicit = root.appendingPathComponent("Custom.app", isDirectory: true)
            let codex = root.appendingPathComponent("Codex.app", isDirectory: true)
            let chatGPT = root.appendingPathComponent("ChatGPT.app", isDirectory: true)
            try [explicit, codex, chatGPT].forEach { try FileManager.default.createDirectory(at: $0, withIntermediateDirectories: true) }
            let resolver = CodexResolver(standardCandidates: [codex, chatGPT])
            guard resolver.resolve(preferredPath: explicit) == .resolved(explicit) else {
                throw TestFailure.assertion("explicit app path was not preferred")
            }
            guard resolver.resolve(preferredPath: nil) == .resolved(codex) else {
                throw TestFailure.assertion("Codex.app was not preferred over ChatGPT.app")
            }
        }
    }
]

if !results.allSatisfy({ $0 }) {
    exit(1)
}

let asynchronousResults = await [
    asyncTest("CDP rejects non-loopback endpoints") {
        try expectThrows { _ = try CDPClient.validatedLoopbackURL(URL(string: "http://example.com/json/list")!) }
        try expectThrows { _ = try CDPClient.validatedLoopbackURL(URL(string: "http://192.168.1.2:39222/json/list")!) }
        _ = try CDPClient.validatedLoopbackURL(URL(string: "http://127.0.0.1:39222/json/list")!)
    },
    asyncTest("CDP selects only the main Codex renderer") {
        let overlay = CDPTarget(id: "overlay", type: "page", url: "app://-/index.html#overlay", webSocketDebuggerURL: "ws://127.0.0.1/devtools/page/overlay")
        let main = CDPTarget(id: "main", type: "page", url: "app://-/index.html", webSocketDebuggerURL: "ws://127.0.0.1/devtools/page/main")
        let unrelated = CDPTarget(id: "other", type: "page", url: "https://example.com", webSocketDebuggerURL: "ws://127.0.0.1/devtools/page/other")
        let selected = try CDPClient.selectMainTarget(from: [overlay, unrelated, main])
        guard selected.id == "main" else { throw TestFailure.assertion("selected a non-main target") }
    },
    asyncTest("CDP response uses the matching request identifier") {
        let data = Data("{\"id\":7,\"result\":{\"value\":\"ok\"}}".utf8)
        let response = try CDPWireResponse.decode(data: data, expectingID: 7)
        guard response == .object(["value": .string("ok")]) else {
            throw TestFailure.assertion("decoded response did not preserve result")
        }
        try expectThrows { _ = try CDPWireResponse.decode(data: data, expectingID: 8) }
    },
    asyncTest("CDP runtime evaluation serializes a text-frame payload") {
        let text = try CDPWireRequest.runtimeEvaluate(id: 7, expression: "1+1")
        let decoded = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
        guard case .object(let request) = decoded,
              request["id"] == .number(7),
              request["method"] == .string("Runtime.evaluate"),
              case .object(let parameters)? = request["params"],
              parameters["expression"] == .string("1+1") else {
            throw TestFailure.assertion("runtime evaluation request was not valid text JSON")
        }
    },
    asyncTest("CDP timeout surfaces a bounded timeout error") {
        try await expectAsyncThrows {
            _ = try await CDPClient.withTimeout(nanoseconds: 1_000_000) {
                try await Task.sleep(for: .milliseconds(100))
                return 1
            }
        }
    },
    asyncTest("selector mismatch blocks style injection") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: cyan; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(
            manifest: ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-not-present]", "[data-still-present]"]),
            directoryURL: directory,
            stylesheetURL: stylesheetURL
        )
        let cdp = RecordingCDP(responses: [runtimeValue(.array([.string("[data-not-present]")]))])
        let result = try await ThemeInjector().apply(theme, using: cdp)
        guard result.missingSelectors == ["[data-not-present]"], !result.didInject else {
            throw TestFailure.assertion("mismatch did not produce an incompatible result")
        }
        guard await cdp.capturedExpressions().count == 1 else {
            throw TestFailure.assertion("style injection ran after failed preflight")
        }
    },
    asyncTest("switching themes updates only the tagged manager style") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstCSS = directory.appendingPathComponent("first.css")
        let secondCSS = directory.appendingPathComponent("second.css")
        try Data("body { color: cyan; }".utf8).write(to: firstCSS)
        try Data("body { color: magenta; }".utf8).write(to: secondCSS)
        let manifest = ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"])
        let first = ThemePackage(manifest: manifest, directoryURL: directory, stylesheetURL: firstCSS)
        let second = ThemePackage(manifest: ThemeManifest(id: "fixture-two", name: "Fixture Two", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: manifest.requiredSelectors), directoryURL: directory, stylesheetURL: secondCSS)
        let cdp = RecordingCDP(responses: [runtimeValue(.array([])), .null, runtimeValue(.array([])), .null])
        _ = try await ThemeInjector().apply(first, using: cdp)
        _ = try await ThemeInjector().apply(second, using: cdp)
        let expressions = await cdp.capturedExpressions()
        guard expressions.count == 4,
              ThemeInjector.themeDataAttribute == "data-codex-appearance-manager-theme",
              expressions[1].contains("codex-appearance-manager-style"),
              expressions[1].contains(ThemeInjector.themeDataAttribute),
              expressions[1].contains("body { color: cyan; }"),
              expressions[3].contains("codex-appearance-manager-style"),
              expressions[3].contains(ThemeInjector.themeDataAttribute),
              expressions[3].contains("body { color: magenta; }") else {
            throw TestFailure.assertion("theme switch did not target the managed style element")
        }
    },
    asyncTest("rainy neon injection themes only diff-preview shadow roots") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: cyan; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(
            manifest: ThemeManifest(id: "rainy-neon", name: "Rainy Neon", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]),
            directoryURL: directory,
            stylesheetURL: stylesheetURL
        )
        let cdp = RecordingCDP(responses: [runtimeValue(.array([])), .null])
        _ = try await ThemeInjector().apply(theme, using: cdp)
        let expression = await cdp.capturedExpressions().last ?? ""
        guard expression.contains("data-codex-appearance-manager-shadow-diff-style"),
              expression.contains("host.closest('[role=\"tooltip\"][class~=\"group/diff-preview\"]')"),
              expression.contains("shadowRoot"),
              expression.contains(":host *"),
              expression.contains("MutationObserver") else {
            throw TestFailure.assertion("Rainy Neon injection is missing scoped diff-preview shadow styling")
        }
    },
    asyncTest("forest injection uses green diff surfaces without leaking the rainy blue palette") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: ivory; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(
            manifest: ThemeManifest(id: "aurora-neon", name: "Enchanted Forest", description: "Fixture", version: 2, palette: ["#8FDCAD", "#E2C27E"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]),
            directoryURL: directory,
            stylesheetURL: stylesheetURL
        )
        let cdp = RecordingCDP(responses: [runtimeValue(.array([])), .null])
        let result = try await ThemeInjector().apply(theme, using: cdp)
        let expression = await cdp.capturedExpressions().last ?? ""
        guard result.didInject,
              result.themeID == "aurora-neon",
              expression.contains("rgba(9, 32, 26, 0.97)"),
              expression.contains("#f39d87"),
              expression.contains("#8fdcad"),
              !expression.contains("rgba(7, 27, 62, 0.97)") else {
            throw TestFailure.assertion("Forest diff-preview injection is missing its green palette or retains the rainy blue surface")
        }
    },
    asyncTest("injection resolves theme asset tokens relative to the installed theme") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { background-image: url('__CAM_THEME_ASSET__/rainy-city-v1.png'); }".utf8).write(to: stylesheetURL)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: directory.appendingPathComponent("rainy-city-v1.png"))
        let theme = ThemePackage(
            manifest: ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]),
            directoryURL: directory,
            stylesheetURL: stylesheetURL
        )
        let cdp = RecordingCDP(responses: [runtimeValue(.array([])), .null])
        _ = try await ThemeInjector().apply(theme, using: cdp)
        let expressions = await cdp.capturedExpressions()
        let injectedExpression = (expressions.dropFirst().first ?? "").replacingOccurrences(of: "\\/", with: "/")
        guard expressions.count == 2,
              injectedExpression.contains("data:image/png;base64,iVBORw=="),
              !injectedExpression.contains("__CAM_THEME_ASSET__"),
              !injectedExpression.contains(directory.absoluteString) else {
            throw TestFailure.assertion("theme asset token was not resolved before injection")
        }
    },
    asyncTest("restore removes only manager-owned renderer artifacts") {
        let cdp = RecordingCDP(responses: [.null])
        try await ThemeInjector().restore(using: cdp)
        let expressions = await cdp.capturedExpressions()
        guard expressions.count == 1,
              expressions[0].contains("codex-appearance-manager-style"),
              expressions[0].contains(ThemeInjector.themeDataAttribute) else {
            throw TestFailure.assertion("restore script did not limit itself to manager artifacts")
        }
    },
    asyncTest("launcher refuses to launch while Codex is still running") {
        let recorder = ProcessRecorder()
        let launcher = CodexLauncher(
            isApplicationRunning: { _ in true },
            startProcess: { executableURL, arguments in
                recorder.record(executableURL: executableURL, arguments: arguments)
            }
        )
        let appURL = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
        do {
            try await launcher.relaunchForInjection(appURL: appURL)
            throw TestFailure.assertion("launcher accepted an already-running Codex app")
        } catch let error as CodexLauncherError {
            guard error == .applicationStillRunning, recorder.calls.isEmpty else {
                throw TestFailure.assertion("launcher did not preserve the running Codex instance")
            }
        }
    },
    asyncTest("launcher starts the app executable with loopback debug arguments") {
        let recorder = ProcessRecorder()
        let launcher = CodexLauncher(
            isApplicationRunning: { _ in false },
            startProcess: { executableURL, arguments in
                recorder.record(executableURL: executableURL, arguments: arguments)
            }
        )
        let appURL = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
        try await launcher.relaunchForInjection(appURL: appURL)
        guard recorder.calls.count == 1,
              recorder.calls[0].0 == appURL.appendingPathComponent("Contents/MacOS/ChatGPT"),
              recorder.calls[0].1 == CodexLauncher.debuggingArguments,
              recorder.calls[0].1.contains("--remote-allow-origins=http://127.0.0.1") else {
            throw TestFailure.assertion("launcher did not directly start the executable with loopback arguments")
        }
    },
    asyncTest("inject asks for restart without invoking the launcher") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: cyan; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(manifest: ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]), directoryURL: directory, stylesheetURL: stylesheetURL)
        let launcher = FixtureLauncher()
        let viewModel = AppearanceViewModel(
            themeStore: FixtureThemeStore(theme: theme),
            injector: FixtureInjector(applyResult: .failure(CDPClientError.mainTargetUnavailable)),
            connectionProvider: FixtureConnectionProvider(),
            launcher: launcher,
            resolver: FixtureResolver(resolution: .resolved(URL(fileURLWithPath: "/Applications/Codex.app")))
        )
        viewModel.load()
        await viewModel.injectSelectedTheme()
        guard viewModel.status == .restartNeeded, launcher.calls == 0 else {
            throw TestFailure.assertion("normal inject launched Codex instead of requesting an explicit restart")
        }
    },
    asyncTest("restart action launches Codex only after explicit method call") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: cyan; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(manifest: ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]), directoryURL: directory, stylesheetURL: stylesheetURL)
        let launcher = FixtureLauncher()
        let viewModel = AppearanceViewModel(
            themeStore: FixtureThemeStore(theme: theme),
            injector: FixtureInjector(applyResult: .success(ThemeInjectionResult(themeID: theme.manifest.id, missingSelectors: [], didInject: true))),
            connectionProvider: FixtureConnectionProvider(),
            launcher: launcher,
            resolver: FixtureResolver(resolution: .resolved(URL(fileURLWithPath: "/Applications/Codex.app")))
        )
        viewModel.load()
        guard launcher.calls == 0 else { throw TestFailure.assertion("launcher ran during view-model setup") }
        await viewModel.restartAndInject()
        guard launcher.calls == 1, viewModel.status == .debugLaunchStarted else {
            throw TestFailure.assertion("explicit restart did not invoke the launcher")
        }
    },
    asyncTest("incompatible preflight retains the editable CSS draft") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: cyan; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(manifest: ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]), directoryURL: directory, stylesheetURL: stylesheetURL)
        let draft = "body { color: magenta; }"
        let viewModel = AppearanceViewModel(
            themeStore: FixtureThemeStore(theme: theme),
            injector: FixtureInjector(applyResult: .success(ThemeInjectionResult(themeID: theme.manifest.id, missingSelectors: ["[data-app-action-sidebar-thread-row]"], didInject: false))),
            connectionProvider: FixtureConnectionProvider(),
            launcher: FixtureLauncher(),
            resolver: FixtureResolver(resolution: .resolved(URL(fileURLWithPath: "/Applications/Codex.app")))
        )
        viewModel.load()
        viewModel.cssDraft = draft
        await viewModel.injectSelectedTheme()
        guard viewModel.cssDraft == draft,
              viewModel.status == .incompatible(["[data-app-action-sidebar-thread-row]"]) else {
            throw TestFailure.assertion("incompatible preflight discarded the CSS draft")
        }
    },
    asyncTest("connection status becomes ready only after the CDP target responds") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: cyan; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(manifest: ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]), directoryURL: directory, stylesheetURL: stylesheetURL)
        let viewModel = AppearanceViewModel(
            themeStore: FixtureThemeStore(theme: theme),
            injector: FixtureInjector(applyResult: .success(ThemeInjectionResult(themeID: theme.manifest.id, missingSelectors: [], didInject: true))),
            connectionProvider: FixtureConnectionProvider(),
            launcher: FixtureLauncher(),
            resolver: FixtureResolver(resolution: .resolved(URL(fileURLWithPath: "/Applications/ChatGPT.app")))
        )
        viewModel.load()
        await viewModel.checkCodexConnection()
        guard viewModel.status == .debugConnectionReady else {
            throw TestFailure.assertion("a successful CDP target did not produce a connected status")
        }
    },
    asyncTest("failed CDP check never reports the debug connection as ready") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stylesheetURL = directory.appendingPathComponent("style.css")
        try Data("body { color: cyan; }".utf8).write(to: stylesheetURL)
        let theme = ThemePackage(manifest: ThemeManifest(id: "fixture", name: "Fixture", description: "Fixture", version: 1, palette: ["#00E5FF", "#FF2DDE"], requiredSelectors: ["[data-app-action-sidebar-thread-row]"]), directoryURL: directory, stylesheetURL: stylesheetURL)
        let viewModel = AppearanceViewModel(
            themeStore: FixtureThemeStore(theme: theme),
            injector: FixtureInjector(applyResult: .success(ThemeInjectionResult(themeID: theme.manifest.id, missingSelectors: [], didInject: true))),
            connectionProvider: UnavailableConnectionProvider(),
            launcher: FixtureLauncher(),
            resolver: FixtureResolver(resolution: .resolved(URL(fileURLWithPath: "/Applications/ChatGPT.app")))
        )
        viewModel.load()
        await viewModel.checkCodexConnection()
        guard viewModel.status == .restartNeeded else {
            throw TestFailure.assertion("failed CDP check incorrectly reported a live connection")
        }
    }
]

if !asynchronousResults.allSatisfy({ $0 }) {
    exit(1)
}

private extension Array {
    func singleValue() throws -> Element {
        guard count == 1, let value = first else {
            throw TestFailure.assertion("expected exactly one value")
        }
        return value
    }
}
