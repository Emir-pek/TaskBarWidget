# =====================================================================
#  ORTAK SAHNE MOTORU - PowerShell portu
#  kaynak/scene.js'in BIREBIR karsiligidir. Birini degistirirsen digerini
#  de degistir ve kaynak/test/parity.sh ile karsilastir (ayni tohum, ayni
#  tiklamalar -> her tick ayni ozet satiri).
#  Dikkat: [int] yuvarlar (banker's), JS Math.floor gibi davranmaz;
#  her yerde [Math]::Floor kullaniliyor.
# =====================================================================

$STAGE_W      = 200
$TICK         = 80
$HEADROOM     = 34
$SUN_TOP      = 0
$SUN_CX       = 16
$DECOR_W      = 37
$DECOR_MARGIN = 6
$FLOWER_DX    = 19

# ---- tohumlu rastgele sayi (Park-Miller MINSTD) -----------------------
$script:RNG = [long]1
function Rng-Seed([double]$s) { $script:RNG = [long](([Math]::Floor([double][Math]::Abs($s)) % 2147483646) + 1) }
function Rnd { $script:RNG = ($script:RNG * [long]48271) % [long]2147483647; return ([double]($script:RNG - 1)) / 2147483646 }
function RandInt($a, $b) { return $a + [Math]::Floor([double](Rnd) * ($b - $a + 1)) }
function Shuffle3 {
  $p = @(0, 1, 2)
  for ($i = 2; $i -gt 0; $i--) {
    $j = [int][Math]::Floor([double](Rnd) * ($i + 1))
    $t = $p[$i]; $p[$i] = $p[$j]; $p[$j] = $t
  }
  return ,$p
}

# ---- animasyonlar -------------------------------------------------------
$ANIM = @{
  walk   = @{ f = @('walk_1','walk_2','walk_3','walk_4'); hold = 2 }
  stand  = @{ f = @('stand'); hold = 8 }
  sit    = @{ f = @('sit_a','sit_a','sit_a','sit_blink'); hold = 8 }
  sitwag = @{ f = @('sit_a','sit_b'); hold = 6 }
  lookup = @{ f = @('lookup','lookup','lookup','sit_blink'); hold = 8 }
  jump   = @{ f = @('jump_1','jump_2','jump_3','jump_2','jump_1'); hold = 2 }
  sleep  = @{ f = @('sleep_a','sleep_b'); hold = 14; bob = @(0, -1) }
  yawn   = @{ f = @('sleep_a','yawn','yawn','stretch','stretch','sleep_a'); hold = 5 }
  rub    = @{ f = @('rub_a','rub_b'); hold = 5 }
  happy  = @{ f = @('sit_happy','sit_b'); hold = 5 }
}
$HANIM = @{
  hwalk  = @{ f = @('dogis_walk_1','dogis_walk_2','dogis_walk_3','dogis_walk_4'); hold = 3 }
  hstand = @{ f = @('dogis_stand'); hold = 10 }
  hwave  = @{ f = @('dogis_wave_1','dogis_wave_2','dogis_wave_3','dogis_wave_2'); hold = 3 }
  hpet   = @{ f = @('dogis_crouch_1','dogis_crouch_2'); hold = 6 }
  hjoy   = @{ f = @('dogis_pet_1','dogis_pet_2'); hold = 4 }
  hangry = @{ f = @('dogis_angry_1','dogis_angry_2'); hold = 5 }
}

# ---- sahneler -----------------------------------------------------------
$SCENES = @{
  parade = @{ dur = @(180, 300); follow = $true;  sun = 0.6; flipDogis = $false
              dogis = @{ x = 150; a = 'hwalk' }
              cats  = @(@{ x = 108; a = 'walk' }, @{ x = 68; a = 'walk' }, @{ x = 28; a = 'walk' }) }
  play   = @{ dur = @(200, 320); follow = $false; sun = 0.1; flipDogis = $true
              dogis = @{ x = 152; a = 'hwave' }
              cats  = @(@{ x = 112; a = 'jump' }, @{ x = 74; a = 'lookup' }, @{ x = 34; a = 'sit' }) }
  pet    = @{ dur = @(200, 320); follow = $false; sun = 0.1; flipDogis = $true
              dogis = @{ x = 146; a = 'hpet' }
              cats  = @(@{ x = 116; a = 'rub' }, @{ x = 76; a = 'happy' }, @{ x = 36; a = 'sitwag' }) }
  nap    = @{ dur = @(250, 400); follow = $false; sun = 0.1; flipDogis = $false
              dogis = @{ x = 150; a = 'hstand' }
              cats  = @(@{ x = 104; a = 'sleep' }, @{ x = 66; a = 'yawn' }, @{ x = 26; a = 'sleep' }) }
}
$ORDER = @('parade', 'play', 'pet', 'nap')

