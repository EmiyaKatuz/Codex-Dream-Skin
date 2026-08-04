[CmdletBinding()]
param(
  [int]$Port = 9335,
  [switch]$RestartExisting,
  [switch]$AutoRestartStock,
  [string]$AutoRestartReservationToken,
  [switch]$PromptRestart,
  [string]$ProfilePath,
  [switch]$ForegroundInjector,
  [ValidateRange(0, 300000)][int]$OperationLockTimeoutMilliseconds = 0,
  [switch]$RequireUnpaused
)

$ErrorActionPreference = 'Stop'
$PortExplicit = $PSBoundParameters.ContainsKey('Port')
$Injector = Join-Path $PSScriptRoot 'injector.mjs'
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')

function Assert-DreamSkinAutoRestartStableZero {
  param(
    [Parameter(Mandatory = $true)][string]$StateRoot,
    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 2147483647)][int]$ExpectedSessionId,
    [ValidateRange(250, 5000)][int]$StableMilliseconds = 1000
  )

  $registeredInstalls = @(Get-DreamSkinRegisteredCodexInstalls)
  Assert-DreamSkinAutoRestartControlClear -StateRoot $StateRoot
  $first = Get-DreamSkinRegisteredCodexProcessSnapshot -RegisteredInstalls $registeredInstalls `
    -ExpectedSessionId $ExpectedSessionId
  if (@($first.TargetProcesses).Count -ne 0) {
    throw 'A new Codex process appeared before the automatic managed launch.'
  }
  Start-Sleep -Milliseconds $StableMilliseconds
  Assert-DreamSkinAutoRestartControlClear -StateRoot $StateRoot
  $second = Get-DreamSkinRegisteredCodexProcessSnapshot -RegisteredInstalls $registeredInstalls `
    -ExpectedSessionId $ExpectedSessionId
  if (@($second.TargetProcesses).Count -ne 0) {
    throw 'The Codex zero-process boundary was not stable before automatic managed launch.'
  }
}

