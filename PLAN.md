# Genişletme Planı

Kaynak: Farm Together Wiki, *Game Basics* ve *Crops* sayfaları (okundu: 23.11.2026). Amaç bu türün sistemlerini **kendi tasarımımız, adlarımız ve modellerimizle** eklemek; oyunun kendisini kopyalamak değil.

## Durum

| Sistem | Wiki'de | Bizde |
|---|---|---|
| Para, XP, seviye, kilit açma | ✓ | ✓ |
| Ekin/ağaç/hayvan zamanlayıcıları, sulama | ✓ | ✓ (su seviyesi zamanla azalır) |
| Çevrimdışı büyüme | ✓ | ✓ (6 saate kadar) |
| Tıklanan yere yürüme | ✓ | ✓ (bu sürümde eklendi) |
| Kaynak envanteri (sebze, tahıl, meyve, süt, yumurta, kumaş…) | ✓ | ✓ Aşama 1 (ambar, satış, sipariş, madalya) |
| Mevsimler + hava (yağmur, kuraklık, kar) | ✓ 17 dk'da bir | ✓ Aşama 2 (10 dk mevsim, su seviyesi) |
| Hayvan yemleme, ağıl (bitişik aynı tür yemi paylaşır), hayvan seviyesi | ✓ | ✓ Aşama 3 |
| Çiçekler (sulanınca çok daha fazla kazanç, seviye) | ✓ | ✓ Aşama 4 |
| Göletler / balık | ✓ | ✓ Aşama 4 (basit) |
| Görevler (aynı anda 4, madalya/elmas/XP ödülü) | ✓ | ✓ Aşama 5 |
| İşleme binaları (meyve → reçel, süt → peynir) ve tezgahlar | ✓ | ✗ |
| Arazi genişletme (seviye şartı + artan maliyet) | ✓ | ✓ (8×8 parseller) |
| Araçlar, ev içi işler, bilet | ✓ | ✗ |
| Çok oyunculu: başka çiftlikte çalışınca 2× bonus, izinler | ✓ | ✗ (sonraya) |

## Aşamalar

Her aşama kendi içinde oynanabilir biter; sonunda `--selftest` genişletilir ve commit edilir.

### 1. Ekonomi temeli: kaynaklar ve satış ✅ (tamamlandı)
- Hasat altının yanında **kaynak** da verir: sebze, tahıl, meyve, yumurta, süt, yün, çiçek, balık.
- Ambar ekranı: kaynakları gör, sat. İkinci para birimi **madalya** (işlenmiş ürünlerden ve görevlerden).
- `data.gd`'ye her ekin/hayvan için `resource` alanı.

### 2. Su ve mevsimler ✅ (tamamlandı)
- Mevsimlik ekinler: buğday her mevsim; havuç ilkbahar/sonbahar/kış; domates ilkbahar/yaz; mısır yaz/sonbahar; ayçiçeği yaz; balkabağı sonbahar. Ekilmiş ekin mevsim dışında da büyümeye devam eder.
- Zemin mevsime göre renk değiştirir; yağmur/kar parçacıkları, kuraklıkta sıcak ışık.
- Sulama tek tık yerine **su seviyesi**: zamanla azalır, sulu süre boyunca 2× hız.
- 4 mevsim, her biri ~10 dk (gün/gece döngüsünden bağımsız). Bazı ekinler yalnız belli mevsimlerde ekilir; ağaçlar mevsim başında ürün verebilir.
- Mevsim başında küçük ihtimalle hava olayı: **yağmur** (tarlaları yavaşça sular), **kuraklık** (yaz; su 3× hızlı biter), **kar** (kış; sulama bonusu yok). Parçacık efektleri ile.

### 3. Hayvanlar: yem ve ağıl ✅ (tamamlandı)
- Bir tam yem 3 ürün süresi yeter. Yem: tavuk 1, koyun 2, domuz 3, inek 4 tahıl; ambarda tahıl yoksa tahıl başına 6 altın.
- Seviye: Sv n → n+1 için 4·n toplama; her seviye +%15 altın, her 2 seviyede +1 kaynak (en fazla Sv 5).
- Sonra: ağıl içinde hayvanlar komşu karelere de gezinsin; yem teknesi modeli.
- Hayvanların yem deposu var; biterse üretim durur. ✋ ile yemle (altın/tahıl harcar).
- Bitişik aynı tür hayvan kareleri **ağıl** olur, yemi paylaşır, tek tıkla hepsi yemlenir.
- Her N toplamada hayvan seviye atlar, kazancı biraz artar.

