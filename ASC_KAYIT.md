# App Store Connect kaydı — hazırlık

> Hazırlanma: 16 Ekim 2026 · Sürüm **1.0 (169)**
> Bu dosyada sır YOK. App Review test numarası ve App Check jetonu
> `APP_REVIEW.local.md` içinde (gitignore'lu).

---

## 1 · Uygulama bilgileri

| Alan | Değer |
|---|---|
| **Ad** (30 kr.) | `İnşaat Takip: Şantiye Kaydı` — 27 kr. |
| **Bundle ID** | `com.sinanalpagut.insaattakip` |
| **SKU** | `insaattakip-001` |
| **Birincil dil** | Türkçe |
| **Sürüm** | 1.0 (build 169) |

### Ad neden uzun (16 Eki 2026)

Düz **`İnşaat Takip`** App Store'da BAŞKASI TARAFINDAN ALINMIŞ; uygulama
adları global olarak benzersiz ve ASC kaydı reddetti.

**TELEFONDAKİ AD DEĞİŞMEDİ.** Mağaza adı ile ana ekranda görünen ad ayrı
alanlar: `CFBundleDisplayName` hâlâ `İnşaat Takip` ve uygulamanın kendisine
hiç dokunulmadı. Değişen yalnızca mağaza listesindeki satır.

**"Kayıt" kelimesi bilerek seçildi, "Yönetim" değil.** Kullanım
koşullarında ve uygulama içi tanıtımda "bu bir kayıt aracıdır, vergi
hesaplamaz, muhasebe defteri yerine geçmez" diyoruz. Adında "yönetimi"
geçen bir uygulama, mağaza sayfasında reddettiğimiz beklentiyi adıyla
yaratırdı.

Marka her yerde **İnşaat Takip** olarak duruyor: simge, hukuki metinler,
destek sayfası, davet sayfası. Mağaza adı onun üstüne eklenen bir
niteleme.

### Alt başlık (30 karakter sınırı)

Üç aday — ilkini öneriyorum:

1. `Şantiye, satış ve ortak takibi` — 30 kr. (tam sınırda)
2. `Şantiye kayıtları ve ortaklar` — 29 kr.
3. `Müteahhit için şantiye takibi` — 29 kr.

**Neden 1:** üç kelimesi de hedef kitlenin aradığı kelime ve "ortak"
ürünü ayıran şeyi daha alt başlıkta söylüyor.

### Kategori

- **Birincil:** İş *(Business)*
- **İkincil:** Verimlilik *(Productivity)*

Finans'ı bilerek seçmiyoruz: uygulama para **hesaplamıyor**, kayıt
tutuyor. Finans kategorisi, kullanım koşullarında açıkça reddettiğimiz
bir beklenti yaratır.

---

## 2 · Açıklama (4000 karakter sınırı)

```
İnşaat Takip, müteahhitlerin şantiye kayıtlarını tek yerde tutması ve bu
kayıtları iş ortaklarıyla paylaşması için yapıldı.

Ada ve parsel bazlı çalışır. Her proje için daireleri, satışları,
tahsilatları, giderleri ve malzeme hareketlerini ayrı ayrı tutar;
rakamları siz girdikçe kendisi hesaplar.

NELER YAPAR

• Daireler — satılan, boş, rezerve ve kat karşılığı ayrı ayrı. Her daire
  için satış bedeli, tahsilat durumu ve taksit planı.
• Tahsilat ve taksit — hangi daireden ne zaman ne girecek, hangi vade
  geçti.
• Giderler — arsa, taşeron, işçilik, malzeme, ruhsat. Nereye ne
  harcandığı kalem kalem.
• Malzeme — giren, kullanılan, kalan. Fişin fotoğrafını çekersiniz,
  tutarı kendisi okur.
• Ortaklar — hisse payları, ortak cari hesabı ve mutabakat.
• Raporlar — dönem raporu, PDF ve Excel çıktısı.
• Belgeler — ruhsat, proje, sözleşme; dosyalarınız yanınızda.

ORTAKLARLA ŞEFFAF

Projeye davet ettiğiniz ortak aynı rakamları görür ama hiçbir kaydı
değiştiremez. Herkes aynı tabloya bakar.

Daire alıcılarının adları ortaklara gösterilmez. Bu kısıt uygulamada
gizlemekle değil, sunucudaki güvenlik kurallarıyla uygulanır.

VERİLERİNİZ

• Reklam yok, kullanıcı izleme yok, analitik yok.
• Veriler Avrupa Birliği içindeki (Belçika) sunucularda saklanır.
• Hesabınızı ve tüm verilerinizi uygulama içinden silebilirsiniz.
• Kayıtlarınızı istediğiniz an Excel ve yedek dosyası olarak dışa
  aktarabilirsiniz.

ŞUNU DA SÖYLEYELİM

İnşaat Takip bir kayıt aracıdır. Vergi hesaplamaz, muhasebe defteri
yerine geçmez ve mali müşavirin yerini tutmaz. Gösterdiği rakamlar
yalnızca sizin girdiğiniz kayıtlardan hesaplanır.

ÜCRETSİZ KATMAN

1 aktif proje ve 2 davet edilmiş ortak — süre sınırı yok. Biten projeyi
arşivlediğinizde kontenjanınız boşalır, kayıtlarınız durur.
```

**"Şunu da söyleyelim" bölümü bilerek var.** Kullanım koşullarında yazan
sınırı mağaza sayfasında da söylemek, indirdikten sonra "ben bunu
muhasebe sanıyordum" diyen kullanıcıyı ve onun bir yıldızını önlüyor.

---

## 3 · Anahtar kelimeler (100 karakter sınırı)

```
şantiye,müteahhit,inşaat,daire,satış,tahsilat,gider,malzeme,ortak,hakediş,kat karşılığı,taksit
```

Virgülden sonra **boşluk yok** — boşluk da karakter sayılıyor.
"İnşaat Takip" adı zaten aranıyor, anahtar kelimeye koymaya gerek yok.

---

## 4 · Tanıtım metni (170 karakter · incelemesiz güncellenebilir)

```
Daireler, satışlar, tahsilatlar, giderler ve malzeme tek yerde. Ortağınız
aynı rakamları görür, değiştiremez. Dönem raporu PDF ve Excel olarak
hazır gelir.
```

---

## 5 · URL'ler

| Alan | Adres | Durum |
|---|---|---|
| Gizlilik politikası | `https://benav.com.tr/privacy/insaat-takip.html` | ✅ yayında |
| **Destek** | `https://benav.com.tr/destek/insaat-takip.html` | ⚠️ **YAPILACAK** |
| Pazarlama (isteğe bağlı) | boş bırakılabilir | — |

**Destek URL'i ZORUNLU ve hakem açıp bakıyor.** Çalışmayan ya da içeriği
olmayan bir adres ret sebebi.

---

## 6 · Gizlilik anketi (App Privacy)

Cevaplar `PrivacyInfo.xcprivacy` ile **birebir aynı olmak zorunda**.
Ayrışırlarsa Apple ikisini karşılaştırıp reddediyor.

| Veri | ASC'deki yeri | Amaç | Kimliğe bağlı | İzleme |
|---|---|---|---|---|
| Telefon numarası | Contact Info › Phone Number | App Functionality | **Evet** | Hayır |
| Ad | Contact Info › Name | App Functionality | **Evet** | Hayır |
| Fotoğraf | User Content › Photos or Videos | App Functionality | **Evet** | Hayır |
| Diğer kullanıcı içeriği | User Content › Other User Content | App Functionality | **Evet** | Hayır |

**"Data Used to Track You" → HİÇBİRİ.** Manifest `NSPrivacyTracking = false`
diyor ve izleme alan adı listesi boş.

Toplanmayanlar (sorulduğunda "Hayır"): konum, kişiler, arama geçmişi,
tanımlayıcılar, satın alma, kullanım verisi, tanılama, sağlık, finans.

> **Alıcı adları** "Other User Content" altında beyan ediliyor. Bunlar
> kullanıcının girdiği üçüncü kişi verisi; KVKK metninde de kullanıcı
> veri sorumlusu, benav veri işleyen olarak ayrıldı.

---

## 7 · Yaş derecelendirmesi

Tüm sorulara **Yok / Hiçbiri** → sonuç **4+**.

Dikkat: "Kullanıcı tarafından oluşturulan içerik" sorusu. Uygulamada
fotoğraf ve not var ama **herkese açık paylaşım yok** — içerik yalnızca
projeye davet edilen ortaklarla paylaşılıyor. Açık uçlu bir topluluk
özelliği olmadığı için işaretlenmiyor.

---

## 8 · Fiyatlandırma

**Ücretsiz.** Uygulama içi satın alma **henüz yok** — StoreKit bağlanmadı
(madde 87/c). Paketler uygulama içinde yalnızca BİLGİ olarak gösteriliyor,
satın alma düğmesi görünmüyor (`Plan.purchasesAvailable = false`).

Abonelikler eklendiğinde fiyatlar: Şantiye 749 ₺/ay, Müteahhit 1.499 ₺/ay,
Kurumsal 4.999 ₺/ay (yıllıklar on ayın fiyatı).

---

## 9 · App Review bilgileri

- **İletişim:** Sinan Alpagut · `info@benav.com.tr`
- **Giriş gerekiyor:** EVET — telefon + SMS
- **Demo hesap:** test telefon numarası ve kodu `APP_REVIEW.local.md`
  içinde. Firebase test numarası olduğu için **gerçek SMS gitmiyor**,
  hakem kodu doğrudan girebiliyor.

### Review notlarına yazılacaklar

```
Giriş telefon numarası + SMS kodu ile yapılıyor. Aşağıdaki test
numarası Firebase test numarasıdır; gerçek SMS gönderilmez, verilen
kodu doğrudan girebilirsiniz.

Numara: [APP_REVIEW.local.md]
Kod: [APP_REVIEW.local.md]

Uygulama yalnızca Türkiye (+90) numaralarını kabul eder; bu, ücretli SMS
kötüye kullanımını önlemek için sunucu tarafında uygulanan bir
kısıtlamadır.

Hesap silme: Hesap ekranı → Hesabı Sil (App Store 5.1.1(v)).
```

**Bölge kısıtını yazmak önemli:** hakem +90 dışı bir numara denerse
giriş yapamaz ve uygulamayı bozuk sanır.

---

## 10 · Ekran görüntüleri

6,9" (1320×2868) · 6 adet · sırasıyla:
pano, daireler, ortaklar, dönem raporu, giderler, malzemeler

Kalan dört görsel (daire detay, ortak görünümü, hareket akışı, fiş ekle)
hazır, sonra eklenecek.

---

## 11 · Dışa aktarım uyumluluğu

`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` derleme ayarlarında
yazılı, yani ASC bu soruyu **sormayacak**. Uygulama yalnızca HTTPS
kullanıyor; kendi şifreleme uygulaması yok.

---

## YAYINDAN ÖNCE KAPATILMASI GEREKENLER

- [ ] Destek sayfası yayınlanacak (yukarıda)
- [ ] Hukuki metinler avukat incelemesinden geçecek
- [ ] İlk TestFlight derlemesinde `[appcheck]` satırı okunacak — App
      Attest'in mağaza derlemesinde de çalıştığı teyit edilecek