$SNIFF = @(@('giraffe_lean', 4), @('giraffe_sniff_1', 6), @('giraffe_sniff_2', 6),
           @('giraffe_sniff_1', 6), @('giraffe_sniff_2', 6), @('giraffe_sniff_1', 5),
           @('giraffe_lean', 4))
$FLWIG = @('flower_1', 'flower_2', 'flower_1', 'flower_3')

# ---- durum --------------------------------------------------------------
function New-Actor($name, $x, $anim) {
  return @{ name = $name; x = $x; tx = $x; anim = $anim; nextAnim = $anim; fi = 0; fh = 0
            flip = $false; nextFlip = $false; y = 0; ov = ''; ovT = 0 }
}

function New-State($screenW) {
  $st = @{
    scene = 'parade'; t = 0; clock = 0; dur = 200; phase = 'run'; screenW = $screenW
    groupX = 0; vel = 0; lead = 60
    sun = @{ x = 0; dir = 1 }
    dg  = @{ pets = 0; need = 3; last = -1000 }
    dc  = @{ wait = 0; seq = -1; seqT = 0; blink = 0; blinkWait = 0 }
    actors = @((New-Actor 'dogis' 150 'hwalk'), (New-Actor 'tarcin' 108 'walk'),
               (New-Actor 'maya' 68 'walk'), (New-Actor 'zilli' 28 'walk'))
    fx = (New-Object System.Collections.ArrayList)
    draw = (New-Object System.Collections.ArrayList)
  }
  $st.groupX = [Math]::Floor([double]$screenW / 2 - $STAGE_W / 2)
  $st.sun.x = $st.groupX + $STAGE_W / 2 + 60
  $st.dg.need = RandInt 2 3
  $st.dc.wait = RandInt 150 300
  $st.dc.blinkWait = RandInt 40 120
  Clamp-World $st
  Build-Draw $st
  return $st
}

# ---- yerlesim --------------------------------------------------------------
function Get-DecorX($st)   { return $st.screenW - $DECOR_MARGIN - $DECOR_W }
function Get-GroupMax($st) { return [Math]::Max([double]8, [double]((Get-DecorX $st) - 8 - $STAGE_W)) }
function Get-SunMin($st)   { return 24 }
function Get-SunMax($st)   { return [Math]::Max([double]25, [double]((Get-DecorX $st) - 24)) }

function Clamp-World($st) {
  $gm = Get-GroupMax $st
  if ($st.groupX -gt $gm) { $st.groupX = $gm }
  if ($st.groupX -lt 8) { $st.groupX = 8 }
  $sm = Get-SunMax $st
  if ($st.sun.x -gt $sm) { $st.sun.x = $sm }
  if ($st.sun.x -lt (Get-SunMin $st)) { $st.sun.x = Get-SunMin $st }
}
function Set-ScreenW($st, $w) { $st.screenW = $w; Clamp-World $st; Build-Draw $st }

function Get-FollowTarget($st) {
  $t = $st.sun.x - $STAGE_W / 2 - $st.lead
  $gm = Get-GroupMax $st
  if ($t -gt $gm) { $t = $gm }
  if ($t -lt 8) { $t = 8 }
  return $t
}

# ---- sahne gecisi ------------------------------------------------------------
function Apply-Scene($st, $name) {
  $s = $SCENES[$name]
  $st.scene = $name; $st.t = 0; $st.phase = 'move'; $st.vel = 0
  $st.dur = $s.dur[0] + [Math]::Floor([double](Rnd) * ($s.dur[1] - $s.dur[0]))
  $d = $st.actors[0]
  $d.tx = $s.dogis.x; $d.nextAnim = $s.dogis.a; $d.nextFlip = [bool]$s.flipDogis
  $perm = Shuffle3
  for ($i = 0; $i -lt 3; $i++) {
    $slot = $perm[$i]
    $c = $st.actors[$i + 1]
    $c.tx = $s.cats[$slot].x
    $c.nextAnim = $s.cats[$slot].a
    $c.nextFlip = $false
  }
}

