function Test-WingetPackageInstalled {
    param([Parameter(Mandatory = $true)][string]$Id)

    $arguments = @("list", "--id", $Id, "--exact", "--accept-source-agreements")
    $output = & winget @arguments 2>$null
    return ($LASTEXITCODE -eq 0 -and ($output -match [regex]::Escape($Id)))
}

function Install-WingetPackages {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [switch]$Apply,
        [switch]$AcceptAgreements,
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

        if (Test-WingetPackageInstalled -Id $package.id) {
            Add-SetupResult -Summary $Summary -Status "AlreadyPresent" -Name $package.id -Message $package.name
            continue
        }

        $source = if ($package.source) { [string]$package.source } else { "winget" }
        $arguments = @("install", "--id", [string]$package.id, "--exact", "--source", $source, "--silent")
        if ($AcceptAgreements) {
            $arguments += @("--accept-package-agreements", "--accept-source-agreements")
        }

        $exitCode = Invoke-ExternalCommand -FilePath "winget" -Arguments $arguments
        if ($exitCode -eq 0) {
            Add-SetupResult -Summary $Summary -Status "Installed" -Name $package.id -Message $package.name
        } else {
            Add-SetupResult -Summary $Summary -Status "Failed" -Name $package.id -Message "winget exited with code $exitCode"
        }
    }
}
