# Çiftliğim 3D — Oyun Mantığı (v0.21.0)

> Bu belge oyunun **şu anki** halini anlatır. İstediğin yeri değiştir, sil, ekle.
> Her bölümün altında **✏️ Notların** alanı var; fikirlerini oraya yazıp bana geri ver.
> Değiştirmek istediğin bir sayı varsa doğrudan üzerine yazman yeterli (örn. `60 sn` → `45 sn`).

---

## 1. Oyunun özü

Rahat (cozy) bir çiftlik oyunu. Oyuncu teyzesinden kalan, otlarla kaplı bir araziye gelir. Araziyi temizler, tarla sürer, ekin eker, hayvan besler. Ürünleri ambarda biriktirip satar, köylülerin isteklerini karşılar. Kazandığı parayla çiftliğini büyütür ve süsler.

- **Tür:** 3D, yukarıdan bakışlı, tıkla-yürü çiftlik oyunu
- **Kayıt:** Birden çok kariyer (kayıt yuvası), otomatik kayıt
- **Çevrimdışı büyüme:** Oyun kapalıyken ekinler en fazla 6 saat büyümeye devam eder
- **Çok oyunculu:** Yerel ağ ya da internet üzerinden arkadaş çiftliğe katılır (ev sahibi yetkili)

✏️ Notların:

---

## 2. Dünya ve harita

| Alan | Açıklama |
|---|---|
| **Çiftlik** | Ortada, çitle çevrili kare alan. Başlangıçta 16×16 m, genişletmeyle 40×40 m'ye kadar büyür. Güney kapısında çiftliğin adını taşıyan tabela var. |
| **Kasaba Pazarı** | Çiftlik kapısından çıkan toprak yolun hemen güneyinde. Çeşmeli bir meydan, 4 tezgâh ve 4 köylü (Fırıncı Zeynep, Balıkçı Rıza, Çiçekçi Leyla, Muhtar Hasan). |
| **Yeşilköy** | Pazarın güneyinde. Ana yol, iki cadde ve iki yan yol üzerinde 18 ev; uçlarda ahırlar ve silolar; ortada büyük ağaçlı meydan. |
| **Göl** | Çiftliğin doğusunda. Kıyısında balıkçı tezgâhı ve kano var. |
| **Kamp alanı** | Batıda: çadır, kamp ateşi, kütükler. |
| **Yel değirmeni** | Kuzeydoğuda. Tahıl buradan una dönüşür. |
| **Doğa** | Başlangıç bölgesinin çevresi ılıman çayır; uzaklaştıkça biyomlar başlar. |

- **Sonsuz dünya (v0.21):** Sınır yok, görünmez duvar yok. Dünya oyuncunun çevresinde 50×50 m'lik karolar halinde yüklenir. Yakın karolarda gerçek modeller var, uzakta ucuz biçimler. Ağır hesap arka plan iş parçacığında yapılır.
- **Tohum:** Her yeni kariyer kendi dünya tohumunu alır ve kayda yazılır. Eski kariyerler 1 numaralı dünyayı kullanır. Ağ oyununda misafir, ev sahibinin dünyasını görür.
- **Başlangıç bölgesi (±100 m):** Elle yapılmış çiftlik, pazar, Yeşilköy, göl, kamp ve değirmen burada. Kenarda sonsuz araziye dikişsiz karışır. Çevresindeki ~250 m hep ılıman çayırdır.
- **6 biyom**, yumuşak geçişlerle:
  - **Ilıman çayırlar:** hafif tepeler, meşe ve huş, çalı, çiçek.
  - **Orman kıyısı:** sık huş, meşe ve çam; eğrelti, mantar, kütük.
  - **Göl vadisi:** çok göl, kumsal, kiraz çiçeği, sazlık.
  - **Güneşli ova:** düz altın sarısı otlak, ayçiçeği.
  - **Yüksek yayla:** büyük tepeler, karlı zirveler, çam ve kaya.
  - **Karlı kuzey:** kar örtüsü, ladin, kar yığınları; kuzeye (-z) gidildikçe sıklaşır.
