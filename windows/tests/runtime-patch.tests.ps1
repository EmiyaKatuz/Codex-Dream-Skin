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
  New-Item -ItemType Directory -Path $scriptsRoot -Force | Out-Null
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
  if ((Get-FileHash -LiteralPath $installedCommon -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceCommon -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedStart -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceStart -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedPatch -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourcePatch -Algorithm SHA256).Hash -or
    [System.IO.File]::ReadAllText($sentinel) -cne 'keep') {
    throw 'Runtime patch did not replace the launcher files and patch script while preserving the sentinel file.'
  }

  & $patchScript -SourceRoot $Root -StateRoot $stateRoot
  if ((Get-FileHash -LiteralPath $installedCommon -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceCommon -Algorithm SHA256).Hash -or
    (Get-FileHash -LiteralPath $installedStart -Algorithm SHA256).Hash -cne
      (Get-FileHash -LiteralPath $sourceStart -Algorithm SHA256).Hash) {
    throw 'Applying the runtime patch twice changed the already patched files.'
  }

  $transactionDirectories = @(Get-ChildItem -LiteralPath $stateRoot -Directory -Force |
    Where-Object { $_.Name -like '.engine-patch*' -or $_.Name -like '.engine-patch-backup*' })
  if ($transactionDirectories.Count -ne 0) {
    throw 'Runtime patch left staging or backup transaction directories behind.'
  }
} finally {
  Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'PASS: runtime patch replaces launcher files in place and preserves state and themes.'
