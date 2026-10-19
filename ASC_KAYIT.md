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
| **Destek** | `https://benav.com.tr/destek/insaat-takip.html` | ✅ yayında (HTTP 200, 16 Eki) |
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
| Kullanıcı kimliği | Identifiers › User ID | App Functionality | **Evet** | Hayır |

### User ID 19 Eki'de EKLENDİ

Önce atlanmıştı. Sebebi, UID'yi kullanıcının GİRMEMESİ — uygulama
üretiyor, kimse yazmıyor. Ama Apple'ın ölçütü verinin nereden geldiği
değil, **cihazdan çıkıp saklanıp saklanmadığı.** Kodda bakıldı ve
saklanıyor:

- `projects/{id}.ownerUid`
- `projects/{id}.memberUids` dizisi
- `users/{uid}` profil belgesinin yolu
- denetim izindeki `updatedBy` alanı

Güvenlik kuralları yetkiyi UID üzerinden veriyor, yani saklanmaması
mümkün de değil. `PrivacyInfo.xcprivacy` de aynı gün güncellendi;
anketle manifesto ayrışırsa Apple ikisini karşılaştırıp reddediyor.

**APNs jetonu AKSİNE beyan edilmiyor.** `setAPNSToken` ile doğrudan
Firebase Auth SDK'sına veriliyor, telefon doğrulaması bitince işimiz
kalmıyor, bizim sunucumuzda hiç durmuyor. Apple'ın "toplama" tanımı
"isteği gerçek zamanlı karşılamak için gerekenden uzun süre erişilebilir
tutmak" diyor; bu onun dışında kalıyor. Uygulamada FirebaseMessaging
paketi de yok (pbxproj'de sıfır geçiş), kullanıcıya giden uzak bildirim
hiç gönderilmiyor — hatırlatmalar `UNCalendarNotificationTrigger` ile
YEREL.

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

## 7b · Dağıtım: YALNIZCA TÜRKİYE (16 Eki 2026 kararı)

**DSA beyanı: "This is a trader app"** — doğru beyan, abonelik satılacak.
"Non-trader" demek yanlış beyan olurdu.

**Ama trader beyanının bedeli var:** Apple, geliştirici hesabındaki
DOĞRULANMIŞ ADRESİ App Store'da AB'de herkese açık yayımlıyor. Hesap şahıs
hesabı olduğu için bu, EV ADRESİ demek.

**Çözüm dağıtımı Türkiye ile sınırlamak oldu** ve bu karar ürünün
gerçeğiyle zaten uyumlu:

- **SMS bölge politikası yalnızca +90 numaralara izin veriyor** (madde 71).
  Avrupa'daki bir kullanıcı uygulamayı indirse bile GİRİŞ YAPAMIYOR.
  172 ülkede listelenmek kimseye fayda sağlamıyor, yalnızca indirip
  giremeyen ve tek yıldız bırakan kullanıcı üretiyor.
- Arayüz tek dilde (Türkçe), hedef kitle Türkiye'deki müteahhit.
- Türkiye AB dışında olduğu için adres yayımlanması devreye girmiyor.

**ASİMETRİ, ÜCRETSİZ KATMANDAKİNİN AYNISI:** dağıtımı genişletmek bedava,
daraltmak imkânsız. Bugün Türkiye ile başlayıp yarın ülke eklemek tek tık;
tersi, indirmiş kullanıcıyı kaybetmek.

**AÇIK KALAN:** yurt dışında yaşayan, +90 numarası olan kullanıcılar. Onlar
Türkiye App Store hesabı kullanıyorlarsa erişebilir. Gerçek talep görülürse
ülke eklenir — tetik bu.

**BAĞLANTILI KARAR:** şirket kurulup adres onunla değiştirilirse hem bu
sorun hem KVKK metnindeki "veri sorumlusu" satırı birlikte çözülür. O soru
15 Eki'de soruldu, cevabı "benav kalsın" oldu; şirket kurulursa ikisi de
yeniden ele alınacak.

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

**İNGİLİZCE YAZILIYOR.** Uygulamanın Türkçe olması sorun değil, hakem
yerelleştirmeyi test etmeye alışkın. Sorun, hakeme verilen TALİMATIN
anlaşılmaması olurdu: bölge kısıtını okuyamayan hakem kendi numarasını
dener, giremez ve uygulamayı bozuk sanar.

Numara ve kod ayrıca metne yazılmıyor — User name / Password alanları
zaten taşıyor. İki yere yazılan değer, biri güncellenmeyince yanlış
olur.

```
Sign-in uses a phone number plus an SMS verification code.

The number in the User name field is a Firebase test number, so no real
SMS is sent. Enter the code from the Password field directly on the
verification screen.

The app only accepts Turkish (+90) phone numbers. This is enforced
server-side to prevent paid-SMS abuse, so any other country code is
rejected at sign-in by design. Distribution is limited to Turkey and the
interface is Turkish-only.

Account deletion is available in the app: Account tab -> "Hesabı Sil"
(Delete Account), per App Store Review Guideline 5.1.1(v).
```

---

## 10 · Ekran görüntüleri

**BOYUT 1206×2622, 1320×2868 DEĞİL (16 Eki düzeltmesi).** ASC'nin yeni
ürün sayfasında iPhone yuvası tek: "iPhone with Dynamic Island (medium
display)" ve yalnızca 6,1"/6,3" kabul ediyor. 6,9" dosyalar "File
dimensions are invalid" ile reddedildi. Apple tek iPhone setini diğer
cihazlara kendisi ölçeklüyor.

