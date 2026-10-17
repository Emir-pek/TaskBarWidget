# Taskbar Kedileri 🐈

Görev çubuğunun (macOS'ta Dock'un) hemen üzerinde, arka planı olmayan küçük bir
pixel art animasyonu. Tarçın, Maya ve Zilli, Dogis'le birlikte oynuyor, uyuyor,
geziniyor.

| Platform | Nasıl | Gereksinim |
|---|---|---|
| **Windows** | `Kedileri Baslat.bat` | **Yok** — hazır gelen PowerShell yetiyor |
| **macOS / Linux** | `Mac icin Baslat.command` | Node.js (ilk açılışta Electron iner) |

İkisi de **aynı sprite sheet'i ve aynı sahne motorunu** kullanır, yani kediler
her iki platformda birebir aynı davranır.

![sahneler](docs/onizleme.png)

## Çalıştırma

### Windows — kurulum gerektirmez

**`Kedileri Baslat.bat`** dosyasına çift tıkla. Hepsi bu.

Başlarken kısa bir siyah pencere görürsen normal, hemen kapanır. Hiç görünmesin
istersen `Kedileri Baslat (sessiz).vbs` dosyasını kullan; ikisi de aynı şeyi yapar.

### macOS ve Linux — Node.js gerekir

**`Mac icin Baslat.command`** dosyasına çift tıkla. İlk açılışta Electron
indirilir (~150 MB, birkaç dakika); sonraki açılışlar anında olur.

macOS ilk çalıştırmada *"geliştirici doğrulanamadı"* diyebilir. Dosyaya
**sağ tıkla → Aç** dersen bir kereye mahsus izin verir.

Elle çalıştırmak istersen (her platformda çalışır):

```bash
cd masaustu
npm install
npm start
```

### Önizleme

`onizleme.html` dosyasını tarayıcıda açarsan hiçbir şey kurmadan tüm sahneleri
ve karakterleri inceleyebilirsin. Her işletim sisteminde çalışır.

## Kullanım

| İşlem | Nasıl |
|---|---|
| Kediyi zıplatmak | Kedinin **üzerine sol tıkla** — zıplar ve kalp çıkar |
| Menü | Windows: kedinin **üzerine sağ tıkla**. macOS/Linux: **menü çubuğundaki kedi ikonu** |
| Duraklatma | Sağ tık → *Duraklat* |
| Boyut | Sağ tık → *Boyut 1x / 2x / 3x* (varsayılan 2x) |
| Sahneyi atlamak | Sağ tık → *Sahneyi degistir* |
| Kapatmak | Sağ tık → *Cikis* |

> Menü ve tıklama sadece **karakterlerin piksellerinde** çalışır. Pencerenin geri
> kalanı tamamen saydamdır ve tıklamalar altındaki masaüstüne geçer — yani
> çalışmanı hiçbir şekilde engellemez.

## Sahneler

Dört sahne rastgele sırayla, 15–25 saniyede bir değişir:

- **Kortej** — Dogis yürür, kediler peşinden sıra sıra takip eder, grup ekran boyunca gezinir
- **Oyuncak** — Dogis tüylü çubuğu sallar, bir kedi zıplayıp yakalamaya çalışır
- **Sevme** — Dogis çömelir, bir kediyi sever, kalpler yükselir
- **Uyku** — kediler uzanıp uyur, biri ara ara esneyip gerinir, z'ler yükselir

Roller her sahnede karışır, yani hep aynı kedi zıplamaz.

## Açılışta otomatik başlatma

**Windows:** `Win + R` → `shell:startup` → açılan klasöre
`Kedileri Baslat (sessiz).vbs` dosyasının **kısayolunu** at. Kaldırmak için sil.

**macOS:** Sistem Ayarları → Genel → Giriş Öğeleri → `+` →
`Mac icin Baslat.command` dosyasını seç.

## Bir şey ters giderse

- Widget hiç açılmıyorsa klasörde **`catbar-hata.log`** dosyasına bak; hata orada yazar.
- Kediler görünmüyor ama görev yöneticisinde `powershell.exe` varsa, muhtemelen
  ekranın solundalar — birkaç saniye bekle, kortej sahnesinde gezinirler.
- Kapatamıyorsan: Görev Yöneticisi → `Windows PowerShell` işlemini sonlandır.
- Kurumsal bir bilgisayarda PowerShell betikleri tamamen engelliyse `.bat`
  çalışmayabilir; o durumda bilgisayarın yöneticisine sorman gerekir.

---

**macOS'a özel:**

- *"geliştirici doğrulanamadı"* → `.command` dosyasına sağ tıkla → **Aç**.
- Kediler görünmüyorsa menü çubuğunda kedi ikonu var mı bak; varsa uygulama
  çalışıyor demektir, ikondan çıkıp tekrar aç.
- `npm install` takılırsa `masaustu/node_modules` klasörünü silip tekrar dene.

## Nasıl çalışıyor

Tek sanat + mantık kaynağı, iki çalışma zamanı:

```
kaynak/                     TEK KAYNAK
  |- art_*.py               pixel art pozlari
  |- build_sheet.py         -> assets/sprites.png + sprites.json  (73 kare)
  \- scene.js               sahne durum makinesi
        |
        |-- mkdist.py ------> catbar.ps1        Windows  (PowerShell + WinForms)
        \-- mkelectron.py --> masaustu/ortak/   macOS / Windows / Linux (Electron)
```

**Electron sürümü** (`masaustu/`) aynı `scene.js`'i doğrudan çalıştırır:

