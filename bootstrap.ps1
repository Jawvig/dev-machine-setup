[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/Jawvig/dev-machine-setup.git",
    [string]$DestinationPath = (Join-Path $env:USERPROFILE "source\repos\dev-machine-setup"),
    [string]$Branch = "main",
    [switch]$Apply,
    [switch]$AcceptAgreements,
    [switch]$SkipMainSetup
)

$ErrorActionPreference = "Stop"

function Write-BootstrapInfo {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[bootstrap] $Message"
}

function Test-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-NetworkSecurityProtocol {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    } catch {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
}

function Update-CurrentProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = ($machinePath, $userPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ";"
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @Arguments
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Assert-ExternalCommandSucceeded {
    param(
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ($ExitCode -ne 0) {
        throw "$Description failed with exit code $ExitCode."
    }
}

function Register-AppInstallerPackage {
    Write-BootstrapInfo "Requesting App Installer registration."
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    } catch {
        Write-Warning "App Installer registration failed: $($_.Exception.Message)"
    }
}

function Repair-WingetPackageManager {
    Write-BootstrapInfo "Installing Microsoft.WinGet.Client from PSGallery."
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    Import-Module Microsoft.WinGet.Client -Force

    Write-BootstrapInfo "Repairing Windows Package Manager."
    Repair-WinGetPackageManager -AllUsers
}

function Ensure-Winget {
    if (Test-Command "winget") {
        Write-BootstrapInfo "winget is already available."
        return
    }

    Register-AppInstallerPackage
    Update-CurrentProcessPath
    if (Test-Command "winget") {
        Write-BootstrapInfo "winget is available after App Installer registration."
        return
    }

    try {
        Repair-WingetPackageManager
    } catch {
        Write-Warning "Windows Package Manager repair failed: $($_.Exception.Message)"
    }

    Update-CurrentProcessPath
    if (Test-Command "winget") {
        Write-BootstrapInfo "winget is available after repair."
        return
    }

    throw "winget is not available. Install App Installer from the Microsoft Store, then re-run this bootstrap script."
}

function Ensure-Git {
    if (Test-Command "git") {
        Write-BootstrapInfo "Git is already available."
        return
    }

    Write-BootstrapInfo "Installing Git with winget."
    $arguments = @("install", "--id", "Git.Git", "--exact", "--source", "winget", "--silent")
    if ($AcceptAgreements) {
        $arguments += @("--accept-package-agreements", "--accept-source-agreements")
    }

    Assert-ExternalCommandSucceeded -ExitCode (Invoke-ExternalCommand -FilePath "winget" -Arguments $arguments) -Description "Git install"
    Update-CurrentProcessPath

    if (-not (Test-Command "git")) {
        throw "Git was installed, but git.exe is not available on PATH in this process. Open a new elevated Windows PowerShell session and re-run this bootstrap script."
    }
}

function Sync-Repository {
    if (Test-Path -LiteralPath $DestinationPath) {
        $gitDirectory = Join-Path $DestinationPath ".git"
        if (-not (Test-Path -LiteralPath $gitDirectory)) {
            throw "DestinationPath already exists and is not a Git repository: $DestinationPath"
        }

        Write-BootstrapInfo "Using existing repository at $DestinationPath."
        Assert-ExternalCommandSucceeded -ExitCode (Invoke-ExternalCommand -FilePath "git" -Arguments @("-C", $DestinationPath, "fetch", "origin", $Branch)) -Description "git fetch"
        Assert-ExternalCommandSucceeded -ExitCode (Invoke-ExternalCommand -FilePath "git" -Arguments @("-C", $DestinationPath, "checkout", $Branch)) -Description "git checkout"
        Assert-ExternalCommandSucceeded -ExitCode (Invoke-ExternalCommand -FilePath "git" -Arguments @("-C", $DestinationPath, "pull", "--ff-only", "origin", $Branch)) -Description "git pull"
        return
    }

    $parent = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Write-BootstrapInfo "Cloning $RepoUrl to $DestinationPath."
    Assert-ExternalCommandSucceeded -ExitCode (Invoke-ExternalCommand -FilePath "git" -Arguments @("clone", "--branch", $Branch, $RepoUrl, $DestinationPath)) -Description "git clone"
}

function Invoke-MainSetup {
    $setupPath = Join-Path $DestinationPath "Setup-DevMachine.ps1"
    if (-not (Test-Path -LiteralPath $setupPath)) {
        throw "Main setup script not found after clone: $setupPath"
    }

    $arguments = @("-ExecutionPolicy", "Bypass", "-File", $setupPath)
    if ($Apply) {
        $arguments += "-Apply"
    }

    if ($AcceptAgreements) {
        $arguments += "-AcceptAgreements"
    }

    Write-BootstrapInfo "Invoking main setup script."
    Assert-ExternalCommandSucceeded -ExitCode (Invoke-ExternalCommand -FilePath "powershell.exe" -Arguments $arguments) -Description "Main setup"
}

if (-not (Test-IsAdministrator)) {
    Write-Warning "Run this from an elevated Windows PowerShell session for installs and machine settings."
}

Initialize-NetworkSecurityProtocol
Ensure-Winget
Ensure-Git
Sync-Repository

if ($SkipMainSetup) {
    Write-BootstrapInfo "Skipping main setup by request."
} else {
    Invoke-MainSetup
}

