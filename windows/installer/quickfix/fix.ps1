[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
$stateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$patchScript = Join-Path $packageRoot 'scripts\patch-dream-skin.ps1'

if (-not (Test-Path -LiteralPath $patchScript -PathType Leaf)) {
  throw "The quick-fix package is incomplete: $patchScript"
}

& $patchScript -SourceRoot $packageRoot -StateRoot $stateRoot -DryRun:$DryRun
exit $LASTEXITCODE
