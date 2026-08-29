# =====================================================================
#  Taskbar Kedileri  -  pixel art masaustu widget'i
#  Bagimliligi yok: Windows'ta hazir gelen PowerShell + WinForms yeterli.
#  Baslatmak icin "Kedileri Baslat.bat" dosyasina cift tikla.
# =====================================================================
$ErrorActionPreference = 'Stop'
$LogPath = Join-Path $PSScriptRoot 'catbar-hata.log'

try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- sprite
$CELL_W = __CELLW__
$CELL_H = __CELLH__
$SHEET_W = __SHEETW__
$FRAMES = __FRAMES__

$sheetBytes = [Convert]::FromBase64String(@'
__B64__
'@)
$ms     = New-Object System.IO.MemoryStream(,$sheetBytes)
$Sheet  = [System.Drawing.Image]::FromStream($ms)
$SheetF = New-Object System.Drawing.Bitmap $Sheet
$SheetF.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)

# ---------------------------------------------------------------- ayarlar
$KEY      = [System.Drawing.Color]::FromArgb(255, 0, 255)   # saydamlik anahtari
$STAGE_W  = 200        # gruba ayrilan ic genislik (piksel)
$HEADROOM = 14         # kalp/zzz efektleri icin ust bosluk
$TICK     = 80         # ms
$Scale    = 2

# ---------------------------------------------------------------- animasyonlar
$ANIM = @{
  walk   = @{ f = @('walk_1','walk_2','walk_3','walk_4'); hold = 2 }
  stand  = @{ f = @('stand');                             hold = 8 }
  sit    = @{ f = @('sit_a','sit_a','sit_a','sit_blink'); hold = 8 }
  sitwag = @{ f = @('sit_a','sit_b');                     hold = 6 }
  lookup = @{ f = @('lookup','lookup','lookup','sit_blink'); hold = 8 }
  jump   = @{ f = @('jump_1','jump_2','jump_3','jump_2','jump_1'); hold = 2 }
  sleep  = @{ f = @('sleep_a','sleep_b');                 hold = 14 }
  yawn   = @{ f = @('sleep_a','yawn','yawn','stretch','stretch','sleep_a'); hold = 5 }
  rub    = @{ f = @('rub_a','rub_b');                     hold = 5 }
  happy  = @{ f = @('sit_happy','sit_b');                 hold = 5 }
}
$HANIM = @{
  hwalk  = @{ f = @('human_walk_1','human_walk_2','human_walk_3','human_walk_4'); hold = 3 }
  hstand = @{ f = @('human_stand');                       hold = 10 }
  hwave  = @{ f = @('human_wave_1','human_wave_2','human_wave_3','human_wave_2'); hold = 3 }
  hpet   = @{ f = @('human_crouch_1','human_crouch_2');   hold = 6 }
}

# ---------------------------------------------------------------- sahneler
$SCENES = @{
  parade = @{ dur = @(180,300); move = 2; flipHuman = $false
              human = @{ x = 150; a = 'hwalk' }
              cats  = @(@{x=108;a='walk'}, @{x=68;a='walk'}, @{x=28;a='walk'}) }
  play   = @{ dur = @(200,320); move = 0; flipHuman = $true
              human = @{ x = 152; a = 'hwave' }
              cats  = @(@{x=112;a='jump'}, @{x=74;a='lookup'}, @{x=34;a='sit'}) }
  pet    = @{ dur = @(200,320); move = 0; flipHuman = $true
              human = @{ x = 146; a = 'hpet' }
              cats  = @(@{x=116;a='rub'}, @{x=76;a='happy'}, @{x=36;a='sitwag'}) }
  nap    = @{ dur = @(250,400); move = 0; flipHuman = $false
              human = @{ x = 150; a = 'hstand' }
              cats  = @(@{x=104;a='sleep'}, @{x=66;a='yawn'}, @{x=26;a='sleep'}) }
}
$ORDER = @('parade','play','pet','nap')

# ---------------------------------------------------------------- durum
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$script:S = @{
  scene = 'parade'; t = 0; dur = 200; phase = 'run'; paused = $false
  groupX = [int]([Math]::Floor($wa.Width / $Scale / 2) - $STAGE_W / 2)
  dir = 1
  screenW = [int]([Math]::Floor($wa.Width / $Scale))
  actors = @(
    @{ name='dogis';  x=150.0; tx=150.0; anim='hwalk'; nextAnim='hwalk'; fi=0; fh=0; flip=$false; nextFlip=$false; y=0 }
    @{ name='tarcin'; x=108.0; tx=108.0; anim='walk';  nextAnim='walk';  fi=0; fh=0; flip=$false; nextFlip=$false; y=0 }
    @{ name='maya';   x= 68.0; tx= 68.0; anim='walk';  nextAnim='walk';  fi=0; fh=0; flip=$false; nextFlip=$false; y=0 }
    @{ name='zilli';  x= 28.0; tx= 28.0; anim='walk';  nextAnim='walk';  fi=0; fh=0; flip=$false; nextFlip=$false; y=0 }
  )
  fx = New-Object System.Collections.ArrayList
  poke = @{}      # tiklanan kedi -> kalan tick
}

