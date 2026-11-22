# 🌾 Çiftliğim 3D — Godot 4 sürümü

Web sürümündeki (`../ciftlik`) low-poly çiftlik oyununun Godot 4.7 karşılığı. Tüm modeller GDScript ile, basit geometrilerden çizilir; dışarıdan model, doku veya ses dosyası yok (sesler de kodla sentezlenir).

## Çalıştırma

- **Editörde:** Godot'u aç → *İçe Aktar* → bu klasördeki `project.godot` → ▶ (F5).
- **Komut satırından:**

```powershell
& "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe" --path D:\klonlama\ciftlik-godot
```

## Oynanış

Web sürümüyle aynı: ⛏️ Çapa ile sür, 🌱 ek, 💧 sula (2× hız), ✋ El ile topla. Sürükleyerek çok kareye iş ver; çiftçi sırayla yapar. Altınla meyve ağaçları, hayvanlar ve dekor al; seviye atladıkça yeni ekinler açılır. 🧑‍🌾 Korkuluk çevresini %25 hızlandırır. 5 dakikalık gün/gece; fenerler geceleri yanar. Otomatik kayıt (`user://save.json`), sen yokken 6 saate kadar büyüme.

**Kontroller:** sol tık/sürükle = alet · sağ tık sürükle veya Q/E = kamera · tekerlek = yakınlaştır · WASD = yürü · 1–8 = alet · Esc = iş sırasını iptal.

## Dosyalar

| Dosya | İçerik |
|---|---|
| `scenes/main.tscn` | Tek sahne; her şey koddan kurulur |
| `scripts/game.gd` | Dünya, simülasyon, çiftçi, kamera, gün/gece, arayüz, ses, kayıt |
| `scripts/models.gd` | Tüm prosedürel low-poly modeller (`Models` sınıfı) |
| `scripts/data.gd` | Ekin/ağaç/hayvan/dekor fiyat ve süreleri (`Data` sınıfı) |

## Geliştirici bayrakları

`--` sonrasına verilir: `--fresh` (kaydı yok say), `--night` (geceden başla), `--selftest` (oyun mantığını test edip çıkar), `--shot=yol.png` (4 sn sonra ekran görüntüsü alıp çıkar).

```powershell
& "<godot_console.exe>" --headless --path D:\klonlama\ciftlik-godot -- --fresh --selftest
```

## Dışa aktarma (exe / Android / Web)

Editörde *Proje → Dışa Aktar*. İlk seferde Godot "dışa aktarma şablonlarını" indirmeyi önerir (Editör → Dışa Aktarma Şablonlarını Yönet).
