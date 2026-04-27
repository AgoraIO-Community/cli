#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$Version = $env:VERSION,
    [string]$InstallDir = $(if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\Agora\bin' }),
    [string]$GitHubRepo = $(if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { 'AgoraIO-Extensions/agora-cli' }),
    [switch]$AddToPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$GitHubApiUrl = if ($env:GITHUB_API_URL) { $env:GITHUB_API_URL } else { 'https://api.github.com' }
$ReleasesDownloadBaseUrl = if ($env:RELEASES_DOWNLOAD_BASE_URL) { $env:RELEASES_DOWNLOAD_BASE_URL } else { "https://github.com/$GitHubRepo/releases/download" }
$ReleasesPageUrl = if ($env:RELEASES_PAGE_URL) { $env:RELEASES_PAGE_URL } else { "https://github.com/$GitHubRepo/releases" }
$AuthToken = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { $null }

function Write-Info {
    param([string]$Message)
    Write-Host $Message
}

function Fail {
    param([string]$Message)
    throw $Message
}

function Normalize-Version {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    if ($Value.StartsWith('v')) {
        return $Value.Substring(1)
    }

    return $Value
}

function Get-AuthHeaders {
    $headers = @{
        Accept = 'application/vnd.github+json'
    }

    if ($AuthToken) {
        $headers.Authorization = "Bearer $AuthToken"
    }

    return $headers
}

function Resolve-Architecture {
    switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()) {
        'x64'   { return 'amd64' }
        'arm64' { return 'arm64' }
        default { Fail "Unsupported architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)." }
    }
}

function Resolve-Version {
    if ($script:Version) {
        $script:Version = Normalize-Version $script:Version
        return
    }

    $latestUrl = "$($GitHubApiUrl.TrimEnd('/'))/repos/$GitHubRepo/releases/latest"

    try {
        $release = Invoke-RestMethod -Uri $latestUrl -Headers (Get-AuthHeaders)
    } catch {
        Fail "Could not resolve the latest release. Set VERSION explicitly or provide GITHUB_TOKEN / GH_TOKEN if you are hitting rate limits. Release page: $ReleasesPageUrl"
    }

    $script:Version = Normalize-Version $release.tag_name
    if (-not $script:Version) {
        Fail 'Could not parse the latest release version.'
    }
}

function Download-File {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -Headers (Get-AuthHeaders)
    } catch {
        Fail "Failed to download $Url`nRelease page: $ReleasesPageUrl`nCheck your network or proxy settings, or try again with VERSION pinned."
    }
}

function Get-ExpectedChecksum {
    param(
        [Parameter(Mandatory = $true)][string]$ChecksumsPath,
        [Parameter(Mandatory = $true)][string]$FileName
    )

    foreach ($line in Get-Content -Path $ChecksumsPath) {
        if ($line -match '^\s*([0-9A-Fa-f]+)\s+[*]?(.+?)\s*$') {
            if ($matches[2] -eq $FileName) {
                return $matches[1].ToLowerInvariant()
            }
        }
    }

    return $null
}

function Ensure-InstallDirectory {
    try {
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    } catch {
        Fail "Could not create or write to $InstallDir. Use a writable -InstallDir or rerun from an elevated PowerShell session."
    }
}

function Add-InstallDirToUserPath {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $segments = @()
    if ($userPath) {
        $segments = $userPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
    }

    if ($segments -contains $InstallDir) {
        Write-Info "$InstallDir is already on your user PATH."
        return
    }

    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Info "Added $InstallDir to your user PATH."
}

function Verify-Binary {
    param([string]$Path)

    try {
        & $Path --version *> $null
        return
    } catch {
    }

    try {
        & $Path --help *> $null
    } catch {
        Fail "Installed binary did not start correctly: $Path"
    }
}

function Show-ExistingInstall {
    $command = Get-Command agora -ErrorAction SilentlyContinue
    if (-not $command) {
        return
    }

    $versionOutput = ''
    try {
        $versionOutput = (& $command.Source --version 2>$null | Out-String).Trim()
    } catch {
    }

    if ($versionOutput) {
        Write-Info "Existing install: $versionOutput ($($command.Source))"
    } else {
        Write-Info "Existing install detected at $($command.Source)"
    }
}

$Version = Normalize-Version $Version
$arch = Resolve-Architecture
$fileName = "agora-cli-go_v$Version" + "_windows_${arch}.zip"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agora-install-" + [System.Guid]::NewGuid().ToString('N'))
$archivePath = Join-Path $tempRoot $fileName
$checksumsPath = Join-Path $tempRoot 'checksums.txt'
$extractDir = Join-Path $tempRoot 'extract'
$sourceBinary = Join-Path $extractDir 'agora.exe'
$destinationBinary = Join-Path $InstallDir 'agora.exe'
$tempDestinationBinary = Join-Path $InstallDir ('.agora.tmp.' + [System.Guid]::NewGuid().ToString('N') + '.exe')

try {
    Resolve-Version
    $fileName = "agora-cli-go_v$Version" + "_windows_${arch}.zip"
    $archiveUrl = "$($ReleasesDownloadBaseUrl.TrimEnd('/'))/v$Version/$fileName"
    $checksumsUrl = "$($ReleasesDownloadBaseUrl.TrimEnd('/'))/v$Version/checksums.txt"

    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

    Show-ExistingInstall
    Write-Info "Installing agora $Version (windows/$arch) -> $destinationBinary"

    Download-File -Url $archiveUrl -Destination $archivePath
    Download-File -Url $checksumsUrl -Destination $checksumsPath

    $expectedChecksum = Get-ExpectedChecksum -ChecksumsPath $checksumsPath -FileName $fileName
    if (-not $expectedChecksum) {
        Fail "Could not find checksum for $fileName in checksums.txt."
    }

    $actualChecksum = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualChecksum -ne $expectedChecksum) {
        Fail "Checksum verification failed for $fileName."
    }

    Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force
    if (-not (Test-Path -LiteralPath $sourceBinary)) {
        Fail "Expected binary not found after extraction: $sourceBinary"
    }

    Ensure-InstallDirectory
    Copy-Item -LiteralPath $sourceBinary -Destination $tempDestinationBinary -Force
    Move-Item -LiteralPath $tempDestinationBinary -Destination $destinationBinary -Force

    Verify-Binary -Path $destinationBinary
    Write-Info "Installed agora to $destinationBinary"

    $resolved = Get-Command agora -ErrorAction SilentlyContinue
    if ($resolved) {
        Write-Info "Current PATH resolves agora to $($resolved.Source)"
    } else {
        Write-Warning "agora is not on your PATH yet."
        Write-Host "Current session: `$env:Path = `"$InstallDir;`$env:Path`""
        Write-Host "Persistent user PATH: add $InstallDir in Windows Environment Variables"
    }

    if ($AddToPath) {
        Add-InstallDirToUserPath
        Write-Host "Open a new terminal after updating PATH."
    }

    Write-Info 'Done. Run: agora --help'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
