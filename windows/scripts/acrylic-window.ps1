[CmdletBinding()]
param(
  [ValidateSet('Describe', 'Probe', 'Apply', 'Monitor', 'Restore')]
  [string]$Action = 'Probe',

  [int]$TargetProcessId = 0,
  [long]$ExpectedStartTimeFileTimeUtc = 0,
  [string]$ExpectedExecutablePath = '',
  [string]$ExpectedPackageFamilyName = '',
  [string]$ExpectedWindowClass = 'Chrome_WidgetWin_1',
  [long]$ExpectedWindowHandle = 0,

  [ValidateRange(100, 10000)]
  [int]$PollMilliseconds = 500,
  [string]$StopFile = '',
  [string]$ArmFile = '',
  [ValidateRange(1000, 120000)]
  [int]$ArmTimeoutMilliseconds = 30000,
  [ValidateRange(0, 30000)]
  [int]$MutexAcquireTimeoutMilliseconds = 5000,
  [switch]$AllowHiddenTarget,
  [switch]$ConfirmTargetIdentity,
  [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# This helper deliberately does not discover and mutate a process in one step. Describe is
# read-only; every mutating action requires the caller to pin the complete descriptor it
# returned (PID, creation time, image path, package family, and window class).

if (-not ('CodexDreamSkin.AcrylicNative' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace CodexDreamSkin {
  public sealed class AcrylicProcessIdentity {
    public int ProcessId { get; set; }
    public long StartTimeFileTimeUtc { get; set; }
    public string ExecutablePath { get; set; }
    public string PackageFamilyName { get; set; }
  }

  public sealed class AcrylicWindowIdentity {
    public long Handle { get; set; }
    public int ProcessId { get; set; }
    public bool IsVisible { get; set; }
    public bool IsRoot { get; set; }
    public bool IsUnowned { get; set; }
    public bool IsChild { get; set; }
    public bool IsToolWindow { get; set; }
    public string ClassName { get; set; }
  }

  public static class AcrylicNative {
    private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    private const int ERROR_INSUFFICIENT_BUFFER = 122;
    private const int APPMODEL_ERROR_NO_PACKAGE = 15700;
    private const uint GA_ROOT = 2;
    private const uint GW_OWNER = 4;
    private const int GWL_STYLE = -16;
    private const int GWL_EXSTYLE = -20;
    private const long WS_CHILD = 0x40000000L;
    private const long WS_EX_TOOLWINDOW = 0x00000080L;
    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;

    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint desiredAccess, bool inheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool QueryFullProcessImageName(
      IntPtr process,
      int flags,
      StringBuilder executablePath,
      ref uint size
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetProcessTimes(
      IntPtr process,
      out long creationTime,
      out long exitTime,
      out long kernelTime,
      out long userTime
    );

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetPackageFamilyName(
      IntPtr process,
      ref uint packageFamilyNameLength,
      StringBuilder packageFamilyName
    );

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindow(IntPtr hwnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindowVisible(IntPtr hwnd);

    [DllImport("user32.dll")]
    private static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);

    [DllImport("user32.dll")]
    private static extern IntPtr GetWindow(IntPtr hwnd, uint command);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int GetClassName(IntPtr hwnd, StringBuilder className, int maximumCount);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong")]
    private static extern int GetWindowLong32(IntPtr hwnd, int index);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hwnd, int index);

    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(
      IntPtr hwnd,
      int attribute,
      out int value,
      int valueSize
    );

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(
      IntPtr hwnd,
      int attribute,
      ref int value,
      int valueSize
    );

    private static long GetWindowLong(IntPtr hwnd, int index) {
      return IntPtr.Size == 8
        ? GetWindowLongPtr64(hwnd, index).ToInt64()
        : GetWindowLong32(hwnd, index);
    }

    private static IntPtr RequireWindow(long handle, int expectedProcessId) {
      IntPtr hwnd = new IntPtr(handle);
      if (!IsWindow(hwnd)) {
        throw new InvalidOperationException("The pinned window handle is no longer valid.");
      }
      uint processId;
      GetWindowThreadProcessId(hwnd, out processId);
      if (processId != (uint)expectedProcessId) {
        throw new InvalidOperationException("The pinned window handle no longer belongs to the expected process.");
      }
      return hwnd;
    }

    public static int GetWindowProcessIdOrZero(long handle) {
      IntPtr hwnd = new IntPtr(handle);
      if (!IsWindow(hwnd)) {
        return 0;
      }
      uint processId;
      if (GetWindowThreadProcessId(hwnd, out processId) == 0 || processId == 0) {
        throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not identify the pinned window owner.");
      }
      return checked((int)processId);
    }

    public static AcrylicProcessIdentity CaptureProcessIdentity(int processId) {
      IntPtr process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, processId);
      if (process == IntPtr.Zero) {
        throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open the target process.");
      }
      try {
        long creationTime;
        long exitTime;
        long kernelTime;
        long userTime;
        if (!GetProcessTimes(process, out creationTime, out exitTime, out kernelTime, out userTime)) {
          throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read the target process creation time.");
        }

        StringBuilder executablePath = new StringBuilder(32768);
        uint executablePathLength = (uint)executablePath.Capacity;
        if (!QueryFullProcessImageName(process, 0, executablePath, ref executablePathLength)) {
          throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read the target process image path.");
        }

        uint familyNameLength = 0;
        int packageResult = GetPackageFamilyName(process, ref familyNameLength, null);
        if (packageResult == APPMODEL_ERROR_NO_PACKAGE) {
          throw new InvalidOperationException("The target process does not have a packaged app identity.");
        }
        if (packageResult != ERROR_INSUFFICIENT_BUFFER || familyNameLength == 0) {
          throw new Win32Exception(packageResult, "Could not size the target package family name.");
        }
        StringBuilder familyName = new StringBuilder((int)familyNameLength);
        packageResult = GetPackageFamilyName(process, ref familyNameLength, familyName);
        if (packageResult != 0) {
          throw new Win32Exception(packageResult, "Could not read the target package family name.");
        }

        return new AcrylicProcessIdentity {
          ProcessId = processId,
          StartTimeFileTimeUtc = creationTime,
          ExecutablePath = executablePath.ToString(),
          PackageFamilyName = familyName.ToString()
        };
      } finally {
        CloseHandle(process);
      }
    }

    public static AcrylicWindowIdentity[] EnumerateProcessWindows(int expectedProcessId) {
      List<AcrylicWindowIdentity> result = new List<AcrylicWindowIdentity>();
      EnumWindows(delegate(IntPtr hwnd, IntPtr ignored) {
        uint processId;
        GetWindowThreadProcessId(hwnd, out processId);
        if (processId != (uint)expectedProcessId) {
          return true;
        }

        StringBuilder className = new StringBuilder(256);
        if (GetClassName(hwnd, className, className.Capacity) == 0) {
          className.Clear();
        }
        long style = GetWindowLong(hwnd, GWL_STYLE);
        long extendedStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
        result.Add(new AcrylicWindowIdentity {
          Handle = hwnd.ToInt64(),
          ProcessId = expectedProcessId,
          IsVisible = IsWindowVisible(hwnd),
          IsRoot = GetAncestor(hwnd, GA_ROOT) == hwnd,
          IsUnowned = GetWindow(hwnd, GW_OWNER) == IntPtr.Zero,
          IsChild = (style & WS_CHILD) != 0,
          IsToolWindow = (extendedStyle & WS_EX_TOOLWINDOW) != 0,
          ClassName = className.ToString()
        });
        return true;
      }, IntPtr.Zero);
      return result.ToArray();
    }

    public static int GetBackdrop(long handle, int expectedProcessId) {
      IntPtr hwnd = RequireWindow(handle, expectedProcessId);
      int value;
      int result = DwmGetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, out value, sizeof(int));
      if (result != 0) {
        Marshal.ThrowExceptionForHR(result);
      }
      return value;
    }

    public static int SetBackdrop(long handle, int expectedProcessId, int value) {
      if (value < 1 || value > 4) {
        throw new ArgumentOutOfRangeException("value");
      }
      IntPtr hwnd = RequireWindow(handle, expectedProcessId);
      int requestedValue = value;
      int result = DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ref requestedValue, sizeof(int));
      if (result != 0) {
        Marshal.ThrowExceptionForHR(result);
      }

      // Recheck ownership after the write, then read back the material. This makes window
      // destruction/reuse a failed operation instead of silently affecting another window.
      hwnd = RequireWindow(handle, expectedProcessId);
      int actualValue;
      result = DwmGetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, out actualValue, sizeof(int));
      if (result != 0) {
        Marshal.ThrowExceptionForHR(result);
      }
      if (actualValue != value) {
        throw new InvalidOperationException("Windows did not retain the requested system backdrop type.");
      }
      return actualValue;
    }
  }
}
'@
}

function Get-DreamSkinAcrylicNormalizedPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not [System.IO.Path]::IsPathRooted($Path)) {
    throw 'The expected executable path must be absolute.'
  }
  return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Assert-DreamSkinAcrylicAllowedIdentity {
  param([Parameter(Mandatory = $true)]$Identity)
  if ($Identity.ProcessId -le 0) { throw 'The target process ID is invalid.' }
  if ($Identity.StartTimeFileTimeUtc -le 0) { throw 'The target process creation time is invalid.' }
  $path = Get-DreamSkinAcrylicNormalizedPath -Path ([string]$Identity.ExecutablePath)
  if ([System.IO.Path]::GetFileName($path) -cne 'ChatGPT.exe') {
    throw 'Only the official Codex ChatGPT.exe host is supported.'
  }
  if ([string]$Identity.PackageFamilyName -cnotmatch '^OpenAI\.Codex_[A-Za-z0-9]+$') {
    throw 'The process package family is not an official OpenAI.Codex package identity.'
  }
}

function Get-DreamSkinAcrylicIdentityErrors {
  param(
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)]$Actual
  )
  $errors = [System.Collections.Generic.List[string]]::new()
  if ([int]$Actual.ProcessId -ne [int]$Expected.ProcessId) {
    $errors.Add('process ID')
  }
  if ([long]$Actual.StartTimeFileTimeUtc -ne [long]$Expected.StartTimeFileTimeUtc) {
    $errors.Add('process creation time')
  }
  try {
    $expectedPath = Get-DreamSkinAcrylicNormalizedPath -Path ([string]$Expected.ExecutablePath)
    $actualPath = Get-DreamSkinAcrylicNormalizedPath -Path ([string]$Actual.ExecutablePath)
    if (-not [string]::Equals($expectedPath, $actualPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      $errors.Add('executable path')
    }
  } catch {
    $errors.Add('executable path')
  }
  if (-not [string]::Equals(
      [string]$Expected.PackageFamilyName,
      [string]$Actual.PackageFamilyName,
      [System.StringComparison]::Ordinal
    )) {
    $errors.Add('package family')
  }
  return $errors.ToArray()
}

