import Foundation

public struct ThemeInjectionResult: Equatable, Sendable {
    public let themeID: String
    public let missingSelectors: [String]
    public let didInject: Bool

    public init(themeID: String, missingSelectors: [String], didInject: Bool) {
        self.themeID = themeID
        self.missingSelectors = missingSelectors
        self.didInject = didInject
    }
}

public enum ThemeInjectorError: Error, Equatable, LocalizedError, Sendable {
    case invalidPreflightResponse
    case invalidThemeAsset(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPreflightResponse:
            return "Codex did not return a valid selector preflight result."
        case .invalidThemeAsset(let path):
            return "Theme asset is missing or unsafe: \(path)"
        }
    }
}

public final class ThemeInjector: @unchecked Sendable {
    public static let styleElementID = "codex-appearance-manager-style"
    /// Public theme scope consumed by each theme stylesheet.
    public static let themeDataAttribute = "data-codex-appearance-manager-theme"

    public init() {}

    public func apply(_ theme: ThemePackage, using connection: CDPConnecting) async throws -> ThemeInjectionResult {
        let target = try await connection.mainTarget()
        let preflightResponse = try await connection.evaluate(preflightScript(selectors: theme.manifest.requiredSelectors), on: target)
        let missingSelectors = try missingSelectors(from: preflightResponse)
        guard missingSelectors.isEmpty else {
            return ThemeInjectionResult(themeID: theme.manifest.id, missingSelectors: missingSelectors, didInject: false)
        }

        let stylesheet = try String(contentsOf: theme.stylesheetURL, encoding: .utf8)
        let css = try resolveThemeAssets(in: stylesheet, themeDirectory: theme.directoryURL)
        _ = try await connection.evaluate(injectionScript(css: css, themeID: theme.manifest.id), on: target)
        return ThemeInjectionResult(themeID: theme.manifest.id, missingSelectors: [], didInject: true)
    }

    public func restore(using connection: CDPConnecting) async throws {
        let target = try await connection.mainTarget()
        _ = try await connection.evaluate(restorationScript(), on: target)
    }

    private func missingSelectors(from response: JSONValue) throws -> [String] {
        guard case .object(let envelope) = response,
              case .object(let runtimeResult)? = envelope["result"],
              case .array(let values)? = runtimeResult["value"] else {
            throw ThemeInjectorError.invalidPreflightResponse
        }
        return try values.map { value in
            guard case .string(let selector) = value else {
                throw ThemeInjectorError.invalidPreflightResponse
            }
            return selector
        }
    }

    private func preflightScript(selectors: [String]) throws -> String {
        let selectorsJSON = try jsonLiteral(selectors)
        return """
        (() => {
          const selectors = \(selectorsJSON);
          return selectors.filter((selector) => document.querySelectorAll(selector).length === 0);
        })()
        """
    }

