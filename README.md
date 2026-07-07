# Windows Dev Machine Setup

PowerShell scripts for setting up a new Windows development machine.

The scripts are written for Windows PowerShell 5.1 because PowerShell 7 is one
of the tools being installed. The default run is non-mutating: it prints the
planned work. Add `-Apply` to install packages and apply settings.

## Usage

From an elevated Windows PowerShell prompt:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Setup-DevMachine.ps1
.\Setup-DevMachine.ps1 -Apply -AcceptAgreements
```

Useful switches:

- `-SkipSettings`
- `-SkipWinget`
- `-SkipChocolatey`
- `-SkipNpm`
- `-SkipStore`
- `-AcceptAgreements`
- `-NodeVersion lts`

## Package Ownership

- `winget` owns most desktop and developer tools.
- Chocolatey is used for packages that are Chocolatey-specific or preferred
  there.
- NVM for Windows owns Node.js. Global npm packages install after NVM selects
  the configured Node version.
- Microsoft Store installs go through `winget --source msstore`.
- Package versions are not pinned; the scripts install the latest stable
  version available from the configured source.
- ChatGPT Desktop was observed on the current machine, but no official
  installable winget package was found during setup planning, so it is not
  installed automatically.

## Microsoft Developer Configuration

The repo does not use Microsoft's Build 2026 developer configuration as a
package source. Instead, package installs remain in PowerShell manifests and
`dev-config.winget` is reserved for Windows developer settings through
`winget configure`.

The repo-local Codex skill in `skills/review-windows-dev-config/` is intended
for reviewing the latest Microsoft `dev-config.winget` and proposing updates to
this repo.

## Inventories

Generated inventories and package-manager exports should go under `artifacts/`.
They are intentionally ignored so current-machine snapshots do not become the
desired state by accident.

## Validation

```powershell
.\scripts\Test-Manifests.ps1
.\Setup-DevMachine.ps1
```
