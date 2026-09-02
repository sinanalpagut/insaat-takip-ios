# Cihaz Turu — tam modül taraması

> **2 Eyl 2026'da koşturuldu.** Sonuçlar `ANALIZ.md` içinde ("CİHAZ TURU"
> başlıkları) ve hafızada. Aşağıdaki liste bir dahaki tur için duruyor;
> geçenler ve kalanlar sonunda özetli.

**Amaç:** simülatörde YAPISAL olarak kanıtlanamayan yollar + son turdan (18 Ağu)
sonra eklenen her şey, GERÇEK cihazda ve GERÇEK Firebase'de bir kez koşsun.

**Cihaz:** iPhone 13 Pro · `51B0D092-721A-5A8C-8C50-3A1D8275EB48`

**İş bölümü:** ekrana Sinan dokunur, Claude günlükten ve veritabanından
doğrular. Claude cihazı süremiyor — simülatör aracı gerçek telefona dokunmuyor.

**TUZAK (bir tur bu yüzden boşa gitti):** üretim testinde `-backend firestore`
ŞART. Bayrak verilmezse DEBUG derlemesi bellek içi demo verisi kullanır; Auth
gerçek olur ama hiçbir şey Firestore'a/Storage'a yazılmaz.

---

## 0 · Kurulum (Claude yapar, Sinan yalnızca telefonu açık tutar)

- [ ] Cihaz USB ile bağlı ve **KİLİDİ AÇIK** (kilitliyse başlatma "Locked" ile reddedilir)
- [ ] Derleme + kurulum
- [ ] Davet kuralının yayına alınması — **SIRA ÖNEMLİ: önce kurulum, sonra deploy.**
      Yeni derleme eski kuralla çalışır; eski derleme yeni kuralla davet ÜRETEMEZ.
- [ ] `-backend firestore` ile başlat, konsol günlüğü açık

---

## 1 · AÇIK SORU — önce bu (10 saniye)

Sheet içindeki metin alanları odak almıyordu (simülatörde; cihazda hiç
denenmedi). Cevabı diğer her şeyin önünde çünkü olumsuzsa yayından önceki ilk
iş bu olur.

- [ ] Fiş Ekle → **MİKTAR** alanına dokun → klavye açılıyor mu, imleç var mı?
- [ ] Açılıyorsa: rakam yaz, alanda görünüyor mu?

---

## 2 · Giriş ve kimlik

- [ ] Telefonla giriş (test numarası) — SMS turu, reCAPTCHA AÇILMAMALI
- [ ] İsim ekranı (yeni kullanıcıysa) → profil `users/{uid}` yazıldı mı
- [ ] Uygulamayı kapat/aç → oturum korunuyor mu

## 3 · Proje ve daireler

- [ ] Yeni proje oluştur (ada/parsel/ilçe/il/kat/daire sayısı)
- [ ] **Kurulum ekranındaki "parsel başına tek proje" yönlendirmesi görünüyor mu** (madde 83)
- [ ] Daire düzenle: tip, alan, **BLOK / ETAP** etiketi, liste fiyatı
- [ ] **Blok etiketi kaydedildikten sonra uygulamayı kapat/aç — etiket DURUYOR mu**
      (bugün bulunan kusur: kodlayıcı alanı yazmıyordu, bellekte duruyor
      veritabanına gitmiyordu)
- [ ] İki farklı blok etiketi gir → Daireler listesinde GRUPLAMA çıkıyor mu
- [ ] Satış ekle (alıcı adı, bedel, tarih) → daire kartı ve toplamlar
- [ ] Tahsilat ekle → "Tahsil edilen" ve "Kalan alacak" değişiyor mu
- [ ] Taksit planı üret → vadeler, gecikmiş tahsilat kartı

## 4 · Malzeme ve gider (şantiyenin günlük işi)

- [ ] **Fotoğraf Çek** ile fiş → OCR tutarı yakalıyor mu
- [ ] Fiş kaydet → stok, birim fiyat, tutar
- [ ] Gider ekle (kategori, tutar, kime ödendi, fiş görseli)
- [ ] Devir (açılış bakiyesi) gir
- [ ] **KDV Beyanı** (madde 80): gider "KDV dahil", satış "KDV hariç" seç →
      form etiketlerinde ek görünüyor mu ("TUTAR (₺) · KDV DAHİL")
- [ ] Rapor kapsam cümlesi iki tabanın farkını söylüyor mu

## 5 · Ortaklar ve cari hesap (madde 82 — cihazda hiç koşmadı)

