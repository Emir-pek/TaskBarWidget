# -*- coding: utf-8 -*-
import base64, json, os, textwrap

meta = json.load(open('assets/sprites.json'))
png  = open('assets/sprites.png', 'rb').read()
b64  = base64.b64encode(png).decode()


# ---- sprite sheet + kare tablosu C# kaynagi olarak (exe kendi kendine yetsin)
names = sorted(meta['frames'])
chunks = textwrap.wrap(b64, 100)
assets_cs = """using System.Reflection;

[assembly: AssemblyTitle("Taskbar Kedileri")]
[assembly: AssemblyProduct("Taskbar Kedileri")]
[assembly: AssemblyDescription("Taskbar Kedileri - pixel art masaustu widget'i")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]

namespace TaskbarKedileri
{
    // URETILDI: kaynak/mkdist.py (assets/sprites.png + sprites.json). Elle duzenleme.
    internal static class KediAssets
    {
        public const int CellW = %d;
        public const int CellH = %d;
        public static readonly string[] Names = { %s };
        public static readonly int[] Xs = { %s };
        public static readonly int[] Ys = { %s };
        public const string SheetB64 =
%s;
    }
}
""" % (meta['cell_w'], meta['cell_h'],
       ', '.join('"%s"' % n for n in names),
       ', '.join(str(meta['frames'][n]['x']) for n in names),
       ', '.join(str(meta['frames'][n]['y']) for n in names),
       '\n'.join('            %s"%s"' % ('' if i == 0 else '+ ', c) for i, c in enumerate(chunks)))

# C# kaynaklari tek derleme birimine birlestirilir: using satirlari en uste,
# assembly nitelikleri (KediAssets) hemen arkasina.
CS_SOURCES = [('KediAssets.cs', assets_cs)] + [
    (n, open(os.path.join('win', n), encoding='ascii').read())
    for n in ['Engine.cs', 'KediWidget.cs', 'DesktopHost.cs', 'KediApp.cs']]
usings, bodies = [], []
for name, src in CS_SOURCES:
    body = []
    for line in src.splitlines():
        if line.startswith('using ') and line.rstrip().endswith(';'):
            if line not in usings: usings.append(line)
        else:
            body.append(line)
    bodies.append('\n'.join(body).strip())
kedi_cs = '\n'.join(sorted(usings)) + '\n\n' + '\n\n'.join(bodies) + '\n'
assert not any(l.startswith("'@") for l in kedi_cs.splitlines())   # here-string'i bozar
kedi_cs.encode('ascii')                                             # csc icin ASCII

tpl = open('catbar_tpl.ps1', encoding='utf-8').read()
out = tpl.replace('__KEDI_CS__', kedi_cs.strip())
assert '__' not in ''.join(l for l in out.splitlines() if l.startswith('__')), 'doldurulmamis yer tutucu'
os.makedirs('build', exist_ok=True)
with open('build/kedi_all.cs', 'w', encoding='ascii') as fh:   # test/derleme kontrolu icin
    fh.write(kedi_cs)

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

print('dist ok  ps1=%d KB  frames=%d  cs=%d satir' % (os.path.getsize('dist/catbar.ps1')//1024, len(meta['frames']), kedi_cs.count(chr(10))))
