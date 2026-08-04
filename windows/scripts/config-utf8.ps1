$script:DreamSkinUtf8NoBom = [System.Text.UTF8Encoding]::new($false, $true)
$script:DreamSkinLegacyAppearanceTheme = 'appearanceTheme = "light"'
$script:DreamSkinManagedLightCodeTheme = 'appearanceLightCodeThemeId = "codex"'
$script:DreamSkinManagedLightChromeTheme = 'appearanceLightChromeTheme = { accent = "#B65CFF", contrast = 64, fonts = { code = "Cascadia Code", ui = "Microsoft YaHei UI" }, ink = "#4A235F", opaqueWindows = true, semanticColors = { diffAdded = "#BCE8CF", diffRemoved = "#F7B8CE", skill = "#C47BFF" }, surface = "#FFF4FA" }'

function ConvertFrom-DreamSkinUtf8Bytes {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes,
    [Parameter(Mandatory = $true)][string]$Path
  )

  try {
    $offset = if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { 3 } else { 0 }
    $content = $script:DreamSkinUtf8NoBom.GetString($Bytes, $offset, $Bytes.Length - $offset)
    if ($content.IndexOf([char]0) -ge 0) {
      throw "Refusing to rewrite a config file containing NUL characters (possibly BOM-less UTF-16): $Path"
    }
    return $content
  } catch [System.Text.DecoderFallbackException] {
    throw "Refusing to rewrite a config file that is not valid UTF-8: $Path"
  }
}

function Test-DreamSkinBytesEqual {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Left,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Right
  )
  if ($Left.Length -ne $Right.Length) { return $false }
  for ($index = 0; $index -lt $Left.Length; $index++) {
    if ($Left[$index] -ne $Right[$index]) { return $false }
  }
  return $true
}

function Assert-DreamSkinFileUnchanged {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [AllowNull()][byte[]]$ExpectedBytes
  )
  if ($null -eq $ExpectedBytes) {
    if (Test-Path -LiteralPath $Path) { throw "File changed during the operation; retry without other writers: $Path" }
    return
  }
  if (-not (Test-Path -LiteralPath $Path)) { throw "File disappeared during the operation; retry: $Path" }
  $currentBytes = [System.IO.File]::ReadAllBytes($Path)
  if (-not (Test-DreamSkinBytesEqual -Left $ExpectedBytes -Right $currentBytes)) {
    throw "File changed during the operation; retry without other writers: $Path"
  }
}

function Get-DreamSkinNewLine {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)
  if ($Content.Contains("`r`n")) { return "`r`n" }
  return "`n"
}

function Read-DreamSkinUtf8File {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  return (ConvertFrom-DreamSkinUtf8Bytes -Bytes $bytes -Path $Path)
}

function Write-DreamSkinUtf8FileAtomically {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Content,

    [AllowNull()]
    [byte[]]$ExpectedBytes
  )

  $bytes = $script:DreamSkinUtf8NoBom.GetBytes($Content)
  if ($PSBoundParameters.ContainsKey('ExpectedBytes')) {
    Write-DreamSkinBytesAtomically -Path $Path -Bytes $bytes -ExpectedBytes $ExpectedBytes
  } else {
    Write-DreamSkinBytesAtomically -Path $Path -Bytes $bytes
  }
}

function Remove-DreamSkinAtomicArtifact {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  for ($attempt = 1; $attempt -le 3; $attempt++) {
    if (-not [System.IO.File]::Exists($Path)) { return }
    try {
      [System.IO.File]::Delete($Path)
      return
    } catch {
      if ($attempt -eq 3) { throw }
      Start-Sleep -Milliseconds (20 * $attempt)
    }
  }
}

function Write-DreamSkinBytesAtomically {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes,
    [AllowNull()][byte[]]$ExpectedBytes
  )

  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $directory = [System.IO.Path]::GetDirectoryName($fullPath)
  if (-not [System.IO.Directory]::Exists($directory)) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
  }
  $fileName = [System.IO.Path]::GetFileName($fullPath)
  $operationId = "$PID.$([guid]::NewGuid().ToString('N'))"
  $temporary = Join-Path $directory ".$fileName.$operationId.tmp"
  $replacementBackup = Join-Path $directory ".$fileName.$operationId.replace-backup"

  try {
    [System.IO.File]::WriteAllBytes($temporary, $Bytes)
    if ($PSBoundParameters.ContainsKey('ExpectedBytes')) {
      Assert-DreamSkinFileUnchanged -Path $fullPath -ExpectedBytes $ExpectedBytes
    }
    if ([System.IO.File]::Exists($fullPath)) {
      [System.IO.File]::Replace($temporary, $fullPath, $replacementBackup)
    } else {
      [System.IO.File]::Move($temporary, $fullPath)
    }
  } finally {
    foreach ($artifact in @($temporary, $replacementBackup)) {
      try {
        Remove-DreamSkinAtomicArtifact -Path $artifact
      } catch {
        try {
          Write-Warning "Could not remove temporary atomic config artifact '$artifact': $($_.Exception.Message)"
        } catch {
          # Cleanup must never mask the result of the atomic write.
        }
      }
    }
  }
}