function Get-NextScene($st) {
  if ($st.scene -ne 'parade' -and [Math]::Abs((Get-FollowTarget $st) - $st.groupX) -gt 40) { return 'parade' }
  $others = @($ORDER | Where-Object { $_ -ne $st.scene })
  return $others[[int][Math]::Floor([double](Rnd) * $others.Count)]
}

# ---- etkilesim ------------------------------------------------------------------
function Set-Ov($a, $anim, $ticks) { $a.ov = $anim; $a.ovT = $ticks; $a.fi = 0; $a.fh = 0 }

function Find-Actor($st, $id) {
  foreach ($a in $st.actors) { if ($a.name -eq $id) { return $a } }
  return $null
}

# Donus: 'joy' | 'angry' | 'jump' | ''
function Invoke-Poke($st, $id) {
  $a = Find-Actor $st $id
  if ($null -eq $a) { return '' }
  if ($id -eq 'dogis') {
    $d = $st.dg
    if ($a.ov -eq 'hangry') {
      if ($a.ovT -lt 25) { $a.ovT = 25 }
      return 'angry'
    }
    if (($st.clock - $d.last) -gt 150) { $d.pets = 0 }
    $d.pets++; $d.last = $st.clock
    if ($d.pets -ge $d.need) {
      Set-Ov $a 'hangry' 64
      $d.pets = 0; $d.need = RandInt 2 3
      $keep = New-Object System.Collections.ArrayList
      foreach ($f in $st.fx) { if ($f.own -ne 'dogis') { [void]$keep.Add($f) } }
      $st.fx = $keep
      return 'angry'
    }
    Set-Ov $a 'hjoy' 24
    [void]$st.fx.Add(@{ kind = 'fx_heart'; x = $st.groupX + $a.x; y = -6; life = 24; own = 'dogis' })
    return 'joy'
  }
  Set-Ov $a 'jump' 26
  [void]$st.fx.Add(@{ kind = 'fx_heart'; x = $st.groupX + $a.x + 6; y = -4; life = 24 })
  return 'jump'
}

# Sprite pikseli koordinatina tiklama. $hit: { param($k, $lx, $ly) -> opak mi }
function Click-At($st, $sx, $sy, $cw, $ch, $hit) {
  for ($i = $st.draw.Count - 1; $i -ge 0; $i--) {
    $d = $st.draw[$i]
    if (-not $d.id) { continue }
    $lx = $sx - $d.x; $ly = $sy - $d.y
    if ($lx -lt 0 -or $ly -lt 0 -or $lx -ge $cw -or $ly -ge $ch) { continue }
    $hx = if ($d.f) { $cw - 1 - $lx } else { $lx }
    if (& $hit $d.k $hx $ly) { [void](Invoke-Poke $st $d.id); return $d.id }
  }
  return ''
}

# ---- kare adi ---------------------------------------------------------------------
function Get-AnimSet($a) {
  $an = if ($a.ov) { $a.ov } else { $a.anim }
  if ($a.name -eq 'dogis') { return $HANIM[$an] } else { return $ANIM[$an] }
}
function Get-FrameName($a) {
  $set = Get-AnimSet $a
  $f = $set.f[$a.fi % $set.f.Count]
  if ($a.name -eq 'dogis') { return $f } else { return $a.name + '_' + $f }
}

