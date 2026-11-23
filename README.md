# 🌾 Çiftliğim 3D — Godot 4 sürümü

Web sürümündeki (`../ciftlik`) low-poly çiftlik oyununun Godot 4.7 karşılığı. Görseller `assets/` içindeki CC0 modellerden gelir; bir dosya yoksa GDScript ile çizilen prosedürel model kullanılır. Sesler kodla sentezlenir.

## Çalıştırma

- **Editörde:** Godot'u aç → *İçe Aktar* → bu klasördeki `project.godot` → ▶ (F5).
- **Komut satırından:**

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path D:\klonlama\ciftlik-godot
```

## Oynanış

Web sürümüyle aynı: ⛏️ Çapa ile sür, 🌱 ek, 💧 sula (2× hız), ✋ El ile topla. Sürükleyerek çok kareye iş ver; çiftçi sırayla yapar. Tarla üstündeki 🧺 hasada hazır, 💧 su istiyor demektir. Altınla meyve ağaçları, hayvanlar ve dekor al; seviye atladıkça yeni ekinler açılır. 🧑‍🌾 Korkuluk çevresini %25 hızlandırır. 15 dakikalık gün (gece kısa); fenerler geceleri yanar. Otomatik kayıt (`user://save.json`), sen yokken 6 saate kadar büyüme.

**Su ve mevsimler:** sulanan toprak ~90 sn ıslak kalır (2× hız), sonra kurur; elle ya da 💧 ile yeniden sula. 10'ar dakikalık 4 mevsim var, her tohum yalnız kendi mevsiminde ekilir (rafta 🚫 ile gösterilir). Mevsim başında ağaçlar meyve verir (kış hariç) ve hava olayı gelebilir: 🌧️ yağmur tarlaları sular, 🔥 kuraklıkta su 3× hızlı biter, 🌨️ karda sulamaya gerek yok.

**Hayvanlar:** yem ister (tahıl, yoksa altın); aç hayvanın üstünde 🌾❔ çıkar ve üretmez. ✋ ile yemle. Yan yana aynı tür hayvanlar ağıl olur: birini yemlemek hepsini doyurur. Her hayvan topladıkça seviye atlar (Sv 5'e kadar), daha çok altın ve ürün verir.

**Bahçe (9):** 🌼 çiçek tarhları kalıcıdır; sabit sürede açar, hasattan sonra yeniden büyür. Büyürken toprağı ıslak tutarsan kazanç 3 katına çıkar. Her çiçek türü hasat edildikçe seviye atlar. 🐟 Balık göleti 2×2 kare kaplar, kendiliğinden balık üretir.

**Görevler (J):** sol panelde aynı anda 4 görev ("8 Havuç topla", "17 kez sula"…). Tamamlanınca 🏅 madalya, 💎 elmas ve XP verir, yerine yenisi gelir. ✕ ile görev silinir: günde 1 ücretsiz, sonrası 2 💎.

**Ambar (B):** hasat, altının yanında kaynak da verir (tahıl, sebze, meyve, yumurta, süt…). Ambarda sat ya da pazar siparişini teslim edip 🏅 madalya kazan. Ambara/siloya tıklamak da açar.

**Ana menü ve kariyerler:** açılışta yükleme ekranı ve ana menü gelir. 3 kariyer yuvası var: *Yeni Kariyer* (çiftliğine ad ver), *Kariyerler* (yükle / iki basışla sil), *Devam Et*. Oyun içindeki 🏠 düğmesi kaydedip menüye döner; sıfırlama yok.

**Yeni kariyer:** bir mektup ve hikâyeyle başlar; ot, taş ve kütük bürümüş araziyi 🗑️ Kaldır ile temizleyip ⭐ Hikâye görevlerini izlersin.

**Arazi:** başlangıçta ortadaki 24×24 alan açık. Çevresindeki 8×8 parsellere tıklayıp seviye ve altınla satın alırsın; her parsel bir öncekinden pahalı. Kilitli parseller çalı, kaya, kütük, çiçek ve mantarla dolu yabani arazidir; satın alınca temizlenir. Çiftlik dışında orman, çiçek tarlaları, kamp alanı ve gölette kano var.

**Hayvanlar ve çitler:** çiftçi çitlerden, kayalardan, ağaçlardan ve binalardan geçmez, etrafından dolaşır; ağıla 🚪 çit kapısından girer. 🛖 Kümes (Hayvan rafı): çevresindeki 6 karedeki tavuklar yumurtayı kümese bırakır, kümese tıklayınca hepsi toplanır.

**Kontroller:** boş yere tıkla = oraya yürü · sol tık/sürükle = alet · WASD = yürü · sağ tık sürükle = döndür/eğ · orta tık sürükle veya ok tuşları = haritada gez · Boşluk = çiftçiye dön · Q/E döndür · R/F eğ · tekerlek = yakınlaştır · 1–9 = alet · J = görevler · B = ambar · Esc = iptal.

## Dosyalar

| Dosya | İçerik |
|---|---|
| `scenes/main.tscn` | Tek sahne; her şey koddan kurulur |
| `scripts/game.gd` | Dünya, simülasyon, çiftçi, kamera, gün/gece, arayüz, ses, kayıt |
| `scripts/models.gd` | Tüm prosedürel low-poly modeller (`Models` sınıfı) |
| `scripts/visuals.gd` | Asset → prosedürel yedek seçimi |
| `scripts/assets.gd` | Model yükleme, malzeme/palet düzeltme |
| `scripts/data.gd` | Ekin/ağaç/hayvan/dekor fiyat ve süreleri (`Data` sınıfı) |

## Geliştirici bayrakları

`--` sonrasına verilir. Geliştirici bayrakları kariyer dosyalarına dokunmaz (`--slot=N` verilmedikçe). `--fresh` (kaydı yok say), `--menu` (menüyle başla), `--slot=1..3` (kariyer seç), `--cam=40` (kamera uzaklığı), `--fps` (8 sn FPS ölç), `--night` (geceden başla), `--selftest` (oyun mantığını test edip çıkar), `--shot=yol.png` (4 sn sonra ekran görüntüsü alıp çıkar).

```powershell
& "<godot_console.exe>" --headless --path D:\klonlama\ciftlik-godot -- --fresh --selftest
```

## Dışa aktarma (exe / Android / Web)

Editörde *Proje → Dışa Aktar*. İlk seferde Godot "dışa aktarma şablonlarını" indirmeyi önerir (Editör → Dışa Aktarma Şablonlarını Yönet).

## Asset'ler (hepsi CC0 1.0, atıf zorunlu değil)

- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) — ağaç, kaya, çalı (`assets/nature`)
- [Quaternius LowPoly Crops](https://opengameart.org/node/126983) — ekinler ve meyve ağaçları (`assets/crops`)
- [Quaternius Farm Animals](https://opengameart.org/content/lowpoly-animated-farm-animal-pack) — inek, domuz, koyun (`assets/animals`)

Geliştirici araçları: `tools/career_test.gd` (kariyer akışı testi: `--headless --script res://tools/career_test.gd`), `tools/probe.gd` (model boyut/animasyon listesi), `tools/preview.gd` (modelleri tek karede önizle). Ek bayraklar: `--demo` (her türden örnek), `--barn` (ambarı açık başlat), `--season=0..3` (mevsim seç), `--weather=rain|drought|snow` (hava olayı başlat), `--story` (hikâyeli başlangıç), `--night`, `--tool=seed` (eşya penceresi açık), `--pitch=`/`--yaw=`/`--lookup=` (kamera açısı).