$operationLock = Enter-DreamSkinOperationLock `
  -TimeoutMilliseconds $OperationLockTimeoutMilliseconds
try {
  if ($AutoRestartStock -and ($RestartExisting -or $PromptRestart)) {
    throw '-AutoRestartStock cannot be combined with -RestartExisting or -PromptRestart.'
  }
  if ($AutoRestartStock -and -not $AutoRestartReservationToken) {
    throw '-AutoRestartStock requires a live auto-launch reservation token.'
  }
  if (-not $AutoRestartStock -and $AutoRestartReservationToken) {
    throw '-AutoRestartReservationToken is only valid with -AutoRestartStock.'
  }
  Assert-DreamSkinPort -Port $Port
  if ($ProfilePath) { $ProfilePath = [System.IO.Path]::GetFullPath($ProfilePath) }
  $node = Get-DreamSkinNodeRuntime
  $currentCodex = Get-DreamSkinCodexInstall
  $codex = $currentCodex
  $StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
  $windowEffects = Read-DreamSkinWindowEffects -StateRoot $StateRoot
  $windowMaterial = $windowEffects.WindowMaterial
  $acrylicTransparencyReady = $false
  $acrylicHelper = Join-Path $PSScriptRoot 'acrylic-window.ps1'
  if ($windowMaterial -ceq 'acrylic') {
    $acrylicEnvironment = Get-DreamSkinAcrylicEnvironment
    if (-not $acrylicEnvironment.Supported) {
      throw "Desktop Acrylic requires Windows 11 build 22621 or newer with Transparency effects enabled. Current build: $($acrylicEnvironment.Build)."
    }
    if (-not (Test-Path -LiteralPath $acrylicHelper -PathType Leaf)) {
      throw "The managed Desktop Acrylic helper is missing: $acrylicHelper"
    }
    $codexConfigPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\config.toml'
    $acrylicTransparencyReady = Test-DreamSkinAcrylicTransparencyConfig `
      -ConfigPath $codexConfigPath
    if (-not (Test-DreamSkinAcrylicTransparencyConfigManageable -ConfigPath $codexConfigPath)) {
      throw 'Desktop Acrylic cannot safely manage opaqueWindows = false in the active Codex light chrome theme; no app process or native window was changed.'
    }
    if ($ForegroundInjector) {
      throw 'Desktop Acrylic currently requires the managed background injector; remove -ForegroundInjector or set window effects to System.'
    }
  }
  $themePaths = Get-DreamSkinThemePaths -StateRoot $StateRoot
  Ensure-DreamSkinManagedDirectory -Path $themePaths.Root -Root $themePaths.Root
  $StatePath = Join-Path $StateRoot 'state.json'
  $StdoutPath = Join-Path $StateRoot 'injector.log'
  $StderrPath = Join-Path $StateRoot 'injector-error.log'
  $VerifyPath = Join-Path $StateRoot 'verify.log'
  $AcrylicStdoutPath = Join-Path $StateRoot 'acrylic-monitor.log'
  $AcrylicStderrPath = Join-Path $StateRoot 'acrylic-monitor-error.log'
  $themePaths = Initialize-DreamSkinThemeStore -SkillRoot (Split-Path -Parent $PSScriptRoot) -StateRoot $StateRoot
  $pauseWasSet = Test-DreamSkinPaused -StateRoot $StateRoot
  if ($RequireUnpaused -and $pauseWasSet) {
    throw 'A newer pause request superseded this theme apply before renderer verification.'
  }
  $autoLaunchScript = $null
  $autoRestartReservation = $null
  $autoRestartExpectedSessionId = $null
  $autoSessionParameters = @{}
  if ($AutoRestartStock) {
    $autoLaunchScript = Join-Path (Split-Path -Parent $Injector) 'auto-launch-dream-skin.ps1'
    $autoRestartReservation = Assert-DreamSkinAutoRestartReservation -StateRoot $StateRoot `
      -Token $AutoRestartReservationToken -ExpectedScriptPath $autoLaunchScript
    $autoRestartExpectedSessionId = [int]$autoRestartReservation.SessionId
    $autoSessionParameters = @{ ExpectedSessionId = $autoRestartExpectedSessionId }
  }

  $previousState = Read-DreamSkinState -Path $StatePath
  $previousStateOwnership = Get-DreamSkinRecordedStateSessionOwnership `
    -State $previousState -StateRoot $StateRoot
  if ($previousStateOwnership.IsLive) {
    $launcherProcess = Get-Process -Id $PID -ErrorAction Stop
    try { $launcherSessionId = [int]$launcherProcess.SessionId } finally {
      $launcherProcess.Dispose()
    }
    $expectedOwnerSessionId = if ($AutoRestartStock) {
      $autoRestartExpectedSessionId
    } else {
      $launcherSessionId
    }
    if ([int]$previousStateOwnership.SessionId -ne [int]$expectedOwnerSessionId) {
      $ownershipMessage =
        'A live Dream Skin session in another Windows session owns the shared managed state.'
      if ($AutoRestartStock) {
        Write-Host "Automatic Dream Skin restart skipped: $ownershipMessage"
        return
      }
      throw "$ownershipMessage Close or restore that session before reapplying the skin here."
    }
  }
  if (-not $PortExplicit -and $null -ne $previousState -and $previousState.port) {
    $savedPort = [int]$previousState.port
    Assert-DreamSkinPort -Port $savedPort
    $Port = $savedPort
  }
  $savedPathCandidate = Get-DreamSkinCodexStatePathCandidate -State $previousState
  $savedCodex = Get-DreamSkinCodexInstallFromState -State $previousState
  $candidateMatchesCurrent = [bool]($null -ne $savedPathCandidate -and
    (Test-DreamSkinPathEqual -Left $savedPathCandidate.PackageRoot -Right $currentCodex.PackageRoot) -and
    (Test-DreamSkinPathEqual -Left $savedPathCandidate.Executable -Right $currentCodex.Executable))
  if ($null -ne $savedPathCandidate -and $null -eq $savedCodex -and -not $candidateMatchesCurrent) {
    $unverifiedSavedRunning =
      (Get-DreamSkinCodexProcesses -Codex $savedPathCandidate @autoSessionParameters).Count -gt 0
    $unverifiedSavedOwnsPort = Test-DreamSkinCodexPortOwner -Port $Port `
      -Codex $savedPathCandidate @autoSessionParameters
    if ($unverifiedSavedRunning -or $unverifiedSavedOwnsPort) {
      throw 'The saved Codex path is still active but no longer matches a registered OpenAI.Codex package. Close it manually; state was preserved.'
    }
  }

  $currentProcesses = Get-DreamSkinCodexProcesses -Codex $currentCodex @autoSessionParameters
  $codexToStop = $currentCodex
  $cdpIdentity = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $currentCodex `
    @autoSessionParameters
  if ($null -eq $cdpIdentity) {
    # After a Store auto-update the running (older) package still owns the
    # verified endpoint while Get-DreamSkinCodexInstall already resolves to
    # the new one.  Adopt the running install instead of restarting it.
    $runningRegistered = Get-DreamSkinVerifiedCdpIdentityForAnyRegistered -Port $Port `
      @autoSessionParameters
    if ($null -ne $runningRegistered) {
      $cdpIdentity = $runningRegistered.Identity
      $codex = $runningRegistered.Codex
      $codexToStop = $runningRegistered.Codex
    }
  }
  $savedIsDifferent = [bool]($null -ne $savedCodex -and
    -not (Test-DreamSkinPathEqual -Left $savedCodex.Executable -Right $currentCodex.Executable))
  if ($savedIsDifferent) {
    $savedProcesses = Get-DreamSkinCodexProcesses -Codex $savedCodex @autoSessionParameters
    $savedOwnsPort = Test-DreamSkinCodexPortOwner -Port $Port -Codex $savedCodex `
      @autoSessionParameters
    if ($currentProcesses.Count -gt 0 -and ($savedProcesses.Count -gt 0 -or $savedOwnsPort)) {
      throw 'Multiple registered Codex package versions are active. Close them manually before starting Dream Skin.'
    }
    if ($savedProcesses.Count -gt 0 -or $savedOwnsPort) {
      if ($savedOwnsPort -and $savedProcesses.Count -eq 0) {
        throw 'The saved Codex listener is active but its process cannot be managed safely; state was preserved.'
      }
      $savedIdentity = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $savedCodex `
        @autoSessionParameters
      if ($null -ne $savedIdentity) {
        $codex = $savedCodex
        $codexToStop = $savedCodex
        $cdpIdentity = $savedIdentity
        Write-Warning 'Reapplying Dream Skin to the still-running registered Codex version; the current Store version will be used after that app exits.'
      } else {
        $codexToStop = $savedCodex
        $currentProcesses = $savedProcesses
      }
    }
  }
  if ($windowMaterial -ceq 'acrylic' -and $null -ne $cdpIdentity -and
    -not $acrylicTransparencyReady) {
    # A live System/Mica session cannot be made renderer-transparent safely
    # while Codex owns config.toml. Route through the existing explicit restart
    # authorization so the closed-app transaction can set opaqueWindows=false.
    $cdpIdentity = $null
    Write-Warning 'Desktop Acrylic requires a one-time Codex restart to enable transparent window rendering.'
  }
  $debugReady = $null -ne $cdpIdentity
  $codexProcesses = if (Test-DreamSkinPathEqual -Left $codexToStop.Executable -Right $currentCodex.Executable) {
    $currentProcesses
  } else {
    Get-DreamSkinCodexProcesses -Codex $codexToStop @autoSessionParameters
  }
  if ($AutoRestartStock) {
    # Revalidate both the reservation and the complete registered Codex process
    # set under the operation mutex. A session that exited, was replaced, or
    # gained another process cannot transfer its one-shot authorization.
    $autoRestartReservation = Assert-DreamSkinAutoRestartReservation -StateRoot $StateRoot `
      -Token $AutoRestartReservationToken -ExpectedScriptPath $autoLaunchScript
    try {
      $autoRestartSnapshot = Get-DreamSkinRegisteredCodexProcessSnapshot `
        -RegisteredInstalls @(Get-DreamSkinRegisteredCodexInstalls) `
        -ExpectedSessionId $autoRestartExpectedSessionId
    } catch {
      Write-Host "Automatic Dream Skin restart skipped: the reserved Codex process set could not be verified: $($_.Exception.Message)"
      return
    }
    if (-not (Test-DreamSkinAutoRestartTargetProcessesEqual `
        -Reserved @($autoRestartReservation.TargetProcesses) `
        -Current @($autoRestartSnapshot.TargetProcesses))) {
      Write-Host 'Automatic Dream Skin restart skipped: the reserved Codex process set exited, changed, or gained another process.'
      return
    }
    $targetsMatchSelectedInstall = @($autoRestartReservation.TargetProcesses | Where-Object {
      -not (Test-DreamSkinPathEqual -Left "$($_.executablePath)" -Right "$($codexToStop.Executable)") -or
      "$($_.packageFullName)" -ine "$($codexToStop.PackageFullName)" -or
      "$($_.packageFamilyName)" -ine "$($codexToStop.PackageFamilyName)"
    }).Count -eq 0
    if (-not $targetsMatchSelectedInstall) {
      Write-Host 'Automatic Dream Skin restart skipped: the reserved processes do not belong to the one selected Codex Store install.'
      return
    }
    $codexProcesses = @($autoRestartSnapshot.Processes)
  }
  $closedExistingCodex = $false
  if (-not $debugReady -and $codexProcesses.Count -gt 0) {
    $restartAuthorized = [bool]($RestartExisting -or $AutoRestartStock)
    if ($AutoRestartStock) {
      $debugIntent = Get-DreamSkinCodexAnyDebugIntentStatus -Processes $codexProcesses
      if ($debugIntent -ne 'none') {
        Write-Host "Automatic Dream Skin restart skipped: Codex debug intent is $debugIntent."
        return
      }
      if (Test-DreamSkinPaused -StateRoot $StateRoot) {
        Write-Host 'Automatic Dream Skin restart skipped: the skin was paused.'
        return
      }
      $latestAutoRestartReservation = Assert-DreamSkinAutoRestartReservation `
        -StateRoot $StateRoot -Token $AutoRestartReservationToken `
        -ExpectedScriptPath $autoLaunchScript
      if (-not (Test-DreamSkinAutoRestartTargetProcessesEqual `
          -Reserved @($autoRestartReservation.TargetProcesses) `
          -Current @($latestAutoRestartReservation.TargetProcesses))) {
        Write-Host 'Automatic Dream Skin restart skipped: the process reservation changed before shutdown.'
        return
      }
      $autoRestartReservation = $latestAutoRestartReservation
    }
    if (-not $restartAuthorized -and $PromptRestart) {
      $restartAuthorized = Confirm-DreamSkinRestart -Message 'Codex must restart once to enable Dream Skin. Unsaved input may be lost. Restart now?'
      if (-not $restartAuthorized) {
        Write-Host 'Dream Skin launch was cancelled; Codex was not changed.'
        exit 0
      }
    }
    if (-not $restartAuthorized) {
      throw 'Codex is open without a verified Dream Skin CDP endpoint. Close it first or explicitly use -RestartExisting.'
    }
    if ($AutoRestartStock) {
      Stop-DreamSkinCodex -Codex $codexToStop -AllowForce `
        -ExpectedAutoRestartTargets @($autoRestartReservation.TargetProcesses) `
        -AutoRestartStateRoot $StateRoot
    } else {
      Stop-DreamSkinCodex -Codex $codexToStop -AllowForce
    }
    $closedExistingCodex = $true
    $codex = $currentCodex
    if ($AutoRestartStock) {
      try {
        Assert-DreamSkinAutoRestartStableZero -StateRoot $StateRoot `
          -ExpectedSessionId $autoRestartExpectedSessionId
      } catch {
        Invoke-DreamSkinAutoRestartStockRecovery -StateRoot $StateRoot `
          -Codex $currentCodex -ExpectedSessionId $autoRestartExpectedSessionId `
          -FailureMessage "Automatic Dream Skin restart stopped after the reserved close: $($_.Exception.Message)"
      }
    }
  }

  $launchedWithCdp = $false
  $debugLaunchAttempted = $false
  $debugLaunch = $null
  $debugLaunchBaselineProcessIds = @()
  $acrylicDescriptor = $null
  try {
    if ($null -eq (Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex `
        @autoSessionParameters)) {
      # Codex is closed on this path; sync the appearanceTheme pin to the
      # active theme before launching (config writes race the app while it runs).
      try {
        Install-DreamSkinBaseTheme -ConfigPath (Join-Path $HOME '.codex\config.toml') `
          -BackupPath (Join-Path $StateRoot 'config.before-dream-skin.toml') `
          -AppearanceTheme (Get-DreamSkinActiveThemeAppearance -ThemeDirectory $themePaths.Active) `
          -TransparentWindows:($windowMaterial -ceq 'acrylic')
      } catch {
        Write-Warning "Could not sync Codex appearanceTheme to the active theme: $($_.Exception.Message)"
      }
      if ($windowMaterial -ceq 'acrylic' -and
        -not (Test-DreamSkinAcrylicTransparencyConfig -ConfigPath $codexConfigPath)) {
        throw 'The Codex theme sync did not preserve opaqueWindows = false for Desktop Acrylic.'
      }
      if (-not (Test-DreamSkinPortAvailable -Port $Port)) {
        if ($PortExplicit) { throw "Port $Port is already occupied by an unverified listener. Choose another port." }
        $Port = Select-DreamSkinPort -PreferredPort $Port
      }
      $arguments = @('--remote-debugging-address=127.0.0.1', "--remote-debugging-port=$Port")
      if ($ProfilePath) {
        New-Item -ItemType Directory -Force -Path $ProfilePath | Out-Null
        $arguments += "--user-data-dir=$ProfilePath"
      }
      if ($AutoRestartStock) {
        try {
          Assert-DreamSkinAutoRestartControlClear -StateRoot $StateRoot
          $preLaunchSnapshot = Get-DreamSkinRegisteredCodexProcessSnapshot `
            -RegisteredInstalls @(Get-DreamSkinRegisteredCodexInstalls) `
            -ExpectedSessionId $autoRestartExpectedSessionId
          if (@($preLaunchSnapshot.TargetProcesses).Count -ne 0) {
            throw 'A new Codex process appeared at the automatic activation boundary.'
          }
        } catch {
          Invoke-DreamSkinAutoRestartStockRecovery -StateRoot $StateRoot `
            -Codex $currentCodex -ExpectedSessionId $autoRestartExpectedSessionId `
            -FailureMessage "Automatic Dream Skin activation failed before direct launch: $($_.Exception.Message)"
        }
      }
      $debugLaunchAttempted = $true
      if ($AutoRestartStock) {
        # The official handoff has already closed one exact reserved session and
        # proved a same-session stable zero. Launch the validated Store
        # executable directly so a package-protocol redirect does not require a
        # broad cleanup/retry. Any failure preserves every process it created.
        $directProcessId = Start-DreamSkinCodexDirect -Codex $codex -Arguments $arguments
        $directStatus = Wait-DreamSkinCodexDebugArgumentStatus -Codex $codex -Port $Port `
          @autoSessionParameters
        if ($directStatus -in @('protocol-redirected', 'not-forwarded')) {
          throw "Automatic Dream Skin direct launch did not retain the CDP arguments ($directStatus); its processes were preserved."
        }
        $debugLaunch = [pscustomobject]@{
          ProcessId = $directProcessId
          Strategy = 'direct-store-executable'
          ArgumentStatus = $directStatus
          PackageArgumentStatus = 'not-attempted'
        }
      } else {
        $debugLaunchBaselineProcessIds = @(
          Get-DreamSkinCodexProcesses -Codex $codex @autoSessionParameters |
            ForEach-Object { [int]$_.ProcessId }
        )
        $debugLaunch = Start-DreamSkinCodexForDebugging -Codex $codex -Arguments $arguments `
          -Port $Port -PreserveProcessIds $debugLaunchBaselineProcessIds
      }
      $launchedWithCdp = $true
      if ($debugLaunch.Strategy -eq 'direct-store-executable' -and
        $debugLaunch.PackageArgumentStatus -ne 'not-attempted') {
        Write-Warning 'Codex package activation did not preserve the CDP arguments; using the validated Store executable fallback for this session.'
      }
    }

    $deadline = (Get-Date).AddSeconds(45)
    $cdpIdentity = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex `
      @autoSessionParameters
    while ($null -eq $cdpIdentity) {
      $argumentStatus = Get-DreamSkinCodexDebugArgumentStatus `
        -Processes @(Get-DreamSkinCodexProcesses -Codex $codex @autoSessionParameters) `
        -Port $Port
      if ($argumentStatus -eq 'protocol-redirected') {
        throw "Codex $($codex.Version) converted the CDP argument into a codex:// navigation path instead of opening a debugging endpoint."
      }
      if ((Get-Date) -ge $deadline) {
        if ($null -ne $debugLaunch -and $debugLaunch.Strategy -eq 'direct-store-executable') {
          throw "The validated direct Store executable fallback did not expose a verified loopback CDP endpoint on port $Port within 45 seconds. Codex $($codex.Version) may disable CDP in this production runtime; no protected app files or permissions were changed."
        }
        throw "Codex did not expose a verified loopback CDP endpoint on port $Port within 45 seconds."
      }
      Start-Sleep -Milliseconds 400
      $cdpIdentity = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex `
        @autoSessionParameters
    }
    $win32Window = Wait-DreamSkinWin32WindowEvidence -Codex $codex `
      -TimeoutMilliseconds 30000 @autoSessionParameters
    if ($null -eq $win32Window) {
      throw 'Codex exposed CDP without a verified visible Win32 HWND owned by the registered executable.'
    }
    $win32WindowArgs = @(
      '--win32-window-pid', "$($win32Window.ProcessId)",
      '--win32-window-hwnd', "$($win32Window.Handle)",
      '--win32-window-width', "$($win32Window.Width)",
      '--win32-window-height', "$($win32Window.Height)"
    )
    if ($windowMaterial -ceq 'acrylic') {
      $descriptors = @(& $acrylicHelper -Action Describe `
        -TargetProcessId $win32Window.ProcessId `
        -ExpectedWindowHandle ([long]$win32Window.Handle))
      if ($descriptors.Count -ne 1) {
        throw 'The Desktop Acrylic helper did not return exactly one pinned Codex window descriptor.'
      }
      $acrylicDescriptor = $descriptors[0]
      if ([int]$acrylicDescriptor.ProcessId -ne [int]$win32Window.ProcessId -or
        "$($acrylicDescriptor.ExecutablePath)" -ine "$($codex.Executable)" -or
        "$($acrylicDescriptor.PackageFamilyName)" -cne "$($codex.PackageFamilyName)" -or
        [long]$acrylicDescriptor.WindowHandleValue -ne [long]$win32Window.Handle -or
        [int]$acrylicDescriptor.CurrentBackdrop -notin @(2, 3)) {
        throw 'The Desktop Acrylic descriptor does not match the exact verified Store Codex HWND or a supported native backdrop.'
      }
    }
    $injectorWindowArgs = $win32WindowArgs + @('--window-material', $windowMaterial)
  } catch {
    $launchError = $_
    if ($debugLaunchAttempted -and -not $AutoRestartStock) {
      try {
        Stop-DreamSkinCodex -Codex $codex `
          -PreserveProcessIds $debugLaunchBaselineProcessIds -AllowForce
      } catch {
        Write-Warning 'Launch rollback could not fully close the failed CDP session.'
      }
    }
    if ($AutoRestartStock -and ($closedExistingCodex -or $debugLaunchAttempted)) {
      Invoke-DreamSkinAutoRestartStockRecovery -StateRoot $StateRoot `
        -Codex $currentCodex -ExpectedSessionId $autoRestartExpectedSessionId `
        -FailureMessage "Automatic Dream Skin launch failed: $($launchError.Exception.Message)"
    }
    if (-not $AutoRestartStock -and ($closedExistingCodex -or $debugLaunchAttempted) -and
      (Get-DreamSkinCodexProcesses -Codex $codex).Count -eq 0) {
      if ($debugLaunchAttempted) {
        Write-Warning 'Dream Skin launch failed; reopening Codex without a debugging port.'
      }
      try { $null = Start-DreamSkinCodex -Codex $codex } catch {
        Write-Warning 'Launch rollback could not reopen Codex automatically.'
      }
    }
    throw $launchError
  }

  try {
    $null = Stop-DreamSkinRecordedAcrylicMonitor -State $previousState -StateRoot $StateRoot
    if ($windowMaterial -ceq 'acrylic') {
      $restoredDescriptors = @(& $acrylicHelper -Action Describe `
        -TargetProcessId $win32Window.ProcessId `
        -ExpectedWindowHandle ([long]$win32Window.Handle))
      if ($restoredDescriptors.Count -ne 1 -or
        [int]$restoredDescriptors[0].ProcessId -ne [int]$acrylicDescriptor.ProcessId -or
        [long]$restoredDescriptors[0].StartTimeFileTimeUtc -ne [long]$acrylicDescriptor.StartTimeFileTimeUtc -or
        [long]$restoredDescriptors[0].WindowHandleValue -ne [long]$acrylicDescriptor.WindowHandleValue -or
        "$($restoredDescriptors[0].ExecutablePath)" -ine "$($acrylicDescriptor.ExecutablePath)" -or
        "$($restoredDescriptors[0].PackageFamilyName)" -cne "$($acrylicDescriptor.PackageFamilyName)" -or
        [int]$restoredDescriptors[0].CurrentBackdrop -ne 2) {
        throw 'The exact Codex HWND did not return to its verified Mica baseline before Acrylic handoff.'
      }
      $acrylicDescriptor = $restoredDescriptors[0]
    }
    $recordedInjectorStopped = Stop-DreamSkinRecordedInjector -State $previousState
    if (-not $recordedInjectorStopped) {
      $staleStatePath = Archive-DreamSkinStateFile -Path $StatePath
      Write-Warning "Archived stale Dream Skin state at $staleStatePath"
    }
  } catch {
    if ($launchedWithCdp) {
      if ($AutoRestartStock) {
        Write-Warning 'Automatic handoff state validation failed; the exact launched Codex processes were preserved.'
      } else {
        try {
          Stop-DreamSkinCodex -Codex $codex -AllowForce
          $null = Start-DreamSkinCodex -Codex $codex
        } catch {
          Write-Warning 'State validation rollback could not fully restart Codex; close Codex to ensure its CDP port is closed.'
        }
      }
    }
    throw
  }

  # Keep a paused, already-running watcher paused until all state checks and any
  # restart consent have succeeded.  A cancelled prompt must be side-effect free.
  if ($AutoRestartStock) {
    try {
      Assert-DreamSkinAutoRestartControlClear -StateRoot $StateRoot
    } catch {
      throw "Automatic Dream Skin apply stopped after launch; the launched Codex session was preserved: $($_.Exception.Message)"
    }
  }
  Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
  $pauseCleared = $true

  if ($ForegroundInjector) {
    try {
      Remove-Item -LiteralPath $StatePath -Force -ErrorAction SilentlyContinue
      Exit-DreamSkinOperationLock -Mutex $operationLock
      $operationLock = $null
      & $node.Path $Injector --watch --port $Port --browser-id $cdpIdentity.BrowserId `
        --theme-dir $themePaths.Active --pause-file $themePaths.PauseFile @injectorWindowArgs
      $foregroundExitCode = $LASTEXITCODE
      if ($foregroundExitCode -ne 0 -and $pauseWasSet) {
        Set-DreamSkinPaused -Paused $true -StateRoot $StateRoot | Out-Null
      }
      exit $foregroundExitCode
    } catch {
      if ($pauseWasSet) {
        try { Set-DreamSkinPaused -Paused $true -StateRoot $StateRoot | Out-Null } catch {
          Write-Warning 'Foreground startup rollback could not restore the existing paused state.'
        }
      }
      throw
    }
  }

  $state = $null
  $daemon = $null
  $acrylicMonitor = $null
  $acrylicMonitorStartedAt = $null
  $acrylicStopFile = $null
  $acrylicArmFile = $null
  try {
    $injectorArgs = @((ConvertTo-DreamSkinProcessArgument -Value $Injector), '--watch', '--port', "$Port",
      '--browser-id', $cdpIdentity.BrowserId, '--theme-dir',
      (ConvertTo-DreamSkinProcessArgument -Value $themePaths.Active), '--pause-file',
      (ConvertTo-DreamSkinProcessArgument -Value $themePaths.PauseFile)) + $injectorWindowArgs
    $daemon = Start-Process -FilePath $node.Path -ArgumentList $injectorArgs -WindowStyle Hidden -PassThru `
      -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath
    Start-Sleep -Milliseconds 500
    if ($daemon.HasExited) { throw "The injector exited during startup. See $StderrPath" }

    $injectorStartedAt = Get-DreamSkinProcessStartedAt -ProcessId $daemon.Id
    if (-not $injectorStartedAt) { throw 'The injector process identity could not be recorded safely.' }
    if ($windowMaterial -ceq 'acrylic') {
      $acrylicStopFile = Join-Path $StateRoot `
        ('acrylic-monitor-' + [guid]::NewGuid().ToString('N') + '.stop')
      $acrylicArmFile = Join-Path $StateRoot `
        ('acrylic-monitor-' + [guid]::NewGuid().ToString('N') + '.arm')
      Assert-DreamSkinNoReparseComponents -Path $acrylicStopFile
      Assert-DreamSkinNoReparseComponents -Path $acrylicArmFile
      if ((Test-Path -LiteralPath $acrylicStopFile) -or
        (Test-Path -LiteralPath $acrylicArmFile)) {
        throw 'A new Acrylic monitor control path already exists.'
      }
    }
    $state = [pscustomobject]@{
      schemaVersion = 3
      platform = 'windows'
      port = $Port
      injectorPid = $daemon.Id
      injectorStartedAt = $injectorStartedAt
      injectorPath = $Injector
      nodePath = $node.Path
      nodeVersion = $node.Version
      codexExe = $codex.Executable
      codexPackageRoot = $codex.PackageRoot
      codexPackageFullName = $codex.PackageFullName
      codexPackageFamilyName = $codex.PackageFamilyName
      codexVersion = $codex.Version
      codexPid = [int]$win32Window.ProcessId
      codexStartTimeFileTimeUtc = [long]$win32Window.StartTimeFileTimeUtc
      codexSessionId = [int]$win32Window.SessionId
      browserId = $cdpIdentity.BrowserId
      profilePath = $ProfilePath
      themeDir = $themePaths.Active
      pauseFile = $themePaths.PauseFile
      windowMaterial = $windowMaterial
      nativeBackdropBefore = if ($null -ne $acrylicDescriptor) { [int]$acrylicDescriptor.CurrentBackdrop } else { $null }
      acrylicMonitorPid = $null
      acrylicMonitorStartedAt = $null
      acrylicMonitorPath = if ($null -ne $acrylicDescriptor) { $acrylicHelper } else { $null }
      acrylicMonitorStopFile = $acrylicStopFile
      acrylicMonitorArmFile = $acrylicArmFile
      acrylicTargetPid = if ($null -ne $acrylicDescriptor) { [int]$acrylicDescriptor.ProcessId } else { $null }
      acrylicTargetStartTimeFileTimeUtc = if ($null -ne $acrylicDescriptor) { [long]$acrylicDescriptor.StartTimeFileTimeUtc } else { $null }
      acrylicTargetExecutablePath = if ($null -ne $acrylicDescriptor) { "$($acrylicDescriptor.ExecutablePath)" } else { $null }
      acrylicTargetPackageFamilyName = if ($null -ne $acrylicDescriptor) { "$($acrylicDescriptor.PackageFamilyName)" } else { $null }
      acrylicTargetWindowClass = if ($null -ne $acrylicDescriptor) { "$($acrylicDescriptor.WindowClass)" } else { $null }
      acrylicTargetWindowHandle = if ($null -ne $acrylicDescriptor) { [long]$acrylicDescriptor.WindowHandleValue } else { $null }
      startupPhase = if ($null -ne $acrylicDescriptor) { 'acrylic-monitor-spawning' } else { 'verifying' }
      createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    # Persist the target and control files before an unarmed monitor exists.
    # A hard crash can therefore leave no unrecorded native Acrylic write.
    Write-DreamSkinState -Path $StatePath -State $state
    if ($windowMaterial -ceq 'acrylic') {
      $powershellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
      $monitorTokens = @(
        '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'RemoteSigned',
        '-File', $acrylicHelper,
        '-Action', 'Monitor',
        '-TargetProcessId', "$($acrylicDescriptor.ProcessId)",
        '-ExpectedStartTimeFileTimeUtc', "$($acrylicDescriptor.StartTimeFileTimeUtc)",
        '-ExpectedExecutablePath', "$($acrylicDescriptor.ExecutablePath)",
        '-ExpectedPackageFamilyName', "$($acrylicDescriptor.PackageFamilyName)",
        '-ExpectedWindowClass', "$($acrylicDescriptor.WindowClass)",
        '-ExpectedWindowHandle', "$($acrylicDescriptor.WindowHandleValue)",
        '-StopFile', $acrylicStopFile,
        '-ArmFile', $acrylicArmFile,
        '-ConfirmTargetIdentity'
      )
      $monitorArgumentLine = ($monitorTokens | ForEach-Object {
        ConvertTo-DreamSkinProcessArgument -Value "$_"
      }) -join ' '
      $acrylicMonitor = Start-Process -FilePath $powershellPath -ArgumentList $monitorArgumentLine `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $AcrylicStdoutPath `
        -RedirectStandardError $AcrylicStderrPath
      Start-Sleep -Milliseconds 300
      if ($acrylicMonitor.HasExited) {
        throw "The Desktop Acrylic monitor exited during startup. See $AcrylicStderrPath"
      }
      $acrylicMonitorStartedAt = Get-DreamSkinProcessStartedAt -ProcessId $acrylicMonitor.Id
      if (-not $acrylicMonitorStartedAt) {
        throw 'The Desktop Acrylic monitor process identity could not be recorded safely.'
      }
      $state.acrylicMonitorPid = $acrylicMonitor.Id
      $state.acrylicMonitorStartedAt = $acrylicMonitorStartedAt
      $state.startupPhase = 'acrylic-monitor-recorded'
      Write-DreamSkinState -Path $StatePath -State $state
      Write-DreamSkinUtf8FileAtomically -Path $acrylicArmFile `
        -Content ("armedAt=" + [DateTime]::UtcNow.ToString('o') + "`r`n")
      $acrylicDeadline = [DateTime]::UtcNow.AddSeconds(8)
      $acrylicApplied = $false
      do {
        if ($acrylicMonitor.HasExited) {
          throw "The Desktop Acrylic monitor exited before applying the material. See $AcrylicStderrPath"
        }
        try {
          $probes = @(& $acrylicHelper -Action Probe `
            -TargetProcessId $acrylicDescriptor.ProcessId `
            -ExpectedStartTimeFileTimeUtc $acrylicDescriptor.StartTimeFileTimeUtc `
            -ExpectedExecutablePath $acrylicDescriptor.ExecutablePath `
            -ExpectedPackageFamilyName $acrylicDescriptor.PackageFamilyName `
            -ExpectedWindowClass $acrylicDescriptor.WindowClass `
            -ExpectedWindowHandle $acrylicDescriptor.WindowHandleValue)
          $acrylicApplied = $probes.Count -eq 1 -and [int]$probes[0].CurrentBackdrop -eq 3
        } catch {
          $acrylicApplied = $false
        }
        if (-not $acrylicApplied) { Start-Sleep -Milliseconds 200 }
      } while (-not $acrylicApplied -and [DateTime]::UtcNow -lt $acrylicDeadline)
      if (-not $acrylicApplied) {
        throw 'Windows did not retain Desktop Acrylic on the verified Codex window.'
      }
      Remove-Item -LiteralPath $acrylicArmFile -Force -ErrorAction SilentlyContinue
      $state.startupPhase = 'verifying'
      Write-DreamSkinState -Path $StatePath -State $state
    }

    # The one-shot verify races Codex's first paint: on a slow machine the
    # shell markers are not rendered yet when the daemon has barely started,
    # and a single early miss used to tear the whole startup down.  The
    # watcher keeps applying in the background, so retry until a deadline.
    $verifyDeadline = (Get-Date).AddSeconds(90)
    while ($true) {
      $verifyArguments = @(
        $Injector, '--verify', '--port', "$Port",
        '--browser-id', $cdpIdentity.BrowserId, '--theme-dir', $themePaths.Active,
        '--timeout-ms', '30000', '--allow-hidden-document'
      ) + $injectorWindowArgs
      $verify = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList $verifyArguments
      Write-DreamSkinUtf8FileAtomically -Path $VerifyPath -Content (($verify.Output -join "`r`n") + "`r`n")
      if ($verify.ExitCode -eq 0) { break }
      if ($daemon.HasExited) { throw "The injector exited during startup. See $StderrPath" }
      if ((Get-Date) -ge $verifyDeadline) { throw "Dream Skin verification failed. See $VerifyPath" }
      Start-Sleep -Seconds 3
    }
    $state.startupPhase = 'active'
    Write-DreamSkinState -Path $StatePath -State $state
  } catch {
    $startupError = $_
    $acrylicStopped = $true
    if ($null -ne $acrylicMonitor) {
      try {
        if (-not $acrylicMonitor.HasExited -and $acrylicStopFile) {
          if (-not (Test-Path -LiteralPath $acrylicStopFile)) {
            Write-DreamSkinUtf8FileAtomically -Path $acrylicStopFile `
              -Content ("stopRequestedAt=" + [DateTime]::UtcNow.ToString('o') + "`r`n")
          }
          [void]$acrylicMonitor.WaitForExit(15000)
        }
        if (-not $acrylicMonitor.HasExited) {
          # Stop the loop before restoring; otherwise it can race the rollback
          # and immediately reapply Acrylic after a successful Mica write.
          Stop-Process -InputObject $acrylicMonitor -Force -ErrorAction Stop
          [void]$acrylicMonitor.WaitForExit(5000)
        }
        if ($null -ne $acrylicDescriptor) {
          [void](& $acrylicHelper -Action Restore `
            -TargetProcessId $acrylicDescriptor.ProcessId `
            -ExpectedStartTimeFileTimeUtc $acrylicDescriptor.StartTimeFileTimeUtc `
            -ExpectedExecutablePath $acrylicDescriptor.ExecutablePath `
            -ExpectedPackageFamilyName $acrylicDescriptor.PackageFamilyName `
            -ExpectedWindowClass $acrylicDescriptor.WindowClass `
            -ExpectedWindowHandle $acrylicDescriptor.WindowHandleValue `
            -ConfirmTargetIdentity)
        }
        $acrylicStopped = $acrylicMonitor.HasExited
      } catch {
        $acrylicStopped = $false
        Write-Warning 'Startup rollback could not fully stop the newly created Desktop Acrylic monitor.'
      } finally {
        if ($acrylicStopFile -and $acrylicStopped) {
          Remove-Item -LiteralPath $acrylicStopFile -Force -ErrorAction SilentlyContinue
        }
      }
    }
    if ($acrylicArmFile -and $acrylicStopped) {
      Remove-Item -LiteralPath $acrylicArmFile -Force -ErrorAction SilentlyContinue
    }
    if ($acrylicStopFile -and $acrylicStopped) {
      Remove-Item -LiteralPath $acrylicStopFile -Force -ErrorAction SilentlyContinue
    }
    # We own the daemon Process object, so stop it directly: the object is
    # immune to PID reuse, and identity re-validation cannot spuriously
    # refuse.  Slow machines also need more than a moment for teardown; a
    # premature "did not stop" here is what used to leave duelling watchers.
    $injectorStopped = $true
    if ($null -ne $daemon) {
      if (-not $daemon.HasExited) {
        try {
          Stop-Process -InputObject $daemon -Force -ErrorAction Stop
        } catch {
          Write-Warning 'The newly created injector could not be signalled during startup rollback.'
        }
      }
      [void]$daemon.WaitForExit(15000)
      $injectorStopped = $daemon.HasExited
      if (-not $injectorStopped) {
        Write-Warning "The rollback injector has not exited yet: PID $($daemon.Id). State was preserved so the next start can reconcile it."
      }
    }
    if ($injectorStopped -and -not $launchedWithCdp) {
      try {
        $rollbackIdentity = Get-DreamSkinVerifiedCdpIdentity -Port $Port -Codex $codex `
          @autoSessionParameters
        if ($null -ne $rollbackIdentity -and $rollbackIdentity.BrowserId -ceq $cdpIdentity.BrowserId) {
          $removal = Invoke-DreamSkinNative -FilePath $node.Path -ArgumentList @(
            $Injector, '--remove', '--port', "$Port",
            '--browser-id', $cdpIdentity.BrowserId, '--timeout-ms', '5000') -DiscardStderr
          if ($removal.ExitCode -ne 0) { throw 'Injector removal returned a failure status.' }
        }
      } catch {
        Write-Warning 'Startup rollback could not remove the partially applied live skin; reload or close Codex to clear it.'
      }
    }
    if ($injectorStopped -and $acrylicStopped) {
      Remove-Item -LiteralPath $StatePath -Force -ErrorAction SilentlyContinue
    }
    if ($launchedWithCdp) {
      if ($AutoRestartStock) {
        Write-Warning 'Automatic handoff startup rollback preserved the exact launched Codex processes.'
      } else {
        try {
          Stop-DreamSkinCodex -Codex $codex -AllowForce
          $null = Start-DreamSkinCodex -Codex $codex
        } catch {
          Write-Warning 'Startup rollback could not fully restart Codex; close Codex to ensure its CDP port is closed.'
        }
      }
    }
    if ($pauseWasSet -and $pauseCleared) {
      try {
        Set-DreamSkinPaused -Paused $true -StateRoot $StateRoot | Out-Null
      } catch {
        Write-Warning 'Startup rollback could not restore the existing paused state.'
      }
    }
    throw $startupError
  }

  Write-Host "Codex Dream Skin is active on verified loopback port $Port."
} finally {
  if ($null -ne $operationLock) { Exit-DreamSkinOperationLock -Mutex $operationLock }
}

# This script launches native verification helpers.  A successful helper can
# still leave PowerShell's process-level LASTEXITCODE stale on some hosts, so
# make the already-verified success result explicit for callers such as the
# managed hot-update wrapper.
exit 0
