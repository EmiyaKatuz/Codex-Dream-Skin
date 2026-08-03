[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Root)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $Root 'scripts\acrylic-window.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
  throw "Acrylic helper is missing: $scriptPath"
}

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile(
  $scriptPath,
  [ref]$tokens,
  [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
  throw "Acrylic helper failed to parse: $($parseErrors[0].Message)"
}

$source = [System.IO.File]::ReadAllText($scriptPath)
foreach ($forbidden in @(
  'Stop-Process',
  'taskkill',
  'Start-Process',
  'ExecutionPolicy Bypass',
  'app.asar',
  'Set-Acl',
  'takeown'
)) {
  if ($source.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
    throw "Acrylic helper contains a forbidden process/package mutation: $forbidden"
  }
}

foreach ($required in @(
  'ExpectedStartTimeFileTimeUtc',
  'ExpectedExecutablePath',
  'ExpectedPackageFamilyName',
  'ExpectedWindowHandle',
  'WindowHandleValue',
  'ConfirmTargetIdentity',
  'CaptureProcessIdentity',
  'GetPackageFamilyName',
  'QueryFullProcessImageName',
  'GetProcessTimes',
  'GetWindowProcessIdOrZero',
  'EnumWindows',
  'IsUnowned',
  'IsToolWindow',
  'Chrome_WidgetWin_1',
  'DwmSetWindowAttribute',
  'DWMWA_SYSTEMBACKDROP_TYPE',
  'SetBackdrop',
  'GetBackdrop',
  "-Material Acrylic",
  "-Material Mica",
  'StopFile',
  'ArmFile',
  'AllowHiddenTarget',
  'AllowHiddenPinnedWindow',
  'TargetMissing',
  'still exists but no longer satisfies',
  'RequireSoleEligibleWindow',
  'MonitorMutex',
  'MutexAcquireTimeoutMilliseconds',
  'Retry transient enumeration/DWM races'
)) {
  if (-not $source.Contains($required)) {
    throw "Acrylic helper safety/behavior contract is missing: $required"
  }
}

$authorizationIndex = $source.LastIndexOf(
  'if (-not $ConfirmTargetIdentity)',
  [StringComparison]::Ordinal
)
$mutationSwitchIndex = $source.LastIndexOf('switch ($Action)', [StringComparison]::Ordinal)
if ($authorizationIndex -lt 0 -or $mutationSwitchIndex -le $authorizationIndex) {
  throw 'Acrylic mutation actions are not guarded by explicit target confirmation.'
}

& $scriptPath -SelfTest
Write-Host 'PASS: Acrylic helper is non-launching, identity-pinned, reversible, and monitorable.'
