# Çiftliğim 3D — Sürüm Notları

## v0.5.0 · Erken Erişim
- 😄 Emote: üst çubuktaki 😄 düğmesi ya da G tuşu. El salla, gül, kalp, beğen, kahkaha, kutla, şaşır, üzül. Balon karakterinin başında çıkar; yakında arkadaşın varsa karakterin ona döner. Online iki tarafta da görünür (çubuk açıkken 1–8 tuşları).
- Online: arkadaşın da ambarı açıp ürün satabilir ve sipariş teslim edebilir; para ve ambar iki tarafta eşitlenir.
- Kendi koyduğun çitler çiftliğin sınır çitine bağlanır, arada boşluk kalmaz.
- Hikâye: istenen şey önceden yapıldıysa (ör. kümesi erken kurduysan) adım kendiliğinden geçer.

## v0.4.0 · Erken Erişim
- 🚚 Taşı aleti (- tuşu): bir nesneye tıkla, sonra yeni yerine tıkla. Ambar, ev, silo, kuyu, ağaç, hayvan, kümes, çit, yol… hepsi bedava taşınır; Esc vazgeçer.
- 🔄 Döndürme: Taşı aletiyle seçili nesneye tekrar tıkla ya da T'ye bas, 90° döner.
- Binanın üstünde sol tuşu basılı tut: 🔄 Döndür · 🚚 Taşı · 🗑️ Kaldır menüsü açılır. Kısa tıklama eskisi gibi (ambarı açar).
- 🗑️ Kaldır artık satın alma fiyatının yarısını geri veriyor (önce %25'ti). İmleç üstünde ne kadar geri geleceği yazar.
- Online: paylaşım penceresi Hamachi ve Tailscale adreslerini işaretliyor; bağlanamayınca Güvenlik Duvarı ipucu çıkıyor.

## v0.3.1 · Erken Erişim
- Online görevler ortak: arkadaşın da çiftliğin hikâye adımını ve günlük görevlerini görür. Onun yaptığı işler (sürme, ekme, hasat…) aynı görevlere sayılır.
  - Görev tamamlanınca duyuru iki oyuncuda da çıkar. Madalya ve elmas sayısı da eşitlenir.
  - Misafir görev silerse ev sahibinin ücretsiz hakkı ya da elması kullanılır.
- Not: Online oynarken iki oyuncunun da aynı sürümde olması gerekir.

## v0.3.0 · Erken Erişim
- Yeni arazi düzeni: yeni kariyer 16×16 küçük bir kareyle başlar. 🗺️ Arazi menüsünden (üst çubuk ya da L tuşu) altın ve seviyeyle adım adım 40×40'a kadar büyür; çit kendiliğinden dışarı taşınır.
  - Temalı bölgeler, sis ve tabelalar kalktı; çitin dışı doğal, yabani bir arazi.
  - Eski kayıtlar açtığın alanı kapsayan kareyle açılır, hiçbir şey kaybolmaz.
- Oyun artık tam ekran açılır (Ayarlar'dan ya da F11 ile pencereye alınabilir). Pencere başlığındaki "(DEBUG)" yazısı kalktı.
- Düzeltme: Kaldır aleti ambara ya da siloya tıklayınca ambar penceresini açıyordu; artık binayı kaldırıyor.

## v0.2.0 · Erken Erişim
- Her şeyi sen kur: yeni çiftlikte ev, ambar, silo, kuyu, yol ve fener yok. 🏗️ Yapı aletiyle (0 tuşu) kurulur.
  - Ambar: hasat saklama (150). Silo: +100 yer. Kuyu: çevresindeki tarlalar yarı hızda kurur. Ev: her sabah hediye altın.
  - Hikâyeye "ambar kur" ve "ev kur" adımları eklendi. Eski kayıtlar binalarıyla açılır.
- ⚙️ Ayarlar: tam ekran (F11), dikey eşitleme, FPS sınırı ve göstergesi, grafik kalitesi (Düşük/Orta/Yüksek/Ultra), çözünürlük, gece parlaklığı, ana ses ve efekt sesi.
- Gece: daha aydınlık mavi ay ışığı, suda ağaç ve çevre yansıması (Yüksek ve Ultra), suda ay parıltısı.
- Ağaç yaprakları daha canlı ve dolgun; kuru ağaçlar yol kenarlarından kalktı.
- Güncelleme duyurusu: oyun açılışta GitHub'daki son sürüme bakar, yenisi varsa ana menüde 🔔 gösterir.

## v0.1.0 · Erken Erişim (ilk sürüm)
- Hikâyeyle başlayan kariyer: Nermin Teyze'nin çiftliğini temizle, sür, ek, büyüt.
- Ekinler, meyve ağaçları, hayvanlar, kümes, çiçek tarhları, balık göletleri, ambar ve pazar siparişleri.
- Mevsimler, hava durumu, gün/gece, ay ve yıldızlar, su yansımaları.
- Çark menü (Tab), iş animasyonları (çapa, sulama, ekim, hasat, yemleme).
- 6 temalı bölge: Orman Kenarı, Meyve Tepesi, Mera, Göl Kıyısı, Çiçek Vadisi, Güneş Bayırı — her birinin bonusu var.
- Stilize doğa modelleri (Quaternius Stylized Nature MegaKit).
- Arkadaşın çiftliğine katılma (aynı ağ ya da port yönlendirmeyle, UDP 24565).

Kayıtlar: %APPDATA%\Godot\app_userdata\Çiftliğim 3D — yeni sürüm eski kayıtları açar.
