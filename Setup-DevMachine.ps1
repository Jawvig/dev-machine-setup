[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$AcceptAgreements,
    [switch]$SkipSettings,
    [switch]$SkipWinget,
    [switch]$SkipChocolatey,
    [switch]$SkipNpm,
    [switch]$SkipStore,
    [string]$NodeVersion = "lts",
    [string]$ManifestsRoot = (Join-Path $PSScriptRoot "packages")
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "scripts\DevMachine.Common.ps1")
. (Join-Path $PSScriptRoot "scripts\Install-WingetPackages.ps1")
. (Join-Path $PSScriptRoot "scripts\Install-ChocolateyPackages.ps1")
. (Join-Path $PSScriptRoot "scripts\Install-NpmGlobalPackages.ps1")
. (Join-Path $PSScriptRoot "scripts\Install-StorePackages.ps1")
. (Join-Path $PSScriptRoot "scripts\Invoke-DeveloperSettings.ps1")

$summary = New-SetupSummary
$mode = if ($Apply) { "APPLY" } else { "PLAN" }
Write-SetupInfo "Mode: $mode"

if (-not (Test-IsAdministrator)) {
    Add-SetupResult -Summary $summary -Status "Warning" -Name "Elevation" -Message "Some installers and settings require an elevated Windows PowerShell session."
}

if (-not $Apply) {
    Write-SetupInfo "No changes will be made. Re-run with -Apply to install packages."
}

Initialize-NetworkSecurityProtocol

if (-not $SkipWinget) {
    if (-not (Test-Command "winget")) {
        Add-SetupResult -Summary $summary -Status "Manual" -Name "winget" -Message "Install App Installer / Windows Package Manager, then re-run this script."
    } else {
        Install-WingetPackages -ManifestPath (Join-Path $ManifestsRoot "winget.json") -Apply:$Apply -AcceptAgreements:$AcceptAgreements -Summary $summary
    }
} else {
    Add-SetupResult -Summary $summary -Status "Skipped" -Name "winget packages" -Message "Skipped by switch."
}

if (-not $SkipChocolatey) {
    if (-not (Test-Command "choco")) {
        Install-ChocolateyBootstrap -Apply:$Apply -Summary $summary
    }

    if (Test-Command "choco") {
        Install-ChocolateyPackages -ManifestPath (Join-Path $ManifestsRoot "chocolatey.json") -Apply:$Apply -Summary $summary
    } elseif (-not $Apply) {
        Add-SetupResult -Summary $summary -Status "Planned" -Name "Chocolatey packages" -Message "Would install after Chocolatey bootstrap."
    } else {
        Add-SetupResult -Summary $summary -Status "Manual" -Name "Chocolatey packages" -Message "Chocolatey is not available after bootstrap attempt."
    }
} else {
    Add-SetupResult -Summary $summary -Status "Skipped" -Name "Chocolatey packages" -Message "Skipped by switch."
}

if (-not $SkipStore) {
    if (Test-Command "winget") {
        Install-StorePackages -ManifestPath (Join-Path $ManifestsRoot "store.json") -Apply:$Apply -AcceptAgreements:$AcceptAgreements -Summary $summary
    } else {
        Add-SetupResult -Summary $summary -Status "Manual" -Name "Store packages" -Message "winget is required for Microsoft Store installs."
    }
} else {
    Add-SetupResult -Summary $summary -Status "Skipped" -Name "Store packages" -Message "Skipped by switch."
}

if (-not $SkipNpm) {
    Update-CurrentProcessPath
    Install-NpmGlobalPackages -ManifestPath (Join-Path $ManifestsRoot "npm-global.json") -NodeVersion $NodeVersion -Apply:$Apply -Summary $summary
} else {
    Add-SetupResult -Summary $summary -Status "Skipped" -Name "npm global packages" -Message "Skipped by switch."
}

if (-not $SkipSettings) {
    Invoke-DeveloperSettings -ConfigurationPath (Join-Path $PSScriptRoot "dev-config.winget") -Apply:$Apply -AcceptAgreements:$AcceptAgreements -Summary $summary
} else {
    Add-SetupResult -Summary $summary -Status "Skipped" -Name "Developer settings" -Message "Skipped by switch."
}

Write-SetupSummary $summary

if ($summary.Failed.Count -gt 0) {
    exit 1
}
