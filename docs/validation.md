# Local preparation validation

Date: 2026-10-04. Scope: source import, unchanged automated tests, local Release build and package checks. No actual Codex process was started, stopped, restarted or injected during this pass.

## Environment

- macOS 26.5, arm64.
- Apple Swift 6.3.1; swift-driver 1.148.6.
- Package minimums remain macOS 14 and Swift tools 6.0. Passing in this environment does not certify all minimum-supported environments.

## Evidence

| Check | Actual result | Scope |
| --- | --- | --- |
| Imported snapshot | 34 files, 12,599,370 bytes; all SHA-256 and sizes match original current working files and inventory | Current-source preservation, including uncommitted changes |
| Theme IDs and resources | Both IDs match; all six stylesheet image references resolve to the selected active backgrounds | Asset completeness, not rendering correctness |
| `swift run CodexAppearanceTestRunner` | Exit 0; 68 PASS, 0 FAIL; repeated cached run also passed | Existing behavior/fixture and CSS-source checks, not complete real UI coverage |
| `swift build -c release` | Exit 0 | Local release compilation |
| `./scripts/package-app.sh` | Exit 0 | Local app bundle creation without opening it |
| Packaged resource verification | Executable, Info.plist, icon and complete theme packages present; packaged theme hashes match source | Resource layout and integrity |
| `codesign --verify --deep --strict` | Exit 0 | Local signature validity only; the package is ad-hoc signed, not notarized |
| Initial text privacy scan | 33 source/documentation text files; zero searched personal-path/name/credential-pattern matches | Pattern scan, not proof of absence of every possible secret |
| Initial publication allowlist check | 46 selected files, including 32 text files; zero searched privacy/credential matches; local links and both coverage disclaimers checked | Before adding MIT and edited demonstrations; excludes local-only records, Finder metadata and build outputs |
| Artwork visual inspection | Active forest/rainy backgrounds and icon source viewed; no private chat screenshots or obvious identifying text observed | Visual privacy only, not rights clearance |
| PNG metadata check | 13 PNGs checked; icon-size EXIF fields were numeric color-space/dimension metadata | Not comprehensive binary forensics or validation of C2PA provenance/signatures |
| Independent read-only review | Source hashes/resources and public claims reviewed; no Critical/Important local-preparation issue identified | Reviewer did not independently execute build/tests or native UI checks |
| Post-license/preview check | 51 allowlisted files exist; 34 imported hashes unchanged; 35 public text files have zero searched privacy/credential matches; local Markdown links resolve; both preview PNG signatures valid | After adding MIT and AI-edited demonstrations; visual review found no original private names/text, not complete secret/metadata forensics or native UI verification |

The reviewer observed an outdated initial-preparation status while the parent was updating it. The final local preparation record now reflects owner confirmation and completed import; it is not selected for public upload.

## Documentation review and handling decisions

- The owner's standalone publication directory is used rather than a Git worktree. During initial local preparation, no Git initialization, copied history, commit, remote setup or push occurred. Git-dependent execution helpers were replaced by an ignored local ledger. The owner subsequently authorized Git integration and upload; original Git history remains excluded.
- Application code and CSS were imported byte-for-byte. Existing runtime limitations were documented, not silently fixed. This pass therefore does not resolve those existing defects.
- The independent reviewer set aside real UI/accessibility/performance, other machines/versions, adversarial CDP/custom-theme security, complete hidden metadata/rights, remote publication/CI and future files. They remain explicitly unverified or pending in the compatibility, security, licensing and release documents; no broader guarantee is made.
- Local planning/review records and the execution ledger are retained but ignored for public upload. Use the explicit publication inventory, not a zip of the entire working folder.
- No unresolved reviewer Minor remains: the observed stale preparation status was corrected and the final record checked.

## Not verified or still pending

- Complete CSS component/state coverage; any real native popup or full UI flow in this pass.
- A certified Codex version/build compatibility matrix, minimum-macOS acceptance, Intel macOS or another Mac.
- Accessibility and performance guarantees.
- Gatekeeper recipient acceptance, Developer ID signing or notarization.
- Adversarial local-debugger identity, port/origin behavior in the live app and arbitrary custom theme sandboxing.
- Complete snippet/icon/artwork provenance. The owner selected MIT for source/CSS/scripts/project-authored documentation and project-owned artwork after initial validation; `LICENSE` is now present. This does not grant third-party rights.
- Recipient installation and a packaged GitHub Release. The owner approved the final preview appearance and the initial source upload on 2026-10-04; that approval is not a claim that upload or recipient acceptance has completed. The previews are not native UI evidence.

## Initial source upload preparation

On 2026-10-04 the 68 existing tests were rerun successfully before committing. Runtime source and CSS remain unchanged. The upload list was expanded to 52 files to include the bilingual GitHub issue template; README files show the owner-approved edited demonstrations and label the snapshot experimental. All 34 source hashes remain unchanged, 36 public text files passed the searched privacy patterns and local-link checks, and 16 selected binary artwork files contained none of the searched identifying strings. These scans are not comprehensive forensics. GitHub repository metadata confirmed that the target is public, empty and has Issues enabled before upload. A new local repository uses a GitHub no-reply author email; only the reviewed allowlist is staged. This preparation note is not proof of successful push; verify the remote commit independently.

Known limitations and reporting guidance are in `compatibility.md`, `security.md` and the two READMEs. Do not turn these local results into a claim of fully covered or universally compatible styling.
