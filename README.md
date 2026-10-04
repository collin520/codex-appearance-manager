# Codex Appearance Manager

[简体中文](README.zh-CN.md)

Create your own Codex theme with Codex, using CSS adaptations accumulated through long-term everyday use.

This unofficial, local macOS toolkit shares the interface selectors and styling fixes we have collected for composers, small popovers, transient cards and other easy-to-miss surfaces. You can ask Codex to help build the manager and create a theme you like on top of those existing rules, instead of having to rediscover each surface yourself. Enchanted Forest and Rainy Neon are reference themes and starting points, not the limit of what this project is for.

The manager applies editable CSS on demand and removes its styling without modifying the Codex application bundle. AI-assisted setup depends on your environment and permissions; the project does not provide a guaranteed unattended installer or a universal theme generator.

## Status and coverage

This is an **experimental source-only snapshot**, not a stable or officially supported release. Application source, CSS, scripts, project-authored documentation and project-owned artwork use [MIT](LICENSE). Third-party rights are not included; see [assets and licensing](docs/assets-and-licensing.md).

**We do not guarantee coverage of every Codex UI component or state.** The themes contain many fixes for small, transient and nested surfaces discovered during everyday use, but uncommon dialogs, new features, changed DOM structures and different Codex versions may still display native or incomplete styling. Passing automated tests or selector preflight does not prove complete visual coverage. See [compatibility and limitations](docs/compatibility.md).

This project is not affiliated with or endorsed by OpenAI. It styles the interface; it does not add model capabilities or subscription features.

## Reference themes

These examples show two visual directions using the accumulated adaptations. Reuse their full stylesheets when building a different look; do not replace them with a short stylesheet that drops the small-surface fixes. The existing CSS is a practical starting point, not a fully separated, palette-only theme framework.

| Theme | Visual direction | Package ID |
| --- | --- | --- |
| Enchanted Forest · 奇幻森林 | Moonlit woodland, animals and winged fairies, deep-green glass, mint and gold accents | `aurora-neon` |
| Rainy Neon · 科幻雨夜 | Rainy futuristic city, translucent midnight panels, cyan and pink accents | `rainy-neon` |

The forest keeps its historical `aurora-neon` ID for compatibility. This snapshot includes only each theme's active background. The owner approved these two [privacy-edited demonstrations](docs/previews/README.md) with fictional content. Generative editing can alter UI details, so these are not untouched screenshots or acceptance evidence. Original private chat screenshots are not included.

### Enchanted Forest

![Enchanted Forest — AI privacy-edited demonstration](docs/previews/enchanted-forest-demo-v1.png)

### Rainy Neon

![Rainy Neon — AI privacy-edited demonstration](docs/previews/rainy-neon-demo-v1.png)

## Requirements

- macOS 14 or newer.
- A Swift toolchain that supports Swift tools 6.0 or newer and the macOS SDK. Install Apple's Command Line Tools or Xcode as appropriate; check with `swift --version`.
- Codex Desktop installed locally. Default discovery checks `/Applications/Codex.app`, then `/Applications/ChatGPT.app`; the fallback is not a promise of support for every ChatGPT app version. Other install locations are not selectable in the current GUI.
- No third-party Swift package dependencies are declared. Windows and Linux are not supported by this macOS application.

## Ask Codex to install and create your theme

Open a local Codex task with access to your chosen working folder. You can copy these prompts, adjusting the theme description to your taste. They are suggested instructions, not a tested one-click automation; review requested actions and permissions.

### Setup prompt

```text
Help me set up https://github.com/collin520/codex-appearance-manager on this Mac.
Use an existing checkout if available, or clone it into a folder we agree on.
Read README.md, docs/security.md and docs/validation.md first. Check macOS and
the Swift toolchain; ask before installing missing tools or overwriting files.
Run the documented tests, Release build and packaging script. Show me the
resulting app path and explain the manual connection, injection and restore steps.
Do not modify the Codex bundle, force-quit or restart Codex, inject automatically,
or disable system protections. Stop and report environment or permission blockers.
```

### Theme prompt