function Get-DreamSkinTomlKeyTokenPattern {
  param([Parameter(Mandatory = $true)][string]$Key)
  $bare = [regex]::Escape($Key)
  $doubleQuoted = [regex]::Escape('"' + $Key + '"')
  $singleQuoted = [regex]::Escape("'" + $Key + "'")
  return "(?:$bare|$doubleQuoted|$singleQuoted)"
}

function ConvertTo-DreamSkinTomlAsciiEscapeProbe {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

  $result = $Value
  $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'.ToCharArray()
  foreach ($character in $characters) {
    $code = ([int][char]$character).ToString('x2')
    $pattern = '(?i)\\(?:u00' + $code + '|U000000' + $code + ')'
    $result = [regex]::Replace($result, $pattern, [string]$character)
  }
  return $result
}

function Get-DreamSkinTomlArrayBracketBalance {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

  $quote = $null
  $escaped = $false
  $balance = 0
  for ($index = 0; $index -lt $Line.Length; $index++) {
    $character = $Line[$index]
    if ($null -eq $quote) {
      if ($character -eq '#') { break }
      if ($character -eq '"' -or $character -eq "'") { $quote = $character }
      elseif ($character -eq '[') { $balance++ }
      elseif ($character -eq ']') { $balance-- }
      continue
    }
    if ($quote -eq '"') {
      if ($escaped) { $escaped = $false; continue }
      if ($character -eq '\') { $escaped = $true; continue }
    }
    if ($character -eq $quote) { $quote = $null }
  }
  return $balance
}

function Get-DreamSkinTomlLineStructure {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

  $builder = [System.Text.StringBuilder]::new()
  $quote = $null
  $escaped = $false
  for ($index = 0; $index -lt $Line.Length; $index++) {
    $character = $Line[$index]
    if ($quote -ceq '"') {
      if ($escaped) {
        $escaped = $false
      } elseif ($character -eq '\') {
        $escaped = $true
      } elseif ($character -eq $quote) {
        $quote = $null
      }
      continue
    }
    if ($quote -ceq "'") {
      if ($character -eq $quote) { $quote = $null }
      continue
    }
    if ($character -eq '"' -or $character -eq "'") {
      $quote = $character
    } elseif ($character -eq '#') {
      break
    } else {
      [void]$builder.Append($character)
    }
  }
  return $builder.ToString()
}

function Test-DreamSkinTomlTableHeaderStructure {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Structure)

  $value = $Structure.Trim()
  if ($value.StartsWith('[[')) {
    return (
      $value.EndsWith(']]') -and
      -not $value.Substring(2, $value.Length - 4).Contains('[') -and
      -not $value.Substring(2, $value.Length - 4).Contains(']')
    )
  }
  return (
    $value.StartsWith('[') -and
    -not $value.StartsWith('[[') -and
    $value.EndsWith(']') -and
    -not $value.Substring(1, $value.Length - 2).Contains('[') -and
    -not $value.Substring(1, $value.Length - 2).Contains(']')
  )
}

function Get-DreamSkinTomlTableHeaders {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)

  $headers = @()
  $offset = 0
  $arrayDepth = 0
  $desktopToken = Get-DreamSkinTomlKeyTokenPattern -Key 'desktop'
  $desktopPattern = "^[\t ]*\[[\t ]*$desktopToken[\t ]*\][\t ]*(?:#[^\r\n]*)?(?:\r?\n)?$"
  foreach ($lineMatch in [regex]::Matches($Content, '[^\n]*\n|[^\n]+$')) {
    $line = $lineMatch.Value
    $structure = Get-DreamSkinTomlLineStructure -Line $line
    $trimmed = $structure.Trim()
    if ($arrayDepth -eq 0 -and (Test-DreamSkinTomlTableHeaderStructure -Structure $trimmed)) {
      $headers += [pscustomobject]@{
        Index = $offset
        BodyStart = $offset + $line.Length
        Desktop = [regex]::IsMatch($line, $desktopPattern)
      }
    } else {
      $assignment = $structure.IndexOf('=')
      if ($arrayDepth -eq 0 -and $assignment -lt 0) {
        if ($structure.Contains('[') -or $structure.Contains(']')) {
          throw 'Refusing to rewrite malformed TOML array syntax.'
        }
      } else {
        $expression = if ($arrayDepth -gt 0) {
          $structure
        } else {
          $structure.Substring($assignment + 1)
        }
        $arrayDepth += Get-DreamSkinTomlArrayBracketBalance -Line $expression
        if ($arrayDepth -lt 0) {
          throw 'Refusing to rewrite TOML containing an unmatched array bracket.'
        }
      }
    }
    $offset += $line.Length
  }
  if ($arrayDepth -ne 0) {
    throw 'Refusing to rewrite TOML containing an unterminated array.'
  }
  return $headers
}