- **Engeller:** Göl suyu, ağaçlar, büyük kayalar ve kütükler yürünemez; yol bulma etraflarından dolaşır.
- **Görüş:** Grafik kalitesine göre 4–6 karo halkası (~225–325 m), ötesi sis.
- **Henüz yok (sıradaki aşamalar):** dışarıda serbest çiftlik kurma (v0.22), M harita ekranı (v0.23), biyomlarda yeni köy ve pazarlar.

✏️ Notların:

---

## 3. Gün, mevsim, hava

- **Gün/gece:** 1 oyun günü = 15 dakika (gündüz ~%70, gece ~%30). Gece lambalar ve fenerler yanar.
- **Mevsimler:** İlkbahar 🌸, Yaz ☀️, Sonbahar 🍂, Kış ❄️. Her mevsim 30 dakika ve gün/geceden bağımsız ilerler. Zemin ve ağaç renkleri mevsimle değişir.
- **Hava olayları** (mevsim başında şansa bağlı):
  - 🌧️ **Yağmur:** Tarlalar kendiliğinden sulanır (ilkbahar ve sonbahar %40, yaz %15).
  - 🔥 **Kuraklık:** Toprak 3 kat hızlı kurur (yaz %35).
  - 🌨️ **Kar:** Sulamaya gerek kalmaz, ekinler yavaş ama düzenli büyür (kış %60).

✏️ Notların:

---

## 4. Aletler (alt çubuk)

| Tuş | Alet | Ne yapar |
|---|---|---|
| ✋ | **El** | Akıllı el: bakılan şeye göre ekim, sulama, toplama ya da yemleme |
| ⛏️ | **Çapa** | Boş çimeni tarlaya çevirir |
| 🌱 | **Tohum** | Seçili tohumu eker |
| 💧 | **Sula** | Toprağı ıslatır; ıslak toprak 2 kat hızlı büyür |
| 🌳 | **Ağaç** | Meyve ağacı diker |
| 🐔 | **Hayvan** | Hayvan satın alır |
| 🌷 | **Dekor** | Çit, yol, çiçek, köy süsleri |
| 🌼 | **Bahçe** | Çiçek tarhı ve balık göleti |
| 🏗️ | **Yapı** | Ambar, kuyu, silo, fırın, ahır, ev, süs yapılar |
| 🗑️ | **Kaldır** | Nesneyi kaldırır; nesne çantaya girer |
| 🚚 | **Taşı** | Nesneyi başka yere taşır |

✏️ Notların:

---

## 5. Üretim

### 5.1 Ekinler
Islak tarlada aşağıdaki sürelerde olgunlaşır, kuru tarlada yarı hızda büyür. Her ekin belli mevsimlerde ekilebilir.

| Ekin | Seviye | Tohum | Satış | Süre | Mevsim | Ambara |
|---|---|---|---|---|---|---|
| 🌾 Buğday | 1 | 5 | 12 | 60 sn | Hepsi | 2 tahıl |
| 🥕 Havuç | 1 | 10 | 26 | 135 sn | İlkbahar, Sonbahar, Kış | 2 sebze |
| 🥗 Marul | 1 | 8 | 20 | 100 sn | İlkbahar, Sonbahar | 2 sebze |
| 🍅 Domates | 2 | 20 | 52 | 270 sn | İlkbahar, Yaz | 3 sebze |
| 🥬 Lahana | 3 | 25 | 70 | 380 sn | Sonbahar, Kış | 4 sebze |
| 🌽 Mısır | 3 | 30 | 80 | 450 sn | Yaz, Sonbahar | 4 tahıl |
| 🌻 Ayçiçeği | 4 | 45 | 120 | 720 sn | Yaz | 3 kuruyemiş |
| 🎃 Balkabağı | 5 | 70 | 190 | 1080 sn | Sonbahar | 6 sebze |

