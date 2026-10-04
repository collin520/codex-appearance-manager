# Publication file allowlist

This list identifies the 52 files selected for the initial experimental source-only upload. On 2026-10-04 the owner approved the previews, MIT for code and project-owned artwork, and uploading to `collin520/codex-appearance-manager`. Approval covers this reviewed snapshot, not future unrelated files. Complete provenance and cross-machine acceptance are not certified; see the licensing and validation documents.

Use an explicit file selection or a reviewed Git staging list. **Do not zip or upload the entire working folder:** it also contains ignored build outputs, Finder metadata and local preparation records.

Application-source SHA-256 values are recorded in `source-inventory.md`. New documentation is reviewed separately.

## Selected relative paths

```text
.github/ISSUE_TEMPLATE/bug_report.md
.gitignore
LICENSE
Package.swift
README.md
README.zh-CN.md
Sources/CodexAppearanceApp/AppearanceViewModel.swift
Sources/CodexAppearanceApp/ContentView.swift
Sources/CodexAppearanceApp/PackageMarker.swift
Sources/CodexAppearanceApp/Resources/StarterThemes/aurora-neon/enchanted-forest-v3.png
Sources/CodexAppearanceApp/Resources/StarterThemes/aurora-neon/manifest.json
Sources/CodexAppearanceApp/Resources/StarterThemes/aurora-neon/style.css
Sources/CodexAppearanceApp/Resources/StarterThemes/rainy-neon/manifest.json
Sources/CodexAppearanceApp/Resources/StarterThemes/rainy-neon/rainy-skyline-duel-v1.png
Sources/CodexAppearanceApp/Resources/StarterThemes/rainy-neon/style.css
Sources/CodexAppearanceCore/CDPClient.swift
Sources/CodexAppearanceCore/CodexLauncher.swift
Sources/CodexAppearanceCore/CodexResolver.swift
Sources/CodexAppearanceCore/PackageMarker.swift
Sources/CodexAppearanceCore/Theme.swift
Sources/CodexAppearanceCore/ThemeInjector.swift
Sources/CodexAppearanceCore/ThemeRepository.swift
Sources/CodexAppearanceLauncher/CodexAppearanceApp.swift
Sources/CodexAppearanceLauncher/PackageMarker.swift
Sources/CodexAppearanceTestRunner/main.swift
assets/AppIcon.icns
assets/AppIcon.iconset/icon_128x128.png
assets/AppIcon.iconset/icon_128x128@2x.png
assets/AppIcon.iconset/icon_16x16.png
assets/AppIcon.iconset/icon_16x16@2x.png
assets/AppIcon.iconset/icon_256x256.png
assets/AppIcon.iconset/icon_256x256@2x.png
assets/AppIcon.iconset/icon_32x32.png
assets/AppIcon.iconset/icon_32x32@2x.png
assets/AppIcon.iconset/icon_512x512.png
assets/AppIcon.iconset/icon_512x512@2x.png
assets/app-icon-neon-source.png
docs/assets-and-licensing.md
docs/compatibility.md
docs/manual-acceptance.md
docs/previews/README.md
docs/previews/edit-prompts.md
docs/previews/enchanted-forest-demo-v1.png
docs/previews/rainy-neon-demo-v1.png
docs/publication-inventory.md
docs/release-checklist.md
docs/security.md
docs/source-inventory.md
docs/theme-format.md
docs/validation.md
scripts/CodexAppearanceManager-Info.plist
scripts/package-app.sh
```

## Not selected

Original Git history; `.build/`, `.swiftpm/`, `dist/`, `.superpowers/`, `.DS_Store`, log files, `docs/superpowers/` and `docs/preparation-review.md`. There are no private previews or user-installed theme files in the selected payload.

`LICENSE` contains the owner-selected MIT license. Third-party rights are not granted; review `assets-and-licensing.md` and preserve any required notices. The two preview images are AI-edited demonstrations, not original private screenshots or native UI evidence.
