[CmdletBinding()]
param(
  [int]$Port = 9335,
  [string]$ScreenshotPath
)

$ErrorActionPreference = 'Stop'
$PortExplicit = $PSBoundParameters.ContainsKey('Port')
$injector = Join-Path $PSScriptRoot 'injector.mjs'
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')

$operationLock = Enter-DreamSkinOperationLock
$verifyExitCode = 1
try {
  $StatePath = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin\state.json'
  $state = Read-DreamSkinState -Path $StatePath
  $windowMaterial = if ($null -ne $state -and $state.windowMaterial) {
    "$($state.windowMaterial)".ToLowerInvariant()
  } else {
    # A preference describes the next launch, not an already-running legacy
    # session. States created before this feature are therefore System/Mica.
    'system'
  }
  if ($windowMaterial -notin @('system', 'acrylic')) {
    throw 'The recorded Dream Skin window material is invalid.'
  }
  if (-not $PortExplicit -and $null -ne $state -and $state.port) { $Port = [int]$state.port }
  Assert-DreamSkinPort -Port $Port
  $node = Get-DreamSkinNodeRuntime
  $currentCodex = Get-DreamSkinCodexInstall
  $codex = $currentCodex
  $cdpIdentity = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex
  if ($null -eq $cdpIdentity -and $null -ne $state) {
    $savedCodex = Get-DreamSkinCodexInstallFromState -State $state
    if ($null -ne $savedCodex -and
      -not (Test-DreamSkinPathEqual -Left $savedCodex.Executable -Right $currentCodex.Executable)) {
      $savedIdentity = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $savedCodex
      if ($null -ne $savedIdentity) {
        $codex = $savedCodex
        $cdpIdentity = $savedIdentity
      }
    }
  }
  if ($null -eq $cdpIdentity) {
    # A Store auto-update replaces the "current" package while an older
    # registered version still owns the verified endpoint.
    $runningRegistered = Get-DreamSkinVerifiedCdpIdentityForAnyRegistered -Port $Port
    if ($null -ne $runningRegistered) {
      $codex = $runningRegistered.Codex
      $cdpIdentity = $runningRegistered.Identity
    }
  }
  if ($null -eq $cdpIdentity) {
    throw "No verified Codex CDP endpoint is active on loopback port $Port."
  }
  if ($null -ne $state -and $state.browserId -and "$($state.browserId)" -cne $cdpIdentity.BrowserId) {
    throw 'The active CDP browser does not match the saved Dream Skin session; state was preserved.'
  }
  $win32Window = Wait-DreamSkinWin32WindowEvidence -Codex $codex -TimeoutMilliseconds 5000
  if ($null -eq $win32Window) {
    throw 'No visible Win32 HWND owned by the verified Codex executable is available.'
  }
  if ($null -ne $state -and
    $null -ne $state.PSObject.Properties['codexSessionId'] -and
    [int]$state.codexSessionId -ne [int]$win32Window.SessionId) {
    throw 'The verified Codex window belongs to a different Windows session than the saved state.'
  }
  if ($null -ne $state -and
    $null -ne $state.PSObject.Properties['codexPid'] -and
    ([int]$state.codexPid -ne [int]$win32Window.ProcessId -or
      [long]$state.codexStartTimeFileTimeUtc -ne
        [long]$win32Window.StartTimeFileTimeUtc)) {
    throw 'The verified Codex window does not match the saved process identity.'
  }
  if ($windowMaterial -ceq 'acrylic') {
    $acrylicHelper = Join-Path $PSScriptRoot 'acrylic-window.ps1'
    if ($null -eq $state) { throw 'Desktop Acrylic has no recorded active-session state.' }
    foreach ($field in @(
      'acrylicMonitorPid', 'acrylicMonitorStartedAt', 'acrylicMonitorPath',
      'acrylicMonitorStopFile', 'acrylicMonitorArmFile',
      'acrylicTargetPid', 'acrylicTargetStartTimeFileTimeUtc',
      'acrylicTargetExecutablePath', 'acrylicTargetPackageFamilyName',
      'acrylicTargetWindowClass', 'acrylicTargetWindowHandle', 'startupPhase'
    )) {
      if ($state.PSObject.Properties.Name -notcontains $field -or -not "$($state.$field)") {
        throw "Desktop Acrylic active state is missing: $field"
      }
    }
    if ("$($state.startupPhase)" -cne 'active') {
      throw 'Desktop Acrylic startup has not reached its verified active phase.'
    }
    $monitorPid = 0
    if (-not [int]::TryParse("$($state.acrylicMonitorPid)", [ref]$monitorPid) -or $monitorPid -le 0) {
      throw 'Desktop Acrylic monitor PID is invalid.'
    }
    $monitorInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $monitorPid" `
      -ErrorAction SilentlyContinue
    $monitorProcess = Get-Process -Id $monitorPid -ErrorAction SilentlyContinue
    if ($null -eq $monitorInfo -or $null -eq $monitorProcess) {
      throw 'The recorded Desktop Acrylic monitor is not running.'
    }
    try {
      $monitorStartedAt = $monitorProcess.StartTime.ToUniversalTime().ToString('o')
    } finally {
      $monitorProcess.Dispose()
    }
    $monitorCommandLine = "$($monitorInfo.CommandLine)"
    $monitorPath = Get-DreamSkinProcessExecutablePath -ProcessInfo $monitorInfo
    $powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
    $monitorIdentityMatches = $monitorPath -and $monitorCommandLine -and
      (Test-DreamSkinPathEqual -Left $monitorPath -Right $powershellPath) -and
      (Test-DreamSkinPathEqual -Left "$($state.acrylicMonitorPath)" -Right $acrylicHelper) -and
      (Test-DreamSkinCommandLineToken -CommandLine $monitorCommandLine -Token $acrylicHelper) -and
      (Test-DreamSkinCommandLineToken -CommandLine $monitorCommandLine -Token 'Monitor') -and
      (Test-DreamSkinCommandLineToken -CommandLine $monitorCommandLine -Token '-ExpectedWindowHandle') -and
      (Test-DreamSkinCommandLineToken -CommandLine $monitorCommandLine -Token "$($state.acrylicTargetWindowHandle)") -and
      (Test-DreamSkinCommandLineToken -CommandLine $monitorCommandLine -Token "$($state.acrylicMonitorArmFile)") -and
      $monitorStartedAt -ceq "$($state.acrylicMonitorStartedAt)" -and
      -not (Test-Path -LiteralPath "$($state.acrylicMonitorStopFile)")
    if (-not $monitorIdentityMatches) {
      throw 'The recorded Desktop Acrylic monitor identity is not live or exact.'
    }
    $descriptors = @(& $acrylicHelper -Action Describe `
      -TargetProcessId $win32Window.ProcessId `
      -ExpectedWindowHandle ([long]$win32Window.Handle))
    if ($descriptors.Count -ne 1 -or [int]$descriptors[0].CurrentBackdrop -ne 3 -or
      [long]$descriptors[0].WindowHandleValue -ne [long]$win32Window.Handle -or
      [int]$state.acrylicTargetPid -ne [int]$descriptors[0].ProcessId -or
      [long]$state.acrylicTargetStartTimeFileTimeUtc -ne [long]$descriptors[0].StartTimeFileTimeUtc -or
      [long]$state.acrylicTargetWindowHandle -ne [long]$descriptors[0].WindowHandleValue -or
      "$($state.acrylicTargetExecutablePath)" -ine "$($descriptors[0].ExecutablePath)" -or
      "$($state.acrylicTargetPackageFamilyName)" -cne "$($descriptors[0].PackageFamilyName)" -or
      "$($state.acrylicTargetWindowClass)" -cne "$($descriptors[0].WindowClass)" -or
      "$($descriptors[0].ExecutablePath)" -ine "$($codex.Executable)" -or
      "$($descriptors[0].PackageFamilyName)" -cne "$($codex.PackageFamilyName)") {
      throw 'The verified Codex window is not currently using Desktop Acrylic.'
    }
  }

  # Without an explicit --theme-dir the injector falls back to the engine's
  # bundled assets theme, so verification compares the live skin against the
  # wrong expected theme and never passes.  Always verify against the staged
  # active theme, exactly like the watcher applies it.
  $themePaths = Get-DreamSkinThemePaths -StateRoot (Join-Path $env:LOCALAPPDATA 'CodexDreamSkin')
  $arguments = @($injector, '--verify', '--port', "$Port", '--browser-id', $cdpIdentity.BrowserId,
    '--theme-dir', $themePaths.Active, '--timeout-ms', '30000',
    '--win32-window-pid', "$($win32Window.ProcessId)",
    '--win32-window-hwnd', "$($win32Window.Handle)",
    '--win32-window-width', "$($win32Window.Width)",
    '--win32-window-height', "$($win32Window.Height)",
    '--window-material', $windowMaterial)
  if ($ScreenshotPath) { $arguments += @('--screenshot', $ScreenshotPath) }
  & $node.Path @arguments
  $verifyExitCode = $LASTEXITCODE
} finally {
  Exit-DreamSkinOperationLock -Mutex $operationLock
}
exit $verifyExitCode