function Assert-DreamSkinAcrylicExpectedDescriptor {
  if ($TargetProcessId -le 0) { throw '-TargetProcessId must pin a positive process ID.' }
  if ($ExpectedStartTimeFileTimeUtc -le 0) {
    throw '-ExpectedStartTimeFileTimeUtc must pin the process creation time returned by Describe.'
  }
  if ([string]::IsNullOrWhiteSpace($ExpectedExecutablePath)) {
    throw '-ExpectedExecutablePath must pin the image path returned by Describe.'
  }
  if ([string]::IsNullOrWhiteSpace($ExpectedPackageFamilyName)) {
    throw '-ExpectedPackageFamilyName must pin the package family returned by Describe.'
  }
  if ([string]::IsNullOrWhiteSpace($ExpectedWindowClass)) {
    throw '-ExpectedWindowClass must not be empty.'
  }
  if ($ExpectedWindowClass -cne 'Chrome_WidgetWin_1') {
    throw 'Only the Electron top-level Chrome_WidgetWin_1 window class is supported.'
  }
  if ($ExpectedWindowHandle -le 0) {
    throw '-ExpectedWindowHandle must pin the exact HWND returned by Describe.'
  }
  $expected = [pscustomobject]@{
    ProcessId = $TargetProcessId
    StartTimeFileTimeUtc = $ExpectedStartTimeFileTimeUtc
    ExecutablePath = Get-DreamSkinAcrylicNormalizedPath -Path $ExpectedExecutablePath
    PackageFamilyName = $ExpectedPackageFamilyName
    WindowHandle = $ExpectedWindowHandle
  }
  Assert-DreamSkinAcrylicAllowedIdentity -Identity $expected
  return $expected
}

function Get-DreamSkinAcrylicLiveIdentity {
  param([Parameter(Mandatory = $true)][int]$ProcessId)
  return [CodexDreamSkin.AcrylicNative]::CaptureProcessIdentity($ProcessId)
}

function Assert-DreamSkinAcrylicLiveTarget {
  param([Parameter(Mandatory = $true)]$Expected)
  $actual = Get-DreamSkinAcrylicLiveIdentity -ProcessId ([int]$Expected.ProcessId)
  Assert-DreamSkinAcrylicAllowedIdentity -Identity $actual
  $errors = @(Get-DreamSkinAcrylicIdentityErrors -Expected $Expected -Actual $actual)
  if ($errors.Count -gt 0) {
    throw ('The live target no longer matches the pinned descriptor: ' + ($errors -join ', ') + '.')
  }
  return $actual
}

