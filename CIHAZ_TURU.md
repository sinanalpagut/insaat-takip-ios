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

---

## YAYIN ÖNCESİ BLOKE EDEN TEK TEST — App Attest gerçek cihazda (15 Eki 2026)

**Bu test geçmeden TestFlight'a ya da App Store'a gönderim YAPILMAMALI.**

**Neden:** App Check zorlaması 15 Eki 2026'da açıldı. Bugüne kadar üretilen
her App Check jetonu **hata ayıklama jetonundan** geldi — `AppCheckSetup`
App Attest'i yalnızca Release'de kuruyor, cihaz turu DEBUG derlemesiyle
yapıldı ve tek Release koşusu simülatördeydi (App Attest simülatörde hiç
çalışmaz). Yani App Attest'in bu uygulamada çalıştığı **hiç kanıtlanmadı.**
Konsoldaki "Verified requests" oranı bu soruyu cevaplayamaz: o oran debug
jetonunu ölçüyor.

**Geçmezse ne olur:** mağaza derlemesi Firestore'dan tek satır okuyamaz,
Storage'a dosya yazamaz ve kullanıcı giriş yapamaz. App Review "uygulama
açılmıyor" diye reddeder.

**Simülatör bu testi YAPAMAZ.** Fiziksel iPhone şart.

- [ ] iPhone USB ile bağlı ve kilidi açık
- [ ] **RELEASE** derlemesi (Debug DEĞİL — Debug debug jetonunu kullanır ve
      hiçbir şey kanıtlamaz):
      `xcodebuild -scheme InsaatTakip -configuration Release -destination 'generic/platform=iOS'`
- [ ] Cihaza kur ve `-firedebug` ile başlat (SDK günlüğü açık)
- [ ] Günlükte App Check jetonunun ALINDIĞI görülmeli; `App Attest` ile
      ilgili hata YOKSA geçti
- [ ] Asıl kanıt davranışta: uygulama açılıyor, projeler **geliyor**, bir
      kayıt yazılabiliyor, çıkış yapıp yeniden **SMS ile giriş** yapılabiliyor.
      Zorlama açık olduğu için bunların çalışması App Attest'in çalıştığı
      anlamına gelir — zorlama kapalıyken aynı ekranlar hiçbir şey kanıtlamazdı.
- [ ] Geçmezse: konsoldan zorlama geri alınır (tek düğme), callable'lar için
      `enforceAppCheck` kaldırılıp yeniden dağıtılır (~1 dakika)

---

## GEÇTİ (16 Eki 2026, ikinci deneme) — **YAYIN BLOKAJI KALKTI**

```
[appcheck] jeton alındı
```

Günlükte başka hiçbir satır yok. App Attest bu uygulamada **çalışıyor.**

**ÇÖZÜM İKİ PARÇAYDI ve ikisi de ayrı ayrı gerekliydi:**
1. **App ID'de App Attest yeteneği açıldı** (Xcode → Signing & Capabilities
   → + Capability → App Attest). Apple portalındaki bu yetenek, Firebase
   konsolundaki App Check kaydından AYRI bir şey — Firebase tarafı 2 Eyl'de
   yapılmıştı, Apple tarafı hiç yapılmamıştı.
2. **Yetki değeri `production` yapıldı.** Xcode yeteneği eklerken
   `development` yazıyor ve O DEĞERLE 403 DEVAM EDERDİ: geliştirme ortamında
   üretilen doğrulamayı Firebase production ortamında doğrulayıp reddediyor.
   Yani Xcode'un varsayılanı burada yanlış çalışıyor.

**DOĞRULANDI, VARSAYILMADI** — imzalı pakette dört şey tek tek okundu:
`appattest-environment = production`, `CFBundleDevelopmentRegion = tr`
(Xcode göçü sırasında düşmediği denetlendi), kamera ve Face ID metinleri.

**AÇIK KALAN:** bu kanıt geliştirme imzalı bir derlemenin production
ortamına zorlanmasıyla alındı. Mağaza derlemesi o ortamı zaten kendiliğinden
kullandığı için doğru kanıt budur; yine de ilk TestFlight derlemesinde
`[appcheck]` satırı bir kez daha okunmalı — bedeli sıfır.

---

## İLK DENEME (16 Eki 2026) — DÜŞTÜ, kayıt olarak duruyor

Test tam da koyulma sebebini yaptı: **App Attest bu uygulamada çalışmıyor** ve
bu, mağazaya gönderilmeden önce öğrenildi.

### Kanıt

Release derlemesi iPhone 13 Pro'ya kuruldu, teşhis satırı günlüğe düştü:

```
[appcheck] JETON ALINAMADI — The server responded with an error:
 - URL: .../apps/<APP-ID>:exchangeAppAttestAttestation
 - HTTP status code: 403
 - Response body: { "error": { "code": 403,
     "message": "App attestation failed.", "status": "PERMISSION_DENIED" } }
```

### KESİN OLANLAR (yerel kanıtla)

1. Derleme **geliştirme imzalı**: `codesign -d --entitlements` çıktısında
   `aps-environment = development` ve `get-task-allow = true`.
2. Derlemede `com.apple.developer.devicecheck.appattest-environment`
   yetkisi **YOK**.
3. App Attest doğrulama takası **403 PERMISSION_DENIED** dönüyor.
4. O yetki eklendiğinde **imzalama düşüyor**:
   `Provisioning profile ... doesn't include the App Attest capability`
   — yani **App ID'de App Attest yeteneği AÇIK DEĞİL.**

### VARSAYIM (doğrulanmadı, öyle sunulmamalı)