    private func injectionScript(css: String, themeID: String) throws -> String {
        let cssJSON = try jsonLiteral(css)
        let themeIDJSON = try jsonLiteral(themeID)
        let styleIDJSON = try jsonLiteral(Self.styleElementID)
        let dataAttributeJSON = try jsonLiteral(Self.themeDataAttribute)
        let shadowDiffCSSJSON = try jsonLiteral(diffShadowCSS(for: themeID))
        return """
        (() => {
          const styleID = \(styleIDJSON);
          const css = \(cssJSON);
          const themeID = \(themeIDJSON);
          const dataAttribute = \(dataAttributeJSON);
          const shadowDiffStyleID = 'data-codex-appearance-manager-shadow-diff-style';
          const shadowDiffCSS = \(shadowDiffCSSJSON);
          const existing = document.getElementById(styleID);
          const style = existing && existing.tagName === 'STYLE'
            ? existing
            : document.createElement('style');
          style.id = styleID;
          if (!style.parentElement) document.head.appendChild(style);
          style.textContent = css;
          document.documentElement.setAttribute(dataAttribute, themeID);

          window.__codexAppearanceManagerShadowDiff?.dispose?.();
          delete window.__codexAppearanceManagerShadowDiff;
          if (shadowDiffCSS) {
            const roots = new Set();
            const rootObservers = new Map();
            const previewSelector = '[role="tooltip"][class~="group/diff-preview"]';
            const isPreviewHost = (host) => {
              if (host.closest('[role="tooltip"][class~="group/diff-preview"]')) return true;
              let current = host;
              while (current) {
                const root = current.getRootNode?.();
                const next = current.parentElement ?? root?.host ?? null;
                if (!next) return false;
                if (next.matches?.(previewSelector)) return true;
                current = next;
              }
              return false;
            };
            const install = (root) => {
              const host = root?.host;
              if (!host || !isPreviewHost(host)) return;
              let shadowStyle = root.getElementById?.(shadowDiffStyleID);
              if (!shadowStyle) {
                shadowStyle = document.createElement('style');
                shadowStyle.id = shadowDiffStyleID;
                root.appendChild(shadowStyle);
              }
              shadowStyle.textContent = shadowDiffCSS;
              roots.add(root);
              if (rootObservers.has(root)) return;
              const observer = new MutationObserver((records) => {
                for (const record of records) for (const node of record.addedNodes) visit(node);
              });
              observer.observe(root, { childList: true, subtree: true });
              rootObservers.set(root, observer);
              for (const node of root.querySelectorAll('*')) if (node.shadowRoot) install(node.shadowRoot);
            };
            const visit = (node) => {
              if (!(node instanceof Element)) return;
              if (node.shadowRoot) install(node.shadowRoot);
              for (const child of node.querySelectorAll('*')) if (child.shadowRoot) install(child.shadowRoot);
            };
            const observer = new MutationObserver((records) => {
              for (const record of records) for (const node of record.addedNodes) visit(node);
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });
            visit(document.documentElement);
            window.__codexAppearanceManagerShadowDiff = {
              dispose() {
                observer.disconnect();
                for (const entry of rootObservers.values()) entry.disconnect();
                for (const root of roots) root.getElementById?.(shadowDiffStyleID)?.remove();
              }
            };
          }
          return true;
        })()
        """
    }

    private func restorationScript() -> String {
        """
        (() => {
          const style = document.getElementById('\(Self.styleElementID)');
          if (style && style.tagName === 'STYLE') style.remove();
          window.__codexAppearanceManagerShadowDiff?.dispose?.();
          delete window.__codexAppearanceManagerShadowDiff;
          document.documentElement.removeAttribute('\(Self.themeDataAttribute)');
          return true;
        })()
        """
    }

    private func diffShadowCSS(for themeID: String) -> String {
        switch themeID {
        case "rainy-neon":
            return rainyNeonDiffShadowCSS
        case "aurora-neon":
            // Diff previews own a Shadow DOM, so the forest palette must enter there too.
            let palette = [
                ("rgba(7, 27, 62, 0.97)", "rgba(9, 32, 26, 0.97)"),
                ("rgba(9, 35, 76, 0.98)", "rgba(12, 42, 32, 0.98)"),
                ("rgba(16, 100, 113, 0.58)", "rgba(30, 108, 71, 0.58)"),
                ("rgba(106, 24, 87, 0.58)", "rgba(109, 44, 37, 0.58)"),
                ("rgba(13, 54, 93, 0.94)", "rgba(21, 58, 40, 0.94)"),
                ("#dff8ff", "#e9f3db"),
                ("#79dcff", "#b7e1b0"),
                ("#33dfce", "#8fdcad"),
                ("#ff7cc8", "#f39d87"),
                ("#6ae4ff", "#8fdcad"),
                ("#a8edff", "#cce7bb")
            ]
            return palette.reduce(rainyNeonDiffShadowCSS) { css, colors in
                css.replacingOccurrences(of: colors.0, with: colors.1)
            }
        default:
            return ""
        }
    }