function Select-DreamSkinAcrylicMainWindow {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Windows,
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$WindowClass,
    [long]$ExpectedWindowHandle = 0,
    [switch]$AllowHiddenPinnedWindow,
    [switch]$RequireSoleEligibleWindow,
    [switch]$AllowMissing
  )
  $guardedCandidates = @($Windows | Where-Object {
    [int]$_.ProcessId -eq $ProcessId -and
    [bool]$_.IsRoot -and [bool]$_.IsUnowned -and
    -not [bool]$_.IsChild -and -not [bool]$_.IsToolWindow -and
    [string]::Equals([string]$_.ClassName, $WindowClass, [System.StringComparison]::Ordinal)
  })
  $candidates = @(if ($AllowHiddenPinnedWindow) {
      $guardedCandidates
    } else {
      @($guardedCandidates | Where-Object { [bool]$_.IsVisible })
    })

  if ($RequireSoleEligibleWindow -and $candidates.Count -gt 1) {
    throw 'Desktop Acrylic trial mode supports exactly one eligible top-level Codex window.'
  }

  if ($ExpectedWindowHandle -ne 0) {
    $expected = @($candidates | Where-Object { [long]$_.Handle -eq $ExpectedWindowHandle })
    if ($expected.Count -eq 1) { return $expected[0] }
    if ($expected.Count -gt 1) { throw 'The pinned Codex window handle is ambiguous.' }
    $rawExpected = @($Windows | Where-Object { [long]$_.Handle -eq $ExpectedWindowHandle })
    if ($rawExpected.Count -gt 0) {
      throw 'The pinned window still exists but no longer satisfies the guarded top-level Codex window contract.'
    }
    if ($AllowMissing) { return $null }
    throw 'The pinned window handle no longer identifies a guarded top-level Codex window.'
  }

  if ($candidates.Count -eq 1) { return $candidates[0] }
  if ($candidates.Count -eq 0 -and $AllowMissing) { return $null }
  if ($candidates.Count -eq 0) {
    throw 'No visible, unowned, top-level Codex main window matches the pinned process and class.'
  }
  throw 'Multiple top-level Codex windows match the target and the process main window is ambiguous.'
}