```
main.js       saydam / cercevesiz / her zaman ustte pencere, tepsi menusu,
              workArea'ya gore konumlandirma, tiklama gecirgenligi
preload.js    contextIsolation acik dar IPC koprusu
renderer.js   canvas cizimi + alfa tabanli hit-test
ortak/        mkelectron.py'nin kopyaladigi scene.js ve sprite'lar
```

Teknik notlar (Electron):

- **Saydamlık** renk anahtarıyla değil gerçek alfa ile (`transparent: true`).
  Tıklama geçirgenliği için pencere `setIgnoreMouseEvents(true, {forward:true})`
  ile açılıyor; `forward` sayesinde renderer yine de `mousemove` alıyor ve imleç
  dolu bir pikselin üzerine gelince geçirgenliği kapatıyor. Hit-test canvas'ın
  alfa kanalından okunuyor.
- **Konumlandırma** `screen.getPrimaryDisplay().workArea` ile — bu alan Dock'u ve
  menü çubuğunu zaten dışarıda bırakıyor. `display-metrics-changed` olayında
  yeniden hizalanıyor, yani Dock'u gizlersen veya monitör eklersen düzeliyor.
- `setAlwaysOnTop('screen-saver')` + `setVisibleOnAllWorkspaces` olmadan macOS'ta
  kediler tam ekran uygulamaların ve diğer Space'lerin altında kalıyor.
- Retina'da netlik için canvas `devicePixelRatio` ile ölçekleniyor,
  `imageSmoothingEnabled = false` kalıyor.

Teknik notlar (Windows / PowerShell):

```
Kedileri Baslat.bat          ->  powershell -File catbar.ps1
catbar.ps1                       tek dosya: sprite sheet base64 olarak icinde gomulu
  ├─ $FRAMES                     73 karenin sprite sheet'teki hucre koordinatlari
  ├─ $ANIM / $HANIM              animasyon tablolari (kare listesi + kac tick tutacagi)
  ├─ $SCENES                     dort sahnenin hedef pozisyonlari ve animasyonlari
  ├─ Step-World                  sahne durum makinesi, 80 ms'lik tick
  └─ Form.Add_Paint              NearestNeighbor ile sprite cizimi
```

Teknik notlar:

- **Saydamlık** `Form.TransparencyKey` ile renk anahtarlı yapılıyor (magenta,
  `255,0,255`). Sprite'larda o renk hiç kullanılmıyor ve alfa değerleri yalnızca
  0 veya 255 — yani yumuşatılmış kenar yok, anahtar renk temiz çalışıyor.
  Bunun güzel yan etkisi: saydam alanlar tıklamayı altındaki pencereye geçirir.
- **Konumlandırma** `Screen.PrimaryScreen.WorkingArea` ile yapılıyor, yani görev
  çubuğu nerede olursa olsun ve DPI ölçeklemesi kaç olursa olsun doğru oturuyor.
- **Aynalama** için sprite sheet'in yatay çevrilmiş bir kopyası bellekte tutuluyor;
  kaynak koordinat `SHEET_W - x - CELL_W` ile hesaplanıyor.
- Form `DoubleBuffered` olarak işaretleniyor (reflection ile, çünkü property
  `protected`), aksi halde titriyor.

## Sprite'ları değiştirmek

```bash
cd kaynak
pip install pillow
python3 build_sheet.py    # assets/sprites.png + sprites.json
python3 mkdist.py         # dist/catbar.ps1     -> Windows surumu
python3 mkelectron.py     # masaustu/ortak/     -> Electron surumu
python3 mkpreview.py      # build/preview.html  -> onizleme
```

Üretilen `dist/catbar.ps1` dosyasını kök dizindeki `catbar.ps1` ile,
`build/preview.html` dosyasını `onizleme.html` ile değiştir.
`mkelectron.py` zaten doğru yere yazar.

> **`scene.js`'i değiştirdiysen `mkelectron.py`'yi çalıştırmayı unutma** —
> Electron sürümü `masaustu/ortak/scene.js` kopyasını okur, `kaynak/scene.js`'i
> değil. `catbar_tpl.ps1`'deki sahne tablolarını da elle eşitle.

`kaynak/` içeriği:

| Dosya | İçerik |
|---|---|
| `art_cat.py` | Kedi pozları — ASCII pixel art, bacaklar programatik üretiliyor |
| `art_sleep.py` | Uyku / esneme / gerinme pozları |
| `art_human.py` | Dogis'in (insan) pozları ve efektler (kalp, zzz, kıvılcım) — sprite adları `human_*` olarak kalıyor |
| `shapes.py` | Elips / kontur yardımcıları |
| `build_sheet.py` | Paletler, kedi siluet varyantları, sprite sheet paketleyici |
| `scene.js` | Sahne durum makinesi — `catbar_tpl.ps1` ile aynı mantık |
| `catbar_tpl.ps1` | PowerShell şablonu; `mkdist.py` içine sprite'ları gömer |

> `scene.js` ile `catbar_tpl.ps1` aynı sahne mantığını taşır. Birini
> değiştirdiğinde diğerini de güncelle, yoksa önizleme widget'la uyuşmaz.

Karakter ayrımı palet + poza duyarlı siluet ile yapılıyor: Maya'ya genişletme
(dilate) ve sırtında tüy dikenleri ekleniyor, Zilli'ye yalnızca oturma
pozlarında yatay genişletme uygulanıyor — bacaklı ve uyku pozlarında uygulanırsa
bacaklar birleşip yüz bozuluyor.
