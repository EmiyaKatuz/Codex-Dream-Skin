[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Root)

$ErrorActionPreference = 'Stop'
. (Join-Path $Root 'scripts\common-windows.ps1')
. (Join-Path $Root 'scripts\theme-windows.ps1')

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
  ('dream-skin-window-effects-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
try {
  $missing = Read-DreamSkinWindowEffects -StateRoot $temporaryRoot
  if ($missing.Exists -or $missing.WindowMaterial -cne 'system') {
    throw 'Missing window-effects settings did not fail closed to System.'
  }

  $written = Write-DreamSkinWindowEffects -StateRoot $temporaryRoot -WindowMaterial acrylic
  if (-not $written.Exists -or $written.WindowMaterial -cne 'acrylic') {
    throw 'Acrylic preference was not written and read back exactly.'
  }
  $path = Get-DreamSkinWindowEffectsPath -StateRoot $temporaryRoot
  $bytes = [System.IO.File]::ReadAllBytes($path)
  if ($bytes.Length -lt 2 -or ($bytes.Length -ge 3 -and
    $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
    throw 'Window-effects settings are empty or gained a UTF-8 BOM.'
  }

  $invalidFixtures = @(
    '{"schemaVersion":1,"platform":"windows","windowMaterial":"blur"}',
    '{"schemaVersion":1,"platform":"windows","windowMaterial":"acrylic","extra":true}',
    '{not-json'
  )
  foreach ($fixture in $invalidFixtures) {
    [System.IO.File]::WriteAllText($path, $fixture, [System.Text.UTF8Encoding]::new($false))
    $rejected = $false
    try { [void](Read-DreamSkinWindowEffects -StateRoot $temporaryRoot) } catch { $rejected = $true }
    if (-not $rejected) { throw "Invalid window-effects settings were accepted: $fixture" }
  }

  $configPath = Join-Path $temporaryRoot 'config.toml'
  [System.IO.File]::WriteAllText(
    $configPath,
    "[desktop]`r`nappearanceLightChromeTheme = { opaqueWindows = false }`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
  if (-not (Test-DreamSkinAcrylicTransparencyConfig -ConfigPath $configPath)) {
    throw 'Inline opaqueWindows=false was not accepted for Acrylic.'
  }
  [System.IO.File]::WriteAllText(
    $configPath,
    "[desktop]`r`n`r`n[desktop.appearanceLightChromeTheme]`r`nopaqueWindows = false`r`n`r`n[desktop.appearanceLightChromeTheme.fonts]`r`nui = `"Segoe UI`"`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
  if (-not (Test-DreamSkinAcrylicTransparencyConfig -ConfigPath $configPath)) {
    throw 'Nested opaqueWindows=false was not accepted for Acrylic.'
  }
  [System.IO.File]::WriteAllText(
    $configPath,
    "[desktop]`r`nappearanceLightChromeTheme = { opaqueWindows = true }`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
  if (Test-DreamSkinAcrylicTransparencyConfig -ConfigPath $configPath) {
    throw 'opaqueWindows=true was accepted for Acrylic.'
  }
  foreach ($falsePositive in @(
    "[desktop]`r`nappearanceLightChromeTheme = { opaqueWindows = true } # opaqueWindows = false`r`n",
    "[desktop]`r`nappearanceLightChromeTheme = { note = `"opaqueWindows = false`", opaqueWindows = true }`r`n",
    "[desktop]`r`nappearanceLightChromeTheme = { semanticColors = { opaqueWindows = false } }`r`n",
    "[desktop]`r`nappearanceLightChromeTheme = { not-opaqueWindows = false }`r`n",
    "[desktop]`r`nappearanceLightChromeTheme = { palette.opaqueWindows = false }`r`n"
  )) {
    [System.IO.File]::WriteAllText(
      $configPath,
      $falsePositive,
      [System.Text.UTF8Encoding]::new($false)
    )
    if (Test-DreamSkinAcrylicTransparencyConfig -ConfigPath $configPath) {
      throw 'A TOML comment/string produced an opaqueWindows=false false positive.'
    }
  }
  [System.IO.File]::WriteAllText(
    $configPath,
    "[desktop]`r`nappearanceLightChromeTheme = { opaqueWindows = true }`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
  if (-not (Test-DreamSkinAcrylicTransparencyConfigManageable -ConfigPath $configPath)) {
    throw 'A managed opaque System chrome theme could not transition safely to Acrylic.'
  }
  $sequenceBackup = Join-Path $temporaryRoot 'config.before.toml'
  Install-DreamSkinBaseTheme -ConfigPath $configPath -BackupPath $sequenceBackup `
    -TransparentWindows
  if (-not (Test-DreamSkinAcrylicTransparencyConfig -ConfigPath $configPath)) {
    throw 'Base-theme synchronization invalidated the Acrylic transparency precondition.'
  }
  [System.IO.File]::WriteAllText(
    $configPath,
    "[desktop]`r`n`r`n[desktop.appearanceLightChromeTheme]`r`nopaqueWindows = true`r`n",
    [System.Text.UTF8Encoding]::new($false)
  )
  if (Test-DreamSkinAcrylicTransparencyConfigManageable -ConfigPath $configPath) {
    throw 'An opaque nested chrome-theme table was incorrectly considered safely manageable.'
  }

  $acrylicCss = [System.IO.File]::ReadAllText(
    (Join-Path $Root 'assets\internet-angel-acrylic.css')
  )
  foreach ($requiredCssGuard in @(
    'color-scheme: dark',
    '--dream-text: #fff5ff',
    '--dream-text-muted: #cabfe8',
    '--dream-text-primary: var(--dream-text)',
    '--angel-ink: #090827',
    '--angel-paper: #fbf5ff',
    '--angel-acrylic-art-opacity: .18',
    '--dream-surface: rgb(19 16 61 / .16)',
    '--dream-task-immersive-edge: rgb(23 19 70 / .20)',
    '[class~="group/application-menu-top-bar"] button',
    'text-shadow: 0 1px 2px rgb(5 4 26 / .82)',
    '[data-dream-skin="active"].dream-art-wide[data-dream-route="home"] body',
    ')[data-dream-route]:not([data-dream-route="home"]) body',
    'background-image: none !important',
    'body::before',
    'High-frequency surfaces stay transparent',
    'transition: color 80ms linear',
    'translate: none !important',
    'Chromium''s native edge-fade ScrollTimeline',
    'mask-image: none !important'
  )) {
    if (-not $acrylicCss.Contains($requiredCssGuard)) {
      throw "Acrylic wide-art cascade guard is missing: $requiredCssGuard"
    }
  }

  $managerPath = Join-Path $Root 'scripts\manage-window-effects.ps1'
  $managerSource = [System.IO.File]::ReadAllText($managerPath)
  foreach ($forbidden in @('Start-DreamSkinCodex', 'Stop-DreamSkinCodex', 'DwmSetWindowAttribute')) {
    if ($managerSource.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
      throw "The preference-only window-effects manager gained a live mutation: $forbidden"
    }
  }
  foreach ($scriptPath in @(
    $managerPath,
    (Join-Path $Root 'scripts\start-dream-skin.ps1'),
    (Join-Path $Root 'scripts\restore-dream-skin.ps1')
  )) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
      throw "Window-effects integration failed to parse: $scriptPath ($($errors[0].Message))"
    }
  }

  $startSource = [System.IO.File]::ReadAllText((Join-Path $Root 'scripts\start-dream-skin.ps1'))
  foreach ($startupGuard in @(
    '-ExpectedWindowHandle',
    'acrylicTargetWindowHandle',
    'acrylicMonitorArmFile',
    'acrylic-monitor-recorded',
    "startupPhase = 'active'",
    'Test-DreamSkinAcrylicTransparencyConfigManageable',
    'acrylicTransparencyReady',
    'requires a one-time Codex restart',
    'Stop the loop before restoring'
  )) {
    if (-not $startSource.Contains($startupGuard)) {
      throw "Acrylic startup lifecycle guard is missing: $startupGuard"
    }
  }
  $initialDescribeIndex = $startSource.IndexOf(
    '$descriptors = @(& $acrylicHelper -Action Describe',
    [StringComparison]::Ordinal
  )
  if ($initialDescribeIndex -lt 0) {
    throw 'Acrylic startup no longer captures an initial pinned window descriptor.'
  }
  $stopRecordedIndex = $startSource.IndexOf(
    'Stop-DreamSkinRecordedAcrylicMonitor',
    $initialDescribeIndex,
    [StringComparison]::Ordinal
  )
  if ($stopRecordedIndex -le $initialDescribeIndex) {
    throw 'Acrylic startup no longer reconciles its recorded native monitor.'
  }
  $restoredDescribeIndex = $startSource.IndexOf(
    '$restoredDescriptors = @(& $acrylicHelper -Action Describe',
    $stopRecordedIndex,
    [StringComparison]::Ordinal
  )
  if ($restoredDescribeIndex -le $stopRecordedIndex) {
    throw 'Acrylic startup no longer re-describes the pinned window after monitor reconciliation.'
  }
  $micaBaselineIndex = $startSource.IndexOf(
    'CurrentBackdrop -ne 2',
    $restoredDescribeIndex,
    [StringComparison]::Ordinal
  )
  if ($micaBaselineIndex -le $restoredDescribeIndex) {
    throw 'Acrylic reapply does not stop the recorded monitor before verifying the restored Mica baseline.'
  }
  $initialDescribeBlock = $startSource.Substring(
    $initialDescribeIndex,
    $stopRecordedIndex - $initialDescribeIndex
  )
  if (-not $initialDescribeBlock.Contains('CurrentBackdrop -notin @(2, 3)')) {
    throw 'Acrylic reapply does not accept an identity-pinned active Acrylic backdrop before reconciliation.'
  }

  $traySource = [System.IO.File]::ReadAllText((Join-Path $Root 'scripts\tray-dream-skin.ps1'))
  $pauseRestoreIndex = $traySource.IndexOf(
    'Stop-DreamSkinRecordedAcrylicMonitor',
    [StringComparison]::Ordinal
  )
  if ($pauseRestoreIndex -lt 0) {
    throw 'Tray pause no longer restores an active Acrylic monitor.'
  }
  $pauseMarkerIndex = $traySource.IndexOf(
    'Set-DreamSkinPaused',
    $pauseRestoreIndex,
    [StringComparison]::Ordinal
  )
  $liveRemoveIndex = $traySource.IndexOf(
    'Invoke-DreamSkinLiveRemove',
    $pauseMarkerIndex,
    [StringComparison]::Ordinal
  )
  if ($pauseRestoreIndex -lt 0 -or $pauseMarkerIndex -le $pauseRestoreIndex -or
    $liveRemoveIndex -le $pauseMarkerIndex) {
    throw 'Tray pause does not restore Acrylic before marking the skin paused and removing renderer CSS.'
  }

  $commonSource = [System.IO.File]::ReadAllText((Join-Path $Root 'scripts\common-windows.ps1'))
  foreach ($restoreGuard in @(
    'Restore-DreamSkinRecordedAcrylicTarget',
    'The recorded Codex HWND did not verify as Mica',
    'acrylicTargetWindowHandle',
    'acrylicMonitorArmFile'
  )) {
    if (-not $commonSource.Contains($restoreGuard)) {
      throw "Acrylic shutdown restoration guard is missing: $restoreGuard"
    }
  }
  foreach ($orphanGuard in @(
    'Wait-DreamSkinAcrylicMonitorMutexAvailable',
    'acrylic-monitor-spawning',
    'unarmed Acrylic monitor'
  )) {
    if (-not $commonSource.Contains($orphanGuard)) {
      throw "Acrylic pre-arm crash recovery guard is missing: $orphanGuard"
    }
  }
  $installSource = [System.IO.File]::ReadAllText((Join-Path $Root 'scripts\install-dream-skin.ps1'))
  if (-not $installSource.Contains('Read-DreamSkinWindowEffects') -or
    -not $installSource.Contains("-TransparentWindows:(`$windowMaterial -ceq 'acrylic')")) {
    throw 'A normal reinstall no longer preserves the selected Acrylic transparency mode.'
  }

  # Simulate a crashed/missing monitor while a non-Codex fixture process remains
  # alive. The native helper is replaced by a harmless argument-checking script;
  # this exercises caller-side Restore -> Probe ordering without touching DWM.
  $fakeHelper = Join-Path $temporaryRoot 'fake-acrylic-helper.ps1'
  [System.IO.File]::WriteAllText($fakeHelper, @'
param(
  [string]$Action,
  [int]$TargetProcessId,
  [long]$ExpectedStartTimeFileTimeUtc,
  [string]$ExpectedExecutablePath,
  [string]$ExpectedPackageFamilyName,
  [string]$ExpectedWindowClass,
  [long]$ExpectedWindowHandle,
  [switch]$AllowHiddenTarget,
  [switch]$ConfirmTargetIdentity
)
if ($ExpectedWindowHandle -ne 123456 -or $TargetProcessId -ne $PID) {
  throw 'The recovery caller did not preserve the pinned target descriptor.'
}
$global:DreamSkinAcrylicRecoveryActions += $Action
if ($Action -ceq 'Restore') {
  [pscustomobject]@{
    CurrentBackdrop = 2
    WindowHandleValue = $ExpectedWindowHandle
    TargetMissing = $false
  }
} elseif ($Action -ceq 'Probe') {
  [pscustomobject]@{
    CurrentBackdrop = $global:DreamSkinAcrylicRecoveryProbeBackdrop
    WindowHandleValue = $ExpectedWindowHandle
  }
}
'@, [System.Text.UTF8Encoding]::new($false))
  $realEnginePaths = (Get-Command Get-DreamSkinRuntimeEnginePaths -CommandType Function).ScriptBlock
  try {
    function Get-DreamSkinRuntimeEnginePaths {
      param([string]$StateRoot)
      return [pscustomobject]@{ AcrylicHelper = $fakeHelper }
    }
    $fixtureProcess = [System.Diagnostics.Process]::GetCurrentProcess()
    try { $fixtureStart = $fixtureProcess.StartTime.ToUniversalTime().ToFileTimeUtc() } finally {
      $fixtureProcess.Dispose()
    }
    $missingMonitorState = [pscustomobject]@{
      acrylicMonitorPid = 2147483000
      acrylicMonitorStartedAt = '2000-01-01T00:00:00.0000000Z'
      acrylicMonitorPath = $fakeHelper
      acrylicMonitorStopFile = (Join-Path $temporaryRoot 'acrylic-monitor-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.stop')
      acrylicMonitorArmFile = (Join-Path $temporaryRoot 'acrylic-monitor-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.arm')
      acrylicTargetPid = $PID
      acrylicTargetStartTimeFileTimeUtc = $fixtureStart
      acrylicTargetExecutablePath = 'fixture.exe'
      acrylicTargetPackageFamilyName = 'fixture_family'
      acrylicTargetWindowClass = 'Chrome_WidgetWin_1'
      acrylicTargetWindowHandle = 123456
    }
    $global:DreamSkinAcrylicRecoveryActions = @()
    $global:DreamSkinAcrylicRecoveryProbeBackdrop = 2
    $null = Stop-DreamSkinRecordedAcrylicMonitor `
      -State $missingMonitorState -StateRoot $temporaryRoot
    if (($global:DreamSkinAcrylicRecoveryActions -join ',') -cne 'Restore,Probe') {
      throw 'A missing Acrylic monitor did not force exact Restore then Probe.'
    }

    $orphanState = $missingMonitorState.PSObject.Copy()
    $orphanState.acrylicMonitorPid = $null
    $orphanState.acrylicMonitorStartedAt = $null
    $orphanState.acrylicMonitorStopFile = Join-Path $temporaryRoot `
      'acrylic-monitor-cccccccccccccccccccccccccccccccc.stop'
    $orphanState.acrylicMonitorArmFile = Join-Path $temporaryRoot `
      'acrylic-monitor-dddddddddddddddddddddddddddddddd.arm'
    $orphanState | Add-Member -NotePropertyName startupPhase `
      -NotePropertyValue 'acrylic-monitor-spawning'
    $global:DreamSkinAcrylicRecoveryActions = @()
    $global:DreamSkinAcrylicRecoveryProbeBackdrop = 2
    $null = Stop-DreamSkinRecordedAcrylicMonitor `
      -State $orphanState -StateRoot $temporaryRoot
    if (($global:DreamSkinAcrylicRecoveryActions -join ',') -cne 'Restore,Probe' -or
      -not (Test-Path -LiteralPath $orphanState.acrylicMonitorStopFile) -or
      (Test-Path -LiteralPath $orphanState.acrylicMonitorArmFile)) {
      throw 'A PID-less pre-arm monitor handoff did not preserve its late-child stop signal safely.'
    }

    [System.IO.File]::WriteAllText(
      $missingMonitorState.acrylicMonitorStopFile,
      'pending',
      [System.Text.UTF8Encoding]::new($false)
    )
    $global:DreamSkinAcrylicRecoveryActions = @()
    $global:DreamSkinAcrylicRecoveryProbeBackdrop = 3
    $failedRestoreRejected = $false
    try {
      $null = Stop-DreamSkinRecordedAcrylicMonitor `
        -State $missingMonitorState -StateRoot $temporaryRoot
    } catch {
      $failedRestoreRejected = $true
    }
    if (-not $failedRestoreRejected -or
      -not (Test-Path -LiteralPath $missingMonitorState.acrylicMonitorStopFile)) {
      throw 'A failed Acrylic restore was accepted or discarded its recovery signal.'
    }
  } finally {
    Set-Item -Path Function:\Get-DreamSkinRuntimeEnginePaths -Value $realEnginePaths
    Remove-Variable DreamSkinAcrylicRecoveryActions -Scope Global -ErrorAction SilentlyContinue
    Remove-Variable DreamSkinAcrylicRecoveryProbeBackdrop -Scope Global -ErrorAction SilentlyContinue
  }

  Write-Host 'PASS: Acrylic preference is strict, persistent, non-launching, and defaults safely.'
} finally {
  if (Test-Path -LiteralPath $temporaryRoot) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
