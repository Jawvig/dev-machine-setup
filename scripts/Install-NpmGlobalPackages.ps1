function Use-ConfiguredNode {
    param(
        [Parameter(Mandatory = $true)][string]$NodeVersion,
        [switch]$Apply,
        [Parameter(Mandatory = $true)]$Summary
    )

    if (-not (Test-Command "nvm")) {
        if ($Apply) {
            Add-SetupResult -Summary $Summary -Status "Manual" -Name "NVM for Windows" -Message "Install or re-open PowerShell after winget installs NVM."
        } else {
            Add-SetupResult -Summary $Summary -Status "Planned" -Name "NVM for Windows" -Message "Would use NVM after winget installs it."
        }
        return $false
    }

    if (-not $Apply) {
        Add-SetupResult -Summary $Summary -Status "Planned" -Name "Node.js $NodeVersion" -Message "Would install/use through NVM."
        return $true
    }

    $installExit = Invoke-ExternalCommand -FilePath "nvm" -Arguments @("install", $NodeVersion)
    if ($installExit -ne 0) {
        Add-SetupResult -Summary $Summary -Status "Failed" -Name "Node.js $NodeVersion" -Message "nvm install exited with code $installExit"
        return $false
    }

    $useExit = Invoke-ExternalCommand -FilePath "nvm" -Arguments @("use", $NodeVersion)
    if ($useExit -ne 0) {
        Add-SetupResult -Summary $Summary -Status "Failed" -Name "Node.js $NodeVersion" -Message "nvm use exited with code $useExit"
        return $false
    }

    Add-SetupResult -Summary $Summary -Status "Installed" -Name "Node.js $NodeVersion" -Message "Selected through NVM."
    return $true
}

function Test-NpmPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)

    $output = & npm list --global --depth=0 --parseable 2>$null
    return ($LASTEXITCODE -eq 0 -and ($output -match "\\node_modules\\$([regex]::Escape($Id.Replace("/", "\\")))$"))
}

function Install-NpmGlobalPackages {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [string]$NodeVersion = "lts",
        [switch]$Apply,
        [Parameter(Mandatory = $true)]$Summary
    )

    $nodeReady = Use-ConfiguredNode -NodeVersion $NodeVersion -Apply:$Apply -Summary $Summary
    if (-not $nodeReady -and $Apply) {
        return
    }

    if (-not (Test-Command "npm")) {
        if ($Apply) {
            Add-SetupResult -Summary $Summary -Status "Manual" -Name "npm" -Message "npm was not found after Node setup."
            return
        }
    }

    foreach ($package in (Get-ManifestPackages -Path $ManifestPath)) {
        if ($package.enabled -eq $false) {
            Add-SetupResult -Summary $Summary -Status "Skipped" -Name $package.id -Message $package.reason
            continue
        }

        if (-not $Apply) {
            Add-SetupResult -Summary $Summary -Status "Planned" -Name $package.id -Message $package.reason
            continue
        }

        if (Test-NpmPackageInstalled -Id $package.id) {
            Add-SetupResult -Summary $Summary -Status "AlreadyPresent" -Name $package.id -Message $package.name
            continue
        }

        $exitCode = Invoke-ExternalCommand -FilePath "npm" -Arguments @("install", "--global", [string]$package.id)
        if ($exitCode -eq 0) {
            Add-SetupResult -Summary $Summary -Status "Installed" -Name $package.id -Message $package.name
        } else {
            Add-SetupResult -Summary $Summary -Status "Failed" -Name $package.id -Message "npm exited with code $exitCode"
        }
    }
}