function Assert-DreamSkinTomlLineEditingSafe {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)

  if ($Content.Contains('"""') -or $Content.Contains("'''")) {
    throw 'Refusing to rewrite TOML containing multiline strings; use single-line values before installing Dream Skin.'
  }
  $null = @(Get-DreamSkinTomlTableHeaders -Content $Content)

  $probe = ConvertTo-DreamSkinTomlAsciiEscapeProbe -Value $Content
  if ($probe -cne $Content) {
    $desktopToken = Get-DreamSkinTomlKeyTokenPattern -Key 'desktop'
    $desktopShape = "(?m)^[\t ]*(?:\[\[?[\t ]*$desktopToken[\t ]*(?:\]|\.)|$desktopToken[\t ]*(?:\.|=))"
    $rawDesktopShapes = [regex]::Matches($Content, $desktopShape).Count
    $probedDesktopShapes = [regex]::Matches($probe, $desktopShape).Count
    if ($probedDesktopShapes -gt $rawDesktopShapes) {
      throw 'Refusing to rewrite an escaped TOML key equivalent to desktop; normalize the key spelling first.'
    }
  }
}

function Test-DreamSkinDesktopNestedTable {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory = $true)][string]$Key
  )

  $desktopToken = Get-DreamSkinTomlKeyTokenPattern -Key 'desktop'
  $keyToken = Get-DreamSkinTomlKeyTokenPattern -Key $Key
  return [regex]::IsMatch(
    $Content,
    "(?m)^[\t ]*\[[\t ]*$desktopToken[\t ]*\.[\t ]*$keyToken[\t ]*(?:\]|\.)"
  )
}

function Assert-DreamSkinDesktopShapeSupported {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)

  Assert-DreamSkinTomlLineEditingSafe -Content $Content
  $headers = @(Get-DreamSkinTomlTableHeaders -Content $Content)
  if (@($headers | Where-Object { $_.Desktop }).Count -gt 1) {
    throw 'Refusing to rewrite multiple equivalent [desktop] tables.'
  }

  $desktopToken = Get-DreamSkinTomlKeyTokenPattern -Key 'desktop'
  if ([regex]::IsMatch($Content, "(?m)^[\t ]*\[\[[\t ]*$desktopToken[\t ]*(?:\]\]|\.)")) {
    throw 'Refusing to rewrite a config that represents desktop as an array of tables.'
  }
  foreach ($key in @('appearanceTheme', 'appearanceLightCodeThemeId')) {
    if (Test-DreamSkinDesktopNestedTable -Content $Content -Key $key) {
      throw "Refusing to replace '$key' because it is represented as a nested desktop table."
    }
  }

  $rootContent = if ($headers.Count -gt 0) { $Content.Substring(0, $headers[0].Index) } else { $Content }
  if ([regex]::IsMatch($rootContent, "(?m)^[\t ]*$desktopToken[\t ]*(?:\.|=)")) {
    throw 'Refusing to rewrite root dotted or inline desktop keys; normalize them to a [desktop] table first.'
  }

  $desktop = Get-DreamSkinDesktopSection -Content $Content
  if ($null -ne $desktop) {
    $bodyProbe = ConvertTo-DreamSkinTomlAsciiEscapeProbe -Value $desktop.Body
    foreach ($key in @('appearanceTheme', 'appearanceLightCodeThemeId', 'appearanceLightChromeTheme')) {
      $keyToken = Get-DreamSkinTomlKeyTokenPattern -Key $key
      $settingShape = "(?m)^[\t ]*$keyToken[\t ]*(?:\.|=)"
      if ($key -eq 'appearanceLightChromeTheme' -and
        (Test-DreamSkinDesktopNestedTable -Content $Content -Key $key) -and
        [regex]::IsMatch($desktop.Body, $settingShape)) {
        throw "Refusing to rewrite '$key' because both a scalar and nested table are present."
      }
      if ([regex]::Matches($bodyProbe, $settingShape).Count -gt
        [regex]::Matches($desktop.Body, $settingShape).Count) {
        throw "Refusing to rewrite an escaped TOML key equivalent to '$key'."
      }
      if ([regex]::IsMatch($desktop.Body, "(?m)^[\t ]*$keyToken[\t ]*\.")) {
        throw "Refusing to replace dotted '$key' keys in the [desktop] table."
      }
    }
  }
}

