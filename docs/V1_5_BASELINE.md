# v1.5.0 execution baseline

The sole master plan is /Users/alhennessey/Desktop/traders_guild/sanctuary/docs/version_docs/ios/1.5.0.md. Its approved scope is frozen; the execution ledger may grow.

Approved-scope SHA-256: `52343abf9e3bbb13c2e13d8c40287a44fb49a016fe8f47b83e0efc1cdbf568d0`.

- Complete confirmed 1.4.1 baseline: `480b79b6942e60bf8ede21a2d28771dfc36248a8`.
- v1.5.0 version foundation: `72b6f2b06d94e58a65de5545760ff92401843ad5`, build 25 for local prototyping.
- Astra integration: `feat/1.5.0-avatar-markers`, `.worktrees/marker-avatar-ios`.
- Claude implementation: `claude/1.5.0-avatar-markers`, `.worktrees/marker-avatar-claude`.
- Xcode target inventory: iOS app and its two test targets only; no TradersGuildMac target.
- Baseline unit/build evidence and outstanding device QA: sanctuary `docs/version_docs/ios/1.4.1.md`; preservation did not re-run those tests or imply release acceptance.
- No push, deployment, production write, or Android v1.5 change.
- Managed worktree tool unavailable for sanctuary root (not a Git repository); isolated worktrees created using Git in the iOS repository.
