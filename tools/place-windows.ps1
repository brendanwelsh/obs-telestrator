# place-windows.ps1 — position the OBS main window on the left (docks + preview in
# the recorded region) and the windowed projector off to the right, OUTSIDE that
# region, so the projector can be foreground (drawable) without occluding OBS.
param(
	[int]$ObsX = 0, [int]$ObsY = 0, [int]$ObsW = 1300, [int]$ObsH = 1040,
	[int]$ProjX = 1306, [int]$ProjY = 40, [int]$ProjW = 600, [int]$ProjH = 360
)
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class Win {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int hh, uint f);
  public static IntPtr Found = IntPtr.Zero;
  public static void Find(string m, bool starts) {
    Found = IntPtr.Zero;
    EnumWindows((h, l) => {
      var sb = new StringBuilder(512); GetWindowText(h, sb, 512); var t = sb.ToString();
      bool hit = starts ? t.StartsWith(m) : t.Contains(m);
      if (IsWindowVisible(h) && hit && t.Length > 4) { Found = h; return false; }
      return true;
    }, IntPtr.Zero);
  }
}
"@
# OBS main (title starts with "OBS ")
[Win]::Find("OBS ", $true)
if ([Win]::Found -ne [IntPtr]::Zero) {
	[void][Win]::ShowWindow([Win]::Found, 1)   # SW_RESTORE
	Start-Sleep -Milliseconds 300
	[void][Win]::SetWindowPos([Win]::Found, [IntPtr]::Zero, $ObsX, $ObsY, $ObsW, $ObsH, 0x0040)
	Write-Output "placed OBS"
} else { Write-Output "OBS window not found" }
# Windowed projector (title contains "Projector")
[Win]::Find("Projector", $false)
if ([Win]::Found -ne [IntPtr]::Zero) {
	[void][Win]::SetWindowPos([Win]::Found, [IntPtr]::Zero, $ProjX, $ProjY, $ProjW, $ProjH, 0x0040)
	Write-Output "placed Projector"
} else { Write-Output "Projector window not found" }
