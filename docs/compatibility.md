# Compatibility and known limitations

## Coverage disclaimer / 覆盖范围说明

**Not every CSS component or UI state is covered.** These themes are a collection of practical adaptations, not a complete or stable third-party skinning API. New features, transient cards, uncommon menus, screen sizes, light/dark settings and DOM changes can expose gaps. A selector existing does not mean its computed styling or every related component is correct.

**不保证覆盖所有 CSS 组件或界面状态。** 本项目基于实际使用逐步适配，新增功能、短暂弹窗、少见菜单、窗口尺寸、明暗设置和 DOM 变化都可能导致漏样式；不能把预检通过理解为全界面兼容。

## Implementation requirements

| Item | Declared or observed scope |
| --- | --- |
| Operating system | Package declares macOS 14+; not all supported releases are independently tested |
| Swift | Package declares tools 6.0; the toolchain used for this snapshot is recorded in validation |
| Default app discovery | `/Applications/Codex.app`, then `/Applications/ChatGPT.app` |
| Renderer discovery | Main page target matching `app://-/index.html`; changed or multiple-target layouts can fail discovery |
| Debug endpoint | Local loopback port 39222 by default |
| Current theme IDs | `aurora-neon`, `rainy-neon` |
| Supported Codex versions | No public release compatibility matrix is yet certified |
| Other machines | Independent recipient-Mac acceptance pending |

The existing themes were iterated against real local interfaces during development. That history is not a versioned public acceptance matrix and is not re-certified by this source preparation.

## Adaptation areas, not exhaustive guarantees

- Sidebar, navigation, project dialogs, icon picker and settings surfaces.
- Codex and ChatGPT chat/work composers, project home and additional rails.
- Code/plain-text blocks, attachments, file-change summaries and diff previews.
- Inline question/reply cards, selected-text controls, notifications and queued-message strips.
- Your dot conversation background and message surfaces.

Some regression tests assert CSS source patterns, predominantly for Rainy Neon. They do not establish equal visual coverage of both themes, accessibility compliance, every popover or every application mode.

## Known limitations

1. **CSS draft conflicts:** Inject saves the editor contents before selector preflight. External edits can be overwritten by a stale draft. Switch away and back to reload, after backing up edits; switching can discard an unsaved draft.
2. **Installed-theme updates:** bootstrap only copies missing files. Existing CSS and manifests are intentionally preserved, even when a new packaged version differs.
3. **Preflight is narrow:** current manifests require a sidebar thread-row selector. A fresh or differently structured account can fail this check; passing it is not a full DOM health gate. Do not disable it blindly.
4. **Runtime state is temporary:** styles do not survive a normal fresh Codex process. The manager has no persistent OS service, login helper or automatic reinjection.
5. **Restore is scoped:** only this manager's root style, theme attribute and owned diff-preview styles/observers are removed. Saved files and other injectors are not reset. The debug port remains until that Codex process ends.
6. **Custom CSS trust:** no comprehensive CSS safety linter, resource-size limit or third-party theme sandbox is supplied. Use trusted local assets and inspect unfamiliar CSS.
7. **Image cropping:** `cover` backgrounds crop with the viewport; composition depends on window dimensions. Half-screen suitability is an artistic design goal, not identical framing at all sizes.
8. **Distribution:** the packaging script produces a locally ad-hoc-signed app, not a notarized public installer.

If a theme breaks readability or access to controls, restore first. See the manual checklist for recording reproducible, privacy-safe evidence.
