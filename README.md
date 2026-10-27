# Taskbar Kedileri 🐈

Görev çubuğunun (macOS'ta Dock'un) hemen üzerinde, arka planı olmayan küçük bir
pixel art animasyonu. Tarçın, Maya ve Zilli, Dogis'le birlikte oynuyor, uyuyor,
ve gökyüzünde süzülen **güneşin peşinden** geziniyor. En sağda Dogis'in kendi
çizdiği **zürafa ile zambak** duruyor; zürafa ara sıra çiçeği kokluyor.

**Gerçek bir masaüstü widget'ı:** yalnızca masaüstünde görünür. Açtığın her
pencere (tarayıcı, editör, oyun) kedilerin **önüne** geçer; pencereleri
küçültünce ya da *Masaüstünü göster* deyince yine oradadırlar.

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
| Dogis'i sevmek | Dogis'e **sol tıkla** — sevinir, kalp çıkar. Ama üst üste **2–3 kez** seversen bıkar: kollarını kavuşturur, yüzü kızarır, "hmph" der. Birkaç saniye sonra geçer |
| Konum (Windows) | Sağ tık → *Konum* → *Otomatik* (önerilen) / *Masaüstüne yerleştir* / *Pencerelerin altında* |
| Menü | Windows: kedinin **üzerine sağ tıkla**. macOS/Linux: **menü çubuğundaki kedi ikonu** |
| Duraklatma | Sağ tık → *Duraklat* |
| Boyut | Sağ tık → *Boyut 1x / 2x / 3x* (varsayılan 2x) |
| Sahneyi atlamak | Sağ tık → *Sahneyi degistir* |
| Kapatmak | Sağ tık → *Cikis* |

> Menü ve tıklama sadece **karakterlerin piksellerinde** çalışır. Pencerenin geri
> kalanı tamamen saydamdır ve tıklamalar altındaki masaüstüne geçer — yani
> çalışmanı hiçbir şekilde engellemez.

## Sahneler

Gökyüzünde parlayan bir **güneş** yavaşça süzülür, ekranın kenarlarında geri döner.
Grup güneşin peşinden gider; güneş çok uzaklaşınca bir kortejle ona yetişirler.

Dört sahne rastgele sırayla, 15–25 saniyede bir değişir:

- **Kortej** — Dogis önde, kediler sıra sıra arkada, güneşi takip ederek yürürler
- **Oyuncak** — Dogis tüylü çubuğu sallar, bir kedi zıplayıp yakalamaya çalışır
- **Sevme** — Dogis çömelir, bir kediyi sever, kalpler yükselir
- **Uyku** — kediler uzanıp uyur, biri ara ara esneyip gerinir, z'ler yükselir

Roller her sahnede karışır, yani hep aynı kedi zıplamaz. Dogis sinirliyken grup onu bekler.