### 4. Çiçekler ve gölet ✅ (tamamlandı)
- Yeni alet 🌼 Bahçe (9). Çiçekler: papatya, lale, gül, lavanta; kalıcı tarh, hasattan sonra yeniden açar. Islak geçen süre oranı kazancı ×3'e, kaynağı +2'ye kadar artırır. Tür seviyesi: 5·n hasatta bir, +%20.
- Gölet 2×2, 350🪙, Sv 3; 2,5 dk'da 4 balık. Sonra: farklı balık türleri, olta mini oyunu.
- Yeni kategori çiçek: sabit büyüme süresi; sulu tutulursa kazanç ve XP çok daha yüksek; hasatla seviye atlar.
- Gölet kareleri (2×2): balık yetiştir/tut. Balık kaynağı.

### 5. Görevler ✅ (tamamlandı)
- 12 görev türü (ekin, meyve, hayvan ürünü, çiçek, balık, ekim, sulama, yemleme, satış, sipariş, ağaç dikme, altın). Yalnız sahip olunan/açılmış şeylerden görev gelir; aynı görev iki kez gelmez.
- Panel solda (J). Silme: 24 saatte 1 ücretsiz, sonra 2 💎. 💎 şimdilik yalnız silmede; dükkân eşyaları Aşama 6–8'de.
- Aynı anda 4 görev ("20 havuç topla", "3 ağaç dik", "10 yumurta sat"…), süresiz.
- Ödül: madalya + elmas + XP. Tamamlanınca yenisi gelir; 24 saatte 1 görev silinebilir.
- Dükkânda görev gerektiren eşyaya işaret.

### 6. İşleme binaları
- **Meyve presi**: meyve → reçel. **Mandıra**: süt → peynir. Zamanlayıcılı üretim kuyruğu.
- **Tezgahlar**: reçel/peynir madalya karşılığı satılır.

