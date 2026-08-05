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
  $acrylicCssPath = Join-Path $Root 'assets\internet-angel-acrylic.css'
  $extensionCssPath = Join-Path $Root 'assets\internet-angel-extension.css'
  foreach ($requiredPath in @(
    $commonPath, $startPath, $versionPath, $rendererPath, $cssPath, $acrylicCssPath, $extensionCssPath
  )) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
      throw "Patch source is incomplete: $requiredPath"
    }
  }

  $commonText = Read-DreamSkinUtf8File -Path $commonPath
  $startText = Read-DreamSkinUtf8File -Path $startPath
  $rendererText = Read-DreamSkinUtf8File -Path $rendererPath
  $cssText = Read-DreamSkinUtf8File -Path $cssPath
  $acrylicCssText = Read-DreamSkinUtf8File -Path $acrylicCssPath
  $extensionCssText = Read-DreamSkinUtf8File -Path $extensionCssPath
  if (-not $commonText.Contains('Resolve-DreamSkinStartPort') -or
    -not $startText.Contains('Resolve-DreamSkinStartPort -Port $Port') -or
    -not $rendererText.Contains('composerOwnerSelector') -or
    -not $rendererText.Contains("owner.closest?.('aside')") -or
    -not $rendererText.Contains('findGenericComposers') -or
    -not $rendererText.Contains('themeDiffsContainers') -or
    -not $rendererText.Contains('const fallbackProbe = () =>') -or
    -not $rendererText.Contains('[data-app-action-sidebar-thread-row]') -or
    -not $rendererText.Contains('appearanceFromClasses') -or
    -not $cssText.Contains('[data-ds-part="composer"]') -or
    -not $cssText.Contains('aside:not(.app-shell-left-panel)') -or
    -not $cssText.Contains('_MainContentFrame_') -or
    -not $cssText.Contains('diffs-container') -or
    -not $cssText.Contains('[aria-modal="true"]') -or
    -not $cssText.Contains('_ComposerLayoutBody_') -or
    -not $cssText.Contains('html.codex-dream-skin.dream-theme-light :where(') -or
    -not $acrylicCssText.Contains('[class*="_railList_"]') -or
    -not $acrylicCssText.Contains('.text-fade-truncate') -or
    -not $acrylicCssText.Contains('.sidebar-item svg') -or
    -not $acrylicCssText.Contains('.dream-task .horizontal-scroll-fade-mask') -or
    -not $extensionCssText.Contains('.dream-theme-light') -or
    -not $extensionCssText.Contains('[data-angel-component]') -or
    -not $extensionCssText.Contains('[data-angel-component="scroll-bottom"]:is(:hover') -or
    -not $extensionCssText.Contains('[data-angel-component="edited-card-files"] button') -or
    -not $extensionCssText.Contains('--angel-paper: var(--dream-text)')) {
    throw 'Patch source does not contain the required Codex 26.730 runtime fixes.'
  }
}