# ---- tick -------------------------------------------------------------------------
function Step-State($st) {
  $st.t++; $st.clock++
  $s = $SCENES[$st.scene]
  $dog = $st.actors[0]
  $hold = ($dog.ov -eq 'hangry')

  # gunes suzulur, kenarlarda doner
  $st.sun.x = $st.sun.x + $s.sun * $st.sun.dir
  $sm = Get-SunMax $st
  if ($st.sun.x -gt $sm) { $st.sun.x = $sm; $st.sun.dir = -1 }
  if ($st.sun.x -lt (Get-SunMin $st)) { $st.sun.x = Get-SunMin $st; $st.sun.dir = 1 }
  $wantLead = 60 * $st.sun.dir
  if ($st.lead -lt $wantLead) { $st.lead = [Math]::Min([double]$wantLead, [double]($st.lead + 0.5)) }
  elseif ($st.lead -gt $wantLead) { $st.lead = [Math]::Max([double]$wantLead, [double]($st.lead - 0.5)) }

  if ($st.phase -eq 'move') {
    $moving = $false
    foreach ($a in $st.actors) {
      if ($a.ov -eq 'hangry') { $moving = $true; continue }
      $d = $a.tx - $a.x
      if ([Math]::Abs($d) -gt 1.5) {
        $a.x = $a.x + [Math]::Sign($d) * 2; $a.flip = ($d -lt 0)
        $a.anim = if ($a.name -eq 'dogis') { 'hwalk' } else { 'walk' }
        $moving = $true
      } else {
        $a.x = $a.tx; $a.anim = $a.nextAnim; $a.flip = $a.nextFlip
      }
    }
    if (-not $moving) { $st.phase = 'run'; $st.t = 0 }
  } else {
    if ($s.follow) {
      $v = 0
      if (-not $hold) {
        $v = ((Get-FollowTarget $st) - $st.groupX) * 0.05
        if ($v -gt 2) { $v = 2 }
        if ($v -lt -2) { $v = -2 }
        if ([Math]::Abs($v) -lt 0.15) { $v = 0 }
      }
      $st.vel = $v
      $st.groupX = $st.groupX + $v
      Clamp-World $st
      $walking = ($v -ne 0)
      $faceLeft = if ($walking) { $v -lt 0 } else { $st.sun.x -lt ($st.groupX + $STAGE_W / 2) }
      foreach ($a in $st.actors) {
        if ($a.name -eq 'dogis') { $a.anim = if ($walking) { 'hwalk' } else { 'hstand' } }
        else { $a.anim = if ($walking) { 'walk' } else { 'stand' } }
        $a.flip = $faceLeft
      }
    }
    if ($st.t -gt $st.dur) { Apply-Scene $st (Get-NextScene $st) }
  }

  # kareler
  foreach ($a in $st.actors) {
    if ($a.ovT -gt 0) {
      $a.ovT--
      if ($a.ovT -eq 0) { $a.ov = ''; $a.fi = 0; $a.fh = 0 }
    }
    $an = if ($a.ov) { $a.ov } else { $a.anim }
    $set = Get-AnimSet $a
    $a.fh++
    if ($a.fh -ge $set.hold) { $a.fh = 0; $a.fi = ($a.fi + 1) % $set.f.Count }
    if ($an -eq 'jump') {
      $f = $set.f[$a.fi]
      $a.y = if ($f -eq 'jump_2') { -5 } elseif ($f -eq 'jump_3') { -3 } else { 0 }
    } elseif ($set.bob) {
      $a.y = $set.bob[$a.fi % $set.bob.Count]
    } else {
      $a.y = 0
    }
  }

  # zurafa ve cicek
  $dc = $st.dc
  if ($dc.blink -gt 0) {
    $dc.blink--
  } else {
    $dc.blinkWait--
    if ($dc.blinkWait -le 0) { $dc.blink = 3; $dc.blinkWait = RandInt 50 140 }
  }
  if ($dc.seq -lt 0) {
    $dc.wait--
    if ($dc.wait -le 0) { $dc.seq = 0; $dc.seqT = 0 }
  } else {
    $dc.seqT++
    if ($dc.seqT -ge $SNIFF[$dc.seq][1]) {
      $dc.seqT = 0; $dc.seq++
      if ($dc.seq -eq 3) { [void]$st.fx.Add(@{ kind = 'fx_heart_s'; x = (Get-DecorX $st) + 12; y = -6; life = 22 }) }
      if ($dc.seq -ge $SNIFF.Count) { $dc.seq = -1; $dc.wait = RandInt 220 480 }
    }
  }

  # sahne efektleri
  if ($st.phase -eq 'run') {
    if ($st.scene -eq 'pet' -and ($st.t % 22) -eq 0) {
      $p = $st.actors[1]
      foreach ($a in $st.actors) { if ($a.anim -eq 'rub') { $p = $a; break } }
      $k = if ((Rnd) -lt 0.5) { 'fx_heart' } else { 'fx_heart_s' }
      [void]$st.fx.Add(@{ kind = $k; x = $st.groupX + $p.x + 4; y = -4; life = 26 })
    }
    if ($st.scene -eq 'nap' -and ($st.t % 16) -eq 0) {
      $sl = @($st.actors | Where-Object { $_.anim -eq 'sleep' })
      $p = if ($sl.Count -gt 0) { $sl[[int][Math]::Floor([double](Rnd) * $sl.Count)] } else { $st.actors[1] }
      [void]$st.fx.Add(@{ kind = 'zzz'; x = $st.groupX + $p.x + 8; y = -2; life = 30 })
    }
    if ($st.scene -eq 'play' -and ($st.t % 30) -eq 0) {
      [void]$st.fx.Add(@{ kind = 'fx_spark'; x = $st.groupX + $st.actors[0].x - 12; y = -14; life = 12 })
    }
  }
  $keep = New-Object System.Collections.ArrayList
  foreach ($f in $st.fx) {
    $f.life--; $f.y = $f.y - 0.5
    if ($f.life -gt 0) { [void]$keep.Add($f) }
  }
  $st.fx = $keep

  Build-Draw $st
}

