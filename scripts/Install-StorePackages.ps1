function Install-StorePackages {
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

        $arguments = @("install", "--id", [string]$package.id, "--exact", "--source", "msstore", "--silent")
        if ($AcceptAgreements) {
            $arguments += @("--accept-package-agreements", "--accept-source-agreements")
        }

        $exitCode = Invoke-ExternalCommand -FilePath "winget" -Arguments $arguments
        if ($exitCode -eq 0) {
            Add-SetupResult -Summary $Summary -Status "Installed" -Name $package.id -Message $package.name
        } else {
            Add-SetupResult -Summary $Summary -Status "Failed" -Name $package.id -Message "winget msstore exited with code $exitCode"
        }
    }
}