AppMockUp'ın bu projedeki cihaz listesinde 6,3" yok; çıktılar 1320×2868
alınıp yerelde 1206×2622'ye küçültüldü (`~/Desktop/InsaatTakip-ASC/
magaza-6.3/`). Küçültme olduğu için netlik korundu; en boy farkı binde
0,7, dikeyde 2 piksel zorlandı — dolgu koyup zemin dikişi riski almaktan
iyi.

### Sıralama (10'luk nihai)

| # | Bant yazısı | Ham ekran |
|---|---|---|
| 1 | Tüm şantiyeler tek ekranda | `01-pano` |
| 2 | Ortak görür, değiştiremez | `19-ortak-gorunumu` |
| 3 | Hangi daire satıldı, hangisi boş | `04-daireler` |
| 4 | Para nereye gitti, belli | `03-giderler` |
| 5 | Fişi çek, tutarı kendi okusun | `10-fis-ekle` |
| 6 | Rapor hazır gelir | `15-donem-raporu` |
| 7 | Giren, kullanılan, kalan | `02-malzemeler` |
| 8 | Taksit planı ve geciken vade | `07-daire-detay` |
| 9 | Hisse payı ve ortak cari hesabı | `05-ortaklar` |
| 10 | Her kayıt iz bırakır | `17-hareket-akisi` |

**1 pano:** header ve arama kartının ikisi de pano ekranını gösteriyor;
aramada pano görüp tıklayan kişi aynı ekranla karşılaşmalı.
**2 ortak görünümü:** rakiplerin söylemediği tek cümle, arama sonucunda
görünen üç kareden birini hak ediyor.
**9'un yazısı değişti:** eskiden "Ortağınla aynı tabloya bak"tı, 2 ile
aynı şeyi vadediyordu; artık ekranda görünen şeyi söylüyor.

**19 Eki: onunun tamamı yüklendi ve sıraya kondu, pano 1 numarada.**

Yükleme sırasında bir görsel "bulut" durumunda takıldı ve `Add for
Review` "1 or more screenshots must finish uploading" diyerek engelledi.
Takılan kutu kaldırılıp yeniden sürüklenince çözüldü. **ASC yarım kalan
yüklemeyi kendi başına temizlemiyor**, sayaç 10/10 gösterse bile.

---

## 10b · Arşiv öncesi denetim (16 Eki 2026)

Release derlemesi alınıp **paketin içine bakılarak** doğrulandı; proje
dosyasına bakarak varsayılmadı:

| Kontrol | Sonuç | Nasıl bakıldı |
|---|---|---|
| `PrivacyInfo.xcprivacy` pakette | ✅ 4168 bayt | `InsaatTakip.app` içinde listelendi |
| `CFBundleShortVersionString` | ✅ 1.0 | `plutil -extract` |
| `CFBundleVersion` | ✅ 169 | `plutil -extract` |
| `CFBundleDisplayName` | ✅ İnşaat Takip | mağaza adından bağımsız, değişmedi |
| `ITSAppUsesNonExemptEncryption` | ✅ false | ASC bu soruyu sormayacak |
| App Attest ortamı | ✅ production | entitlements |

**NEDEN PAKETE BAKILDI:** `PrivacyInfo.xcprivacy` `project.pbxproj`
içinde HİÇ GEÇMİYOR. Proje eşzamanlı klasör kullandığı için bu beklenen
bir durum, ama "beklenen" ile "doğru" aynı şey değil. Dosyanın hedefe
dahil olduğu ancak derlenmiş paketin içinde görülerek kanıtlanır; dahil
olmasaydı Apple gizlilik manifestosu eksik diye reddederdi.

### `CFBundleIconName` elle eklendi (19 Eki)

actool bu anahtarı yalnızca `CFBundleIcons › CFBundlePrimaryIcon`
içine iç içe yazıyor, üst düzeyde bırakmıyor. **Hem simülatör hem
cihaz hedefiyle derleyip bakıldı, ikisinde de üst düzeyde yoktu.**
App Store doğrulaması (ITMS-90713) üst düzeydekini arıyor.

Reddedeceği KANITLANMADI — kanıtlamanın tek yolu yüklemeyi denemek.
`Config/Info.plist`'e elle eklendi; değer actool'un yazdığıyla aynı
(`AppIcon`), çakışma yok, tek satırın bedeli başarısız bir yükleme
turundan düşük.

Cihaz derlemesinde doğrulandı: anahtar artık hem üst düzeyde hem iç
içe, ikisi de `AppIcon`.

### Fotoğraf izni GEREKMİYOR

"Galeriden" düğmesi SwiftUI `PhotosPicker` kullanıyor; süreç dışı
çalıştığı için `NSPhotoLibraryUsageDescription` istemiyor.
`UIImagePickerController`'ın `.photoLibrary` yoluna yalnızca
simülatörde düşülüyor (`#if targetEnvironment(simulator)`), orada da
izin açıklaması aranmıyor. Eksik sanıp eklemek, istemediğimiz bir izni
mağaza sayfasında beyan etmek olurdu.

