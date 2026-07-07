[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$packageRoot = Join-Path $Root "packages"
$manifestFiles = @(
    "winget.json",
    "chocolatey.json",
    "npm-global.json",
    "store.json"
)

$seen = @{}
$errors = New-Object System.Collections.ArrayList

foreach ($file in $manifestFiles) {
    $path = Join-Path $packageRoot $file
    if (-not (Test-Path -LiteralPath $path)) {
        [void]$errors.Add("Missing manifest: $file")
        continue
    }

    $json = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    if ($null -eq $json.packages) {
        [void]$errors.Add("Manifest has no packages array: $file")
        continue
    }

    foreach ($package in @($json.packages)) {
        if ([string]::IsNullOrWhiteSpace($package.id)) {
            [void]$errors.Add("Package without id in $file")
            continue
        }

        $key = $package.id.ToString().ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            [void]$errors.Add("Duplicate package id '$($package.id)' in $file and $($seen[$key])")
        } else {
            $seen[$key] = $file
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Manifest validation failed:"
    foreach ($errorMessage in $errors) {
        Write-Host "  - $errorMessage"
    }
    exit 1
}

Write-Host "Manifest validation passed."