- [ ] Hisse tanımla → kayıt izine yazıldı mı
- [ ] **Cari hareket ekle**: sermaye / çekilen / kâr dağıtımı
- [ ] Bakiye doğru mu (sermaye − çekilen − dağıtım)
- [ ] **Uygulamayı kapat/aç — hareketler DURUYOR mu** (Firestore'a gitti mi)
- [ ] Cari hareketin dönem netini DEĞİŞTİRMEDİĞİ ekranda doğrulanıyor mu
- [ ] Hareket sil → kayıt izinde "silindi" satırı

## 6 · Davet akışı — **PROJENİN EN BÜYÜK KANITSIZ İŞİ**

Üretimde bir kez bile koşmadı. İki hesap gerekiyor.

- [ ] Davet kodu üret → kod ekranda görünüyor mu
- [ ] Kodun ömrü: `invites/{kod}` belgesinde `createdAt` SUNUCU damgası mı
      (bugünkü kural), `expiresAt` 48 saat sınırında mı
- [ ] İkinci hesapla (ya da çıkış yapıp başka numarayla) kodu kullan
- [ ] Ortak projeyi görüyor mu; SALT OKUR mu (yazma denemeleri reddedilmeli)
- [ ] Ortak alıcı adlarını GÖRMÜYOR mu (madde 18)
- [ ] Ortak cari hesabını görüyor ama yazamıyor mu (madde 82 kuralı)
- [ ] Ortağı çıkar → erişimi kesiliyor mu

## 7 · Rapor, PDF ve dosyalar

- [ ] Dönem raporu: dönem çipleri, özet, **beklenen hasılat**, **blok kırılımı**
- [ ] İlerleme sheet'inden **bitirmek için kalan maliyet** gir → "Beklenen sonuç" satırı
- [ ] **PDF indir → AÇ**: dört kart da var mı, kapsam cümleleri TAM mı (kesilmiyor mu)
- [ ] **CSV + yedek indir → AÇ**: `Ortak-Cari.csv`, Daireler'de "Blok / Etap",
      Giderler'de "Kime Ödendi" başlığı, Türkçe karakterler
- [ ] Yedeği geri yükle (başka bir cihazda ya da hesap silmeden önce)

## 8 · Şantiye koşulları

- [ ] **Uçak modu** → gider kaydet → amber "Bağlantı bekleniyor" şeridi
- [ ] Uçak modunu kapat → gönderildi mi, yeniden başlatınca sunucudan geliyor mu
- [ ] Şantiye fotoğrafı çek → yüklendi mi
- [ ] Belge yükle (PDF) → ortak görünürlüğü işareti

## 9 · Güvenlik ve hesap

- [ ] Uygulama kilidi aç (Face ID) → arka plana al, geri dön → kilit ekranı
- [ ] Kayıt izi: bugünkü değişiklikler tarih/saat/kişiyle görünüyor mu
- [ ] **Hesabı sil** → "önce verini indir" adımı → SMS turu → silme
- [ ] Silmeden sonra tekrar giriş → "Adın ne?" ekranı (temiz başlangıç)

## 10 · Erişilebilirlik (bugün eklendi, cihazda hiç görülmedi)

- [ ] Ayarlar → Ekran ve Parlaklık → Metin Boyutu → en büyük
- [ ] Rapor: dönem çipleri okunabiliyor mu (sarılmalı, kesilmemeli)
- [ ] Proje başlığı: tam görünüyor mu, kendi satırında mı
- [ ] Para rakamları kesiliyor mu (kesilmemeli)

---

## 2 Eyl 2026 turunun sonucu

**GEÇTİ:** sheet odak sorusu (araç sınırıymış), giriş/oturum, proje ve daire
kurulumu, blok etiketi + gruplama + rapor kartı, KDV beyanı (ekran → PDF →
CSV), ortak cari hesabı, **davet akışı uçtan uca** (üretimde ilk kez), ortak
yüzeyinin sınırları, Kayıt İzi, PDF ve CSV/yedek dosyalarının içeriği,
uygulama kilidi (Face ID).

**BULUNAN KUSURLAR (üçü de düzeltildi):** cari hareketlerin
`DataSnapshot.merge`de düşmesi · CSV'de girilmemiş fiyatın "0,00" yazılması ·
büyük metinde portföy satırı ve kilit başlığının kesilmesi.

**KOŞMAYANLAR:** hesap silme (gerçek hesabı yok edeceği için bilinçli olarak
atlandı), dolu depolama dalı, davet BAĞLANTISI (alan adı yok — madde 29).