### KAPANDI: `aps-environment` (19 Eki)

Arşivde `development` yazıyordu ve yanında `get-task-allow: true`
duruyordu — ikisi birlikte arşivin GELİŞTİRME sertifikasıyla
imzalandığını söylüyor. Mağaza imzası `Distribute App` adımında
yeniden atılıyor, dolayısıyla soru arşivde değil dışa aktarılmış
pakette cevaplanır.

Dışa aktarılıp `.ipa` açıldı ve bakıldı:

| Yetki | Arşiv | Mağaza imzalı paket |
|---|---|---|
| `aps-environment` | development | **production** ✓ |
| `get-task-allow` | true | **false** ✓ |
| `beta-reports-active` | yok | **true** ✓ |
| `appattest-environment` | production | production ✓ |

**NEDEN APP ATTEST'TE ÇALIŞMAMIŞTI DA BURADA ÇALIŞTI:** çalışmama diye
bir şey olmamış. App Attest'i geliştirme imzalı, doğrudan cihaza
kurulan bir derlemede test ediyorduk; o derleme dağıtım adımından hiç
geçmedi. `aps-environment` dağıtımda çevriliyor; `appattest-environment`
ise çevrilmiyor, imza türüne göre VARSAYILANI değişiyor. Elle
`production` yazmamız geliştirme derlemesini üretim ortamına zorlamak
içindi ve mağaza derlemesi için zaten etkisiz.

Yani "Xcode'un otomatik çevirmesine güvenilmez" çıkarımı yanlıştı;
doğrusu "geliştirme imzalı bir derlemeye bakarak mağaza derlemesi
hakkında konuşulmaz".

### Paketten okunan son değerler

`CFBundleShortVersionString` 1.0 · `CFBundleVersion` 169 ·
`CFBundleIconName` AppIcon · `ITSAppUsesNonExemptEncryption` false ·
gizlilik manifestosunda beş tür (PhoneNumber, Name, PhotosorVideos,
OtherUserContentData, UserID).

---

## 11 · Dışa aktarım uyumluluğu

`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` derleme ayarlarında
yazılı, yani ASC bu soruyu **sormayacak**. Uygulama yalnızca HTTPS
kullanıyor; kendi şifreleme uygulaması yok.

---

## İLERLEME (16 Eki 2026)

