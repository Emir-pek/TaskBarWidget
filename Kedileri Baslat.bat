@echo off
rem ============================================================
rem   Taskbar Kedileri - baslatici
rem   Bu dosyaya cift tiklayin. Hicbir kurulum gerekmez.
rem ============================================================
start "" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0catbar.ps1"
exit