- **Su:** Dolu su seviyesi 4 dakikada kurur. Yeniden sulamak için seviyenin %60'ın altına düşmesi gerekir.
- **Kuyu:** Çevresindeki 5 karedeki tarla ve çiçekleri yarı hızla kendiliğinden sular.

### 5.2 Meyve ağaçları
Dikilip büyüdükten sonra tekrar tekrar meyve verir.

| Ağaç | Seviye | Fiyat | Büyüme | Yeniden meyve | Satış |
|---|---|---|---|---|---|
| 🍎 Elma | 2 | 150 | 6 dk | 4,5 dk | 35 |
| 🍊 Portakal | 4 | 300 | 10 dk | 7 dk | 60 |
| 🍒 Kiraz | 6 | 500 | 15 dk | 10 dk | 95 |

### 5.3 Hayvanlar
Hayvanlar yemle üretim yapar.
- **Yem:** Bir tam yem 3 ürün süresi yeter; yem bitince üretim durur. Yem ambardaki tahıldan karşılanır; tahıl yoksa eksik her tahıl için 6 altın ödenir.
- **Ağıl:** Yan yana duran aynı tür hayvanlar ağıl oluşturur ve tek tıkla hepsi yemlenir.
- **Hayvan seviyesi:** Her seviye satışa +%15 ekler, her 2 seviyede +1 ürün verir. En fazla Sv 5.
- **Sevme:** Hayvana basılı tutarak sevilir. Hayvanlara isim verilebilir.

| Hayvan | Seviye | Fiyat | Ürün | Süre | Yem (tahıl) |
|---|---|---|---|---|---|
| 🐔 Tavuk | 1 | 80 | 🥚 Yumurta | 3 dk | 1 |
| 🐑 Koyun | 3 | 250 | 🧶 Yün | 6 dk | 2 |
| 🐷 Domuz | 5 | 400 | 🍄 Mantar | 9 dk | 3 |
| 🐄 İnek | 6 | 600 | 🥛 Süt | 12 dk | 4 |

- **Kümes:** Çevresindeki 6 karedeki tavuklar yumurtalarını kümese bırakır (en fazla 12).
- **Ahır:** Çevresindeki 4 karedeki koyun, domuz ve inekler için.

### 5.4 Çiçekler ve gölet
- **Çiçek tarhları:** Papatya 🌼, Lale 🌷, Gül 🌹, Lavanta 💜. Tarh kalıcıdır, hasattan sonra yeniden açar.
  - Islak geçen süre arttıkça kazanç 3 kata, ürün +2'ye kadar çıkar.
  - Her tür hasat edildikçe seviye atlar.
- **Balık göleti** (2×2, 350 altın, Sv 3): Kendiliğinden balık üretir.

✏️ Notların:

---

## 6. Ambar ve kaynaklar

Hasat edilen her şey **ambara** kaynak olarak girer.
- **Kapasite:** Ambar 150, her silo +100, Geniş Ambar geliştirmesi +60.

| Kaynak | Fiyat | Nereden gelir |
|---|---|---|
| 🌾 Tahıl | 3 | Buğday, mısır |
| 🥕 Sebze | 4 | Havuç, marul, domates, lahana, balkabağı |
| 🍎 Meyve | 6 | Ağaçlar |
| 🌻 Kuruyemiş | 8 | Ayçiçeği |
| 🥚 Yumurta | 5 | Tavuk |
| 🧶 Yün | 9 | Koyun |
| 🍄 Mantar | 12 | Domuz |
| 🥛 Süt | 14 | İnek |
| 🌷 Çiçek | 7 | Çiçek tarhları |
| 🐟 Balık | 10 | Gölet, balıkçılık |
| 🥖 Un | 8 | Değirmen (tahıldan) |
| 🥐 Poğaça | 30 | Fırın: 2 un + 1 yumurta |
| 🥪 Balık Ekmek | 45 | Fırın: 1 un + 2 balık |
| 🥧 Meyveli Turta | 72 | Fırın: 2 un + 1 süt + 2 meyve |