function Get-DreamSkinDesktopSection {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)

  $headers = @(Get-DreamSkinTomlTableHeaders -Content $Content)
  $desktopHeaders = @($headers | Where-Object { $_.Desktop })
  if ($desktopHeaders.Count -gt 1) {
    throw 'Refusing to rewrite multiple equivalent [desktop] tables.'
  }
  if ($desktopHeaders.Count -eq 0) { return $null }
  $header = $desktopHeaders[0]
  $headerIndex = -1
  for ($index = 0; $index -lt $headers.Count; $index++) {
    if ($headers[$index].Index -eq $header.Index) {
      $headerIndex = $index
      break
    }
  }
  if ($headerIndex -lt 0) { throw 'Could not resolve the [desktop] table boundary.' }
  $bodyEnd = if ($headerIndex + 1 -lt $headers.Count) {
    $headers[$headerIndex + 1].Index
  } else {
    $Content.Length
  }
  return [pscustomobject]@{
    Body = $Content.Substring($header.BodyStart, $bodyEnd - $header.BodyStart)
    BodyStart = $header.BodyStart
    BodyLength = $bodyEnd - $header.BodyStart
    SectionStart = $header.Index
    SectionLength = $bodyEnd - $header.Index
  }
}

function Add-DreamSkinDesktopSection {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
    [Parameter(Mandatory = $true)][string]$NewLine
  )

  if ($Content.Length -eq 0) { return "[desktop]$NewLine" }
  $separator = if ($Content.EndsWith("`n")) { $NewLine } else { $NewLine + $NewLine }
  return $Content + $separator + "[desktop]$NewLine"
}

function Set-DreamSkinSectionSetting {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
    [Parameter(Mandatory = $true)][string]$Key,
    [AllowNull()][object]$Line,
    [Parameter(Mandatory = $true)][string]$NewLine
  )

  $keyToken = Get-DreamSkinTomlKeyTokenPattern -Key $Key
  $pattern = "(?m)^[\t ]*$keyToken[\t ]*=[^\r\n]*(?:\r?\n|(?=\z))"
  $matcher = [regex]::new($pattern)
  if ($matcher.Matches($Body).Count -gt 1) {
    throw "Refusing to rewrite duplicate '$Key' entries in the [desktop] section."
  }
  $existing = $matcher.Match($Body)
  if ($existing.Success -and
    (Get-DreamSkinTomlArrayBracketBalance -Line $existing.Value) -ne 0) {
    throw "Refusing to rewrite multiline '$Key' settings in the [desktop] section."
  }
  if ($null -eq $Line) { return $matcher.Replace($Body, '', 1) }
  $normalizedLine = $Line.TrimEnd("`r", "`n") + $NewLine
  if ($matcher.IsMatch($Body)) {
    $literalReplacement = $normalizedLine.Replace('$', '$$')
    return $matcher.Replace($Body, $literalReplacement, 1)
  }
  $separator = if ($Body.Length -eq 0 -or $Body.EndsWith("`n")) { '' } else { $NewLine }
  return $Body + $separator + $normalizedLine
}

function Get-DreamSkinSectionSettingLine {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body,
    [Parameter(Mandatory = $true)][string]$Key
  )
  $keyToken = Get-DreamSkinTomlKeyTokenPattern -Key $Key
  $matches = [regex]::Matches($Body, "(?m)^[\t ]*$keyToken[\t ]*=.*$")
  if ($matches.Count -gt 1) { throw "Refusing to inspect duplicate '$Key' entries in the [desktop] section." }
  if ($matches.Count -eq 0) { return $null }
  if ((Get-DreamSkinTomlArrayBracketBalance -Line $matches[0].Value) -ne 0) {
    throw "Refusing to inspect multiline '$Key' settings in the [desktop] section."
  }
  return $matches[0].Value.Trim()
}

function Test-DreamSkinLegacyManagedLightTrio {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content)
  $desktop = Get-DreamSkinDesktopSection -Content $Content
  if ($null -eq $desktop) { return $false }
  return (
    (Get-DreamSkinSectionSettingLine -Body $desktop.Body -Key 'appearanceTheme') -ceq
      $script:DreamSkinLegacyAppearanceTheme -and
    (Get-DreamSkinSectionSettingLine -Body $desktop.Body -Key 'appearanceLightCodeThemeId') -ceq
      $script:DreamSkinManagedLightCodeTheme -and
    (Get-DreamSkinSectionSettingLine -Body $desktop.Body -Key 'appearanceLightChromeTheme') -ceq
      $script:DreamSkinManagedLightChromeTheme
  )
}