function Get-DreamSkinAcrylicMainWindow {
  param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$WindowClass,
    [long]$PinnedWindowHandle = 0,
    [switch]$AllowHiddenPinnedWindow,
    [switch]$RequireSoleEligibleWindow,
    [switch]$AllowMissing
  )
  $selectionAllowMissing = [bool]$AllowMissing
  if ($AllowMissing -and $PinnedWindowHandle -ne 0) {
    # Missing is terminal only when the exact HWND was destroyed or was reused
    # by another process. If the same process still owns it, every class/style/
    # root guard must pass or recovery preserves the record and fails closed.
    $liveWindowProcessId = [CodexDreamSkin.AcrylicNative]::GetWindowProcessIdOrZero(
      [long]$PinnedWindowHandle
    )
    if ($liveWindowProcessId -eq 0 -or $liveWindowProcessId -ne $ProcessId) {
      return $null
    }
    $selectionAllowMissing = $false
  }
  $windows = @([CodexDreamSkin.AcrylicNative]::EnumerateProcessWindows($ProcessId))
  return Select-DreamSkinAcrylicMainWindow `
    -Windows $windows `
    -ProcessId $ProcessId `
    -WindowClass $WindowClass `
    -ExpectedWindowHandle $PinnedWindowHandle `
    -AllowHiddenPinnedWindow:$AllowHiddenPinnedWindow `
    -RequireSoleEligibleWindow:$RequireSoleEligibleWindow `
    -AllowMissing:$selectionAllowMissing
}

function Get-DreamSkinAcrylicBackdropValue {
  param([Parameter(Mandatory = $true)][ValidateSet('Acrylic', 'Mica')][string]$Material)
  if ($Material -ceq 'Acrylic') { return 3 }
  return 2
}

function Get-DreamSkinAcrylicVerifiedWindow {
  param(
    [Parameter(Mandatory = $true)]$Expected,
    [switch]$AllowHiddenPinnedWindow,
    [switch]$RequireSoleEligibleWindow,
    [switch]$AllowMissing
  )
  try {
    [void](Assert-DreamSkinAcrylicLiveTarget -Expected $Expected)
  } catch {
    $process = Get-Process -Id ([int]$Expected.ProcessId) -ErrorAction SilentlyContinue
    if ($AllowMissing -and $null -eq $process) { return $null }
    throw
  }
  return Get-DreamSkinAcrylicMainWindow `
    -ProcessId ([int]$Expected.ProcessId) `
    -WindowClass $ExpectedWindowClass `
    -PinnedWindowHandle ([long]$Expected.WindowHandle) `
    -AllowHiddenPinnedWindow:$AllowHiddenPinnedWindow `
    -RequireSoleEligibleWindow:$RequireSoleEligibleWindow `
    -AllowMissing:$AllowMissing
}

function Set-DreamSkinAcrylicVerifiedMaterial {
  param(
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)][ValidateSet('Acrylic', 'Mica')][string]$Material,
    [switch]$AllowHiddenPinnedWindow,
    [switch]$RequireSoleEligibleWindow,
    [switch]$AllowMissing
  )
  $window = Get-DreamSkinAcrylicVerifiedWindow -Expected $Expected `
    -AllowHiddenPinnedWindow:$AllowHiddenPinnedWindow `
    -RequireSoleEligibleWindow:$RequireSoleEligibleWindow -AllowMissing:$AllowMissing
  if ($null -eq $window) { return $null }

  # Revalidate after window selection, immediately before the native write. The native method
  # independently checks HWND ownership both before and after DwmSetWindowAttribute.
  [void](Assert-DreamSkinAcrylicLiveTarget -Expected $Expected)
  $value = Get-DreamSkinAcrylicBackdropValue -Material $Material
  $previous = [CodexDreamSkin.AcrylicNative]::GetBackdrop([long]$window.Handle, [int]$Expected.ProcessId)
  $actual = if ($previous -eq $value) {
    $previous
  } else {
    [CodexDreamSkin.AcrylicNative]::SetBackdrop([long]$window.Handle, [int]$Expected.ProcessId, $value)
  }
  return [pscustomobject]@{
    ProcessId = [int]$Expected.ProcessId
    StartTimeFileTimeUtc = [long]$Expected.StartTimeFileTimeUtc
    WindowHandle = ('0x{0:X}' -f [long]$window.Handle)
    WindowHandleValue = [long]$window.Handle
    WindowClass = [string]$window.ClassName
    PreviousBackdrop = $previous
    CurrentBackdrop = $actual
    Material = $Material
  }
}

function Enter-DreamSkinAcrylicMonitorMutex {
  param([Parameter(Mandatory = $true)]$Expected)
  $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $name = 'Local\CodexDreamSkin.Acrylic.{0}.{1}.{2}' -f `
    $sid, [int]$Expected.ProcessId, [long]$Expected.StartTimeFileTimeUtc
  $mutex = [System.Threading.Mutex]::new($false, $name)
  $acquired = $false
  $deadline = [DateTime]::UtcNow.AddMilliseconds($MutexAcquireTimeoutMilliseconds)
  try {
    do {
      try { $acquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] {
        $acquired = $true
      }
      if ($acquired -or [DateTime]::UtcNow -ge $deadline) { break }
      Start-Sleep -Milliseconds 100
    } while ($true)
  } catch {
    $mutex.Dispose()
    throw
  }
  if (-not $acquired) {
    $mutex.Dispose()
    throw 'An Acrylic monitor is already attached to this exact Codex process.'
  }
  return $mutex
}

function Exit-DreamSkinAcrylicMonitorMutex {
  param([Parameter(Mandatory = $true)][System.Threading.Mutex]$Mutex)
  try { $Mutex.ReleaseMutex() } finally { $Mutex.Dispose() }
}

