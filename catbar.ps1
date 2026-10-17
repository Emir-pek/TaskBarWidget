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
$CELL_W = 34
$CELL_H = 33
$SHEET_W = 340
$FRAMES = @{
  'fx_heart' = @(0,0)
  'fx_heart_s' = @(34,0)
  'fx_spark' = @(68,0)
  'fx_zzz_1' = @(102,0)
  'fx_zzz_2' = @(136,0)
  'fx_zzz_3' = @(170,0)
  'human_crouch_1' = @(204,0)
  'human_crouch_2' = @(238,0)
  'human_stand' = @(272,0)
  'human_walk_1' = @(306,0)
  'human_walk_2' = @(0,33)
  'human_walk_3' = @(34,33)
  'human_walk_4' = @(68,33)
  'human_wave_1' = @(102,33)
  'human_wave_2' = @(136,33)
  'human_wave_3' = @(170,33)
  'maya_jump_1' = @(204,33)
  'maya_jump_2' = @(238,33)
  'maya_jump_3' = @(272,33)
  'maya_lookup' = @(306,33)
  'maya_rub_a' = @(0,66)
  'maya_rub_b' = @(34,66)
  'maya_sit_a' = @(68,66)
  'maya_sit_b' = @(102,66)
  'maya_sit_blink' = @(136,66)
  'maya_sit_happy' = @(170,66)
  'maya_sleep_a' = @(204,66)
  'maya_sleep_b' = @(238,66)
  'maya_stand' = @(272,66)
  'maya_stretch' = @(306,66)
  'maya_walk_1' = @(0,99)
  'maya_walk_2' = @(34,99)
  'maya_walk_3' = @(68,99)
  'maya_walk_4' = @(102,99)
  'maya_yawn' = @(136,99)
  'tarcin_jump_1' = @(170,99)
  'tarcin_jump_2' = @(204,99)
  'tarcin_jump_3' = @(238,99)
  'tarcin_lookup' = @(272,99)
  'tarcin_rub_a' = @(306,99)
  'tarcin_rub_b' = @(0,132)
  'tarcin_sit_a' = @(34,132)
  'tarcin_sit_b' = @(68,132)
  'tarcin_sit_blink' = @(102,132)
  'tarcin_sit_happy' = @(136,132)
  'tarcin_sleep_a' = @(170,132)
  'tarcin_sleep_b' = @(204,132)
  'tarcin_stand' = @(238,132)
  'tarcin_stretch' = @(272,132)
  'tarcin_walk_1' = @(306,132)
  'tarcin_walk_2' = @(0,165)
  'tarcin_walk_3' = @(34,165)
  'tarcin_walk_4' = @(68,165)
  'tarcin_yawn' = @(102,165)
  'zilli_jump_1' = @(136,165)
  'zilli_jump_2' = @(170,165)
  'zilli_jump_3' = @(204,165)
  'zilli_lookup' = @(238,165)
  'zilli_rub_a' = @(272,165)
  'zilli_rub_b' = @(306,165)
  'zilli_sit_a' = @(0,198)
  'zilli_sit_b' = @(34,198)
  'zilli_sit_blink' = @(68,198)
  'zilli_sit_happy' = @(102,198)
  'zilli_sleep_a' = @(136,198)
  'zilli_sleep_b' = @(170,198)
  'zilli_stand' = @(204,198)
  'zilli_stretch' = @(238,198)
  'zilli_walk_1' = @(272,198)
  'zilli_walk_2' = @(306,198)
  'zilli_walk_3' = @(0,231)
  'zilli_walk_4' = @(34,231)
  'zilli_yawn' = @(68,231)
}

$sheetBytes = [Convert]::FromBase64String(@'
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
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