```text
Using Codex Appearance Manager, help me create a separate theme in this style:
[describe the colors, mood, background, typography and usual window size].
Read docs/theme-format.md and the complete CSS of a reference theme first.
Preserve its existing selectors, nested-surface fixes and functional controls.
Create a new theme package with its own valid ID; update all theme-root scopes,
and consistently rename any theme-specific variables and animation names.
Adapt colors, gradients, borders, shadows and local artwork, including hardcoded
colors, while preserving readable contrast and semantic diff/error colors.
Back up local edits and leave the original themes unchanged. By default, do not
change Swift code. Report any theme-ID-specific Shadow DOM adaptation separately.
Verify package structure and asset references; run existing source tests, then
guide me through reloading the manager, draft reload and explicit injection.
Do not claim complete visual coverage without testing actual UI states.
```

See [theme creation steps and limitations](docs/theme-format.md#reuse-the-existing-coverage) before treating a copied theme as complete.

## Build from source

From the repository root:

```sh
swift run CodexAppearanceTestRunner
swift build -c release
./scripts/package-app.sh
```

The package script produces `dist/Codex Appearance Manager.app`; open it in Finder. `dist/` and Swift build caches are ignored and are not source-distribution inputs.

The script signs the locally built app ad hoc. This is not Developer ID signing or Apple notarization, and does not establish acceptance on another Mac. No prebuilt download is supplied with this snapshot. See [validation](docs/validation.md) for actual local results and their limits.

## Apply and restore

1. Open the manager and select a theme. Nothing is injected automatically.
2. Click **Check Codex Connection**. If a compatible local debug session is already available, proceed to step 5.
3. If the connection is unavailable, save your work and unsent input, then manually quit Codex completely with `⌘Q`.
4. Click **Restart Codex and Inject** and confirm. Despite its name, this button only starts Codex with local debugging enabled. Wait for the window, then click **Check Codex Connection**.
5. Only after connection succeeds, click **Inject Codex Style**. This first saves the current CSS editor draft, then performs selector preflight and injection. A mismatch prevents injection, but does not undo that draft save.
6. To remove this manager's styling, click **Restore Original** while the local debug connection is available.

The manager refuses to relaunch a still-running Codex process; it never force-quits it. Closing the manager leaves the current window styled. Quitting and normally reopening Codex removes the process-local appearance and ends that debugging session. Restore does not itself disable the debug port, undo saved CSS or remove other tools' changes.

## Edit themes

Use **Open Themes Folder** to inspect local packages. Themes are stored in:

```text
~/Library/Application Support/CodexAppearanceManager/themes/
```

Each package has `manifest.json`, `style.css` and local artwork. The manager copies missing packaged files, but preserves existing user CSS and manifests. A new application build therefore does not automatically replace an installed theme's old stylesheet.

**Avoid external-edit conflicts:** injection saves the editor draft. If you change CSS outside the manager while it is open, switch to another theme and back to reload the file before injecting. Back up your edits first; conflict detection is not implemented. Theme switching can also discard an unsaved draft.

See [theme format](docs/theme-format.md) for selectors, IDs and portable background references.

## Safety and troubleshooting

The default debug endpoint is `127.0.0.1:39222`. CDP is a powerful local debugging interface, not a security sandbox. Do not expose it to the network. Arbitrary custom CSS can obscure controls or load external resources; use only themes you trust. See [security boundaries](docs/security.md).

If a surface is still light, text is unreadable or a control is obscured, restore the original appearance and [open a GitHub Issue](https://github.com/collin520/codex-appearance-manager/issues/new/choose). Include the Codex version/build, macOS version, manager version or source revision, theme, exact steps and a privacy-edited screenshot. Never include access tokens, personal paths or private chat contents. The bug-report template is available in English and Chinese.

Do not publish exploitable security details or sensitive evidence in public issues. See [security reporting limitations](docs/security.md#recovery-and-reports).

## Project layout

```text
Sources/CodexAppearanceCore/       Theme storage, application discovery, launch, CDP and injection
Sources/CodexAppearanceApp/        SwiftUI views, view model and theme resources
Sources/CodexAppearanceLauncher/   Application entry point
Sources/CodexAppearanceTestRunner/ Lightweight behavior and CSS-source regression checks
scripts/                         Local app packaging
assets/                          Application icon source and generated sizes
docs/                            Theme format, compatibility, safety and acceptance boundaries
```

For contributions, explain the affected UI state and how to reproduce it. Check both themes after changing shared selectors, scope overrides to the theme root and preserve functional controls. Run the test runner and release build; use the [manual acceptance checklist](docs/manual-acceptance.md) when a real UI is available. Do not describe a fixture or source-string check as native UI verification.
