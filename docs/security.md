# Security and recovery boundaries

This is an unofficial appearance tool. Do not treat local debugging, custom CSS or downloaded theme resources as a security sandbox.

## Implemented boundaries

- Default discovery connects to `http://127.0.0.1:39222/json/list`; endpoint and WebSocket host checks reject non-loopback hosts.
- Launch arguments bind the debug port to `127.0.0.1:39222` and limit the configured WebSocket origin to `http://127.0.0.1`.
- Discovery selects the expected main renderer; RPC IDs are correlated and requests have bounded timeouts.
- Injection installs/reuses `style#codex-appearance-manager-style` and a root theme attribute. Manager-owned renderer JavaScript also installs and observes narrow diff-preview Shadow DOM styles; restore disconnects those observers and removes those styles.
- No official application-bundle rewrite, force-quit, login item, persistent OS service, automatic injection or read of `~/.codex` is implemented.
- The manager's own networking is for local CDP; no account, cloud sync, telemetry or update service is implemented.

## Limits

Loopback protects against ordinary remote access, not other processes on the same Mac. The debug interface can control the renderer; do not forward its port or relax its origin policy. Restore removes appearance changes but does not stop the debugging session. To end it, quit that Codex process and reopen normally.

These checks do not validate endpoint identity cryptographically or impose comprehensive theme CSS/asset limits. Arbitrary CSS can obscure controls, change layout or request remote URLs/fonts/imports. The portable-asset path checks are not a symlink sandbox. Only use trusted themes, inspect custom CSS and back up local edits.

The application does not send private chat content to a service, but the CDP connection itself operates within the app renderer. The tool cannot remove the inherent authority of that debugging protocol.

## Recovery and reports

Try **Restore Original** while connected. If a broken layout prevents normal interaction or the connection is lost, save work if possible, quit Codex and reopen normally. Do not disable Gatekeeper or system protections globally as a troubleshooting shortcut.

Ordinary styling and functional problems can be reported through [GitHub Issues](https://github.com/collin520/codex-appearance-manager/issues/new/choose). Remove credentials and private conversation data before posting.

A dedicated confidential vulnerability-reporting channel has not yet been established for this experimental snapshot. Do not post exploitable security details or sensitive proof in a public issue. You may open a minimal, non-sensitive issue asking the maintainer to arrange a private reporting channel, without sharing the vulnerability itself. If GitHub private vulnerability reporting is subsequently enabled for this repository, use its private reporting flow instead. No security-response SLA is promised.
