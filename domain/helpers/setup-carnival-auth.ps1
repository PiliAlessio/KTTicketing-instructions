#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up Azure DevOps / Carnival feed authentication for NuGet.

.DESCRIPTION
    Prompts for Azure DevOps username and PAT token, then creates or updates
    the .nuget/nuget.config file with Base64-encoded credentials for the Carnival feed.

.PARAMETER ProjectRoot
    The root directory of the project. Defaults to the current directory.

.EXAMPLE
    .\setup-carnival-auth.ps1
    .\setup-carnival-auth.ps1 -ProjectRoot "C:\MyProject"
#>

param (
    [string]$ProjectRoot = (Get-Location).Path
)

$NugetConfigPath = Join-Path $ProjectRoot ".nuget" "nuget.config"
$NugetDir = Split-Path $NugetConfigPath

# Ensure .nuget directory exists
if (-not (Test-Path $NugetDir)) {
    Write-Host "Creating .nuget directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $NugetDir | Out-Null
}

# Prompt for credentials
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Carnival Feed Authentication Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$username = Read-Host "Enter your Azure DevOps username"
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "Error: Username cannot be empty." -ForegroundColor Red
    exit 1
}

# Read PAT token securely
$patSecure = Read-Host "Enter your Azure DevOps PAT token" -AsSecureString
$pat = [System.Net.NetworkCredential]::new("", $patSecure).Password

if ([string]::IsNullOrWhiteSpace($pat)) {
    Write-Host "Error: PAT token cannot be empty." -ForegroundColor Red
    exit 1
}

# Base64 encode credentials
$credentialString = "${username}:${pat}"
$credentialBytes = [System.Text.Encoding]::UTF8.GetBytes($credentialString)
$credentialBase64 = [System.Convert]::ToBase64String($credentialBytes)

# Create nuget.config content
$nugetConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <!-- Public NuGet feed -->
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <!-- Carnival feed: Neptune platform packages -->
    <add key="Carnival" value="https://pkgs.dev.azure.com/abg-devops/_packaging/abg-mec.feed/nuget/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <Carnival>
      <add key="Username" value="$username" />
      <add key="ClearTextPassword" value="$pat" />
    </Carnival>
  </packageSourceCredentials>
  <!-- Default push source -->
  <config>
    <add key="defaultPushSource" value="nuget.org" />
  </config>
</configuration>
"@

# Write config file
try {
    Set-Content -Path $NugetConfigPath -Value $nugetConfig -Encoding UTF8
    Write-Host ""
    Write-Host "✓ Authentication configured successfully!" -ForegroundColor Green
    Write-Host "  Config saved to: $NugetConfigPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now restore Neptune packages:" -ForegroundColor Cyan
    Write-Host "  dotnet restore" -ForegroundColor Gray
}
catch {
    Write-Host "Error: Failed to write config file." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
