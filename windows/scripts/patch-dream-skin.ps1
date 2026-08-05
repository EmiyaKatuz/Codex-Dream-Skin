[CmdletBinding()]
param(
  [string]$SourceRoot,
  [string]$StateRoot,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Assert-DreamSkinPatchSource {
  param([Parameter(Mandatory = $true)][string]$Root)

  $commonPath = Join-Path $Root 'scripts\common-windows.ps1'
  $startPath = Join-Path $Root 'scripts\start-dream-skin.ps1'
  $versionPath = Join-Path $Root 'VERSION'
  $rendererPath = Join-Path $Root 'assets\renderer-inject.js'
  $cssPath = Join-Path $Root 'assets\dream-skin.css'
  foreach ($requiredPath in @($commonPath, $startPath, $versionPath, $rendererPath, $cssPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
      throw "Patch source is incomplete: $requiredPath"
    }
  }

  $commonText = Read-DreamSkinUtf8File -Path $commonPath
  $startText = Read-DreamSkinUtf8File -Path $startPath
  $rendererText = Read-DreamSkinUtf8File -Path $rendererPath
  $cssText = Read-DreamSkinUtf8File -Path $cssPath
  if (-not $commonText.Contains('Resolve-DreamSkinStartPort') -or
    -not $startText.Contains('Resolve-DreamSkinStartPort -Port $Port') -or
    -not $rendererText.Contains('composerOwnerSelector') -or
    -not $rendererText.Contains("owner.closest?.('aside')") -or
    -not $rendererText.Contains('findGenericComposers') -or
    -not $cssText.Contains('[data-ds-part="composer"]') -or
    -not $cssText.Contains('aside:not(.app-shell-left-panel)') -or
    -not $cssText.Contains('_MainContentFrame_')) {
    throw 'Patch source does not contain the required Codex 26.730 runtime fixes.'
  }
}

if (-not $SourceRoot) {
  $SourceRoot = Split-Path -Parent $PSScriptRoot
}
$sourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$commonSourcePath = Join-Path $sourceRoot 'scripts\common-windows.ps1'
$startSourcePath = Join-Path $sourceRoot 'scripts\start-dream-skin.ps1'
$patchSourcePath = Join-Path $sourceRoot 'scripts\patch-dream-skin.ps1'
$rendererSourcePath = Join-Path $sourceRoot 'assets\renderer-inject.js'
$cssSourcePath = Join-Path $sourceRoot 'assets\dream-skin.css'

. (Join-Path $sourceRoot 'scripts\common-windows.ps1')
. (Join-Path $sourceRoot 'scripts\theme-windows.ps1')

$stateRoot = if ($StateRoot) {
  [System.IO.Path]::GetFullPath($StateRoot)
} else {
  Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
}
$engine = Get-DreamSkinRuntimeEnginePaths -StateRoot $stateRoot
if (-not (Test-Path -LiteralPath $engine.Root -PathType Container)) {
  throw "No installed Dream Skin runtime was found at $($engine.Root). Run install-dream-skin.ps1 first."
}
if (-not (Test-Path -LiteralPath $engine.Scripts -PathType Container)) {
  throw "The installed Dream Skin runtime is incomplete at $($engine.Root)."
}
Assert-DreamSkinRuntimeTree -Path $engine.Root
Assert-DreamSkinPatchSource -Root $sourceRoot

$installedCommon = Join-Path $engine.Scripts 'common-windows.ps1'
$installedStart = Join-Path $engine.Scripts 'start-dream-skin.ps1'
$installedPatch = Join-Path $engine.Scripts 'patch-dream-skin.ps1'
$installedRenderer = Join-Path $engine.Root 'assets\renderer-inject.js'
$installedCss = Join-Path $engine.Root 'assets\dream-skin.css'
$alreadyPatched = (Test-Path -LiteralPath $installedCommon -PathType Leaf) -and
  (Test-Path -LiteralPath $installedStart -PathType Leaf) -and
  (Test-Path -LiteralPath $installedPatch -PathType Leaf) -and
  (Test-Path -LiteralPath $installedRenderer -PathType Leaf) -and
  (Test-Path -LiteralPath $installedCss -PathType Leaf) -and
  (Read-DreamSkinUtf8File -Path $installedCommon).Contains('Resolve-DreamSkinStartPort') -and
  (Read-DreamSkinUtf8File -Path $installedStart).Contains('Resolve-DreamSkinStartPort -Port $Port') -and
  (Read-DreamSkinUtf8File -Path $installedPatch).Contains('assets\renderer-inject.js') -and
  (Read-DreamSkinUtf8File -Path $installedRenderer).Contains('composerOwnerSelector') -and
  (Read-DreamSkinUtf8File -Path $installedRenderer).Contains('findGenericComposers') -and
  (Read-DreamSkinUtf8File -Path $installedCss).Contains('aside:not(.app-shell-left-panel)') -and
  (Read-DreamSkinUtf8File -Path $installedCss).Contains('_MainContentFrame_')
if ($alreadyPatched) {
  Write-Host "The installed Dream Skin runtime at $($engine.Root) already contains the Codex 26.730 fixes."
  return
}
if ($DryRun) {
  Write-Host "Dry run: would patch launcher scripts and renderer/css assets from $sourceRoot."
  return
}

$operationLock = Enter-DreamSkinOperationLock
try {
  $token = [guid]::NewGuid().ToString('N')
  $stagingRoot = Join-Path $stateRoot ".engine-patch-$token"
  $backupRoot = Join-Path $stateRoot ".engine-patch-backup-$token"
  New-Item -ItemType Directory -Path (Join-Path $stagingRoot 'scripts') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $stagingRoot 'assets') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $backupRoot 'scripts') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $backupRoot 'assets') -Force | Out-Null
  $stagedCommon = Join-Path $stagingRoot 'scripts\common-windows.ps1'
  $stagedStart = Join-Path $stagingRoot 'scripts\start-dream-skin.ps1'
  $stagedPatch = Join-Path $stagingRoot 'scripts\patch-dream-skin.ps1'
  $stagedRenderer = Join-Path $stagingRoot 'assets\renderer-inject.js'
  $stagedCss = Join-Path $stagingRoot 'assets\dream-skin.css'
  Copy-Item -LiteralPath $commonSourcePath -Destination $stagedCommon -Force
  Copy-Item -LiteralPath $startSourcePath -Destination $stagedStart -Force
  Copy-Item -LiteralPath $patchSourcePath -Destination $stagedPatch -Force
  Copy-Item -LiteralPath $rendererSourcePath -Destination $stagedRenderer -Force
  Copy-Item -LiteralPath $cssSourcePath -Destination $stagedCss -Force
  foreach ($stagedScript in @($stagedCommon, $stagedStart, $stagedPatch)) {
    Unblock-File -LiteralPath $stagedScript -ErrorAction Stop
  }

  $patchPairs = @(
    @{
      Relative = 'scripts\common-windows.ps1'
      Source = $commonSourcePath
      Staged = $stagedCommon
      Installed = $installedCommon
    },
    @{
      Relative = 'scripts\start-dream-skin.ps1'
      Source = $startSourcePath
      Staged = $stagedStart
      Installed = $installedStart
    },
    @{
      Relative = 'scripts\patch-dream-skin.ps1'
      Source = $patchSourcePath
      Staged = $stagedPatch
      Installed = $installedPatch
    },
    @{
      Relative = 'assets\renderer-inject.js'
      Source = $rendererSourcePath
      Staged = $stagedRenderer
      Installed = $installedRenderer
    },
    @{
      Relative = 'assets\dream-skin.css'
      Source = $cssSourcePath
      Staged = $stagedCss
      Installed = $installedCss
    }
  )
  foreach ($pair in $patchPairs) {
    $sourceHash = (Get-FileHash -LiteralPath $pair.Source -Algorithm SHA256).Hash
    $stagedHash = (Get-FileHash -LiteralPath $pair.Staged -Algorithm SHA256).Hash
    if ($sourceHash -cne $stagedHash) {
      throw "Staged patch file failed hash verification: $($pair.Relative)"
    }
  }

  $applied = $false
  $backupEntries = @()
  try {
    foreach ($pair in $patchPairs) {
      $backup = Join-Path $backupRoot $pair.Relative
      $hadOriginal = Test-Path -LiteralPath $pair.Installed -PathType Leaf
      if ($hadOriginal) {
        Copy-Item -LiteralPath $pair.Installed -Destination $backup -Force
      }
      $backupEntries += [pscustomobject]@{
        Backup = $backup
        Installed = $pair.Installed
        HadOriginal = $hadOriginal
      }
      Copy-Item -LiteralPath $pair.Staged -Destination $pair.Installed -Force
    }
    foreach ($pair in $patchPairs) {
      $installedHash = (Get-FileHash -LiteralPath $pair.Installed -Algorithm SHA256).Hash
      $stagedHash = (Get-FileHash -LiteralPath $pair.Staged -Algorithm SHA256).Hash
      if ($installedHash -cne $stagedHash) {
        throw "Installed patch file failed verification: $($pair.Relative)"
      }
    }
    $applied = $true
  } catch {
    foreach ($entry in $backupEntries) {
      try {
        if ($entry.HadOriginal -and (Test-Path -LiteralPath $entry.Backup -PathType Leaf)) {
          Copy-Item -LiteralPath $entry.Backup -Destination $entry.Installed -Force
        } else {
          Remove-Item -LiteralPath $entry.Installed -Force -ErrorAction SilentlyContinue
        }
      } catch {
        Write-Warning "Could not restore $($entry.Installed): $($_.Exception.Message)"
      }
    }
    throw
  } finally {
    foreach ($directory in @($stagingRoot, $backupRoot)) {
      if (Test-Path -LiteralPath $directory) {
        try {
          Remove-DreamSkinRuntimeTree -Path $directory -StateRoot $stateRoot
        } catch {
          Write-Warning "Could not remove patch transaction directory ${directory}: $($_.Exception.Message)"
        }
      }
    }
  }
  if (-not $applied) {
    throw 'Patch application did not complete.'
  }
  Write-Host "Patched installed Dream Skin runtime at $($engine.Root). No uninstall or Codex restart was required."
} finally {
  Exit-DreamSkinOperationLock -Mutex $operationLock
}