403'ün sebebi muhtemelen ortam uyuşmazlığı: geliştirme imzalı derleme
Apple'ın *development* App Attest ortamında doğrulama üretir, Firebase ise
*production* ortamını doğrular. **Web araması bu teoriyi DOĞRULAMADI**;
üstelik bir geliştirici yeteneği açıkken de 403 aldığını bildiriyor. Yani
yetenek açıldıktan sonra test YENİDEN koşturulmalı — "açtık, düzelmiştir"
denmemeli.

### SIRADAKİ ADIM (kullanıcının işi — Apple geliştirici portalı)

1. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers**
2. `com.sinanalpagut.insaattakip` → Capabilities listesinde **App Attest**
   işaretle → Save
3. Haber ver: Claude profili yeniler, yetkiyi geri koyar, Release'i yeniden
   derleyip kurar ve teşhis satırını tekrar okur.

**App ID'de App Attest yeteneği, Firebase konsolundaki App Check kaydından
AYRI bir şey.** Firebase tarafı 2 Eyl 2026'da yapılmıştı; Apple tarafı
yapılmamış. İkisinin aynı şey sanılması bu maddeyi altı hafta geciktirdi.

### Geri konacak XML (yetenek açılınca)

```xml
<key>com.apple.developer.devicecheck.appattest-environment</key>
<string>production</string>
```

Gerekçesi: bu yetki olmadan App Attest yayın öncesi **hiç** denenemiyor —
mağaza derlemesi production imzalı olduğu için orada çalışması muhtemel ama
"muhtemel" yeterli değil; çalışmazsa uygulama mağazada tek satır veri
okuyamaz. Mağaza derlemesinde zararsız: App Store ve TestFlight zaten
production ortamını kullanıyor.

### Bu turda kalıcı olarak eklenen

`AppCheckSetup.probe()` — jetonun alınıp alınamadığını her açılışta günlüğe
yazıyor, **`#if DEBUG` YOK**. App Attest zaten yalnızca Release'de çalışıyor;
teşhisi DEBUG'a koymak tam da ölçülemeyen yeri ölçüsüz bırakmak olurdu.
Jetonun kendisi asla yazılmıyor (kimlik bilgisi), yalnızca sonuç ve hata.
Bu satır olmasaydı bugünkü bulgu görünmezdi: uygulama hiçbir şey söylemeden
açılıyordu.

---

## CİHAZ GÜNLÜĞÜNÜ GÜVENİLİR OKUMAK (16 Eki 2026)

Günlük bazen boş geliyordu ve bu, bulguları yanlış okumaya en yakın
olduğumuz an oldu: **sessizliği "sorun yok" sanmak.** İki ayrı sebep vardı.

**1. Tampon (kod kusuruydu, düzeltildi).** `print` stdout'a yazıyor; stdout
bir TTY'ye değil boruya bağlandığında satır değil BLOK bazlı tamponlanıyor.
`Diag` artık `stderr`'e yazıyor — tamponsuz, yazıldığı anda çıkıyor.

**2. Bağlanma yarışı (yöntem bilgisi, kod kusuru değil).** Uygulama ZATEN
ÇALIŞIRKEN `--console` ile bağlanılırsa açılıştaki satırlar kaçırılıyor;
`probe()` jetonu önbellekten alıp anında yazdığında konsol henüz bağlanmamış
oluyor. **Çözüm soğuk başlatma:**

```sh
xcrun devicectl device info processes --device <UDID> | grep InsaatTakip
xcrun devicectl device process terminate --device <UDID> --pid <PID>
xcrun devicectl device process launch --device <UDID> --console <BUNDLE>
```

**KURAL:** boş günlük bir kanıt DEĞİLDİR. Ya soğuk başlatıp tekrar bak, ya
da kanıtı başka yerden al (ekran, konsol metrikleri).

---

## DEBUG DERLEMESİ ZORLAMA ALTINDA ÇALIŞIYOR (16 Eki 2026)

App Check zorlaması açıldıktan sonra "Debug derlemeleri artık cihazda
çalışmaz mı?" sorusu açıktı. **Denendi: çalışıyor.**

```
[appcheck] jeton alındı
[load] proje=4 önbellekten=false
```

Sebebi, bu cihazın hata ayıklama jetonunun konsolda KAYITLI olması (2 Eyl).
Kayıtlı olmayan bir istemci için aynı şey geçerli DEĞİL — nitekim test
simülatöründe `[appcheck] JETON ALINAMADI` düşüyor, çünkü onun jetonu
kaydedilmedi. Yani kural şu: **jetonu kayıtlı cihaz çalışır, kayıtsız olan
çalışmaz.** Yeni bir cihaz ya da temiz kurulum jetonu yenilerse konsola
eklenmesi gerekir.

### devicectl: LAUNCH ARGÜMANLARI `--` SONRASINA

`-auth firebase` doğrudan verilince devicectl onu KENDİ seçeneği sanıyor
(`-a -u -t` diye ayrıştırıp `-t <seconds>` bekliyor) ve başlatmayı
reddediyor. Aynı tuzağın ikinci yüzü — birincisi `-firelog`du.

**Çözüm ayırıcı:**
```sh
xcrun devicectl device process launch --device <UDID> --console <BUNDLE> \
    -- -backend firestore -auth firebase
```

### DEBUG DERLEMESİNİ CİHAZDA BIRAKMA

Ana ekrandan açılınca launch argümanları gitmiyor; DEBUG derlemesi bellek
içi demo verisine düşüyor ve kullanıcı gerçek hesabında **"projelerim
kayboldu"** görüyor. Test bitince Release geri kurulmalı.
