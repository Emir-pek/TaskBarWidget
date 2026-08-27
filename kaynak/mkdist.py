# -*- coding: utf-8 -*-
import base64, json, os, textwrap

meta = json.load(open('assets/sprites.json'))
png  = open('assets/sprites.png', 'rb').read()
b64  = base64.b64encode(png).decode()
sheet_w = __import__('PIL.Image', fromlist=['Image']).open('assets/sprites.png').width

items = []
for name in sorted(meta['frames']):
    f = meta['frames'][name]
    items.append("  '%s' = @(%d,%d)" % (name, f['x'], f['y']))
frames_ps = "@{\n" + "\n".join(items) + "\n}"

tpl = open('catbar_tpl.ps1').read()
out = (tpl.replace('__CELLW__', str(meta['cell_w']))
          .replace('__CELLH__', str(meta['cell_h']))
          .replace('__SHEETW__', str(sheet_w))
          .replace('__FRAMES__', frames_ps)
          .replace('__B64__', "\n".join(textwrap.wrap(b64, 120))))

os.makedirs('dist', exist_ok=True)
with open('dist/catbar.ps1', 'w', encoding='utf-8-sig', newline='\r\n') as fh:
    fh.write(out)

bat = r'''@echo off
rem ============================================================
rem   Taskbar Kedileri - baslatici
rem   Bu dosyaya cift tiklayin. Hicbir kurulum gerekmez.
rem ============================================================
start "" /b powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0catbar.ps1"
exit
'''
with open('dist/Kedileri Baslat.bat', 'w', encoding='ascii', newline='\r\n') as fh:
    fh.write(bat)

vbs = r'''' Konsol penceresi hic gorunmeden baslatir (istege bagli alternatif)
Set sh = CreateObject("WScript.Shell")
p = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & p & "catbar.ps1""", 0, False
'''
with open('dist/Kedileri Baslat (sessiz).vbs', 'w', encoding='ascii', newline='\r\n') as fh:
    fh.write(vbs)

print('dist ok  ps1=%d KB  frames=%d  sheet_w=%d' % (os.path.getsize('dist/catbar.ps1')//1024, len(meta['frames']), sheet_w))