function Invoke-DreamSkinAcrylicMonitor {
  param(
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)][string]$ResolvedStopFile,
    [Parameter(Mandatory = $true)][string]$ResolvedArmFile
  )
  $mutex = Enter-DreamSkinAcrylicMonitorMutex -Expected $Expected
  $applied = $false
  $restoredToMica = $false
  $restoreFailure = $null
  $reason = 'stopped'
  try {
    if (Test-Path -LiteralPath $ResolvedStopFile) {
      throw "The Acrylic stop file already exists: $ResolvedStopFile"
    }
    # Startup records the exact monitor identity before arming it. A hard crash
    # in that handoff can leave a short-lived watcher, but never an unrecorded
    # native Acrylic write.
    $armDeadline = [DateTime]::UtcNow.AddMilliseconds($ArmTimeoutMilliseconds)
    while (-not (Test-Path -LiteralPath $ResolvedArmFile)) {
      if (Test-Path -LiteralPath $ResolvedStopFile) {
        $reason = 'stop-before-arm'
        return
      }
      if ($null -eq (Get-Process -Id ([int]$Expected.ProcessId) -ErrorAction SilentlyContinue)) {
        $reason = 'target-exited-before-arm'
        return
      }
      if ([DateTime]::UtcNow -ge $armDeadline) {
        throw 'The Acrylic monitor was not armed after its identity was recorded.'
      }
      Start-Sleep -Milliseconds 100
    }
    while ($true) {
      if (Test-Path -LiteralPath $ResolvedStopFile) {
        $reason = 'stop-file'
        break
      }

      $process = Get-Process -Id ([int]$Expected.ProcessId) -ErrorAction SilentlyContinue
      if ($null -eq $process) {
        $reason = 'target-exited'
        break
      }

      # The exact HWND is already pinned to the verified process identity. Other
      # legitimate Codex top-level windows may appear later and must not make
      # this monitor abandon or restore the pinned window.
      $window = Get-DreamSkinAcrylicVerifiedWindow -Expected $Expected -AllowMissing
      if ($null -ne $window) {
        $current = [CodexDreamSkin.AcrylicNative]::GetBackdrop(
          [long]$window.Handle,
          [int]$Expected.ProcessId
        )
        if ($current -ne 3) {
          # Assume ownership before the write so that a post-write verification failure still
          # enters the guarded Mica restoration path.
          $applied = $true
          [void](Set-DreamSkinAcrylicVerifiedMaterial -Expected $Expected -Material Acrylic)
        }
        $applied = $true
      }
      Start-Sleep -Milliseconds $PollMilliseconds
    }
  } finally {
    if ($applied) {
      $restoreError = $null
      $restored = $false
      for ($attempt = 0; $attempt -lt 10 -and -not $restored; $attempt++) {
        try {
          $result = Set-DreamSkinAcrylicVerifiedMaterial -Expected $Expected -Material Mica `
            -AllowHiddenPinnedWindow -AllowMissing
          if ($null -eq $result) {
            # The exact HWND was destroyed (or its process exited), so its DWM
            # attribute can no longer affect a live window.
            $restored = $true
            $restoredToMica = $true
            break
          }
          $restored = $true
          $restoredToMica = $true
        } catch {
          $restoreError = $_
          # Retry transient enumeration/DWM races. Every attempt repeats the
          # complete process identity, exact HWND owner and style/class guards,
          # so a deterministic mismatch remains fail-closed without ever
          # writing through a replacement target.
          if ($attempt -lt 9) { Start-Sleep -Milliseconds 100 }
        }
      }
      if (-not $restored -and $null -ne $restoreError) {
        $restoreFailure = 'Could not restore Mica while the Acrylic monitor stopped: {0}' -f `
          $restoreError.Exception.Message
        Write-Warning $restoreFailure
      } elseif (-not $restored -and
        $null -ne (Get-Process -Id ([int]$Expected.ProcessId) -ErrorAction SilentlyContinue)) {
        $restoreFailure = 'The Acrylic target process remained alive but its pinned HWND could not be restored to Mica.'
        Write-Warning $restoreFailure
      }
    }
    Exit-DreamSkinAcrylicMonitorMutex -Mutex $mutex
  }
  if ($restoreFailure) { throw $restoreFailure }
  return [pscustomobject]@{
    Action = 'Monitor'
    ProcessId = [int]$Expected.ProcessId
    StopReason = $reason
    RestoredToMica = $restoredToMica
  }
}