- **Satış:** Ambardan satılır (B tuşu).
- **Pazar siparişleri:** Pazar belli ürünleri ister; teslim edince altın ve madalya kazanılır.

✏️ Notların:

---

## 7. İşleme ve mini oyunlar

- **🌬️ Değirmen:** Tahılı una çevirir. Zamanlama mini oyunu: doğru anda tıklayınca isabet, tam ortada tıklayınca mükemmel.
- **🔥 Fırın:** Poğaça, balık ekmek ve turta pişirilir. Ateşi harlayıp ısıyı "altın kıvam" bölgesinde tutmak gerekir.
- **🎣 Balıkçılık:** Gölde olta atılır; yeşil alanda tutarak balık çekilir.
  - **Balıklar:** Kızılkanat, Sazan, Alabalık, Turna, Yayın (yalnız gece), Altın Sazan (nadir, elmas verir).
  - **Tezgâh:** Bambu ve Usta oltası, solucan ve parlak yem satılır.

✏️ Notların:

---

## 8. İlerleme

- **Seviye ve XP:** Her eylem XP verir. Yeni seviyeler yeni tohum, hayvan, yapı ve süsleri açar.
- **Para birimleri:**
  - 🪙 **Altın:** Ana para.
  - 🏅 **Madalya:** Görev ve siparişlerden gelir; geliştirmelerde harcanır.
  - 💎 **Elmas:** Nadir; görev silme ve geliştirmelerde harcanır.
- **Arazi genişletme:** Çiftlik 6 adımda büyür.

  | Adım | Boyut | Altın | Seviye |
  |---|---|---|---|
  | 1 | 20×20 m | 300 | 2 |
  | 2 | 24×24 m | 700 | 3 |
  | 3 | 28×28 m | 1500 | 5 |
  | 4 | 32×32 m | 3000 | 7 |
  | 5 | 36×36 m | 5500 | 9 |
  | 6 | 40×40 m | 9000 | 12 |

- **Çiftlik geliştirmeleri** (her biri 3 kademe; altın + madalya ile alınır):
  - Bereketli Toprak 🌱: Ekin hasadında +%10 altın
  - Usta Bakıcı 🐄: Hayvanlar %10 hızlı üretir
  - Damla Sulama 💧: Toprak %15 yavaş kurur
  - Geniş Ambar 📦: Ambara +60 yer
  - Budama Ustası 🍎: Meyve hasadında +%15 altın
  - Pazarlık 💰: Ambardan satışta +%8 altın

✏️ Notların:

---

## 9. Görevler

### 9.1 Hikâye (yeni kariyer, 11 adım)
1. Araziyi temizle
2. Ambar kur
3. Tarla sür
4. Buğday ek
5. Sula
6. İlk hasadı topla
7. Ürün sat
8. 2 tavuk al
9. Kümes kur
10. Yumurta topla
11. Çiftlik evi kur

Her adım altın ve XP verir; bazı adımlarda kısa hikâye metni çıkar.

### 9.2 Günlük görevler (sol panel, J tuşu)
- Aynı anda 4 görev açık olur ("4 havuç topla", "17 kez sula", "400 altın kazan" gibi).
- Ödül olarak madalya, elmas ve XP verir.
- Silme: 24 saatte 1 ücretsiz, sonrası 2 💎.

### 9.3 Pazar köylüleri (4 kişi)
- Her sabah her biri yeni bir şey ister; teslim edince altın, XP ve ❤ dostluk kazanılır.
- Günde bir hediye verilebilir; sevdiği bir şey verirsen daha çok ❤ gelir.
- **Kalpler:** Her yeni kalpte altın hediye; 5 kalpte kalıcı yetenek açılır:

| Köylü | 5 kalpte yetenek |
|---|---|
| Fırıncı Zeynep | Fırında altın kıvam süresi +3 sn |
| Balıkçı Rıza | Balık tutarken yeşil alan daha geniş |
| Çiçekçi Leyla | Çiçek tarhları %20 daha hızlı açar |
| Muhtar Hasan | Pazar siparişlerinden %20 fazla altın |

