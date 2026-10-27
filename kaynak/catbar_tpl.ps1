# =====================================================================
#  Taskbar Kedileri  -  pixel art masaustu widget'i
#  Bagimliligi yok: Windows'ta hazir gelen PowerShell + WinForms yeterli.
#  Baslatmak icin "Kedileri Baslat.bat" dosyasina cift tikla.
#
#  BU DOSYA URETILIR: kaynak/catbar_tpl.ps1 + kaynak/engine.ps1 +
#  kaynak/win/DesktopHost.cs + sprite sheet -> python kaynak/mkdist.py
# =====================================================================
$ErrorActionPreference = 'Stop'
$LogPath = Join-Path $PSScriptRoot 'catbar-hata.log'

try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- masaustu penceresi
# Kurulum gerekmez: C# kaynagi Windows'taki .NET Framework derleyicisiyle
# (Add-Type -> csc.exe) acilista bellege derlenir. Pencere masaustu
# katmanina yerlesir: acilan her pencere kedilerin ONUNE gecer.
$DesktopHostCs = @'
__DESKTOPHOST_CS__
'@

function Write-CatLog([string]$Message) {
  try {
    Add-Content -Path $LogPath -Encoding UTF8 -Value ("[{0}] [bilgi] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
  } catch { }
}

# Auto (onerilen) | Desktop | Bottom.  Test icin konsolda:  set CATBAR_MODE=Bottom
$DesktopModeSetting = 'Auto'
if ($env:CATBAR_MODE) { $DesktopModeSetting = $env:CATBAR_MODE }

$script:DesktopOk = $false
try {
  if (-not ('TaskbarKedileri.DesktopForm' -as [type])) {
    Add-Type -TypeDefinition $DesktopHostCs -Language CSharp `
             -ReferencedAssemblies System.Windows.Forms, System.Drawing `
             -IgnoreWarnings -ErrorAction Stop
  }
  # Per-Monitor-V2 DPI: ilk WorkingArea sorgusundan ve pencereden ONCE.
  [void][TaskbarKedileri.DesktopHost]::InitDpi()
  $script:DesktopOk = $true
  Write-CatLog ('DesktopHost hazir: ' + [TaskbarKedileri.DesktopHost]::Describe())
}
catch {
  Write-CatLog ('DesktopHost kullanilamadi, eski TopMost pencereye donuluyor: ' + $_.Exception.Message)
}

function Get-WorkArea {
  if ($script:DesktopOk) { return [TaskbarKedileri.DesktopHost]::GetWorkArea() }
  return [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
}
function Get-PixelScale {
  if ($script:DesktopOk) { return [int][TaskbarKedileri.DesktopHost]::GetPixelScale() }
  return 1
}

# ---------------------------------------------------------------- sprite
$CELL_W = __CELLW__
$CELL_H = __CELLH__
$SHEET_W = __SHEETW__
$FRAMES = __FRAMES__

$sheetBytes = [Convert]::FromBase64String(@'
__B64__
'@)
$ms       = New-Object System.IO.MemoryStream(,$sheetBytes)
$Sheet    = [System.Drawing.Image]::FromStream($ms)
$SheetBmp = New-Object System.Drawing.Bitmap $Sheet       # tiklama testi (GetPixel)
$SheetF   = New-Object System.Drawing.Bitmap $Sheet       # aynali kopya
$SheetF.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)

# ---------------------------------------------------------------- sahne motoru
# (kaynak/engine.ps1 - kaynak/scene.js ile birebir ayni)
__ENGINE__

# ---------------------------------------------------------------- ayarlar
$KEY       = [System.Drawing.Color]::FromArgb(255, 0, 255)   # saydamlik anahtari
$UserScale = 2                   # menudeki "Boyut Nx"
$PxMul     = Get-PixelScale      # DPI carpani: %100-125 -> 1, %150-225 -> 2 (net pikseller)
$Scale     = $UserScale * $PxMul
$script:Paused = $false

$wa = Get-WorkArea
Rng-Seed ([double]((Get-Date).Ticks % 2147483646))
$script:S = New-State ([Math]::Floor([double]$wa.Width / $Scale))

# ---------------------------------------------------------------- cizim
function Draw-Frame($g, $name, $px, $py, $flip) {
  $cell = $FRAMES[$name]
  if ($null -eq $cell) { return }
  $sx = $cell[0]; $sy = $cell[1]
  if ($flip) { $img = $SheetF; $sx = $SHEET_W - $sx - $CELL_W } else { $img = $Sheet }
  $src = New-Object System.Drawing.Rectangle $sx, $sy, $CELL_W, $CELL_H
  $dst = New-Object System.Drawing.Rectangle ([int]$px), ([int]$py), ($CELL_W * $script:Scale), ($CELL_H * $script:Scale)
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
}

# ---------------------------------------------------------------- pencere
if ($script:DesktopOk) {
  $form = New-Object TaskbarKedileri.DesktopForm
  try { $form.RequestedMode = $DesktopModeSetting }
  catch { Write-CatLog "Gecersiz CATBAR_MODE '$DesktopModeSetting' (Auto/Desktop/Bottom) - Auto kullaniliyor" }
} else {
  # Yedek (C# derlenemezse): siradan, ustte-tutulmayan pencere.
  $form = New-Object System.Windows.Forms.Form
  $form.TopMost = $false
}
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar   = $false
$form.StartPosition   = 'Manual'
$form.BackColor       = $KEY
$form.TransparencyKey = $KEY
$form.Text            = 'Taskbar Kedileri'
$form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($form, $true, $null)

function Update-Bounds {
  $wa = Get-WorkArea
  $script:PxMul = Get-PixelScale
  $script:Scale = $script:UserScale * $script:PxMul
  $h  = ($CELL_H + $HEADROOM) * $script:Scale
  # Bounds HER ZAMAN ekran koordinati; DesktopForm Progman/WorkerW icindeyken kendisi cevirir.
  $form.Bounds = New-Object System.Drawing.Rectangle $wa.X, ($wa.Bottom - $h), $wa.Width, $h
  Set-ScreenW $script:S ([Math]::Floor([double]$wa.Width / $script:Scale))
}
Update-Bounds

if ($script:DesktopOk) {
  # taskbar tasindi / boyut / otomatik gizle, cozunurluk ya da DPI degisti, Explorer yeniden basladi
  $form.Add_WorkAreaChanged({ Update-Bounds; $form.Invalidate() })
  $form.Add_ModeChanged({ Write-CatLog ('Masaustu modu: {0} | {1}' -f $form.Mode, $form.ModeDetail) })
  $form.Add_LogMessage({ param($s, $e) Write-CatLog ('DesktopHost: ' + $e.Message) })
}

$form.Add_Paint({
  param($sender, $e)
  $g = $e.Graphics
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::None
  $g.Clear($KEY)
  $z = $script:Scale
  foreach ($d in $script:S.draw) { Draw-Frame $g $d.k ($d.x * $z) ($d.y * $z) $d.f }
})

# ---------------------------------------------------------------- etkilesim
# Kedi: ziplar + kalp. Dogis: sevinir; 2-3 sevmede bikar (kollar kavusur, yuz kizarir).
$HitFn = {
  param($k, $lx, $ly)
  $c = $FRAMES[$k]
  if ($null -eq $c) { return $false }
  return ($SheetBmp.GetPixel([int]($c[0] + $lx), [int]($c[1] + $ly)).A -gt 0)
}
$form.Add_MouseDown({
  param($sender, $e)
  if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
  $z = $script:Scale
  $sx = [Math]::Floor([double]$e.X / $z); $sy = [Math]::Floor([double]$e.Y / $z)
  [void](Click-At $script:S $sx $sy $CELL_W $CELL_H $HitFn)
  $form.Invalidate()
})

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miPause = $menu.Items.Add('Duraklat')
$miPause.Add_Click({
  $script:Paused = -not $script:Paused
  $miPause.Text = if ($script:Paused) { 'Devam et' } else { 'Duraklat' }
})
[void]$menu.Items.Add('-')
foreach ($z in 1,2,3) {
  $mi = $menu.Items.Add("Boyut $($z)x")
  $mi.Tag = $z
  # GetNewClosure KULLANMA: kapanis kendi kapsaminda calisir, Update-Bounds'u bulamaz.
  $mi.Add_Click({ param($s,$e2) $script:UserScale = [int]$s.Tag; Update-Bounds; $form.Invalidate() })
}
[void]$menu.Items.Add('-')
$miScene = $menu.Items.Add('Sahneyi degistir')
$miScene.Add_Click({
  $others = @($ORDER | Where-Object { $_ -ne $script:S.scene })
  Apply-Scene $script:S ($others | Get-Random)
})

if ($script:DesktopOk) {
  [void]$menu.Items.Add('-')
  $miMode     = New-Object System.Windows.Forms.ToolStripMenuItem 'Konum'
  $miModeInfo = New-Object System.Windows.Forms.ToolStripMenuItem 'Aktif: ?'
  $miModeInfo.Enabled = $false
  [void]$miMode.DropDownItems.Add($miModeInfo)
  foreach ($pair in @(@('Otomatik', 'Auto'), @('Masaustune yerlestir', 'Desktop'), @('Pencerelerin altinda', 'Bottom'))) {
    $it = New-Object System.Windows.Forms.ToolStripMenuItem $pair[0]
    $it.Tag = $pair[1]
    $it.Add_Click({ param($s,$e2) $form.RequestedMode = [string]$s.Tag })
    [void]$miMode.DropDownItems.Add($it)
  }
  $miMode.Add_DropDownOpening({
    $miModeInfo.Text = 'Aktif: ' + $form.Mode
    foreach ($it in $miMode.DropDownItems) {
      if ($it.Tag) { $it.Checked = ([string]$it.Tag -eq [string]$form.RequestedMode) }
    }
  })
  [void]$menu.Items.Add($miMode)
}

[void]$menu.Items.Add('-')
$miExit = $menu.Items.Add('Cikis')
$miExit.Add_Click({ $form.Close() })
$form.ContextMenuStrip = $menu

# ---------------------------------------------------------------- dongu
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $TICK
$timer.Add_Tick({
  if (-not $script:Paused) { Step-State $script:S }
  $form.Invalidate()
})
$timer.Start()

$form.Add_FormClosed({ $timer.Stop(); [System.Windows.Forms.Application]::Exit() })
# Run($form) DEGIL: Explorer yeniden baslayinca cocuk pencereyi yok eder; formsuz
# dongu ayakta kalir, DesktopForm penceresini yeniden kurar. "Cikis" yine Exit cagirir.
$form.Show()
[System.Windows.Forms.Application]::Run()

}
catch {
  $msg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.GetType().Name): $($_.Exception.Message)`r`n$($_.ScriptStackTrace)`r`n"
  Add-Content -Path $LogPath -Value $msg -Encoding UTF8
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
  [System.Windows.Forms.MessageBox]::Show("Kedi widget'i baslatilamadi.`r`n`r`n$($_.Exception.Message)`r`n`r`nAyrinti: $LogPath", 'Taskbar Kedileri') | Out-Null
}
