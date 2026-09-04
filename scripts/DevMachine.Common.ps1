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
    foreach ($scope in @("Machine", "User")) {
        $variables = [Environment]::GetEnvironmentVariables($scope)
        foreach ($name in $variables.Keys) {
            if ($name -ieq "Path") {
                continue
            }
            Set-Item -Path "Env:$name" -Value $variables[$name]
        }
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $combinedPath = ($machinePath, $userPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ";"

    # Machine/User Path entries can contain unexpanded references (e.g. "%NVM_HOME%")
    # that GetEnvironmentVariable does not resolve. Expand them now that the
    # variables they reference have just been refreshed above.
    $env:Path = [Environment]::ExpandEnvironmentVariables($combinedPath)
}

function New-SetupSummary {
    return [ordered]@{
        Planned = New-Object System.Collections.ArrayList
        Installed = New-Object System.Collections.ArrayList
        AlreadyPresent = New-Object System.Collections.ArrayList
        Skipped = New-Object System.Collections.ArrayList
        Warning = New-Object System.Collections.ArrayList
        Manual = New-Object System.Collections.ArrayList
        Failed = New-Object System.Collections.ArrayList
    }
}

function Add-SetupResult {
    param(
        [Parameter(Mandatory = $true)]$Summary,
        [Parameter(Mandatory = $true)][ValidateSet("Planned", "Installed", "AlreadyPresent", "Skipped", "Warning", "Manual", "Failed")][string]$Status,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Message = ""
    )

    $entry = [pscustomobject]@{
        Name = $Name
        Message = $Message
    }

    [void]$Summary[$Status].Add($entry)
}

function Write-SetupInfo {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[dev-machine] $Message"
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found: $Path"
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-ManifestPackages {
    param([Parameter(Mandatory = $true)][string]$Path)

    $manifest = Read-JsonFile -Path $Path
    if ($null -eq $manifest.packages) {
        return @()
    }

    return @($manifest.packages)
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $FilePath @Arguments | Out-Host
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Write-SetupSummary {
    param([Parameter(Mandatory = $true)]$Summary)

    Write-Host ""
    Write-Host "Setup summary"
    Write-Host "-------------"

    foreach ($key in $Summary.Keys) {
        $items = @($Summary[$key])
        if ($items.Count -eq 0) {
            continue
        }

        Write-Host ""
        Write-Host "$key ($($items.Count))"
        foreach ($item in $items) {
            if ([string]::IsNullOrWhiteSpace($item.Message)) {
                Write-Host "  - $($item.Name)"
            } else {
                Write-Host "  - $($item.Name): $($item.Message)"
            }
        }
    }
}
