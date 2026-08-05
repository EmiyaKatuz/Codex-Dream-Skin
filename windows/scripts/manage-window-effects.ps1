[CmdletBinding()]
param(
  [ValidateSet('Acrylic', 'System')]
  [string]$Set,
  [switch]$Status
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')

if ([bool]$Set -eq [bool]$Status) {
  throw 'Choose exactly one of -Set Acrylic, -Set System, or -Status.'
}

$operationLock = Enter-DreamSkinOperationLock
try {
  $stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  $settings = if ($Status) {
    Read-DreamSkinWindowEffects -StateRoot $stateRoot
  } else {
    Write-DreamSkinWindowEffects -StateRoot $stateRoot -WindowMaterial $Set.ToLowerInvariant()
  }
  $environment = Get-DreamSkinAcrylicEnvironment
  [pscustomobject]@{
    schemaVersion = $settings.SchemaVersion
    platform = $settings.Platform
    windowMaterial = $settings.WindowMaterial
    path = $settings.Path
    exists = $settings.Exists
    windowsBuild = $environment.Build
    transparencyEnabled = $environment.TransparencyEnabled
    acrylicSupported = $environment.Supported
    appliesOnNextDreamSkinLaunch = $true
  } | ConvertTo-Json -Depth 3
} finally {
  Exit-DreamSkinOperationLock -Mutex $operationLock
}
