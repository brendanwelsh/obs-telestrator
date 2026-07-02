# capture-obs.ps1 — screenshot the OBS main window to a PNG.
# DPI-aware (physical-pixel coords on HiDPI) and captures via PrintWindow with
# PW_RENDERFULLCONTENT, so it works even if another window overlaps OBS.
param(
	[string]$Out = "obs-ui.png",
	[string]$Match = "OBS ",
	[int]$X = 40, [int]$Y = 40, [int]$W = 2000, [int]$H = 1200,  # physical px
	[switch]$NoPlace                                              # capture where it is
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public class Cap {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint flags);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static IntPtr Found = IntPtr.Zero; public static string FoundTitle = "";
  public static void Find(string m) {
    Found = IntPtr.Zero;
    EnumWindows((h, l) => {
      var sb = new StringBuilder(512); GetWindowText(h, sb, 512); var t = sb.ToString();
      if (IsWindowVisible(h) && t.StartsWith(m) && t.Length > 4) { Found = h; FoundTitle = t; return false; }
      return true;
    }, IntPtr.Zero);
  }
}
"@
[void][Cap]::SetProcessDPIAware()   # physical pixels everywhere below
[Cap]::Find($Match)
if ([Cap]::Found -eq [IntPtr]::Zero) { Write-Error "no window starting with '$Match'"; exit 2 }
$h = [Cap]::Found
if (-not $NoPlace) {
	# NB: no ShowWindow(SW_RESTORE) here — restoring a snapped window re-applies
	# its huge saved geometry. And the shell can revert a resize ~1s later (snap
	# re-assert), so keep setting until the rect actually sticks.
	for ($i = 0; $i -lt 6; $i++) {
		[void][Cap]::SetWindowPos($h, [IntPtr]::Zero, $X, $Y, $W, $H, 0x0040)
		Start-Sleep -Milliseconds 700
		$rr = New-Object Cap+RECT
		[void][Cap]::GetWindowRect($h, [ref]$rr)
		if (($rr.Right - $rr.Left) -eq $W -and ($rr.Bottom - $rr.Top) -eq $H) { break }
	}
	[void][Cap]::SetForegroundWindow($h)
	Start-Sleep -Milliseconds 400
}
$r = New-Object Cap+RECT
[void][Cap]::GetWindowRect($h, [ref]$r)
$w = $r.Right - $r.Left; $hh = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap($w, $hh)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[void][Cap]::PrintWindow($h, $hdc, 2)   # 2 = PW_RENDERFULLCONTENT (D3D content too)
$g.ReleaseHdc($hdc)
$bmp.Save($Out)
$g.Dispose(); $bmp.Dispose()
Write-Output "captured '$([Cap]::FoundTitle)' ${w}x${hh} @ $($r.Left),$($r.Top) -> $Out"
