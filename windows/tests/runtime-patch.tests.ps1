[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Root)

$ErrorActionPreference = 'Stop'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
  'codex-dream-skin-runtime-patch-' + [guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null

try {
  $stateRoot = Join-Path $temporaryRoot 'state'
  $engineRoot = Join-Path $stateRoot 'engine'
  $scriptsRoot = Join-Path $engineRoot 'scripts'
  $assetsRoot = Join-Path $engineRoot 'assets'
  New-Item -ItemType Directory -Path $scriptsRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $assetsRoot -Force | Out-Null
  [System.IO.File]::WriteAllText(
    (Join-Path $engineRoot 'VERSION'),
    "1.5.9`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
  $installedCommon = Join-Path $scriptsRoot 'common-windows.ps1'
  $installedStart = Join-Path $scriptsRoot 'start-dream-skin.ps1'
  [System.IO.File]::WriteAllText(
    $installedCommon,
    'old common-windows.ps1',
    [System.Text.UTF8Encoding]::new($false)
  )
  [System.IO.File]::WriteAllText(
    $installedStart,
    'old start-dream-skin.ps1',
    [System.Text.UTF8Encoding]::new($false)
  )
  $sentinel = Join-Path $engineRoot 'keep.txt'
  [System.IO.File]::WriteAllText($sentinel, 'keep', [System.Text.UTF8Encoding]::new($false))

  $patchScript = Join-Path $Root 'scripts\patch-dream-skin.ps1'
  $quickFixBuilder = Join-Path (Split-Path -Parent $Root) 'tools\build-quickfix-patch.ps1'
  $quickFixBuilderSource = [System.IO.File]::ReadAllText($quickFixBuilder)
  foreach ($requiredQuickFixAsset in @(
    'renderer-inject.js',
    'dream-skin.css',
    'internet-angel-acrylic.css',
    'internet-angel-extension.css'
  )) {
    if (-not $quickFixBuilderSource.Contains("'$requiredQuickFixAsset'")) {
      throw "The quick-fix archive omits a runtime patch asset: $requiredQuickFixAsset"
    }
  }
  $quickFixOutput = Join-Path $temporaryRoot 'quickfix-output'
  $quickFixExtract = Join-Path $temporaryRoot 'quickfix-extract'
  & $quickFixBuilder -OutputDirectory $quickFixOutput
  $quickFixArchives = @(Get-ChildItem -LiteralPath $quickFixOutput -Filter '*.zip' -File)
  if ($quickFixArchives.Count -ne 1) {
    throw 'The quick-fix builder did not create exactly one ZIP archive.'
  }
  Expand-Archive -LiteralPath $quickFixArchives[0].FullName -DestinationPath $quickFixExtract
  foreach ($requiredQuickFixAsset in @(
    'renderer-inject.js',
    'dream-skin.css',
    'internet-angel-acrylic.css',
    'internet-angel-extension.css'
  )) {
    $sourceAsset = Join-Path $Root "assets\$requiredQuickFixAsset"
    $archivedAsset = Join-Path $quickFixExtract "assets\$requiredQuickFixAsset"
    if (-not (Test-Path -LiteralPath $archivedAsset -PathType Leaf) -or
      (Get-FileHash -LiteralPath $sourceAsset -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $archivedAsset -Algorithm SHA256).Hash) {
      throw "The built quick-fix archive has a missing or stale asset: $requiredQuickFixAsset"
    }
  }
  & $patchScript -SourceRoot $Root -StateRoot $stateRoot -DryRun
  if ([System.IO.File]::ReadAllText($installedCommon) -cne 'old common-windows.ps1' -or
    [System.IO.File]::ReadAllText($installedStart) -cne 'old start-dream-skin.ps1' -or
    -not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
    throw 'Dry run changed the installed runtime or its sentinel file.'
  }

  & $patchScript -SourceRoot $Root -StateRoot $stateRoot
  $sourceCommon = Join-Path $Root 'scripts\common-windows.ps1'
  $sourceStart = Join-Path $Root 'scripts\start-dream-skin.ps1'
  $sourcePatch = Join-Path $Root 'scripts\patch-dream-skin.ps1'
  $installedPatch = Join-Path $scriptsRoot 'patch-dream-skin.ps1'
  $sourceRenderer = Join-Path $Root 'assets\renderer-inject.js'
  $sourceCss = Join-Path $Root 'assets\dream-skin.css'
  $sourceAcrylicCss = Join-Path $Root 'assets\internet-angel-acrylic.css'
  $sourceExtensionCss = Join-Path $Root 'assets\internet-angel-extension.css'
  $installedRenderer = Join-Path $assetsRoot 'renderer-inject.js'
  $installedCss = Join-Path $assetsRoot 'dream-skin.css'
  $installedAcrylicCss = Join-Path $assetsRoot 'internet-angel-acrylic.css'
  $installedExtensionCss = Join-Path $assetsRoot 'internet-angel-extension.css'
  if ((Get-FileHash -LiteralPath $installedCommon -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceCommon -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedStart -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceStart -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedPatch -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourcePatch -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedRenderer -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceRenderer -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedCss -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceCss -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedAcrylicCss -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceAcrylicCss -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedExtensionCss -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceExtensionCss -Algorithm SHA256).Hash -or
    [System.IO.File]::ReadAllText($sentinel) -cne 'keep') {
    throw 'Runtime patch did not replace the launcher files, renderer/css assets, and patch script while preserving the sentinel file.'
  }

  [System.IO.File]::AppendAllText(
    $installedAcrylicCss,
    "`r`n/* stale token-complete Acrylic payload */`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
  & $patchScript -SourceRoot $Root -StateRoot $stateRoot
  if ((Get-FileHash -LiteralPath $installedCommon -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceCommon -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedStart -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceStart -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedRenderer -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceRenderer -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedCss -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceCss -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedAcrylicCss -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceAcrylicCss -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedExtensionCss -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceExtensionCss -Algorithm SHA256).Hash) {
    throw 'A token-complete but byte-stale runtime was incorrectly treated as already patched.'
  }

  $patchedFiles = @(
    $installedCommon, $installedStart, $installedPatch, $installedRenderer,
    $installedCss, $installedAcrylicCss, $installedExtensionCss
  )
  $beforeIdempotentHashes = @($patchedFiles | ForEach-Object {
    (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash
  })
  & $patchScript -SourceRoot $Root -StateRoot $stateRoot
  $afterIdempotentHashes = @($patchedFiles | ForEach-Object {
    (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash
  })
  if (($beforeIdempotentHashes -join ',') -cne ($afterIdempotentHashes -join ',')) {
    throw 'Applying the exact same runtime patch twice changed an already byte-identical engine.'
  }

  $pathNode = Get-Command node.exe -ErrorAction SilentlyContinue
  if (-not $pathNode) { $pathNode = Get-Command node -ErrorAction Stop }
  $runtimeNodeRoot = Join-Path $engineRoot 'runtime\node'
  New-Item -ItemType Directory -Path $runtimeNodeRoot -Force | Out-Null
  $runtimeNode = Join-Path $runtimeNodeRoot 'node.exe'
  Copy-Item -LiteralPath $pathNode.Source -Destination $runtimeNode -Force
  [System.IO.File]::WriteAllText(
    (Join-Path $runtimeNodeRoot 'LICENSE'),
    'Node.js runtime license fixture',
    [System.Text.UTF8Encoding]::new($false)
  )
  $keepAliveScript = Join-Path $temporaryRoot 'keep-engine-node-alive.mjs'
  [System.IO.File]::WriteAllText(
    $keepAliveScript,
    'setInterval(() => {}, 1000);',
    [System.Text.UTF8Encoding]::new($false)
  )
  $activeEngineNode = Start-Process -FilePath $runtimeNode -ArgumentList $keepAliveScript `
    -WindowStyle Hidden -PassThru
  try {
    [System.IO.File]::AppendAllText(
      $installedAcrylicCss,
      "`r`n/* stale while bundled node is running */`r`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    & $patchScript -SourceRoot $Root -StateRoot $stateRoot
    $activeEngineNode.Refresh()
    if ($activeEngineNode.HasExited) {
      throw 'The runtime patch interrupted the active bundled Node process.'
    }
    if ((Get-FileHash -LiteralPath $installedAcrylicCss -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceAcrylicCss -Algorithm SHA256).Hash) {
      throw 'The runtime patch did not commit while bundled Node was active.'
    }
  } finally {
    if (-not $activeEngineNode.HasExited) {
      Stop-Process -Id $activeEngineNode.Id -Force -ErrorAction SilentlyContinue
      $null = $activeEngineNode.WaitForExit(5000)
    }
    foreach ($oldEngine in Get-ChildItem -LiteralPath $stateRoot -Directory -Force |
      Where-Object Name -Like '.engine-patch-backup-*') {
      Remove-Item -LiteralPath $oldEngine.FullName -Recurse -Force -ErrorAction Stop
    }
  }

  $enginePrefix = $engineRoot.TrimEnd('\') + '\'
  $beforeFailedSwap = @(
    Get-ChildItem -LiteralPath $engineRoot -Recurse -File -Force |
      Sort-Object FullName |
      ForEach-Object {
        $relative = $_.FullName.Substring($enginePrefix.Length)
        "$relative=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
      }
  ) -join "`n"
  $failureSourceRoot = Join-Path $temporaryRoot 'forced-swap-source'
  Copy-Item -LiteralPath $Root -Destination $failureSourceRoot -Recurse -Force
  $failureCommon = Join-Path $failureSourceRoot 'scripts\common-windows.ps1'
  [System.IO.File]::AppendAllText(
    $failureCommon,
    @'

$script:DreamSkinForceOneSwapFailure = $true
function Move-Item {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [Parameter(Mandatory = $true)][string]$Destination,
    [switch]$Force
  )
  if ($script:DreamSkinForceOneSwapFailure -and
    [System.IO.Path]::GetFileName($Destination) -ceq 'engine') {
    $script:DreamSkinForceOneSwapFailure = $false
    throw 'forced atomic patch swap failure'
  }
  Microsoft.PowerShell.Management\Move-Item @PSBoundParameters
}
'@,
    [System.Text.UTF8Encoding]::new($false)
  )
  $forcedPatchFailed = $false
  try {
    & (Join-Path $failureSourceRoot 'scripts\patch-dream-skin.ps1') `
      -SourceRoot $failureSourceRoot -StateRoot $stateRoot
  } catch {
    if ($_.Exception.Message -notlike '*forced atomic patch swap failure*') { throw }
    $forcedPatchFailed = $true
  }
  if (-not $forcedPatchFailed) {
    throw 'The forced patch swap failure did not stop the transaction.'
  }
  $afterFailedSwap = @(
    Get-ChildItem -LiteralPath $engineRoot -Recurse -File -Force |
      Sort-Object FullName |
      ForEach-Object {
        $relative = $_.FullName.Substring($enginePrefix.Length)
        "$relative=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
      }
  ) -join "`n"
  if ($beforeFailedSwap -cne $afterFailedSwap) {
    throw 'A failed atomic patch swap did not restore the exact previous engine.'
  }

  $transactionDirectories = @(Get-ChildItem -LiteralPath $stateRoot -Directory -Force |
    Where-Object {
      $_.Name -like '.engine-patch*' -or
      $_.Name -like '.engine-patch-backup*' -or
      $_.Name -like '.engine-patch-failed*'
    })
  if ($transactionDirectories.Count -ne 0) {
    throw 'Runtime patch left staging or backup transaction directories behind.'
  }
} finally {
  Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'PASS: runtime patch atomically replaces launcher and renderer/css payloads, preserves state, and restores exact bytes on swap failure.'
