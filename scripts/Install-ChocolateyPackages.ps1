function Install-ChocolateyBootstrap {
    param(
        [switch]$Apply,
        [Parameter(Mandatory = $true)]$Summary
    )

    if (-not $Apply) {
        Add-SetupResult -Summary $Summary -Status "Planned" -Name "Chocolatey" -Message "Would bootstrap Chocolatey if it is missing."
        return
    }

    try {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
        $installScript = (New-Object Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1")
        Invoke-Expression $installScript
        Update-CurrentProcessPath
        if (Test-Command "choco") {
            Add-SetupResult -Summary $Summary -Status "Installed" -Name "Chocolatey" -Message "Bootstrapped Chocolatey."
        } else {
            Add-SetupResult -Summary $Summary -Status "Failed" -Name "Chocolatey" -Message "Bootstrap completed but choco was not found on PATH."
        }
    } catch {
        Add-SetupResult -Summary $Summary -Status "Failed" -Name "Chocolatey" -Message $_.Exception.Message
    }
}

function Test-ChocolateyPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)

    $output = & choco list --local-only --exact $Id --limit-output 2>$null
    return ($LASTEXITCODE -eq 0 -and ($output -match "^$([regex]::Escape($Id))\|"))
}

function Install-ChocolateyPackages {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [switch]$Apply,
        [Parameter(Mandatory = $true)]$Summary
    )

    foreach ($package in (Get-ManifestPackages -Path $ManifestPath)) {
        if ($package.enabled -eq $false) {
            Add-SetupResult -Summary $Summary -Status "Skipped" -Name $package.id -Message $package.reason
            continue
        }

        if (-not $Apply) {
            Add-SetupResult -Summary $Summary -Status "Planned" -Name $package.id -Message $package.reason
            continue
        }

        if (Test-ChocolateyPackageInstalled -Id $package.id) {
            Add-SetupResult -Summary $Summary -Status "AlreadyPresent" -Name $package.id -Message $package.name
            continue
        }

        $exitCode = Invoke-ExternalCommand -FilePath "choco" -Arguments @("install", [string]$package.id, "-y", "--no-progress")
        if ($exitCode -eq 0) {
            Add-SetupResult -Summary $Summary -Status "Installed" -Name $package.id -Message $package.name
        } else {
            Add-SetupResult -Summary $Summary -Status "Failed" -Name $package.id -Message "choco exited with code $exitCode"
        }
    }
}