function Get-DreamSkinAppearanceMarkerPath {
  param([Parameter(Mandatory = $true)][string]$BackupPath)
  return "$BackupPath.appearance.json"
}

function Read-DreamSkinAppearanceMarker {
  param([Parameter(Mandatory = $true)][string]$BackupPath)
  $markerPath = Get-DreamSkinAppearanceMarkerPath -BackupPath $BackupPath
  if (-not (Test-Path -LiteralPath $markerPath)) { return $null }
  try {
    $marker = (Read-DreamSkinUtf8File -Path $markerPath) | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Dream Skin appearance marker is unreadable; config was preserved: $markerPath"
  }
  if ($null -eq $marker -or $marker -is [string] -or $marker -is [array]) {
    throw "Dream Skin appearance marker is invalid; config was preserved: $markerPath"
  }
  $schemaVersion = 0
  try { $schemaVersion = [int]$marker.schemaVersion } catch { $schemaVersion = 0 }
  # v1 markers are always unmanaged; v2 markers may pin appearanceTheme.
  $validUnmanagedV1 = $schemaVersion -eq 1 -and $marker.appearanceThemeManaged -is [bool] -and
    -not [bool]$marker.appearanceThemeManaged
  $validV2 = $schemaVersion -eq 2 -and $marker.appearanceThemeManaged -is [bool]
  if (-not ($validUnmanagedV1 -or $validV2)) {
    throw "Dream Skin appearance marker is invalid; config was preserved: $markerPath"
  }
  return $marker
}

function Write-DreamSkinAppearanceMarker {
  param(
    [Parameter(Mandatory = $true)][string]$BackupPath,
    [bool]$Managed = $false
  )
  $markerPath = Get-DreamSkinAppearanceMarkerPath -BackupPath $BackupPath
  if (Get-Command Assert-DreamSkinNoReparseComponents -ErrorAction SilentlyContinue) {
    Assert-DreamSkinNoReparseComponents -Path $markerPath
  }
  # Unmanaged markers keep the v1 shape older engines accept; managed pins use
  # schemaVersion 2, which older engines conservatively refuse to act on.
  $schemaVersion = 1
  if ($Managed) { $schemaVersion = 2 }
  $marker = [ordered]@{
    schemaVersion = $schemaVersion
    appearanceThemeManaged = $Managed
  } | ConvertTo-Json
  Write-DreamSkinUtf8FileAtomically -Path $markerPath -Content ($marker + "`r`n")
}

function Remove-DreamSkinTomlQuotedTextAndComment {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)
  $builder = [System.Text.StringBuilder]::new($Line.Length)
  $quote = [char]0
  $escaped = $false
  foreach ($character in $Line.ToCharArray()) {
    if ($quote -ne [char]0) {
      [void]$builder.Append(' ')
      if ($quote -eq '"' -and $escaped) {
        $escaped = $false
      } elseif ($quote -eq '"' -and $character -eq '\') {
        $escaped = $true
      } elseif ($character -eq $quote) {
        $quote = [char]0
      }
      continue
    }
    if ($character -eq '#') { break }
    if ($character -eq '"' -or $character -eq "'") {
      $quote = $character
      [void]$builder.Append(' ')
      continue
    }
    [void]$builder.Append($character)
  }
  return $builder.ToString()
}

function Get-DreamSkinTomlInlineTableBooleanValues {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line,
    [Parameter(Mandatory = $true)][string]$Key
  )
  $structuralLine = Remove-DreamSkinTomlQuotedTextAndComment -Line $Line
  $equalsIndex = $structuralLine.IndexOf('=')
  if ($equalsIndex -lt 0) { return }
  $value = $structuralLine.Substring($equalsIndex + 1).Trim()
  if ($value.Length -lt 2 -or $value[0] -ne '{' -or $value[$value.Length - 1] -ne '}') {
    return
  }

  $body = $value.Substring(1, $value.Length - 2)
  $segments = [System.Collections.Generic.List[string]]::new()
  $builder = [System.Text.StringBuilder]::new()
  $braceDepth = 0
  $bracketDepth = 0
  foreach ($character in $body.ToCharArray()) {
    if ($character -eq '{') { $braceDepth++ }
    elseif ($character -eq '}') {
      $braceDepth--
      if ($braceDepth -lt 0) { return }
    } elseif ($character -eq '[') { $bracketDepth++ }
    elseif ($character -eq ']') {
      $bracketDepth--
      if ($bracketDepth -lt 0) { return }
    }
    if ($character -eq ',' -and $braceDepth -eq 0 -and $bracketDepth -eq 0) {
      $segments.Add($builder.ToString())
      [void]$builder.Clear()
      continue
    }
    [void]$builder.Append($character)
  }
  if ($braceDepth -ne 0 -or $bracketDepth -ne 0) { return }
  $segments.Add($builder.ToString())

  $pattern = '^\s*' + [regex]::Escape($Key) + '\s*=\s*(true|false)\s*$'
  foreach ($segment in $segments) {
    $match = [regex]::Match($segment, $pattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    if ($match.Success) { $match.Groups[1].Value }
  }
}

