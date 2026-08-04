[CmdletBinding()]
param(
  [switch]$Enable,
  [switch]$Disable,
  [switch]$Status,
  [switch]$ProtectCurrentSession
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')

$operationCount = @(@($Enable, $Disable, $Status) | Where-Object { [bool]$_ }).Count
if ($operationCount -ne 1) { throw 'Choose exactly one of -Enable, -Disable, or -Status.' }
if ($ProtectCurrentSession -and -not $Enable) {
  throw '-ProtectCurrentSession is valid only with -Enable.'
}

$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$AutoLaunchScript = Join-Path $PSScriptRoot 'auto-launch-dream-skin.ps1'
$AutoLaunchState = Join-Path $StateRoot 'auto-launch-state.json'
$StopMarker = Join-Path $StateRoot 'auto-launch.stop'
$StartupDirectory = [Environment]::GetFolderPath('Startup')
$StartupShortcut = Join-Path $StartupDirectory 'Codex Dream Skin Auto Launch.lnk'
$PowerShellPath = (Get-Command powershell.exe -ErrorAction Stop).Source
$StartupArguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ' +
  (ConvertTo-DreamSkinProcessArgument -Value $AutoLaunchScript)

function Assert-DreamSkinAutoLaunchControlFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Automatic-launch control path is not a plain file: $Path"
  }
}

function Get-DreamSkinManagedAutoLaunchShortcut {
  if (-not (Test-Path -LiteralPath $StartupShortcut -PathType Leaf)) { return $null }
  Assert-DreamSkinAutoLaunchControlFile -Path $StartupShortcut
  $shell = New-Object -ComObject WScript.Shell
  try {
    $shortcut = $shell.CreateShortcut($StartupShortcut)
    return [pscustomobject]@{
      TargetPath = "$($shortcut.TargetPath)"
      Arguments = "$($shortcut.Arguments)"
      WorkingDirectory = "$($shortcut.WorkingDirectory)"
    }
  } finally {
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
  }
}

function Test-DreamSkinManagedAutoLaunchShortcut {
  $shortcut = Get-DreamSkinManagedAutoLaunchShortcut
  if ($null -eq $shortcut) { return $false }
  return (Test-DreamSkinPathEqual -Left $shortcut.TargetPath -Right $PowerShellPath) -and
    $shortcut.Arguments -ceq $StartupArguments -and
    (Test-DreamSkinPathEqual -Left $shortcut.WorkingDirectory -Right (Split-Path -Parent $PSScriptRoot))
}