### 7. Arazi genişletme ✅ (tamamlandı, öne alındı)
- Dünya -20..19; ortadaki 24×24 açık, çevresinde 16 parsel. n. parsel: 500·n^1.6 altın, seviye 2+n; yalnız açık araziye kenar komşusu alınır.
- Başlangıç alanı küçülür (ör. 12×12), çevresi 6×6'lık kilitli parseller.
- Parsel n: seviye `2n+1` şartı, maliyet `25·n²` altın (wiki'deki eğriye benzer artış). Kilitli parsel üstünde fiyat tabelası.

### 8. Araçlar ve ev
- **Traktör**: binince 3×3 alanı tek seferde sürer/eker/sular. **Fıskiye**: çevresini otomatik sular.
- Ev içi: mobilya kur, çok adımlı **işler** yap, **bilet** kazan; biletle dekor ve yardımcı işçi.

### 9. Görsel yenileme (CC0 asset'ler) — kısmen ✅
- Yapıldı: ekinler (4 aşama), elma/portakal ağaçları, inek/domuz/koyun (animasyonlu), kaya/çalı, çevre ormanı. Tavuk, kiraz, ayçiçeği pakette yok → prosedürel.
- Ağaç, kaya, çit, çalı, çiçek: [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) (CC0, 330 dosya).
- Animasyonlu hayvanlar: [Quaternius LowPoly Animated Animals](https://quaternius.itch.io/lowpoly-animated-animals) / [OpenGameArt](https://opengameart.org/content/lowpoly-animated-farm-animal-pack) (CC0, idle/yürüme/koşma).
- 5 büyüme aşamalı ekinler: [Quaternius LowPoly Crops](https://opengameart.org/node/126983) (CC0, 100+ model).
- Godot 4.7 FBX ve GLB'yi doğrudan içe aktarır; dönüştürmeye gerek yok. Prosedürel modeller yedek olarak kalır (asset yoksa onlar kullanılır).
- Karakter özelleştirme (şapka, renk).

### Geri bildirim turu (23.11.2026) ✅
- Çarpışma + A* yol bulma, çit kapısı, tavuk kümesi; serbest kamera; ana menü, yükleme ekranı, 3 kariyer yuvası (sıfırlama kaldırıldı); üretim ~3× yavaş, 15 dk gün, 30 dk mevsim; güneş adımsız (gölge titremesi).
- ✅ Modeller elden geçti: yumuşak gölgeli yeni çiftçi (hasır şapka, tulum, yüz), 🥗 Marul (Sv1, ilkbahar/sonbahar) ve 🥬 Lahana (Sv3, sonbahar/kış), sırtlı ve topaklı toprak, rüzgârda sallanan ve mevsimle renk değiştiren çim (parsel başına MultiMesh), tarla/tarh üstünde 🧺 hazır ve 💧 susuz simgeleri.

### Sonraya
- Çok oyunculu ziyaret, bonus sayacı, izinler — ağ altyapısı gerektirir.

## Teknik hazırlık (Aşama 1'den önce)
- `game.gd` ~1300 satır; aşamalar eklendikçe bölünür: `world.gd`, `farm.gd` (varlıklar + simülasyon), `ui.gd`, `save.gd`, `audio.gd`.
- Kayıt dosyasına sürüm alanı zaten var (`v`); her aşamada geçiş (migration) eklenir.

### Geri bildirim turu 2 (23.11.2026) ✅
- Ağıl kapısı ve çiftlik girişi çiftçi yaklaşınca ondan uzağa açılır, uzaklaşınca kapanır.
- Eşya seçimi: alete tıklayınca açılan sayfalı pencere (8'li ızgara, ◀ ▶); seçilen eşyanın simgesi alet düğmesinde.
- Gece: özel gökyüzü shader'ı (ay, hilal gölgesi, titreşen yıldızlar, samanyolu), geceleri ay ışığı; dalgalı, fresnel yansımalı su.
- Uzaklar: ufukta karlı dağlar, büyüyen tepeler, MultiMesh uzak orman, ufuk bulutları.
- Hikâyeli yeni kariyer: Nermin Teyze'nin mektubu (5 sayfa), ot/taş/kütük bürümüş arazi, 9 adımlık ⭐ Hikâye görevi (temizle → sür → ek → sula → hasat → sat → tavuk → kümes → yumurta). Hikâye bitene kadar rastgele görev yok.

### Geri bildirim turu 3 (23.11.2026) ✅
- Çiftlik sınır çiti ve gölet artık yürünmez; çiftçi dışarı kapıdan çıkar. Tıklama tepelere göre hesaplanır; gezilebilir alan ±56.
- Alt alet çubuğu kaldırıldı: Tab / 🎒 ile imlecin etrafında açılan çark menü.
- İş animasyonları: sulama kovası ve damlalar, tohum serpme, yem saçma (hayvanlar zıplar), çapa vuruşu, hasat sepeti.
- Online (Aşama 7'nin ilk parçası): ev sahibi yetkili ENet; avatarlar, iş istek/yayın, 3 sn'de tam senkron. Sonra: sohbet, misafirin ambar kullanması, internet için aracı sunucu.


### Geri bildirim turu 4 (23.11.2026) ✅ — v0.1.0 Erken Erişim
- Godot mağazası incelendi: Stylized Nature MegaKit (CC0) alındı; Sky3D ve Sunshine Clouds şimdilik alınmadı (kendi gökyüzü shader'ımız var, bulutlar ağır).
- Doğa: MegaKit dokulu ağaç/çalı/çiçek/ot/taş; sonbaharda yapraklar kızarır, kışın solar. Uzak süsler gölgesiz, küçük süsler 70 m'den sonra çizilmez.
- Genişleme: kare parsel tabelaları yerine 6 temalı bölge (hafif sis, tek giriş tabelası, bölge bonusu). Kayıt biçimi aynı.
- Uygulama: `tools/build.sh` ile Windows klasörü + zip, menüde sürüm etiketi, `ciftlik/update_url` ile güncelleme duyurusu altyapısı.
- Sonra: dışa aktarma şablonlarıyla özel simgeli exe, güncelleme JSON'unu barındıracak adres (ör. GitHub Releases), kurulum sihirbazı.