function Invoke-DreamSkinAcrylicSelfTest {
  $expected = [pscustomobject]@{
    ProcessId = 42
    StartTimeFileTimeUtc = 133700000000000000L
    ExecutablePath = 'C:\Program Files\WindowsApps\OpenAI.Codex_1.0.0.0_x64__publisher\ChatGPT.exe'
    PackageFamilyName = 'OpenAI.Codex_publisher'
  }
  $actual = [pscustomobject]@{
    ProcessId = 42
    StartTimeFileTimeUtc = 133700000000000000L
    ExecutablePath = 'c:\program files\windowsapps\OpenAI.Codex_1.0.0.0_x64__publisher\ChatGPT.exe'
    PackageFamilyName = 'OpenAI.Codex_publisher'
  }
  Assert-DreamSkinAcrylicAllowedIdentity -Identity $expected
  if (@(Get-DreamSkinAcrylicIdentityErrors -Expected $expected -Actual $actual).Count -ne 0) {
    throw 'Self-test: an exact identity descriptor did not match.'
  }
  $actual.StartTimeFileTimeUtc++
  $mismatch = @(Get-DreamSkinAcrylicIdentityErrors -Expected $expected -Actual $actual)
  if ($mismatch.Count -ne 1 -or $mismatch[0] -cne 'process creation time') {
    throw 'Self-test: PID reuse was not rejected by process creation time.'
  }

  $window = [pscustomobject]@{
    Handle = 101L
    ProcessId = 42
    IsVisible = $true
    IsRoot = $true
    IsUnowned = $true
    IsChild = $false
    IsToolWindow = $false
    ClassName = 'Chrome_WidgetWin_1'
  }
  $toolWindow = [pscustomobject]@{
    Handle = 102L
    ProcessId = 42
    IsVisible = $true
    IsRoot = $true
    IsUnowned = $true
    IsChild = $false
    IsToolWindow = $true
    ClassName = 'Chrome_WidgetWin_1'
  }
  $selected = Select-DreamSkinAcrylicMainWindow `
    -Windows @($window, $toolWindow) `
    -ProcessId 42 `
    -WindowClass 'Chrome_WidgetWin_1' `
    -ExpectedWindowHandle 101 `
    -RequireSoleEligibleWindow
  if ([long]$selected.Handle -ne 101L) {
    throw 'Self-test: the verified main window was not selected.'
  }
  $secondWindow = $window.PSObject.Copy()
  $secondWindow.Handle = 103L
  $pinnedAmongMultiple = Select-DreamSkinAcrylicMainWindow `
    -Windows @($window, $secondWindow) `
    -ProcessId 42 `
    -WindowClass 'Chrome_WidgetWin_1' `
    -ExpectedWindowHandle 101
  if ([long]$pinnedAmongMultiple.Handle -ne 101L) {
    throw 'Self-test: an exact pinned HWND was not preserved after another eligible window appeared.'
  }
  $ambiguous = $false
  try {
    $secondWindow = $window.PSObject.Copy()
    $secondWindow.Handle = 103L
    [void](Select-DreamSkinAcrylicMainWindow `
      -Windows @($window, $secondWindow) `
      -ProcessId 42 `
      -WindowClass 'Chrome_WidgetWin_1' `
      -ExpectedWindowHandle 101 `
      -RequireSoleEligibleWindow)
  } catch {
    $ambiguous = $true
  }
  if (-not $ambiguous) { throw 'Self-test: ambiguous top-level windows were not rejected.' }
  $hiddenWindow = $window.PSObject.Copy()
  $hiddenWindow.IsVisible = $false
  $hiddenSelected = Select-DreamSkinAcrylicMainWindow `
    -Windows @($hiddenWindow) -ProcessId 42 -WindowClass 'Chrome_WidgetWin_1' `
    -ExpectedWindowHandle 101 -AllowHiddenPinnedWindow
  if ([long]$hiddenSelected.Handle -ne 101L) {
    throw 'Self-test: a hidden exact HWND could not be selected for recovery.'
  }
  $guardFailureAcceptedAsMissing = $false
  try {
    [void](Select-DreamSkinAcrylicMainWindow `
      -Windows @($toolWindow) -ProcessId 42 -WindowClass 'Chrome_WidgetWin_1' `
      -ExpectedWindowHandle 102 -AllowHiddenPinnedWindow -AllowMissing)
    $guardFailureAcceptedAsMissing = $true
  } catch {}
  if ($guardFailureAcceptedAsMissing) {
    throw 'Self-test: an existing pinned HWND guard failure was accepted as a destroyed target.'
  }
  $destroyed = Select-DreamSkinAcrylicMainWindow `
    -Windows @() -ProcessId 42 -WindowClass 'Chrome_WidgetWin_1' `
    -ExpectedWindowHandle 101 -AllowHiddenPinnedWindow -AllowMissing
  if ($null -ne $destroyed) {
    throw 'Self-test: a destroyed exact HWND did not produce terminal missing state.'
  }
  if ((Get-DreamSkinAcrylicBackdropValue -Material Acrylic) -ne 3 -or
      (Get-DreamSkinAcrylicBackdropValue -Material Mica) -ne 2) {
    throw 'Self-test: the Acrylic/Mica DWM values changed.'
  }
  Write-Host 'PASS: Acrylic helper identity, PID-reuse, main-window, and material guards.'
}

if ($SelfTest) {
  Invoke-DreamSkinAcrylicSelfTest
  return
}

if ($env:OS -cne 'Windows_NT') {
  throw 'The Acrylic helper is available only on Windows.'
}
if ($TargetProcessId -le 0) {
  throw '-TargetProcessId must identify the exact Codex browser process.'
}
if ($AllowHiddenTarget -and $Action -notin @('Probe', 'Restore')) {
  throw '-AllowHiddenTarget is restricted to recovery Probe and Restore actions.'
}

