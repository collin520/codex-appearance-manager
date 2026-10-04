# Public release checklist

The owner authorized the initial experimental source upload on 2026-10-04. Do not publish build caches, private user data or original local Git history. Unchecked items remain explicit limitations or follow-up work; approval does not turn them into verified results.

## Local preparation

- [x] Owner confirmed the source-publication scope.
- [x] Import current source files and only active theme artwork using an allowlist.
- [x] Preserve runtime code and CSS unchanged; record hashes in `source-inventory.md`.
- [x] Add English/Chinese coverage disclaimers and accurate source-build instructions.
- [x] Complete independent read-only review of imported payload and documentation.
- [x] Run the unchanged automated tests from this directory and record results: 68/68 passed.
- [x] Build Release, package the app and verify its local signature/resource layout.
- [x] Recheck all 34 source hashes and the initial 46-file publication allowlist after validation; verify local links, bilingual disclaimers and privacy patterns.

## Before public upload

- [x] Select and add the code license with owner approval: MIT, 2026-10-04.
- [x] Owner approved MIT distribution of project-owned backgrounds, icon and edited previews, 2026-10-04.
- [x] Recheck the expanded 51-file allowlist, 34 unchanged source hashes, 35 public text files, local links and both edited preview files.
- [ ] Complete artwork provenance review; retain third-party notices as needed.
- [x] Approve the final appearance of both prepared AI-edited previews; original private screenshots are excluded.
- [x] Add GitHub Issues feedback links and a bilingual issue-report template.
- [ ] Establish a dedicated confidential security-reporting channel; the current limitation and safe coordination guidance are documented.
- [x] Explicitly label this source snapshot experimental; a certified version matrix is not claimed.
- [ ] Test on another Mac before claiming independently verified installation/portability.
- [x] Review the exact 52-file staged upload list against `publication-inventory.md`; exclude original `.git` history, `.build`, `.swiftpm`, `dist`, `.superpowers`, `.DS_Store` and local preparation/planning records.
- [x] Obtain the owner's explicit approval to initialize/connect Git and upload to the public repository, 2026-10-04.

## Optional later work

External CSS conflict detection, packaged-theme update handling, complete CSS safety checks, broader visual fixtures, accessibility checks, CI, signed/notarized installers and automated updates are not included in this preparation pass.
