# =====================================================================
#  Taskbar Kedileri  -  pixel art masaustu widget'i
#  Bagimliligi yok: Windows'ta hazir gelen PowerShell + .NET Framework yeter.
#  Baslatmak icin "Kedileri Baslat.bat" dosyasina cift tikla.
#
#  BU DOSYA URETILIR: kaynak/catbar_tpl.ps1 + kaynak/win/*.cs + sprite
#  sheet -> python kaynak/mkdist.py
#
#  Bu betik yalnizca BASLATICIDIR:
#   1. Widget'in C# kaynagini (motor, cizici, masaustu penceresi, sprite'lar)
#      Windows'un kendi derleyicisiyle bir kez kucuk bir .exe'ye derler:
#      %LOCALAPPDATA%\TaskbarKedileri\TaskbarKedileri-<ozet>.exe
#      Kaynak degismedikce sonraki acilislar derlemeyi atlar.
#   2. O exe'yi baslatir ve KAPANIR. Arka planda ~110 MB'lik PowerShell
#      degil, yalnizca kucuk widget sureci kalir.
#   3. Exe herhangi bir sebeple baslatilamazsa widget'i bu PowerShell
#      surecinin icinde calistirir (yedek).
# =====================================================================
$ErrorActionPreference = 'Stop'
$LogPath = Join-Path $PSScriptRoot 'catbar-hata.log'

function Write-CatLog([string]$Message) {
  try {
    Add-Content -Path $LogPath -Encoding UTF8 -Value ("[{0}] [bilgi] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
  } catch { }
}

try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$KediCs = @'
__KEDI_CS__
'@

$refs = @('System.Windows.Forms', 'System.Drawing')
$exe = $null
try {
  $sha  = [System.Security.Cryptography.SHA256]::Create()
  $build = 'exe2-manifest'   # derleme ayarlari degisince onbellegi gecersiz kilmak icin
  $hash = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($build + $KediCs))[0..7] | ForEach-Object { $_.ToString('x2') })
  $dir  = Join-Path $env:LOCALAPPDATA 'TaskbarKedileri'
  $exe  = Join-Path $dir "TaskbarKedileri-$hash.exe"
  if (-not (Test-Path $exe)) {
    [void](New-Item -ItemType Directory -Force -Path $dir)
    Get-ChildItem -Path $dir -Filter 'TaskbarKedileri-*.exe' -ErrorAction SilentlyContinue |
      ForEach-Object { try { Remove-Item $_.FullName -Force -ErrorAction Stop } catch { } }   # eski surumler
    # Uygulama bildirimi (manifest) SART: Windows 8+ uyumlulugunu bildirmeyen bir
    # surec masaustune "katmanli cocuk pencere" acamaz (Desktop modu -> Bottom'a duser).
    $manifest = Join-Path $dir 'TaskbarKedileri.manifest'
    [System.IO.File]::WriteAllText($manifest, @'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.2.0.0" name="TaskbarKedileri" type="win32"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false"/></requestedPrivileges></security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
    </application>
  </compatibility>
</assembly>
'@, [System.Text.Encoding]::ASCII)
    $cp = New-Object System.CodeDom.Compiler.CompilerParameters
    $cp.GenerateExecutable = $true
    $cp.GenerateInMemory   = $false
    $cp.OutputAssembly     = $exe
    $cp.CompilerOptions    = '/target:winexe /optimize+ /win32manifest:"' + $manifest + '"'
    [void]$cp.ReferencedAssemblies.AddRange([string[]]@('System.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll'))
    $res  = (New-Object Microsoft.CSharp.CSharpCodeProvider).CompileAssemblyFromSource($cp, $KediCs)
    $errs = @($res.Errors | Where-Object { -not $_.IsWarning })
    if ($errs.Count -gt 0) { throw ('derleme hatasi: ' + (($errs | Select-Object -First 3 | ForEach-Object { $_.ToString() }) -join ' | ')) }
    Write-CatLog "Widget derlendi: $exe"
  }
} catch {
  Write-CatLog ('Exe derlenemedi (' + $_.Exception.Message + '), PowerShell icinde calisilacak')
  $exe = $null
}

# 1) kucuk exe olarak baslat (onerilen)
if ($exe -and (Test-Path $exe)) {
  try {
    $p = Start-Process -FilePath $exe -ArgumentList ('"' + $LogPath + '"') -PassThru
    Start-Sleep -Milliseconds 1500
    if (-not $p.HasExited -or $p.ExitCode -eq 0) { return }        # calisiyor (ya da zaten acikti)
    Write-CatLog "Exe hemen kapandi (cikis kodu $($p.ExitCode)), PowerShell icinde calisilacak"
  } catch {
    Write-CatLog ('Exe baslatilamadi (' + $_.Exception.Message + '), PowerShell icinde calisilacak')
  }
}

# 2) yedek: ayni widget bu surecte
if (-not ('TaskbarKedileri.KediApp' -as [type])) {
  if ($exe -and (Test-Path $exe)) { [void][System.Reflection.Assembly]::LoadFrom($exe) }
  else { Add-Type -TypeDefinition $KediCs -Language CSharp -ReferencedAssemblies $refs -IgnoreWarnings }
}
Remove-Variable KediCs
[System.Windows.Forms.Application]::EnableVisualStyles()
[TaskbarKedileri.KediApp]::Run($LogPath)

}
catch {
  $msg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.GetType().Name): $($_.Exception.Message)`r`n$($_.ScriptStackTrace)`r`n"
  Add-Content -Path $LogPath -Value $msg -Encoding UTF8
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
  [System.Windows.Forms.MessageBox]::Show("Kedi widget'i baslatilamadi.`r`n`r`n$($_.Exception.Message)`r`n`r`nAyrinti: $LogPath", 'Taskbar Kedileri') | Out-Null
}