function Test-DreamSkinAcrylicTransparencyConfig {
  param([Parameter(Mandatory = $true)][string]$ConfigPath)
  if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $false }
  try {
    $content = ConvertFrom-DreamSkinUtf8Bytes `
      -Bytes ([System.IO.File]::ReadAllBytes($ConfigPath)) -Path $ConfigPath
    Assert-DreamSkinDesktopShapeSupported -Content $content
    $desktop = Get-DreamSkinDesktopSection -Content $content
    if ($null -eq $desktop) { return $false }

    $inline = Get-DreamSkinSectionSettingLine `
      -Body $desktop.Body -Key 'appearanceLightChromeTheme'
    if ($inline) {
      $opaqueValues = @(Get-DreamSkinTomlInlineTableBooleanValues `
        -Line $inline -Key 'opaqueWindows')
      return $opaqueValues.Count -eq 1 -and $opaqueValues[0] -ceq 'false'
    }

    $nested = [regex]::Match(
      $content,
      '(?ms)^[ \t]*\[desktop\.appearanceLightChromeTheme\][ \t]*(?:#.*)?\r?\n(?<body>.*?)(?=^[ \t]*\[|\z)'
    )
    if (-not $nested.Success) { return $false }
    return [regex]::IsMatch(
      $nested.Groups['body'].Value,
      '(?im)^[ \t]*opaqueWindows[ \t]*=[ \t]*false(?:[ \t]*(?:#.*)?)?\r?$'
    )
  } catch {
    return $false
  }
}

function Test-DreamSkinAcrylicTransparencyConfigManageable {
  param([Parameter(Mandatory = $true)][string]$ConfigPath)
  if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $false }
  try {
    $content = ConvertFrom-DreamSkinUtf8Bytes `
      -Bytes ([System.IO.File]::ReadAllBytes($ConfigPath)) -Path $ConfigPath
    Assert-DreamSkinDesktopShapeSupported -Content $content
    if (Test-DreamSkinAcrylicTransparencyConfig -ConfigPath $ConfigPath) { return $true }
    # The managed base-theme transaction can safely create or replace the
    # scalar/inline chrome theme. A nested table is deliberately preserved, so
    # an opaque nested theme must be rejected before Codex is ever closed.
    return -not (Test-DreamSkinDesktopNestedTable `
      -Content $content -Key 'appearanceLightChromeTheme')
  } catch {
    return $false
  }
}

function Install-DreamSkinBaseTheme {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$BackupPath,

    [ValidateSet('auto', 'light', 'dark')]
    [string]$AppearanceTheme = 'auto',

    [switch]$TransparentWindows
  )

  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Codex config not found: $ConfigPath" }
  if (Get-Command Assert-DreamSkinNoReparseComponents -ErrorAction SilentlyContinue) {
    Assert-DreamSkinNoReparseComponents -Path $BackupPath
    Assert-DreamSkinNoReparseComponents -Path (Get-DreamSkinAppearanceMarkerPath -BackupPath $BackupPath)
  }
  $originalBytes = [System.IO.File]::ReadAllBytes($ConfigPath)
  $content = ConvertFrom-DreamSkinUtf8Bytes -Bytes $originalBytes -Path $ConfigPath
  $appearanceMarker = Read-DreamSkinAppearanceMarker -BackupPath $BackupPath
  $appearanceMarkerPath = Get-DreamSkinAppearanceMarkerPath -BackupPath $BackupPath
  $appearanceMarkerExisted = Test-Path -LiteralPath $appearanceMarkerPath -PathType Leaf
  $backupCreated = $false
  if (-not (Test-Path -LiteralPath $BackupPath)) {
    Write-DreamSkinBytesAtomically -Path $BackupPath -Bytes $originalBytes -ExpectedBytes $null
    $backupCreated = $true
  }

  $writeCompleted = $false
  try {
    Assert-DreamSkinDesktopShapeSupported -Content $content
    $newLine = Get-DreamSkinNewLine -Content $content
    $desktop = Get-DreamSkinDesktopSection -Content $content
    if ($null -eq $desktop) {
      $content = Add-DreamSkinDesktopSection -Content $content -NewLine $newLine
      $desktop = Get-DreamSkinDesktopSection -Content $content
    }

    $body = $desktop.Body
    $backupContent = $null
    $pinnedAppearance = $AppearanceTheme -ne 'auto'
    $managedByMarker = $null -ne $appearanceMarker -and [bool]$appearanceMarker.appearanceThemeManaged
    $legacyMigration = $null -eq $appearanceMarker -and (Test-Path -LiteralPath $BackupPath) -and
      (Test-DreamSkinLegacyManagedLightTrio -Content $content)
    # Put the pre-install appearanceTheme back whenever we stop managing it:
    # either migrating away from the legacy forced-light trio, or un-pinning
    # after a fixed-appearance theme is replaced by an auto one.
    if (-not $pinnedAppearance -and ($legacyMigration -or $managedByMarker)) {
      $backupContent = ConvertFrom-DreamSkinUtf8Bytes -Bytes ([System.IO.File]::ReadAllBytes($BackupPath)) -Path $BackupPath
      Assert-DreamSkinDesktopShapeSupported -Content $backupContent
      $backupDesktop = Get-DreamSkinDesktopSection -Content $backupContent
      $savedAppearance = if ($null -ne $backupDesktop) {
        Get-DreamSkinSectionSettingLine -Body $backupDesktop.Body -Key 'appearanceTheme'
      } else { $null }
      $body = Set-DreamSkinSectionSetting -Body $body -Key 'appearanceTheme' -Line $savedAppearance -NewLine $newLine
    }
    if ($pinnedAppearance) {
      # Native token surfaces (dropdowns/popovers) follow appearanceTheme, so a
      # fixed-appearance theme pins it to match; Restore puts the original back.
      $body = Set-DreamSkinSectionSetting -Body $body -Key 'appearanceTheme' `
        -Line ('appearanceTheme = "{0}"' -f $AppearanceTheme) -NewLine $newLine
    }
    $managedLightChromeTheme = $script:DreamSkinManagedLightChromeTheme
    if ($TransparentWindows) {
      $managedLightChromeTheme = $managedLightChromeTheme.Replace(
        'opaqueWindows = true',
        'opaqueWindows = false'
      )
    }
    $settings = [ordered]@{
      appearanceLightCodeThemeId = $script:DreamSkinManagedLightCodeTheme
      appearanceLightChromeTheme = $managedLightChromeTheme
    }
    $hasNestedLightChromeTheme = Test-DreamSkinDesktopNestedTable `
      -Content $content -Key 'appearanceLightChromeTheme'
    foreach ($key in $settings.Keys) {
      if ($key -eq 'appearanceLightChromeTheme' -and $hasNestedLightChromeTheme) { continue }
      $body = Set-DreamSkinSectionSetting -Body $body -Key $key -Line $settings[$key] -NewLine $newLine
    }

    $content = $content.Substring(0, $desktop.BodyStart) + $body +
      $content.Substring($desktop.BodyStart + $desktop.BodyLength)
    # Commit the metadata first. A config commit must never exist without the
    # marker that tells restore exactly which appearance keys we own.
    Write-DreamSkinAppearanceMarker -BackupPath $BackupPath -Managed $pinnedAppearance
    Write-DreamSkinUtf8FileAtomically -Path $ConfigPath -Content $content -ExpectedBytes $originalBytes
    $writeCompleted = $true
  } catch {
    if (-not $writeCompleted) {
      $configUnchanged = $false
      try {
        $configUnchanged = (Test-Path -LiteralPath $ConfigPath -PathType Leaf) -and
          (Test-DreamSkinBytesEqual -Left $originalBytes -Right ([System.IO.File]::ReadAllBytes($ConfigPath)))
      } catch {
        $configUnchanged = $false
      }
      if ($configUnchanged) {
        $markerCleanupSucceeded = $true
        if (-not $appearanceMarkerExisted -and (Test-Path -LiteralPath $appearanceMarkerPath)) {
          try {
            Remove-Item -LiteralPath $appearanceMarkerPath -Force -ErrorAction Stop
          } catch {
            $markerCleanupSucceeded = $false
          }
        }
        if ($markerCleanupSucceeded -and $backupCreated) {
          Remove-Item -LiteralPath $BackupPath -Force -ErrorAction SilentlyContinue
        }
      }
    }
    throw
  }
}

function Restore-DreamSkinBaseTheme {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$BackupPath
  )

  if (-not (Test-Path -LiteralPath $BackupPath)) { throw 'No pre-install config backup is available.' }
  if (Get-Command Assert-DreamSkinNoReparseComponents -ErrorAction SilentlyContinue) {
    Assert-DreamSkinNoReparseComponents -Path $BackupPath
    Assert-DreamSkinNoReparseComponents -Path (Get-DreamSkinAppearanceMarkerPath -BackupPath $BackupPath)
  }
  $backupBytes = [System.IO.File]::ReadAllBytes($BackupPath)
  $backupContent = ConvertFrom-DreamSkinUtf8Bytes -Bytes $backupBytes -Path $BackupPath
  $currentBytes = [System.IO.File]::ReadAllBytes($ConfigPath)
  $currentContent = ConvertFrom-DreamSkinUtf8Bytes -Bytes $currentBytes -Path $ConfigPath
  Assert-DreamSkinDesktopShapeSupported -Content $backupContent
  Assert-DreamSkinDesktopShapeSupported -Content $currentContent
  $newLine = Get-DreamSkinNewLine -Content $currentContent
  $backupDesktop = Get-DreamSkinDesktopSection -Content $backupContent
  $currentDesktop = Get-DreamSkinDesktopSection -Content $currentContent
  if ($null -eq $currentDesktop) {
    $currentContent = Add-DreamSkinDesktopSection -Content $currentContent -NewLine $newLine
    $currentDesktop = Get-DreamSkinDesktopSection -Content $currentContent
  }

  $body = $currentDesktop.Body
  $appearanceMarker = Read-DreamSkinAppearanceMarker -BackupPath $BackupPath
  $restoreLegacyAppearance = $null -eq $appearanceMarker -and
    (Test-DreamSkinLegacyManagedLightTrio -Content $currentContent)
  $restoreManagedAppearance = $null -ne $appearanceMarker -and
    [bool]$appearanceMarker.appearanceThemeManaged
  $restoreKeys = @('appearanceLightCodeThemeId', 'appearanceLightChromeTheme')
  if ($restoreLegacyAppearance -or $restoreManagedAppearance) {
    $restoreKeys = @('appearanceTheme') + $restoreKeys
  }
  $hasNestedLightChromeTheme = Test-DreamSkinDesktopNestedTable `
    -Content $currentContent -Key 'appearanceLightChromeTheme'
  foreach ($key in $restoreKeys) {
    if ($key -eq 'appearanceLightChromeTheme' -and $hasNestedLightChromeTheme) { continue }
    $keyToken = Get-DreamSkinTomlKeyTokenPattern -Key $key
    $pattern = "(?m)^[\t ]*$keyToken[\t ]*=[^\r\n]*(?:\r?\n|(?=\z))"
    $saved = if ($null -ne $backupDesktop) { [regex]::Match($backupDesktop.Body, $pattern) } else { $null }
    $line = if ($null -ne $saved -and $saved.Success) { $saved.Value } else { $null }
    $body = Set-DreamSkinSectionSetting -Body $body -Key $key -Line $line -NewLine $newLine
  }
  if ($null -eq $backupDesktop -and [string]::IsNullOrWhiteSpace($body)) {
    $currentContent = $currentContent.Remove($currentDesktop.SectionStart, $currentDesktop.SectionLength)
  } else {
    $currentContent = $currentContent.Substring(0, $currentDesktop.BodyStart) + $body +
      $currentContent.Substring($currentDesktop.BodyStart + $currentDesktop.BodyLength)
  }
  Write-DreamSkinUtf8FileAtomically -Path $ConfigPath -Content $currentContent -ExpectedBytes $currentBytes
}

function Restore-DreamSkinConfigBackup {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$BackupPath,
    [Parameter(Mandatory = $true)][string]$RecoveryBackupPath
  )

  if (-not (Test-Path -LiteralPath $BackupPath)) { throw 'No pre-install config backup is available.' }
  $backupBytes = [System.IO.File]::ReadAllBytes($BackupPath)
  $null = ConvertFrom-DreamSkinUtf8Bytes -Bytes $backupBytes -Path $BackupPath
  $currentBytes = $null
  if (Test-Path -LiteralPath $ConfigPath) {
    $currentBytes = [System.IO.File]::ReadAllBytes($ConfigPath)
    Write-DreamSkinBytesAtomically -Path $RecoveryBackupPath -Bytes $currentBytes -ExpectedBytes $null
  }

  Write-DreamSkinBytesAtomically -Path $ConfigPath -Bytes $backupBytes -ExpectedBytes $currentBytes
}

function Archive-DreamSkinConfigBackup {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$BackupPath,
    [Parameter(Mandatory = $true)][string]$ArchivePath
  )

  if (-not (Test-Path -LiteralPath $BackupPath)) { return }
  if (Test-Path -LiteralPath $ArchivePath) { throw "Config backup archive already exists: $ArchivePath" }
  Move-Item -LiteralPath $BackupPath -Destination $ArchivePath -ErrorAction Stop
  Remove-Item -LiteralPath (Get-DreamSkinAppearanceMarkerPath -BackupPath $BackupPath) -Force -ErrorAction SilentlyContinue
}
