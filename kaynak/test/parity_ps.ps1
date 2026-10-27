# pwsh parity_ps.ps1 <tohum> <genislik> <tick>
param([double]$Seed, [int]$W, [int]$N)
. (Join-Path $PSScriptRoot '..' 'engine.ps1')
Rng-Seed $Seed
$st = New-State $W
$out = New-Object System.Collections.Generic.List[string]
$out.Add((Get-Digest $st))
$names = @('tarcin', 'maya', 'zilli')
for ($t = 0; $t -lt $N; $t++) {
  $m = $t % 300
  if ($m -eq 150 -or $m -eq 158 -or $m -eq 166 -or $m -eq 230) { $out.Add('poke ' + (Invoke-Poke $st 'dogis')) }
  if (($t % 977) -eq 0) { $out.Add('poke ' + (Invoke-Poke $st $names[$t % 3])) }
  if ($t -eq [Math]::Floor($N / 2)) { Set-ScreenW $st ($W - 333) }
  Step-State $st
  $out.Add((Get-Digest $st))
}
[IO.File]::WriteAllText((Join-Path ([IO.Path]::GetTempPath()) "parity_ps_$Seed.txt"), (($out -join "`n") + "`n"))