### Tamamlananlar
- [x] Lisans sözleşmeleri — Free Apps + Paid Apps **Active**
- [x] Banka hesabı ve vergi formları **Active**
- [x] Uygulama kaydı açıldı · **Apple ID 6823613985**
- [x] App Information — ad, alt başlık, kategoriler, Content Rights,
      Apple standart EULA
- [x] Age Rating → **4+** (172 ülke)
- [x] DSA → **trader** beyanı
- [x] Pricing → temel ülke **Türkiye (TRY)**, fiyat **ücretsiz**
- [x] Availability → **yalnızca Türkiye**
- [x] Mac, Vision Pro ve okul indirimi kutuları **kaldırıldı**
      (hiçbiri test edilmedi / uyumsuz / hedef kitle değil)

### 1.0 sürüm sayfasında kalanlar
- [x] Ekran görüntüleri — **10 adet**, 1206×2622, pano 1 numarada
- [x] Tanıtım metni (155/170) · açıklama (1769/4000) · anahtar kelimeler (94/100)
- [x] Destek URL'i ve gizlilik politikası URL'i — ikisi de HTTP 200
- [x] App Review bilgileri — notlar İngilizce, numara/kod dosyayla doğrulandı
- [ ] Sürüm yayın şekli (otomatik / elle)

### NEREDE KALINDI (16 Eki 2026, akşam)

1.0 sürüm sayfasının **tamamı dolduruldu ve kaydedildi**: 6 ekran
görüntüsü, header, arama kartı, tanıtım metni, açıklama, anahtar
kelimeler, iki URL, telif, App Review bilgileri, yayın şekli **manuel**.

**App Privacy 19 Eki'de yayınlandı.** Gizlilik politikası adresi de o
sayfada ayrıca isteniyordu (1.0 sayfasındakilerden farklı bir alan),
girildi.

**Derleme 19 Eki'de yüklendi** — 1.0 (169). Yüklemeden önce dışa
aktarılıp mağaza imzalı paketin yetkileri okundu; `aps-environment`
açık maddesi orada kapandı.

**19 Eki akşamı itibarıyla teknik tarafta bekleyen iş yok:**
derleme yüklendi, 1.0 sayfasında seçildi, TestFlight'ta kuruldu ve
çalıştığı görüldü (giriş + proje yükleme).

**SIRADAKİ: Add for Review.**

**Gönderimden SONRA, ilk gerçek kullanıcılardan önce:** hukuki
metinlerin avukat incelemesi. Brief hazır (`AVUKAT_BRIEFI.local.md`,
depoya girmiyor). 19 Eki'de iki düzeltme zaten yapıldı: veri sorumlusu
artık gerçek kişi adıyla yazılıyor ve aktarım maddesi barındırmanın
Türkiye dışında olduğunu açıkça söylüyor. Hukuki sebebin
adlandırılması avukatta — dayanılmayan bir mekanizmaya atıf yapmak
boşluğu yanlış beyana çevirirdi.

### Metadata'dan SONRA gelenler
- [x] **Derleme yüklendi** — 19 Eki 10:23 arşivi, 1.0 (169), arm64.
      Yüklemeden önce dışa aktarılıp yetkileri okundu (yukarıda).
- [x] **TestFlight'ta App Attest teyidi — 19 Eki, GEÇTİ.** Mağaza imzalı
      derleme cihaza kuruldu, giriş sorunsuz yapıldı ve projeler yüklendi.
      **Projelerin gelmesi tek başına kanıt:** Firestore'da App Check
      zorlaması açık, geçerli jeton olmadan tek belge bile okunamazdı.
      Mağaza derlemesinde `#if DEBUG` dalı derlenmiyor, yani jetonu üreten
      App Attest'ti. Girişin sorunsuz olması `aps-environment = production`
      sayesinde sessiz doğrulamanın yürüdüğünü de gösteriyor.
- [x] **App Privacy anketi** — 19 Eki'de YAYINLANDI; beş veri türü, hepsi
      App Functionality + kimliğe bağlı, "Data Used to Track You" kutusu
      hiç görünmüyor
- [ ] Avukat incelemesi

## YAYINDAN ÖNCE KAPATILMASI GEREKENLER

- [x] Destek sayfası yayında — 16 Eki'de HTTP 200 doğrulandı
- [ ] Hukuki metinler avukat incelemesinden geçecek
- [x] App Attest mağaza derlemesinde teyit edildi (19 Eki, TestFlight)