En sağdaki **zürafa ve zambak** (Dogis'in çizimleri) yerinden kıpırdamaz ama yaşar:
zürafa göz kırpar, hafifçe sallanır, 20–40 saniyede bir eğilip çiçeği koklar
(küçük bir kalp çıkar); çiçek de esintiyle salınır.

## Açılışta otomatik başlatma

**Windows:** `Win + R` → `shell:startup` → açılan klasöre
`Kedileri Baslat (sessiz).vbs` dosyasının **kısayolunu** at. Kaldırmak için sil.

**macOS:** Sistem Ayarları → Genel → Giriş Öğeleri → `+` →
`Mac icin Baslat.command` dosyasını seç.

## Bir şey ters giderse

- Widget hiç açılmıyorsa klasörde **`catbar-hata.log`** dosyasına bak; hata orada yazar.
- Kediler görünmüyor ama görev yöneticisinde `powershell.exe` varsa, muhtemelen
  ekranın solundalar — birkaç saniye bekle, kortej sahnesinde gezinirler.
- Kapatamıyorsan: Görev Yöneticisi → **Taskbar Kedileri** işlemini sonlandır.
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
  |- build_sheet.py         -> assets/sprites.png + sprites.json  (93 kare)
  |- scene.js               ortak sahne motoru
  \- win/Engine.cs          scene.js'in C# portu (test/parity.sh ile tick tick esit)
        |
        |-- mkdist.py ------> catbar.ps1        Windows  (PowerShell + WinForms)
        \-- mkelectron.py --> masaustu/ortak/   macOS / Windows / Linux (Electron)
```

**Electron sürümü** (`masaustu/`) aynı `scene.js`'i doğrudan çalıştırır:

```
main.js       saydam / cercevesiz pencere, macOS masaustu katmani, tepsi menusu,
              workArea'ya gore konumlandirma, tiklama gecirgenligi
preload.js    contextIsolation acik dar IPC koprusu
renderer.js   st.draw listesini 3 kucuk katmana (gunes / karakterler / zurafa) basar,
              sprite alfa maskesiyle hit-test
ortak/        mkelectron.py'nin kopyaladigi scene.js ve sprite'lar
```

Teknik notlar (Electron / macOS):

- **Masaüstü katmanı:** pencere `type: 'panel'` ve
  `setAlwaysOnTop(true, 'normal', -1)` ile **NSWindow seviyesi -1**'e konur:
  bütün uygulama pencerelerinin (seviye 0) altında, duvar kağıdı ve Finder
  ikonlarının üstünde. Yani her pencere kedilerin önüne geçer.
- **koffi** (isteğe bağlı bağımlılık, derleme gerektirmez) varsa pencereye
  `Stationary | CanJoinAllSpaces | IgnoresCycle` davranışı da verilir:
  *Masaüstünü Göster* ve Mission Control'de kediler yerinde kalır, Cmd-` döngüsüne
  girmez, her Space'te görünür. Yoksa widget yine çalışır, sadece bu üç incelik eksik kalır.
  Terminalde `[kedi] macOS katman: class=ElectronNSPanel level=-1 behavior=0x151`
  satırı her şeyin yerinde olduğunu gösterir.
- **Tıklama:** seviye 0'ın altındaki, odak almayan pencerelere Chromium
  `mousemove` göndermez. Bu yüzden ana süreç imleci ~30 Hz yoklar, renderer aynı
  piksel testini yapar; `acceptFirstMouse` ilk tıklamanın yutulmasını önler.
  Panel tıklanınca uygulamayı öne getirmez — yazdığın yerde odak kalır.
- `setVisibleOnAllWorkspaces` macOS'ta **çağrılmaz**: panel zaten tüm Space'lere
  katılır ve bu çağrı Dock ikonunu geri getiriyordu.
- Tam ekran uygulamalar (video, oyun) seviye -1'in çok üstünde olduğu için kediler
  onların üzerine hiç çıkmaz.
- Çizim sprite çözünürlüğünde yapılır, büyütmeyi compositor `image-rendering:
  pixelated` ile yapar (Retina'da 16 kat az piksel). Sahne üç küçük katmandır;
  güneşin süzülmesi ve grubun yürümesi yalnızca CSS `transform` — yeniden çizim yok.

Teknik notlar (Windows):

```
Kedileri Baslat.bat   ->  powershell -File catbar.ps1   (yalnizca baslatici)
catbar.ps1                tek dosya, uretilir (kaynak/mkdist.py); icinde C# kaynagi:
  ├─ KediAssets            93 karelik sprite sheet + kare tablosu
  ├─ Engine.cs             sahne motoru (scene.js'in birebir portu)
  ├─ KediWidget.cs         cizici, zamanlayici, tiklama, gorunurluk takibi
  ├─ DesktopHost.cs        masaustu penceresi
  └─ KediApp.cs            menu + Main
        │  ilk acilista bir kez derlenir:
        ▼
%LOCALAPPDATA%\TaskbarKedileri\TaskbarKedileri-<ozet>.exe   <- arka planda calisan tek surec
```

- **Masaüstü modu (varsayılan):** pencere, masaüstü ikonlarını taşıyan Explorer
  penceresinin (Windows 11 24H2+'da `Progman`, eskilerde `WorkerW`) **çocuğu**
  olarak açılır. İkonların üstünde, bütün uygulama pencerelerinin altında durur;
  *Masaüstünü göster* (Win+D) ile birlikte görünür. Explorer yeniden başlarsa
  pencere kendini yeniden takar.
- **Yedek mod (Bottom):** masaüstüne takılamazsa sahipsiz bir araç penceresi
  olarak z-sırasının en altında tutulur; öne çıkma girişimleri reddedilir.
  Sağ tık → *Konum* menüsünden elle seçilebilir; `catbar-hata.log` hangi modda
  çalıştığını yazar (`Masaustu modu: Desktop | ...`).
- **DPI:** süreç Per-Monitor-V2; %150 ve üstü ölçeklemede pikseller tam sayı
  çarpanla büyür, bulanıklaşmaz.
- **Saydamlık** `TransparencyKey` (magenta) ile; sprite'larda o renk yok ve alfa
  yalnızca 0/255. Tıklama yalnızca karakter piksellerinde yakalanır, gerisi
  masaüstüne geçer.
- **Aynalama** için sprite sheet'in yatay çevrilmiş bir kopyası bellekte tutuluyor.
- Exe herhangi bir sebeple başlatılamazsa (ör. bir güvenlik yazılımı engellerse)
  aynı widget PowerShell'in içinde çalışır; log'a sebebi yazılır.

## Kaynak kullanımı

Widget arka planda sürekli açık durduğu için olabildiğince az yer kaplayacak
şekilde yazıldı; görüntü ve davranış birebir aynı kalacak şekilde:

| | Ne yapılıyor |
|---|---|
| **Çizilmeyen kare yok** | Her tick yalnızca *değişen* sprite'ların dikdörtgenleri yeniden çizilir (Windows); Electron'da yalnızca değişen katman. Hiçbir şey değişmediyse hiç çizim yapılmaz. |
| **Görünmüyorsa çalışmıyor** | Kedilerin üstü tamamen örtülüyse (tam ekran oyun/video, büyütülmüş pencere, kilit ekranı) motor ve çizim durur. Windows'ta 320 ms'de bir "görünür oldum mu?" diye bakılır; macOS'ta pencere örtülme bilgisi doğrudan kullanılır. Görünür olunca kaldığı yerden devam eder. |
| **Senin uygulamaların önce gelir** | Süreç(ler) düşük öncelikte çalışır (Windows: *BelowNormal* + EcoQoS verimlilik modu; macOS: nice 10). Bilgisayar yoğunken kediler bekler, sen beklemezsin. |
| **Derlenmiş kod** | Windows'ta motor ve çizim C#; tick başına mikrosaniyeler (eski PowerShell motoru ~3–5 ms). |
| **Tek küçük süreç** | Windows'ta arka planda PowerShell değil, ~140 KB'lık bir exe çalışır; ikinci kez başlatılırsa ikinci kopya kendini kapatır. |
| **Seyrek uyanma** | İmleç kedilerin şeridinden uzaktayken tıklama kontrolü 30 ms yerine 100 ms'de bir yapılır (macOS'ta da). |

**Ölçüm (Windows 11, 24 çekirdekli dizüstü, aynı oturumda eski ↔ yeni):**

| | Eski (PowerShell motoru) | Yeni |
|---|---|---|
| CPU, kediler görünürken | %10,6 – %23 (1 çekirdeğin) | **%1,1 – %1,7** |
| CPU, üstleri örtülüyken | %9,6 – %26 | **%0,3 – %0,5** |
| Bellek (çalışma kümesi / özel) | 116 MB / 82 MB | **~42 MB / ~30 MB** |
| Açılış CPU'su | 4,9 – 11,5 sn | 3,0 – 6,4 sn |

(Aralıklar iki ayrı ölçüm oturumundan; ikincisinde dizüstü güç tasarrufundaydı.
Ekranda görünen animasyon her iki sürümde birebir aynı.)

macOS / Electron tarafı (Linux'ta yazılım çizimiyle ölçüldü, Mac'te GPU ile daha da
düşük olur): görünürken toplam CPU ~%9,5 → ~%6, pencere örtülünce motor tamamen durur.

Ölçmek istersen (Windows): komut satırında `set CATBAR_PERF=1` deyip aynı pencereden
`Kedileri Baslat.bat`'ı çalıştır; `catbar-hata.log`'a 30 sn'de bir CPU / bellek satırı düşer.

## Sprite'ları değiştirmek

```bash
cd kaynak
pip install pillow
python3 build_sheet.py    # assets/sprites.png + sprites.json  (93 kare)
python3 mkdist.py         # dist/catbar.ps1     -> Windows surumu
python3 mkelectron.py     # masaustu/ortak/     -> Electron surumu
python3 mkpreview.py      # build/preview.html  -> onizleme
```

Üretilen `dist/catbar.ps1` dosyasını kök dizindeki `catbar.ps1` ile,
`build/preview.html` dosyasını `onizleme.html` ile değiştir.
`mkelectron.py` zaten doğru yere yazar.

> **`scene.js`'i değiştirdiysen `win/Engine.cs`'i de aynı şekilde değiştir** ve
> eşitlik testini çalıştır, sonra `mkdist.py` + `mkelectron.py`:
>
> ```bash
> node kaynak/test/harness.js     # 4 ekran genisligi x 30000 tick: kare adlari, sinirler, Dogis/zurafa
> kaynak/test/parity.sh           # JS ve C# motoru ayni tohumla tick tick ayni mi (mono gerekir)
> ```

`kaynak/` içeriği:

| Dosya | İçerik |
|---|---|
| `art_cat.py` | Kedi pozları — ASCII pixel art, bacaklar programatik üretiliyor |
| `art_sleep.py` | Uyku / esneme / gerinme pozları |
| `art_human.py` | Dogis'in temel pozları ve efektler (kalp, zzz, kıvılcım) — sheet'te `dogis_*` |
| `art_dogis_extra.py` | Dogis'in sevilme (`pet_*`) ve bıkma (`angry_*`, kollar kavuşturulmuş) pozları, öfke işareti, buhar |
| `art_sun.py` | 4 karelik parlayan güneş (33×33) |
| `art_decor.py` | Dogis'in zürafa ve zambak çizimlerinden pixel art (bekleme, göz kırpma, koklama) |
| `shapes.py` | Elips / kontur yardımcıları |
| `build_sheet.py` | Paletler, kedi siluet varyantları, sprite sheet paketleyici |
| `scene.js` | **Ortak sahne motoru** — güneş, takip, sahneler, Dogis'in ruh hali, dekor; çizim listesi `st.draw` üretir |
| `win/Engine.cs` | `scene.js`'in birebir C# portu |
| `win/KediWidget.cs` | Windows çizici: yalnızca değişen alanlar, görünmezken durma, verimlilik modu |
| `win/DesktopHost.cs` | Windows masaüstü penceresi |
| `win/KediApp.cs` | Windows widget'ının `Main`'i ve sağ tık menüsü |
| `catbar_tpl.ps1` | Başlatıcı şablonu; `mkdist.py` C# kaynağını ve sprite'ları içine gömer |
| `test/` | `harness.js` (motor sağlık testi), `parity.sh` (JS ↔ C# eşitliği) |

> Tohumlu rastgele sayı üreteci (Park-Miller) sayesinde iki motor aynı tohumla
> aynı kareyi üretir; `parity.sh` 6 senaryo × 20000 tick'i satır satır karşılaştırır.

Karakter ayrımı palet + poza duyarlı siluet ile yapılıyor: Maya'ya genişletme
(dilate) ve sırtında tüy dikenleri ekleniyor, Zilli'ye yalnızca oturma
pozlarında yatay genişletme uygulanıyor — bacaklı ve uyku pozlarında uygulanırsa
bacaklar birleşip yüz bozuluyor.