function Write-DreamSkinManagedAutoLaunchShortcut {
  if (-not (Test-Path -LiteralPath $StartupDirectory -PathType Container)) {
    throw "The current-user Startup directory is unavailable: $StartupDirectory"
  }
  $startupItem = Get-Item -LiteralPath $StartupDirectory -Force -ErrorAction Stop
  if (($startupItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw 'The current-user Startup directory is a reparse point; refusing to redirect login execution.'
  }
  if ((Test-Path -LiteralPath $StartupShortcut) -and
    -not (Test-DreamSkinManagedAutoLaunchShortcut)) {
    throw "An unmanaged shortcut already uses the automatic-launch name: $StartupShortcut"
  }

  $temporaryShortcut = Join-Path $StartupDirectory (
    '.Codex Dream Skin Auto Launch.' + [guid]::NewGuid().ToString('N') + '.lnk'
  )
  $shell = New-Object -ComObject WScript.Shell
  try {
    $shortcut = $shell.CreateShortcut($temporaryShortcut)
    $shortcut.TargetPath = $PowerShellPath
    $shortcut.Arguments = $StartupArguments
    $shortcut.WorkingDirectory = Split-Path -Parent $PSScriptRoot
    $shortcut.Description = 'Automatically restart a newly opened official Codex session with Dream Skin'
    $icon = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\internet-angel-tray.ico'
    if (Test-Path -LiteralPath $icon -PathType Leaf) { $shortcut.IconLocation = "$icon,0" }
    $shortcut.Save()
  } finally {
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
  }
  try {
    Assert-DreamSkinAutoLaunchControlFile -Path $temporaryShortcut
    $probeShell = New-Object -ComObject WScript.Shell
    try {
      $probe = $probeShell.CreateShortcut($temporaryShortcut)
      if (-not (Test-DreamSkinPathEqual -Left "$($probe.TargetPath)" -Right $PowerShellPath) -or
        "$($probe.Arguments)" -cne $StartupArguments) {
        throw 'The staged automatic-launch shortcut failed target verification.'
      }
    } finally {
      [void][Runtime.InteropServices.Marshal]::ReleaseComObject($probeShell)
    }
    Move-Item -LiteralPath $temporaryShortcut -Destination $StartupShortcut -Force -ErrorAction Stop
  } finally {
    Remove-Item -LiteralPath $temporaryShortcut -Force -ErrorAction SilentlyContinue
  }
}

function Get-DreamSkinAutoLaunchStatus {
  $shortcutExists = Test-Path -LiteralPath $StartupShortcut -PathType Leaf
  $shortcutManaged = $false
  $shortcutError = $null
  if ($shortcutExists) {
    try { $shortcutManaged = Test-DreamSkinManagedAutoLaunchShortcut } catch {
      $shortcutError = $_.Exception.Message
    }
  }

  $stateValid = $false
  $running = $false
  $phase = $null
  $pidValue = $null
  $protected = $false
  $stateError = $null
  if (Test-Path -LiteralPath $AutoLaunchState -PathType Leaf) {
    try {
      Assert-DreamSkinAutoLaunchControlFile -Path $AutoLaunchState
      $stateItem = Get-Item -LiteralPath $AutoLaunchState -Force -ErrorAction Stop
      if ($stateItem.Length -le 0 -or $stateItem.Length -gt 65536) {
        throw 'Automatic-launch state size is invalid.'
      }
      $state = (Read-DreamSkinUtf8File -Path $AutoLaunchState) | ConvertFrom-Json -ErrorAction Stop
      foreach ($field in @('schemaVersion', 'platform', 'pid', 'startedAt', 'scriptPath', 'phase')) {
        if ($state.PSObject.Properties.Name -notcontains $field -or -not "$($state.$field)") {
          throw "Automatic-launch state is missing: $field"
        }
      }
      if ([int]$state.schemaVersion -ne 1 -or "$($state.platform)" -cne 'windows' -or
        -not (Test-DreamSkinPathEqual -Left "$($state.scriptPath)" -Right $AutoLaunchScript)) {
        throw 'Automatic-launch state identity is invalid.'
      }
      $monitorPid = 0
      if (-not [int]::TryParse("$($state.pid)", [ref]$monitorPid) -or $monitorPid -le 0) {
        throw 'Automatic-launch state PID is invalid.'
      }
      $stateValid = $true
      $pidValue = $monitorPid
      $phase = "$($state.phase)"
      $protected = [bool]$state.protectionArmed
      $process = Get-Process -Id $monitorPid -ErrorAction SilentlyContinue
      if ($null -ne $process -and
        $process.StartTime.ToUniversalTime().ToString('o') -ceq "$($state.startedAt)") {
        $processInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $monitorPid" -ErrorAction Stop
        $processPath = Get-DreamSkinProcessExecutablePath -ProcessInfo $processInfo
        $running = (Test-DreamSkinPathEqual -Left $processPath -Right $PowerShellPath) -and
          (Test-DreamSkinCommandLineToken -CommandLine "$($processInfo.CommandLine)" -Token $AutoLaunchScript)
      }
    } catch {
      $stateError = $_.Exception.Message
    }
  }

  return [pscustomobject]@{
    Enabled = [bool]$shortcutManaged
    ShortcutExists = [bool]$shortcutExists
    ShortcutManaged = [bool]$shortcutManaged
    ShortcutPath = $StartupShortcut
    Running = [bool]$running
    Pid = $pidValue
    Phase = $phase
    ProtectingCurrentSession = [bool]$protected
    StopRequested = Test-Path -LiteralPath $StopMarker -PathType Leaf
    StateValid = [bool]$stateValid
    ShortcutError = $shortcutError
    StateError = $stateError
  }
}

Ensure-DreamSkinManagedDirectory -Path $StateRoot -Root $StateRoot
if (-not (Test-Path -LiteralPath $AutoLaunchScript -PathType Leaf)) {
  throw "The automatic Dream Skin watcher is missing: $AutoLaunchScript"
}
$autoScriptItem = Get-Item -LiteralPath $AutoLaunchScript -Force -ErrorAction Stop
if (($autoScriptItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
  throw 'The automatic Dream Skin watcher is a reparse point.'
}
Assert-DreamSkinAutoLaunchControlFile -Path $StopMarker
Assert-DreamSkinAutoLaunchControlFile -Path $AutoLaunchState

if ($Status) {
  Get-DreamSkinAutoLaunchStatus | ConvertTo-Json -Depth 4
  return
}

if ($Disable) {
  Write-DreamSkinUtf8FileAtomically -Path $StopMarker `
    -Content ("disabledAt=" + [DateTime]::UtcNow.ToString('o') + "`r`n")
  if (Test-Path -LiteralPath $StartupShortcut -PathType Leaf) {
    if (-not (Test-DreamSkinManagedAutoLaunchShortcut)) {
      throw "Automatic launch was stopped, but its Startup shortcut is no longer managed: $StartupShortcut"
    }
    Remove-Item -LiteralPath $StartupShortcut -Force -ErrorAction Stop
  }
  $deadline = [DateTime]::UtcNow.AddSeconds(10)
  do {
    $current = Get-DreamSkinAutoLaunchStatus
    if (-not $current.Running) { break }
    Start-Sleep -Milliseconds 250
  } while ([DateTime]::UtcNow -lt $deadline)
  $current = Get-DreamSkinAutoLaunchStatus
  if ($current.Running) {
    throw 'Automatic Dream Skin launch was disabled, but its exact watcher did not stop within ten seconds.'
  }
  $current | ConvertTo-Json -Depth 4
  return
}

$shortcutWasManaged = Test-DreamSkinManagedAutoLaunchShortcut
$stopMarkerWasPresent = Test-Path -LiteralPath $StopMarker -PathType Leaf
$watcherLaunchAttempted = $false
try {
  Remove-Item -LiteralPath $StopMarker -Force -ErrorAction SilentlyContinue
  Write-DreamSkinManagedAutoLaunchShortcut
  $current = Get-DreamSkinAutoLaunchStatus
  if ($current.Running -and $ProtectCurrentSession -and
    -not $current.ProtectingCurrentSession) {
    throw '-ProtectCurrentSession cannot arm an already-running watcher. Disable it, then enable it again with protection.'
  }
  if (-not $current.Running) {
    $arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File ' +
      (ConvertTo-DreamSkinProcessArgument -Value $AutoLaunchScript)
    if ($ProtectCurrentSession) { $arguments += ' -ProtectCurrentSession' }
    $watcherLaunchAttempted = $true
    Start-Process -FilePath $PowerShellPath -ArgumentList $arguments -WindowStyle Hidden | Out-Null

    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
      $current = Get-DreamSkinAutoLaunchStatus
      if ($current.Running) { break }
      Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
  }
  if (-not $current.Running) {
    throw 'Automatic Dream Skin launch was enabled, but its monitor did not become active.'
  }
  $current | ConvertTo-Json -Depth 4
} catch {
  $enableError = $_
  $rollbackError = $null
  try {
    if ($watcherLaunchAttempted -or $stopMarkerWasPresent) {
      Write-DreamSkinUtf8FileAtomically -Path $StopMarker `
        -Content ("rollbackAt=" + [DateTime]::UtcNow.ToString('o') + "`r`n")
    }
    if (-not $shortcutWasManaged -and
      (Test-Path -LiteralPath $StartupShortcut -PathType Leaf) -and
      (Test-DreamSkinManagedAutoLaunchShortcut)) {
      Remove-Item -LiteralPath $StartupShortcut -Force -ErrorAction Stop
    }
    if ($watcherLaunchAttempted) {
      $rollbackDeadline = [DateTime]::UtcNow.AddSeconds(10)
      do {
        $rollbackStatus = Get-DreamSkinAutoLaunchStatus
        if (-not $rollbackStatus.Running) { break }
        Start-Sleep -Milliseconds 250
      } while ([DateTime]::UtcNow -lt $rollbackDeadline)
      if ($rollbackStatus.Running) {
        throw 'The failed enable transaction could not stop its exact watcher.'
      }
    }
  } catch {
    $rollbackError = $_.Exception.Message
  }
  if ($rollbackError) {
    throw "Automatic Dream Skin launch enable failed: $($enableError.Exception.Message) Rollback also failed: $rollbackError"
  }
  throw $enableError
}
