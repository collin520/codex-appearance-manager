# Editable theme packages

Installed packages live under `~/Library/Application Support/CodexAppearanceManager/themes/`. Source starter packages live under `Sources/CodexAppearanceApp/Resources/StarterThemes/`.

```text
example-theme/
  manifest.json
  style.css
  background.png
```

Example manifest for a new, separate theme:

```json
{
  "id": "example-theme",
  "name": "Example Theme",
  "description": "A local example theme.",
  "version": 1,
  "palette": ["#071810", "#8FDCAD", "#E2C27E"],
  "requiredSelectors": ["[data-app-action-sidebar-thread-row]"]
}
```

IDs must be lowercase kebab-case; names must be nonblank; versions positive; palettes contain two to six `#RRGGBB` colors; requiredSelectors must be nonempty with nonblank entries. Invalid packages are skipped by the repository loader. A `style.css` must exist. Version numbers do not trigger replacement of installed files.

Scope selectors to the active theme attribute:

```css
:root[data-codex-appearance-manager-theme="example-theme"] [data-app-shell-main-surface] {
  background: url("__CAM_THEME_ASSET__/background.png") center / cover;
}
```

The injector replaces `__CAM_THEME_ASSET__/` references with image data URLs at injection time. Assets must exist relative to the theme directory; absolute names and `..` segments are rejected. The implementation accepts png, jpg/jpeg, gif, webp and svg extensions; this preparation bundles PNG artwork only. This path check is not a full symlink/resource sandbox. Avoid unfamiliar SVG or untrusted assets.

Enchanted Forest's existing ID is `aurora-neon`; keep it for current themes. Internal diff-preview Shadow DOM styling is implemented in the injector for the two shipped IDs, not automatically derived from arbitrary custom CSS. A new theme therefore does not inherit that special preview treatment without a separately reviewed adapter change.

Bootstrap adds missing files and preserves existing ones. Back up an installed package before manual updates. When editing outside the manager, reload its draft by changing themes before injecting; there is no conflict detector.

This format is local to this project. Compatibility with another theme manager's package format is not promised.
