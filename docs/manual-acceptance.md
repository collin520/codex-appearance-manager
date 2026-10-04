# Manual acceptance checklist

This is a checklist, not a claim that these tests passed. This preparation does not launch, restart or inject into the active Codex session. Automated test results belong in `validation.md` separately.

Record the date, macOS version/architecture, Codex version and build, manager source revision/version, theme, viewport size and test outcome. Use privacy-edited screenshots only.

## Basic workflow

- [ ] Build the app in a fresh directory and open it; both current theme names and editable CSS appear.
- [ ] Opening the manager alone leaves Codex unchanged.
- [ ] A normal, non-debug Codex launch yields an unavailable debug connection without an automatic restart.
- [ ] Restart while Codex is still running refuses to proceed; no force-quit occurs.
- [ ] After saving work and manually quitting, confirmed debug launch succeeds. Check connection before clicking Inject.
- [ ] Inject each theme and verify the active background, text readability and accessible controls.
- [ ] Repeated injection replaces the manager-owned root style rather than accumulating duplicate styles.
- [ ] Restore removes the root style/attribute and any owned diff-preview styles/observers.
- [ ] Closing the manager retains current process styling; quitting and normally reopening Codex restores native appearance.
- [ ] Existing user theme edits survive bootstrap. Test external-draft conflicts only in a backed-up test package.
- [ ] Missing required selectors prevent injection; note that Inject still saves the draft first.

## Component and state coverage

Check both themes, narrow half-screen and wider windows; mark untested entries explicitly.

- [ ] Sidebar, navigation, settings, project creation and symbol/icon picker.
- [ ] Codex new chat, project home and existing conversation composer.
- [ ] ChatGPT mode → new chat → chat/work toggle, including work project/composer rails.
- [ ] Composer text selection toolbar and conversation text selection toolbar.
- [ ] Native inline questions, option choices and free-text reply cards, including inner input surfaces.
- [ ] Notifications, tool/progress pills, changed-file summaries and queued-message strips.
- [ ] Code blocks including plain text/Bash bodies, attachments and document open-method controls.
- [ ] Diff previews including nested Shadow DOM add/delete semantic colors.
- [ ] Your dot background, messages and composer, if the feature is available.
- [ ] Hover, focus, disabled, selection and reduced-motion states that can actually be triggered.

Do not archive a private conversation or send a real message merely to tick a box. Use approved disposable content for state-changing checks. A fabricated DOM fixture does not count as a native transient card.

## Failure handling

Restore first if readability or controls break. Record exact reproduction steps and the relevant theme/rule. The checklist is not exhaustive: finding and reporting a previously unknown component is expected.