function Test-DreamSkinPatchFileMatches {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Installed
  )

  if (-not (Test-Path -LiteralPath $Source -PathType Leaf) -or
    -not (Test-Path -LiteralPath $Installed -PathType Leaf)) {
    return $false
  }
  return (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ceq
    (Get-FileHash -LiteralPath $Installed -Algorithm SHA256).Hash
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
$acrylicCssSourcePath = Join-Path $sourceRoot 'assets\internet-angel-acrylic.css'
$extensionCssSourcePath = Join-Path $sourceRoot 'assets\internet-angel-extension.css'

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
$installedAcrylicCss = Join-Path $engine.Root 'assets\internet-angel-acrylic.css'
$installedExtensionCss = Join-Path $engine.Root 'assets\internet-angel-extension.css'
$patchIdentityPairs = @(
  @{ Source = $commonSourcePath; Installed = $installedCommon },
  @{ Source = $startSourcePath; Installed = $installedStart },
  @{ Source = $patchSourcePath; Installed = $installedPatch },
  @{ Source = $rendererSourcePath; Installed = $installedRenderer },
  @{ Source = $cssSourcePath; Installed = $installedCss },
  @{ Source = $acrylicCssSourcePath; Installed = $installedAcrylicCss },
  @{ Source = $extensionCssSourcePath; Installed = $installedExtensionCss }
)
$alreadyPatched = $true
foreach ($pair in $patchIdentityPairs) {
  if (-not (Test-DreamSkinPatchFileMatches -Source $pair.Source -Installed $pair.Installed)) {
    $alreadyPatched = $false
    break
  }
}
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
  $failedRoot = Join-Path $stateRoot ".engine-patch-failed-$token"
  $applied = $false
  $hasBackup = $false
  $preserveTransactions = $false
  try {
    # Clone the complete managed engine first so the patch preserves bundled Node,
    # presets, and every non-patch asset. The committed update is one directory swap;
    # consumers can therefore observe either the old engine or the new one, never a
    # seven-file mixture.
    Copy-Item -LiteralPath $engine.Root -Destination $stagingRoot -Recurse -Force `
      -ErrorAction Stop
    Assert-DreamSkinRuntimeTree -Path $stagingRoot

    $stagedCommon = Join-Path $stagingRoot 'scripts\common-windows.ps1'
    $stagedStart = Join-Path $stagingRoot 'scripts\start-dream-skin.ps1'
    $stagedPatch = Join-Path $stagingRoot 'scripts\patch-dream-skin.ps1'
    $stagedRenderer = Join-Path $stagingRoot 'assets\renderer-inject.js'
    $stagedCss = Join-Path $stagingRoot 'assets\dream-skin.css'
    $stagedAcrylicCss = Join-Path $stagingRoot 'assets\internet-angel-acrylic.css'
    $stagedExtensionCss = Join-Path $stagingRoot 'assets\internet-angel-extension.css'
    Copy-Item -LiteralPath $commonSourcePath -Destination $stagedCommon -Force -ErrorAction Stop
    Copy-Item -LiteralPath $startSourcePath -Destination $stagedStart -Force -ErrorAction Stop
    Copy-Item -LiteralPath $patchSourcePath -Destination $stagedPatch -Force -ErrorAction Stop
    Copy-Item -LiteralPath $rendererSourcePath -Destination $stagedRenderer -Force -ErrorAction Stop
    Copy-Item -LiteralPath $cssSourcePath -Destination $stagedCss -Force -ErrorAction Stop
    Copy-Item -LiteralPath $acrylicCssSourcePath -Destination $stagedAcrylicCss -Force `
      -ErrorAction Stop
    Copy-Item -LiteralPath $extensionCssSourcePath -Destination $stagedExtensionCss -Force `
      -ErrorAction Stop
    foreach ($stagedScript in @($stagedCommon, $stagedStart, $stagedPatch)) {
      Unblock-File -LiteralPath $stagedScript -ErrorAction Stop
    }

    $patchPairs = @(
      @{ Relative = 'scripts\common-windows.ps1'; Source = $commonSourcePath; Staged = $stagedCommon; Installed = $installedCommon },
      @{ Relative = 'scripts\start-dream-skin.ps1'; Source = $startSourcePath; Staged = $stagedStart; Installed = $installedStart },
      @{ Relative = 'scripts\patch-dream-skin.ps1'; Source = $patchSourcePath; Staged = $stagedPatch; Installed = $installedPatch },
      @{ Relative = 'assets\renderer-inject.js'; Source = $rendererSourcePath; Staged = $stagedRenderer; Installed = $installedRenderer },
      @{ Relative = 'assets\dream-skin.css'; Source = $cssSourcePath; Staged = $stagedCss; Installed = $installedCss },
      @{ Relative = 'assets\internet-angel-acrylic.css'; Source = $acrylicCssSourcePath; Staged = $stagedAcrylicCss; Installed = $installedAcrylicCss },
      @{ Relative = 'assets\internet-angel-extension.css'; Source = $extensionCssSourcePath; Staged = $stagedExtensionCss; Installed = $installedExtensionCss }
    )
    foreach ($pair in $patchPairs) {
      $sourceHash = (Get-FileHash -LiteralPath $pair.Source -Algorithm SHA256).Hash
      $stagedHash = (Get-FileHash -LiteralPath $pair.Staged -Algorithm SHA256).Hash
      if ($sourceHash -cne $stagedHash) {
        throw "Staged patch file failed hash verification: $($pair.Relative)"
      }
    }

    Assert-DreamSkinRuntimeTree -Path $engine.Root
    Move-Item -LiteralPath $engine.Root -Destination $backupRoot -ErrorAction Stop
    $hasBackup = $true
    try {
      Move-Item -LiteralPath $stagingRoot -Destination $engine.Root -ErrorAction Stop
    } catch {
      $swapError = $_.Exception.Message
      if ($hasBackup -and -not (Test-Path -LiteralPath $engine.Root)) {
        try {
          Move-Item -LiteralPath $backupRoot -Destination $engine.Root -ErrorAction Stop
          $hasBackup = $false
        } catch {
          $preserveTransactions = $true
          throw "Dream Skin runtime patch failed and its previous engine could not be restored. Backup preserved at ${backupRoot}: $swapError"
        }
      }
      throw
    }

    try {
      foreach ($pair in $patchPairs) {
        $installedHash = (Get-FileHash -LiteralPath $pair.Installed -Algorithm SHA256).Hash
        $sourceHash = (Get-FileHash -LiteralPath $pair.Source -Algorithm SHA256).Hash
        if ($installedHash -cne $sourceHash) {
          throw "Installed patch file failed verification: $($pair.Relative)"
        }
      }
    } catch {
      $verificationError = $_.Exception.Message
      try {
        if (Test-Path -LiteralPath $engine.Root) {
          Move-Item -LiteralPath $engine.Root -Destination $failedRoot -ErrorAction Stop
        }
        Move-Item -LiteralPath $backupRoot -Destination $engine.Root -ErrorAction Stop
        $hasBackup = $false
      } catch {
        $preserveTransactions = $true
        throw "Dream Skin runtime patch failed verification and its previous engine could not be restored. Backup preserved at ${backupRoot}; failed candidate preserved at ${failedRoot}: $verificationError"
      }
      if (Test-Path -LiteralPath $failedRoot) {
        try { Remove-DreamSkinRuntimeTree -Path $failedRoot -StateRoot $stateRoot } catch {
          Write-Warning "Could not remove failed patch candidate ${failedRoot}: $($_.Exception.Message)"
        }
      }
      throw "Dream Skin runtime patch failed verification; the previous engine was restored: $verificationError"
    }

    $applied = $true
  } finally {
    if (-not $preserveTransactions -and (Test-Path -LiteralPath $stagingRoot)) {
      try { Remove-DreamSkinRuntimeTree -Path $stagingRoot -StateRoot $stateRoot } catch {
        Write-Warning "Could not remove staged patch engine ${stagingRoot}: $($_.Exception.Message)"
      }
    }
    if ($applied -and $hasBackup -and (Test-Path -LiteralPath $backupRoot)) {
      try { Remove-DreamSkinRuntimeTree -Path $backupRoot -StateRoot $stateRoot } catch {
        Write-Warning "Installed the patch but could not remove its previous engine backup ${backupRoot}: $($_.Exception.Message)"
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
