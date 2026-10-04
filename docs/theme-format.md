# Editable theme packages

Installed packages live under `~/Library/Application Support/CodexAppearanceManager/themes/`. Source starter packages live under `Sources/CodexAppearanceApp/Resources/StarterThemes/`.

## Reuse the existing coverage

The project's main reusable contribution is the accumulated selectors and CSS fixes in its two reference themes. They cover many small and transient surfaces encountered during everyday use; they are not a guarantee that every Codex component or future version is covered. A new visual direction should retain those rules rather than start with a minimal replacement stylesheet.

The two stylesheets are complete, independently maintained themes, not a normalized shared coverage layer with a palette-only API. Besides root variables, they include literal colors, gradients, nested overrides and animation definitions. `manifest.json` palette entries describe the package; changing them alone does not recolor CSS or the injector's special diff-preview styles.

For AI-assisted customization, use the copyable prompts in the [English README](../README.md) or [中文说明](../README.zh-CN.md). Those prompts guide an agent; they are not a built-in installer or theme-generation feature.

### Create a separate local theme

1. Initialize the manager once so its local themes directory exists. Back up user-edited files; do not overwrite a reference theme or unsaved CSS draft.
2. Copy one complete reference package to a new directory under the installed themes directory. Keep the original reference packages unchanged. A local custom package does not need to be added to the bundled source resources or require a Swift change.
3. Give the manifest a new lowercase kebab-case ID, a name and description, and a valid palette. Update every root theme-attribute selector to the new ID; otherwise the copied rules will not match when the theme is selected. Consistently update any renamed theme-specific variables/keyframes and their references.
4. Adapt CSS colors, literal color values, gradients, borders, shadows and typography as well as the background. Keep existing selector coverage, functional controls, readable contrast and meaningful diff/error colors. Use locally owned or properly licensed artwork with portable asset references.
5. Check the manifest, complete stylesheet and all referenced assets. Run the repository's existing tests when source is available, but note that they primarily cover bundled themes and do not certify a newly installed custom theme. Review the theme-ID-specific Shadow DOM limitation below before calling the result complete.
6. Save any draft, then close and reopen the manager to load the new package. This is a manager reload, not a Codex restart. Select the new theme, check the connection and explicitly click **Inject Codex Style**. After external CSS edits, switch themes and back to reload the editor draft before injecting.
7. Verify actual UI states when authorized: normal and half-screen windows, composers, selection popovers, question cards, code/resource cards and diff previews. Record which surfaces were actually checked and which remain unverified; follow the [manual acceptance checklist](manual-acceptance.md). Retain backups for reverting local files; **Restore Original** only removes manager-owned renderer styling.

### 中文制作要点

核心价值是复用长期积累的选择器和小组件适配，减少重新抓取界面的工作。两套 CSS 仍包含硬编码颜色和特殊覆盖，不是仅修改 manifest 调色板就能完成的新主题框架。

建议在本机主题目录复制完整参考包，使用独立 ID，并更新所有主题根作用域；保留原包和草稿备份。检查 CSS 变量、硬编码颜色、渐变、动画名称和本地资源，同时保留差异增删及错误的语义颜色。重新打开的是管理器，不需要仅为加载新主题而重启 Codex；之后仍需检查连接并明确点击注入。

现有测试不等于验证了新建的本机主题。尤其是下文所述的差异预览 Shadow DOM 样式绑定内置 ID，复制为新 ID 后不会自动继承；需要另行适配并验证，不能宣称只复制 CSS 就已完整覆盖。普通本机主题制作默认不改 Swift；如需要特殊适配，应单独说明范围并获得授权。

## Package format

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