# ---- cizim listesi ---------------------------------------------------------------
function Add-Draw($out, $k, $x, $y, $f, $id) {
  [void]$out.Add(@{ k = $k; x = $x; y = $y; f = [bool]$f; id = $id })
}

function Build-Draw($st) {
  $out = New-Object System.Collections.ArrayList
  # 1) gunes
  Add-Draw $out ('sun_' + (1 + [Math]::Floor([double]$st.clock / 2) % 4)) ([Math]::Floor([double]$st.sun.x) - $SUN_CX) $SUN_TOP $false ''
  # 2) zurafa + cicek
  $dx = Get-DecorX $st
  $sniffing = ($st.dc.seq -ge 0)
  $div = if ($sniffing) { 4 } else { 12 }
  $fl = $FLWIG[[int]([Math]::Floor([double]$st.clock / $div) % 4)]
  Add-Draw $out $fl ($dx + $FLOWER_DX) $HEADROOM $false ''
  if ($sniffing) { $gf = $SNIFF[$st.dc.seq][0] }
  elseif ($st.dc.blink -gt 0) { $gf = 'giraffe_blink' }
  elseif (([Math]::Floor([double]$st.clock / 14) % 2) -eq 1) { $gf = 'giraffe_idle_2' }
  else { $gf = 'giraffe_idle_1' }
  Add-Draw $out $gf $dx $HEADROOM $false ''
  # 3) karakterler
  foreach ($a in $st.actors) {
    Add-Draw $out (Get-FrameName $a) ([Math]::Floor([double]$st.groupX + $a.x)) ($HEADROOM + $a.y) $a.flip $a.name
  }
  # 4) Dogis'in ofke isareti ve buhar
  $dog = $st.actors[0]
  if ($dog.ov -eq 'hangry') {
    $bx = [Math]::Floor([double]$st.groupX + $dog.x); $by = $HEADROOM + $dog.y
    $ax = if ($dog.flip) { 7 } else { 20 }
    Add-Draw $out ('fx_anger_' + (1 + [Math]::Floor([double]$st.clock / 4) % 2)) ($bx + $ax) ($by - 29) $false ''
    if ((Get-FrameName $dog) -eq 'dogis_angry_2') {
      $hx = if ($dog.flip) { -5 } else { 5 }
      Add-Draw $out 'fx_huff' ($bx + $hx) ($by - 21) $dog.flip ''
    }
  }
  # 5) ucan efektler
  foreach ($f in $st.fx) {
    $k = $f.kind
    if ($k -eq 'zzz') { $k = 'fx_zzz_' + [Math]::Max(1, [Math]::Min(3, 3 - [Math]::Floor([double](30 - $f.life) / 10))) }
    Add-Draw $out $k ([Math]::Floor([double]$f.x)) ([Math]::Floor([double]$HEADROOM + $f.y - 14)) $false ''
  }
  $st.draw = $out
}

# ---- karsilastirma testi icin tek satirlik ozet -------------------------------------
function Get-Digest($st) {
  $sb = New-Object System.Text.StringBuilder
  $fl = { param($v) [string][long][Math]::Floor([double]$v * 1000) }
  [void]$sb.Append([string]$st.clock + '|' + $st.scene + '|' + $st.phase + '|' + (& $fl $st.groupX) + '|' +
    (& $fl $st.sun.x) + '|' + $st.sun.dir + '|' + (& $fl $st.lead) + '|' + $st.dg.pets + '/' + $st.dg.need + '|' + $st.fx.Count)
  foreach ($d in $st.draw) {
    $ff = if ($d.f) { 1 } else { 0 }
    [void]$sb.Append('|' + $d.k + ',' + [long]$d.x + ',' + [long]$d.y + ',' + $ff + ',' + $d.id)
  }
  return $sb.ToString()
}