if ($Action -ceq 'Describe') {
  if ($ExpectedWindowHandle -le 0) {
    throw 'Describe requires -ExpectedWindowHandle from verified Win32 window evidence.'
  }
  $identity = Get-DreamSkinAcrylicLiveIdentity -ProcessId $TargetProcessId
  Assert-DreamSkinAcrylicAllowedIdentity -Identity $identity
  $window = Get-DreamSkinAcrylicMainWindow `
    -ProcessId $TargetProcessId `
    -WindowClass $ExpectedWindowClass `
    -PinnedWindowHandle $ExpectedWindowHandle
  $backdrop = [CodexDreamSkin.AcrylicNative]::GetBackdrop([long]$window.Handle, $TargetProcessId)
  [pscustomobject]@{
    ProcessId = $identity.ProcessId
    StartTimeFileTimeUtc = $identity.StartTimeFileTimeUtc
    ExecutablePath = $identity.ExecutablePath
    PackageFamilyName = $identity.PackageFamilyName
    WindowHandle = ('0x{0:X}' -f [long]$window.Handle)
    WindowHandleValue = [long]$window.Handle
    WindowClass = $window.ClassName
    CurrentBackdrop = $backdrop
  }
  return
}

$expected = Assert-DreamSkinAcrylicExpectedDescriptor
$requireSoleEligibleWindow = $Action -ceq 'Apply' -and -not $AllowHiddenTarget
$allowMissingTarget = $AllowHiddenTarget -and $Action -in @('Probe', 'Restore')
$window = Get-DreamSkinAcrylicVerifiedWindow -Expected $expected `
  -AllowHiddenPinnedWindow:$AllowHiddenTarget `
  -RequireSoleEligibleWindow:$requireSoleEligibleWindow `
  -AllowMissing:$allowMissingTarget
if ($Action -ceq 'Probe') {
  if ($null -eq $window) {
    [pscustomobject]@{
      Action = 'Probe'
      ProcessId = $TargetProcessId
      StartTimeFileTimeUtc = $ExpectedStartTimeFileTimeUtc
      WindowHandleValue = $ExpectedWindowHandle
      TargetMissing = $true
      IdentityVerified = $true
    }
    return
  }
  $backdrop = [CodexDreamSkin.AcrylicNative]::GetBackdrop([long]$window.Handle, $TargetProcessId)
  [pscustomobject]@{
    Action = 'Probe'
    ProcessId = $TargetProcessId
    StartTimeFileTimeUtc = $ExpectedStartTimeFileTimeUtc
    WindowHandle = ('0x{0:X}' -f [long]$window.Handle)
    WindowHandleValue = [long]$window.Handle
    WindowClass = $window.ClassName
    CurrentBackdrop = $backdrop
    TargetMissing = $false
    IdentityVerified = $true
  }
  return
}

if (-not $ConfirmTargetIdentity) {
  throw 'Apply, Monitor, and Restore require -ConfirmTargetIdentity after pinning a Describe result.'
}

switch ($Action) {
  'Apply' {
    Set-DreamSkinAcrylicVerifiedMaterial -Expected $expected -Material Acrylic `
      -RequireSoleEligibleWindow
    break
  }
  'Restore' {
    $restored = Set-DreamSkinAcrylicVerifiedMaterial -Expected $expected -Material Mica `
      -AllowHiddenPinnedWindow:$AllowHiddenTarget -AllowMissing:$AllowHiddenTarget
    if ($null -eq $restored) {
      [pscustomobject]@{
        Action = 'Restore'
        ProcessId = $TargetProcessId
        StartTimeFileTimeUtc = $ExpectedStartTimeFileTimeUtc
        WindowHandleValue = $ExpectedWindowHandle
        TargetMissing = $true
        IdentityVerified = $true
      }
    } else {
      $restored | Add-Member -NotePropertyName TargetMissing -NotePropertyValue $false -PassThru
    }
    break
  }
  'Monitor' {
    if ([string]::IsNullOrWhiteSpace($StopFile)) {
      throw 'Monitor requires an absolute -StopFile for graceful shutdown and Mica restoration.'
    }
    if (-not [System.IO.Path]::IsPathRooted($StopFile)) {
      throw '-StopFile must be an absolute path.'
    }
    if ([string]::IsNullOrWhiteSpace($ArmFile) -or
      -not [System.IO.Path]::IsPathRooted($ArmFile)) {
      throw 'Monitor requires an absolute -ArmFile for the recorded startup handoff.'
    }
    $resolvedStopFile = [System.IO.Path]::GetFullPath($StopFile)
    $resolvedArmFile = [System.IO.Path]::GetFullPath($ArmFile)
    Invoke-DreamSkinAcrylicMonitor -Expected $expected `
      -ResolvedStopFile $resolvedStopFile -ResolvedArmFile $resolvedArmFile
    break
  }
}
