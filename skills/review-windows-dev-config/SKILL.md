---
name: review-windows-dev-config
description: Review Microsoft's latest Windows Developer Configurations dev-config.winget against this repo's PowerShell manifests and settings-only dev-config.winget. Use when Codex needs to compare Microsoft Build-era Windows developer setup recommendations with this repo, identify new developer tools or settings, and propose updates without blindly adopting Microsoft's full package list.
---

# Review Windows Dev Config

Use this skill to update this repo's setup approach from Microsoft's latest Windows Developer Configurations material.

## Workflow

1. Locate the latest Microsoft `dev-config.winget` source from official Microsoft documentation or GitHub.
2. Read this repo's package manifests under `packages/` and the settings-only `dev-config.winget`.
3. Classify each Microsoft configuration item:
   - package already covered by this repo
   - package candidate for `packages/winget.json`
   - Store package candidate for `packages/store.json`
   - developer setting candidate for this repo's `dev-config.winget`
   - excluded because it is personal, duplicate, preview-only without user intent, or outside dev-tool scope
4. Prefer this repo's rules:
   - winget owns overlapping desktop/dev tools
   - Chocolatey is only for Chocolatey-specific or strongly preferred packages
   - NVM for Windows owns Node.js
   - npm globals install after Node is selected
   - package versions remain unpinned unless the user asks otherwise
5. Produce a concise recommendation with concrete manifest/settings changes.

Do not run `winget configure` or install packages while reviewing. Treat Microsoft's file as an input to review, not as an authoritative desired state.