function Get-AnimSet($a) {
  if ($a.name -eq 'dogis') { return $HANIM[$a.anim] } else { return $ANIM[$a.anim] }
}
function Get-FrameName($a) {
  $set = Get-AnimSet $a
  $f = $set.f[$a.fi % $set.f.Count]
  if ($a.name -eq 'dogis') { return $f } else { return "$($a.name)_$f" }
}

function Set-Scene($name) {
  $sc = $SCENES[$name]
  $script:S.scene = $name; $script:S.t = 0; $script:S.phase = 'move'
  $script:S.dur = $sc.dur[0] + (Get-Random -Minimum 0 -Maximum ($sc.dur[1] - $sc.dur[0]))
  $script:S.actors[0].tx = [double]$sc.human.x
  $script:S.actors[0].nextAnim = $sc.human.a
  $script:S.actors[0].nextFlip = $sc.flipHuman
  # roller her sahnede karisir: hep ayni kedi ziplamasin
  $perm = @(0,1,2) | Get-Random -Count 3
  for ($i = 0; $i -lt 3; $i++) {
    $slot = $perm[$i]
    $script:S.actors[$i+1].tx       = [double]$sc.cats[$slot].x
    $script:S.actors[$i+1].nextAnim = $sc.cats[$slot].a
    $script:S.actors[$i+1].nextFlip = $false
  }
}

function Step-World {
  $st = $script:S
  $st.t++
  $sc = $SCENES[$st.scene]

  if ($st.phase -eq 'move') {
    $moving = $false
    foreach ($a in $st.actors) {
      $d = $a.tx - $a.x
      if ([Math]::Abs($d) -gt 1.5) {
        $a.x = $a.x + ([Math]::Sign($d) * 2)
        $a.flip = ($d -lt 0)
        $a.anim = if ($a.name -eq 'dogis') { 'hwalk' } else { 'walk' }
        $moving = $true
      } else {
        $a.x = $a.tx; $a.anim = $a.nextAnim; $a.flip = $a.nextFlip
      }
    }
    if (-not $moving) { $st.phase = 'run'; $st.t = 0 }
  }
  else {
    if ($sc.move -ne 0) {
      $st.groupX += $sc.move * $st.dir
      if ($st.groupX -lt 8) {
        $st.groupX = 8; $st.dir = 1
        foreach ($a in $st.actors) { $a.flip = $false }
      }
      if ($st.groupX -gt ($st.screenW - $STAGE_W - 8)) {
        $st.groupX = $st.screenW - $STAGE_W - 8; $st.dir = -1
        foreach ($a in $st.actors) { $a.flip = $true }
      }
    }
    if ($st.t -gt $st.dur) {
      $others = $ORDER | Where-Object { $_ -ne $st.scene }
      Set-Scene ($others | Get-Random)
    }
  }

  # kare ilerlet
  foreach ($a in $st.actors) {
    $set = Get-AnimSet $a
    $a.fh++
    if ($a.fh -ge $set.hold) { $a.fh = 0; $a.fi = ($a.fi + 1) % $set.f.Count }
    if ($a.anim -eq 'jump') {
      $f = $set.f[$a.fi]
      $a.y = if ($f -eq 'jump_2') { -5 } elseif ($f -eq 'jump_3') { -3 } else { 0 }
    } else { $a.y = 0 }
  }

  # tiklama tepkisi suresi
  foreach ($k in @($st.poke.Keys)) {
    $st.poke[$k]--
    if ($st.poke[$k] -le 0) {
      $a = $st.actors | Where-Object { $_.name -eq $k }
      if ($a) { $a.anim = $a.nextAnim }
      $st.poke.Remove($k)
    }
  }

  # efektler
  if ($st.phase -eq 'run') {
    if ($st.scene -eq 'pet'  -and ($st.t % 22) -eq 0) {
      $petted = ($st.actors | Where-Object { $_.anim -eq 'rub' } | Select-Object -First 1)
      if ($null -eq $petted) { $petted = $st.actors[1] }
      $hk = @('fx_heart','fx_heart_s') | Get-Random
      [void]$st.fx.Add(@{k=$hk; x=$petted.x+4; y=-4.0; life=26})
    }
    if ($st.scene -eq 'nap'  -and ($st.t % 16) -eq 0) {
      $sleeper = ($st.actors | Where-Object { $_.anim -eq 'sleep' } | Get-Random)
      if ($null -eq $sleeper) { $sleeper = $st.actors[1] }
      [void]$st.fx.Add(@{k='zzz'; x=$sleeper.x+8; y=-2.0; life=30})
    }
    if ($st.scene -eq 'play' -and ($st.t % 30) -eq 0) { [void]$st.fx.Add(@{k='fx_spark'; x=$st.actors[0].x-12; y=-14.0; life=12}) }
  }
  for ($i = $st.fx.Count - 1; $i -ge 0; $i--) {
    $st.fx[$i].life--
    $st.fx[$i].y = $st.fx[$i].y - 0.5
    if ($st.fx[$i].life -le 0) { $st.fx.RemoveAt($i) }
  }
}

