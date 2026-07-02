# sim-draw.ps1 — simulate a real left-button drag on the projector window so the
# telestrator engine's Win32 input path (GetAsyncKeyState + GetForegroundWindow +
# GetCursorPos) is exercised end-to-end during autonomous verification.
#
# Finds a visible top-level window whose title contains -Title (via EnumWindows),
# force-foregrounds it (AttachThreadInput bypasses the foreground lock — the
# engine only draws when the projector is foreground), and drags the cursor from
# (x1,y1) to (x2,y2) as fractions of the client area while holding the left button.
#
#   powershell -File tools/sim-draw.ps1 -Title "Projector" -x1 0.25 -y1 0.3 -x2 0.75 -y2 0.7
param(
	[string]$Title = "Projector",
	[double]$x1 = 0.25, [double]$y1 = 0.30,
	[double]$x2 = 0.75, [double]$y2 = 0.70,
	[int]$Steps = 40, [int]$DelayMs = 12
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Win {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int x, y; }
  public const uint LEFTDOWN = 0x0002, LEFTUP = 0x0004;
  public static IntPtr foundHwnd = IntPtr.Zero;
  public static string foundTitle = "";
  public static IntPtr Find(string frag) {
    foundHwnd = IntPtr.Zero; foundTitle = "";
    EnumWindows((h,l)=>{
      var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
      var t = sb.ToString();
      if (IsWindowVisible(h) && t.IndexOf(frag, StringComparison.OrdinalIgnoreCase) >= 0) {
        foundHwnd = h; foundTitle = t; return false;
      }
      return true;
    }, IntPtr.Zero);
    return foundHwnd;
  }
  public static void Foreground(IntPtr h) {
    uint pid; uint target = GetWindowThreadProcessId(h, out pid);
    uint cur = GetCurrentThreadId();
    AttachThreadInput(cur, target, true);
    ShowWindow(h, 5); // SW_SHOW
    BringWindowToTop(h);
    SetForegroundWindow(h);
    AttachThreadInput(cur, target, false);
  }
}
"@

$found = [Win]::Find($Title)
if ($found -eq [IntPtr]::Zero) { Write-Error "No window matching '$Title'"; exit 2 }
[Win]::Foreground($found)
Start-Sleep -Milliseconds 350

$rc = New-Object Win+RECT
[void][Win]::GetClientRect($found, [ref]$rc)
$origin = New-Object Win+POINT
[void][Win]::ClientToScreen($found, [ref]$origin)
$w = $rc.right - $rc.left
$hgt = $rc.bottom - $rc.top

function ScreenPt([double]$fx, [double]$fy) {
	return , @([int]($origin.x + $w * $fx), [int]($origin.y + $hgt * $fy))
}

$start = ScreenPt $x1 $y1
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($start[0], $start[1])
Start-Sleep -Milliseconds 80
[Win]::mouse_event([Win]::LEFTDOWN, 0, 0, 0, [IntPtr]::Zero)
for ($i = 1; $i -le $Steps; $i++) {
	$t = $i / $Steps
	$fx = $x1 + ($x2 - $x1) * $t
	$fy = $y1 + ($y2 - $y1) * $t
	$p = ScreenPt $fx $fy
	[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($p[0], $p[1])
	Start-Sleep -Milliseconds $DelayMs
}
[Win]::mouse_event([Win]::LEFTUP, 0, 0, 0, [IntPtr]::Zero)
Write-Output "drew on '$([Win]::foundTitle)' (client ${w}x${hgt})"
