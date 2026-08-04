[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Root)

$ErrorActionPreference = 'Stop'
$startSource = [System.IO.File]::ReadAllText((Join-Path $Root 'scripts\start-dream-skin.ps1'))
$verifySource = [System.IO.File]::ReadAllText((Join-Path $Root 'scripts\verify-dream-skin.ps1'))
$commonSource = [System.IO.File]::ReadAllText((Join-Path $Root 'scripts\common-windows.ps1'))

foreach ($required in @(
  'EnumWindows',
  'GetWindowThreadProcessId',
  'IsWindowVisible',
  'IsIconic',
  'GetWindowRect',
  'DwmGetWindowAttribute',
  'Get-DreamSkinProcessExecutablePath',
  'Test-DreamSkinPathEqual'
)) {
  if (-not $commonSource.Contains($required)) {
    throw "Win32 fallback no longer verifies required native evidence: $required"
  }
}

foreach ($source in @($startSource, $verifySource)) {
  foreach ($required in @(
    'Wait-DreamSkinWin32WindowEvidence',
    '--win32-window-pid',
    '--win32-window-hwnd',
    '--win32-window-width',
    '--win32-window-height'
  )) {
    if (-not $source.Contains($required)) {
      throw "Windows launcher no longer forwards required HWND evidence: $required"
    }
  }
}

foreach ($forbidden in @(
  '$skinLooksRendered',
  '$verifyJson.installed',
  '$readiness.documentPass',
  'the theme is rendered'
)) {
  if ($startSource.Contains($forbidden)) {
    throw "Startup still contains the retired renderer-only safety fallback: $forbidden"
  }
}

if (-not $startSource.Contains('--allow-hidden-document') -or
    $verifySource.Contains('--allow-hidden-document')) {
  throw 'Only managed startup may use the exact-HWND hidden-document readiness allowance.'
}

if (-not $startSource.Contains('if ($launchedWithCdp) {')) {
  throw 'A failed verified launch no longer restarts the CDP session during rollback.'
}

Write-Output 'PASS: Windows fallback requires verified Win32 HWND evidence.'