# ---------------------------------------------------------------- cizim
function Draw-Frame($g, $name, $px, $py, $flip) {
  $cell = $FRAMES[$name]
  if ($null -eq $cell) { return }
  $sx = $cell[0]; $sy = $cell[1]
  if ($flip) { $img = $SheetF; $sx = $SHEET_W - $sx - $CELL_W } else { $img = $Sheet }
  $src = New-Object System.Drawing.Rectangle $sx, $sy, $CELL_W, $CELL_H
  $dst = New-Object System.Drawing.Rectangle ([int]$px), ([int]$py), ($CELL_W * $Scale), ($CELL_H * $Scale)
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
}

# ---------------------------------------------------------------- pencere
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar   = $false
$form.TopMost         = $true
$form.StartPosition   = 'Manual'
$form.BackColor       = $KEY
$form.TransparencyKey = $KEY
$form.Text            = 'Taskbar Kedileri'
$form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($form, $true, $null)

function Update-Bounds {
  $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $h  = ($CELL_H + $HEADROOM) * $Scale
  $form.Bounds = New-Object System.Drawing.Rectangle $wa.X, ($wa.Bottom - $h), $wa.Width, $h
  $script:S.screenW = [int]([Math]::Floor($wa.Width / $Scale))
  if ($script:S.groupX -gt ($script:S.screenW - $STAGE_W - 8)) {
    $script:S.groupX = [Math]::Max(8, $script:S.screenW - $STAGE_W - 8)
  }
}
Update-Bounds

$form.Add_Paint({
  param($sender, $e)
  $g = $e.Graphics
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::None
  $g.Clear($KEY)
  $st = $script:S
  foreach ($a in $st.actors) {
    Draw-Frame $g (Get-FrameName $a) (($st.groupX + $a.x) * $Scale) (($HEADROOM + $a.y) * $Scale) $a.flip
  }
  foreach ($f in $st.fx) {
    $n = $f.k
    if ($n -eq 'zzz') {
      $lvl = [Math]::Max(1, [Math]::Min(3, 3 - [int]((30 - $f.life) / 10)))
      $n = "fx_zzz_$lvl"
    }
    Draw-Frame $g $n (($st.groupX + $f.x) * $Scale) (($HEADROOM + $f.y - 14) * $Scale) $false
  }
})

# ---------------------------------------------------------------- etkilesim
$form.Add_MouseDown({
  param($sender, $e)
  if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
  $st = $script:S
  $sx = $e.X / $Scale - $st.groupX
  foreach ($a in $st.actors) {
    if ($a.name -eq 'dogis') { continue }
    if ($sx -ge $a.x -and $sx -le ($a.x + $CELL_W)) {
      $a.anim = 'jump'; $a.fi = 0; $a.fh = 0
      $st.poke[$a.name] = 26
      [void]$st.fx.Add(@{ k = 'fx_heart'; x = $a.x + 6; y = -4.0; life = 24 })
      break
    }
  }
})

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miPause = $menu.Items.Add('Duraklat')
$miPause.Add_Click({
  $script:S.paused = -not $script:S.paused
  $miPause.Text = if ($script:S.paused) { 'Devam et' } else { 'Duraklat' }
})
[void]$menu.Items.Add('-')
foreach ($z in 1,2,3) {
  $mi = $menu.Items.Add("Boyut $($z)x")
  $mi.Tag = $z
  $mi.Add_Click({ param($s,$e2) $script:Scale = [int]$s.Tag; Update-Bounds; $form.Invalidate() }.GetNewClosure())
}
[void]$menu.Items.Add('-')
$miScene = $menu.Items.Add('Sahneyi degistir')
$miScene.Add_Click({
  $others = $ORDER | Where-Object { $_ -ne $script:S.scene }
  Set-Scene ($others | Get-Random)
})
[void]$menu.Items.Add('-')
$miExit = $menu.Items.Add('Cikis')
$miExit.Add_Click({ $form.Close() })
$form.ContextMenuStrip = $menu

# ---------------------------------------------------------------- dongu
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $TICK
$timer.Add_Tick({
  if (-not $script:S.paused) { Step-World }
  $form.Invalidate()
})
$timer.Start()

$form.Add_FormClosed({ $timer.Stop(); [System.Windows.Forms.Application]::Exit() })
[System.Windows.Forms.Application]::Run($form)

}
catch {
  $msg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.GetType().Name): $($_.Exception.Message)`r`n$($_.ScriptStackTrace)`r`n"
  Add-Content -Path $LogPath -Value $msg -Encoding UTF8
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
  [System.Windows.Forms.MessageBox]::Show("Kedi widget'i baslatilamadi.`r`n`r`n$($_.Exception.Message)`r`n`r`nAyrinti: $LogPath", 'Taskbar Kedileri') | Out-Null
}
