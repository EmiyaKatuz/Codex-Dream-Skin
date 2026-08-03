[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Root)

$ErrorActionPreference = 'Stop'
$autoPath = Join-Path $Root 'scripts\auto-launch-dream-skin.ps1'
$managerPath = Join-Path $Root 'scripts\manage-auto-launch-dream-skin.ps1'
$startPath = Join-Path $Root 'scripts\start-dream-skin.ps1'
$commonPath = Join-Path $Root 'scripts\common-windows.ps1'
$restorePath = Join-Path $Root 'scripts\restore-dream-skin.ps1'

foreach ($path in @($autoPath, $managerPath, $startPath, $commonPath, $restorePath)) {
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
  if ($errors.Count -gt 0) { throw "$path failed to parse: $($errors[0].Message)" }
}

$autoSource = [IO.File]::ReadAllText($autoPath)
$managerSource = [IO.File]::ReadAllText($managerPath)
$startSource = [IO.File]::ReadAllText($startPath)
$commonSource = [IO.File]::ReadAllText($commonPath)
$restoreSource = [IO.File]::ReadAllText($restorePath)

foreach ($forbidden in @('Stop-DreamSkinCodex', 'Stop-Process', 'taskkill', '-RestartExisting')) {
  if ($autoSource.Contains($forbidden)) {
    throw "The automatic watcher directly controls Codex instead of using its guarded handoff: $forbidden"
  }
}
foreach ($required in @(
  'StartupBaselineMilliseconds',
  'StartupBaselineActive $startupBaselineActive',
  'TrustedZeroCount',
  'ZeroStartedAtMilliseconds',
  'StableZeroMilliseconds',
  "Phase 'restart-reserved'",
  '-AutoRestartReservationToken $attemptToken',
  '-RequireUnpaused',
  'auto-launch-state.json',
  'auto-launch.stop',
  '[System.Diagnostics.Stopwatch]::StartNew()',
  'Get-DreamSkinCodexAnyDebugIntentStatus',
  '__InstanceCreationEvent WITHIN 2',
  '__InstanceDeletionEvent WITHIN 2',
  '[System.Threading.AutoResetEvent]::new($false)',
  '-MessageData $eventSignal -Action',
  '$eventSignal.WaitOne($waitMilliseconds)',
  'Process events are unavailable; using the bounded polling fallback.'
)) {
  if (-not $autoSource.Contains($required)) { throw "Automatic watcher safety contract is missing: $required" }
}
if ($autoSource.Contains('Wait-Event')) {
  throw 'The watcher must not consume unrelated PowerShell events or process a burst one event at a time.'
}
if ($autoSource.Contains('-Port $Port -AutoRestartStock')) {
  throw 'Automatic handoff pins an explicit port instead of allowing the guarded launcher to select safely.'
}

foreach ($forbidden in @('Stop-Process', 'taskkill', 'Stop-DreamSkinCodex')) {
  if ($managerSource.Contains($forbidden)) {
    throw "The automatic-launch manager may not terminate processes: $forbidden"
  }
}
foreach ($required in @(
  'Codex Dream Skin Auto Launch.lnk',
  '-ExecutionPolicy RemoteSigned',
  'auto-launch-dream-skin.ps1',
  'auto-launch.stop',
  'auto-launch-state.json'
)) {
  if (-not $managerSource.Contains($required)) { throw "Automatic-launch manager is missing: $required" }
}
$startupArgumentIndex = $managerSource.IndexOf('$StartupArguments =', [StringComparison]::Ordinal)
$shortcutFunctionIndex = $managerSource.IndexOf('function Assert-DreamSkinAutoLaunchControlFile', [StringComparison]::Ordinal)
if ($startupArgumentIndex -lt 0 -or $shortcutFunctionIndex -le $startupArgumentIndex) {
  throw 'The managed Startup argument declaration could not be isolated.'
}
$startupArgumentBlock = $managerSource.Substring(
  $startupArgumentIndex,
  $shortcutFunctionIndex - $startupArgumentIndex
)
if ($startupArgumentBlock.Contains('ProtectCurrentSession')) {
  throw 'The login Startup shortcut must not persist the one-time current-session protection switch.'
}

$autoGuardIndex = $startSource.IndexOf(
  'Assert-DreamSkinAutoRestartReservation -StateRoot $StateRoot', [StringComparison]::Ordinal
)
$debugGuardIndex = $startSource.IndexOf(
  'Get-DreamSkinCodexAnyDebugIntentStatus -Processes $codexProcesses', [StringComparison]::Ordinal
)
$stopIndex = $startSource.IndexOf('Stop-DreamSkinCodex -Codex $codexToStop', [StringComparison]::Ordinal)
if ($autoGuardIndex -lt 0 -or $debugGuardIndex -le $autoGuardIndex -or $stopIndex -le $debugGuardIndex -or
  ([regex]::Matches($startSource, 'Assert-DreamSkinAutoRestartReservation').Count -lt 2)) {
  throw 'The launcher does not revalidate its automatic reservation and debug intent before stopping Codex.'
}
foreach ($required in @(
  '[switch]$AutoRestartStock',
  '[string]$AutoRestartReservationToken',
  "'-AutoRestartStock requires a live auto-launch reservation token.'",
  'Test-DreamSkinPaused -StateRoot $StateRoot'
)) {
  if (-not $startSource.Contains($required)) { throw "Automatic restart guard is missing: $required" }
}
if (-not $restoreSource.Contains('& $autoLaunchManager -Disable') -or
  $restoreSource.IndexOf('& $autoLaunchManager -Disable', [StringComparison]::Ordinal) -gt
  $restoreSource.IndexOf('Start-DreamSkinCodex -Codex $relaunchCodex', [StringComparison]::Ordinal)) {
  throw 'Restore does not disable automatic relaunch before reopening official Codex.'
}

if (-not (Get-Command Get-DreamSkinCodexAnyDebugIntentStatus -CommandType Function -ErrorAction SilentlyContinue)) {
  . $commonPath
}
$intentCases = @(
  @{ Expected = 'none'; Processes = @() },
  @{ Expected = 'none'; Processes = @([pscustomobject]@{ CommandLine = 'ChatGPT.exe --type=renderer' }) },
  @{ Expected = 'debug-intent'; Processes = @([pscustomobject]@{ CommandLine = 'ChatGPT.exe --remote-debugging-port 9444' }) },
  @{ Expected = 'debug-intent'; Processes = @([pscustomobject]@{ CommandLine = 'codex://x?arg=%252D%252Dremote-debugging-port%253D9444' }) },
  @{ Expected = 'debug-intent'; Processes = @([pscustomobject]@{ CommandLine = 'ChatGPT.exe --remote-debugging-pipe' }) },
  @{ Expected = 'uninspectable'; Processes = @([pscustomobject]@{ CommandLine = $null }) }
)
foreach ($case in $intentCases) {
  $actual = Get-DreamSkinCodexAnyDebugIntentStatus -Processes $case.Processes
  if ($actual -cne $case.Expected) {
    throw "Generic debug-intent classifier returned $actual instead of $($case.Expected)."
  }
}

& $autoPath -SelfTest
Write-Host 'PASS: automatic launch protects existing sessions and uses a one-shot guarded restart.'
