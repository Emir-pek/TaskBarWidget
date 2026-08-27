' Konsol penceresi hic gorunmeden baslatir (istege bagli alternatif)
Set sh = CreateObject("WScript.Shell")
p = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & p & "catbar.ps1""", 0, False