### 9.4 Yeşilköy işleri (8 isimli köylü)
- **Köylüler:** Postacı Kemal, Terzi Ayşe, Sütçü Fatma, Demirci Mehmet, Öğretmen Elif, Doktor Selin, Marangoz Ali, Bekçi Yusuf.
- **12 adımlık zincir:** Köylüleri birbiriyle tanıştırma ve ambardan ürün götürme işlerinden oluşur.
- **Hediyeler:** 4., 8. ve 12. adımda elmas ve çantaya hediye süs (bank, sokak lambası, pazar tezgâhı).
- **Zincirden sonra:** Her gün bir köylü küçük bir rica eder.
- Sıradaki işi veren köylünün başında ❗ durur.
- Yürüyen köylülere tıklayınca durup bir laf ederler.

### 9.5 Mevsim etkinlikleri
Her mevsim bir yarışma olur:
- İlkbahar: Çiçek Şenliği
- Yaz: Balık Yarışması
- Sonbahar: Hasat Festivali
- Kış: Kardan Adam Yarışması

Üç derece ödülü vardır. Altın derecede kalıcı kupa süsü kazanılır.

✏️ Notların:

---

## 10. Süsleme ve yapılar

- **Dekor:** Çit, taş yol, çiçekler, fenerler, korkuluk ve 21 köy/doğa süsü (bank, fıçı, sokak lambası, kiraz ağacı, kış süsleri…).
- **İşlevli yapılar:** Ambar, Su Kuyusu, Silo, Fırın, Ahır, Çiftlik Evi (her sabah kapıda küçük hediye bırakır).
- **Süs yapılar (işlevsiz):** Yem Kulesi, Su Deposu, Mavi Kulübe, Ahşap Kule, Kırmızı Ev, Ahşap Ev, Kırmızı Ahır, Gri Ahır, Büyük Ahır, Malikâne.
- **🎒 Çanta (I tuşu):** Kaldırılan eşya çantaya girer; bedava yeniden yerleştirilir ya da yarı fiyatına satılır. Hayvanlar kaldırılınca yarı fiyatı geri verir.

✏️ Notların:

---

## 11. Yeşilköy'ün canlılığı

- **Köylüler:** 13 köylü yol kenarlarında yürür, 8'i ikişer ikişer sohbet eder. Çiftçi önlerine çıkarsa beklerler.
- **Arabalar:** 4 araba caddelerde tur atar; önlerine çıkarsan dururlar. Ayrıca park etmiş arabalar, polis arabası, otobüs ve kamyonlar var.
- **Gece:** Sokak lambaları ve araç farları yanar.

✏️ Notların:

---

## 12. Çok oyunculu

- Ev sahibi çiftliği paylaşır; misafir IP ile katılır.
- Ev sahibi yetkilidir: misafirin her eylemi ev sahibine gider, sonuç herkese eşitlenir.
- **Ortak olanlar:** Altın, ambar, görevler, köylü istekleri, Yeşilköy işleri, etkinlikler.
- Oyuncular arasında sohbet ve emoji var.

✏️ Notların:

---

## 13. Konuşulan / planlanan fikirler

- [ ] Büyük ya da sonsuz harita: parça parça yükleme (Minecraft gibi), tohumdan üretilen doğa
  - Sonsuz mu, kenarlı büyük mü (örn. 2×2 km)?
- [ ] Tohumdan üretilen yeni köyler ve kasabalar; kendi köylüleri ve işleri
- [ ] Uzak yerlere ulaşım (otobüs durağı, at arabası…)
- [ ] Yeni işleme binaları (süt → peynir, meyve → reçel, yün → kumaş)
- [ ] Köylülerle dostluk / kalp sistemi Yeşilköy'e de gelsin mi?

✏️ Senin fikirlerin (öncelik sırasına göre yazarsan çok iyi olur):
1.
2.
3.
