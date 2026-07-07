function Invoke-DeveloperSettings {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigurationPath,
        [switch]$Apply,
        [switch]$AcceptAgreements,
        [Parameter(Mandatory = $true)]$Summary
    )

    if (-not (Test-Path -LiteralPath $ConfigurationPath)) {
        Add-SetupResult -Summary $Summary -Status "Skipped" -Name "Developer settings" -Message "No dev-config.winget file found."
        return
    }

    if (-not (Test-Command "winget")) {
        Add-SetupResult -Summary $Summary -Status "Manual" -Name "Developer settings" -Message "winget is required for winget configure."
        return
    }

    if (-not $Apply) {
        Add-SetupResult -Summary $Summary -Status "Planned" -Name "Developer settings" -Message "Would run winget configure on dev-config.winget."
        return
    }

    $arguments = @("configure", "--file", $ConfigurationPath)
    if ($AcceptAgreements) {
        $arguments += @("--accept-configuration-agreements")
    }

    $exitCode = Invoke-ExternalCommand -FilePath "winget" -Arguments $arguments
    if ($exitCode -eq 0) {
        Add-SetupResult -Summary $Summary -Status "Installed" -Name "Developer settings" -Message "Applied dev-config.winget."
    } else {
        Add-SetupResult -Summary $Summary -Status "Warning" -Name "Developer settings" -Message "winget configure exited with code $exitCode"
    }
}