    private var rainyNeonDiffShadowCSS: String {
        """
        :host, :host *, [data-diff], [data-file] {
          color-scheme: dark !important;
          --color-surface: rgba(7, 27, 62, 0.97) !important;
          --color-surface-secondary: rgba(9, 35, 76, 0.98) !important;
          --color-codex-diff-surface: rgba(7, 27, 62, 0.97) !important;
          --color-text: #dff8ff !important;
          --color-text-info: #79dcff !important;
          --diffs-light-bg: rgba(7, 27, 62, 0.97) !important;
          --diffs-dark-bg: rgba(7, 27, 62, 0.97) !important;
          --diffs-bg: rgba(7, 27, 62, 0.97) !important;
          --diffs-bg-addition: rgba(16, 100, 113, 0.58) !important;
          --diffs-bg-deletion: rgba(106, 24, 87, 0.58) !important;
          --diffs-bg-separator: rgba(13, 54, 93, 0.94) !important;
          --diffs-addition-base: #33dfce !important;
          --diffs-deletion-base: #ff7cc8 !important;
          --diffs-mixer: #6ae4ff !important;
        }
        :host * {
          background-color: rgba(7, 27, 62, 0.97) !important;
          color: #dff8ff !important;
        }
        [data-diff], [data-file], [data-line], [data-gutter], [data-column-number], [data-gutter-buffer] {
          background-color: rgba(7, 27, 62, 0.97) !important;
          color: #dff8ff !important;
        }
        [data-line-type="change-addition"]:is([data-line], [data-gutter], [data-column-number], [data-gutter-buffer]) {
          background-color: rgba(16, 100, 113, 0.58) !important;
        }
        [data-line-type="change-deletion"]:is([data-line], [data-gutter], [data-column-number], [data-gutter-buffer]) {
          background-color: rgba(106, 24, 87, 0.58) !important;
        }
        [data-separator], [data-separator-wrapper] {
          background-color: rgba(13, 54, 93, 0.94) !important;
          color: #a8edff !important;
        }
        """
    }

    private func resolveThemeAssets(in stylesheet: String, themeDirectory: URL) throws -> String {
        let token = "__CAM_THEME_ASSET__/"
        var resolved = stylesheet

        while let tokenRange = resolved.range(of: token) {
            let suffix = resolved[tokenRange.upperBound...]
            let assetName = String(suffix.prefix { character in
                !character.isWhitespace && character != "\"" && character != "'" && character != ")"
            })
            guard !assetName.isEmpty, !assetName.hasPrefix("/"), !assetName.split(separator: "/").contains("..") else {
                throw ThemeInjectorError.invalidThemeAsset(assetName)
            }

            let assetURL = themeDirectory.appendingPathComponent(assetName)
            guard FileManager.default.fileExists(atPath: assetURL.path),
                  let data = try? Data(contentsOf: assetURL) else {
                throw ThemeInjectorError.invalidThemeAsset(assetName)
            }

            let mimeType: String
            switch assetURL.pathExtension.lowercased() {
            case "png": mimeType = "image/png"
            case "jpg", "jpeg": mimeType = "image/jpeg"
            case "gif": mimeType = "image/gif"
            case "webp": mimeType = "image/webp"
            case "svg": mimeType = "image/svg+xml"
            default: throw ThemeInjectorError.invalidThemeAsset(assetName)
            }

            let assetEnd = resolved.index(tokenRange.upperBound, offsetBy: assetName.count)
            let dataURL = "data:\(mimeType);base64,\(data.base64EncodedString())"
            resolved.replaceSubrange(tokenRange.lowerBound..<assetEnd, with: dataURL)
        }
        return resolved
    }

    private func jsonLiteral<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let literal = String(data: data, encoding: .utf8) else {
            throw ThemeInjectorError.invalidPreflightResponse
        }
        return literal
    }
}
