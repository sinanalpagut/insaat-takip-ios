# App Store Connect — Abonelik kurulumu (25 Ekim 2026)

1.0 (169), **Guideline 2.1(b)** ile reddedildi: uygulama paket fiyatlarını
gösteriyordu ama App Store Connect'te tek bir satın alma ürünü yoktu.
Karar (kullanıcı, 25 Eki): fiyatı gizlemek yerine aboneliği **ilk sürüme
bağlamak**. Yayında kullanıcı olmadığı için sınırı ilk günden koymak, sonradan
sınırsızlığı geri almaktan daha temiz.

Kodda karşılığı: `InsaatTakip/Data/Subscriptions.swift`,
`ViewModels/SubscriptionManager.swift`, `Views/Dashboard/PlansSheet.swift`.
Ürün kimliklerinin tek doğruluk kaynağı `InsaatTakip/Data/Plan.swift`.
`Config/InsaatTakip.storekit` App Store Connect'in **aynası**: konsolda bir
şey değişirse o dosya da değişmeli (`SubscriptionTests` ikisini karşılaştırıyor).

Sıra önemli; her adımın gerekçesi yanında.

---

## 0 · Ücretli Uygulamalar Sözleşmesi (en uzun süren adım — hemen başla)

**ASC → Business** (eski adı Agreements, Tax, and Banking) → **Paid Apps**:

1. Sözleşmeyi kabul et.
2. **Bank Account** — IBAN.
3. **Tax Forms** — ABD vergi formu (bireysel geliştirici için W-8BEN).

Bu bilgileri yalnızca sen girebilirsin; ödeme, banka ve vergi bilgisi
girmek bu oturumun yapamayacağı bir iş.

**Neden önce:** sözleşme "Active" olmadan abonelikler sandbox'ta test
edilemiyor ve incelemeye gönderilemiyor. Aktifleşmesi saatler, bazen
günler sürüyor; diğer bütün adımlar bunu bekliyor.

---

## 1 · Abonelik grubu

**ASC → Uygulama → Monetization → Subscriptions → Create (grup)**

| Alan | Değer |
|---|---|
| Reference Name | `Paketler` |
| Grup yerelleştirmesi (Türkçe) · Display Name | `İnşaat Takip Paketleri` |

**Neden tek grup:** aynı gruptaki abonelikler birbirini dışlıyor; kişi aynı
anda yalnızca bir pakete abone olabiliyor, paket değiştirmek Apple'da
yükseltme/düşürme olarak işleniyor. İki ayrı grup olsaydı biri iki pakete
birden ödeme yapabilirdi.

---

## 2 · Altı ürün

Her biri: **Create → Reference Name + Product ID** → süre → fiyat →
yerelleştirme → inceleme bilgisi.

| Reference Name | Product ID | Süre | Düzey (Level) | Seçilen fiyat (Türkiye) |
|---|---|---|---|---|
| Kurumsal Aylık | `com.sinanalpagut.insaattakip.kurumsal.aylik` | 1 Month | 1 | 4.999,99 ₺ |
| Kurumsal Yıllık | `com.sinanalpagut.insaattakip.kurumsal.yillik` | 1 Year | 1 | 49.999,99 ₺ |
| Müteahhit Aylık | `com.sinanalpagut.insaattakip.muteahhit.aylik` | 1 Month | 2 | 1.499,99 ₺ |
| Müteahhit Yıllık | `com.sinanalpagut.insaattakip.muteahhit.yillik` | 1 Year | 2 | 14.999,99 ₺ |
| Şantiye Aylık | `com.sinanalpagut.insaattakip.santiye.aylik` | 1 Month | 3 | 749,99 ₺ |
| Şantiye Yıllık | `com.sinanalpagut.insaattakip.santiye.yillik` | 1 Year | 3 | 7.499,99 ₺ |

**Product ID'yi kopyala-yapıştır.** Tek harf farkı satın almanın sessizce
çalışmaması demek (StoreKit tanımadığı kimliği hata vermeden atlıyor) ve
kimlik bir kez oluşturulunca **değiştirilemiyor, silinse bile yeniden
kullanılamıyor**.

**Düzey:** 1 en üst. Büyük paket küçük sayıda olmalı ki Şantiye → Kurumsal
geçişi Apple'da "yükseltme" sayılsın ve hemen geçerli olsun; ters yönü
"düşürme" olur ve dönem sonunda geçerli olur. Aylık ve yıllık aynı düzeyde.

**Fiyat:** Türkiye'yi temel ülke seç, hedef fiyata **en yakın** basamağı
seç (basamaklar büyük olasılıkla ",99" ile bitiyor), diğer ülkeleri Apple
otomatik hesaplasın. **Seçtiğin altı rakamı bana yaz:** `Plan.swift` ve
`Config/InsaatTakip.storekit` o rakamlara eşitlenecek. Ekran fiyatı zaten
Apple'dan okuyor, yani kullanıcı her durumda doğru tutarı görüyor. Eşitleme,
yerel testlerin gerçek mağazayı sınaması için.

**Yerelleştirme (Türkçe):**

| Ürün | Display Name | Description |
|---|---|---|
| Kurumsal Aylık / Yıllık | `Kurumsal` | `Sınırsız aktif proje ve ortak daveti` |
| Müteahhit Aylık / Yıllık | `Müteahhit` | `10 aktif proje, sınırsız ortak daveti` |
| Şantiye Aylık / Yıllık | `Şantiye` | `3 aktif proje, sınırsız ortak daveti` |

**Family Sharing: KAPALI bırak.** Açılınca geri alınamıyor. Paket bir
müteahhidin proje kontenjanı; aile üyelerine dağıtılması ürünün mantığına
uymuyor.

**Tanıtım teklifi (ücretsiz deneme): şimdilik YOK.** Ücretsiz katman zaten
kalıcı. İleride eklenirse kod değişmiyor: paket ekranı teklifi Apple'dan
okuyup yalnızca uygun kişiye gösteriyor.

**Inceleme bilgisi (her ürün):** ekran görüntüsü olarak
`~/Desktop/InsaatTakip-ASC/abonelik-inceleme.png` (paket ekranı). Review
Notes: `Hesap → Paket ya da panodaki paket satırı → Paketler ekranı.`

---

**25 Eki 2026 — KURULDU.** Grup kimliği `22512945`. Fiyatlar Türkiye temel
ülke, diğer 174 ülke Apple'ın otomatik hesabı. Yüksek basamaklar (7.499,99 ₺
ve üstü, 749,99 ₺) "See Additional Prices" altında. Yıllıklarda yalnızca
**1 Year Upfront** kuruldu; "Monthly with a 12-Month Commitment" BİLEREK
kurulmadı (paket ekranı yıllığı tek seferlik tutar olarak gösteriyor ve
taksitli taahhüt denenmedi). **Multiseat KAPALI, yalnızca App Store** — Apple
Business / School Manager toplu lisans yolu kodda yok; sonradan açılabilir,
App Store ise onaydan sonra listeden çıkarılamıyor.

## 3 · Ödeme ek süresi (Billing Grace Period)

**Subscriptions sayfası → Billing Grace Period → Aç**, en uzun süreyi seç.

**Neden:** kartın yenilemede reddedilirse Apple birkaç gün tekrar deniyor.
Ek süre açıksa bu sırada hak SÜRÜYOR — kod bunu doğru okuyor
(`Transaction.currentEntitlements` ek süredeki aboneliği veriyor) ve paket
ekranı kişiye "ödeme alınamadı, bilgini güncelle" diyor. Kapalıysa kartı
yenilenen müteahhidin projeleri o gün salt okunur olur.

---

## 4 · Sürüm sayfası ve gönderim — GERÇEKTE İŞLEYEN AKIŞ (26 Ekim 2026)

**Eski talimat yanlıştı:** sürüm sayfasında "In-App Purchases and
Subscriptions" bölümü ARTIK YOK. Abonelikler kendi sayfalarındaki **Add for
Review** ile bir TASLAK başvuruya ekleniyor; sürüm, grup ve abonelikler aynı
taslakta olmalı (Apple yardım: "Submit an In-App Purchase").

**Reddedilmiş başvuru tuzağı:** 1.0, "Unresolved Issues" durumundaki eski
başvurunun içindeydi ve Apple'a göre o duruma YENİ ÖĞE EKLENEMİYOR. "Update
Review"/"Resubmit" yalnızca sürümü aboneliksiz yeniden gönderir → aynı ret
(Apple forumu 841193'teki deneyim). İşleyen sıra:

1. Sürüm sayfası → Build → yeni derlemeyi seç → Save.
2. Paketler grubu → **Add for Review** → yeni taslak (uyarı: "add an app
   version" — normal).
3. Her abonelik → **Add for Review → Draft Submission (aynı taslak)**.
   Taslak: grup + 6 abonelik = 7 öğe.
4. App Review → eski başvuru → **iOS App 1.0 satırına gel → kırmızı eksi**
   → sürüm başvurudan çıkar ("Removed"). Ret mesajı eski başvuruda kalır.
5. Sürüm taslağa KENDİLİĞİNDEN GELMEDİ: sürüm sayfası → **Add for Review →
   Draft Submission**. Taslak: 8 öğe, "reviewed together with iOS version
   1.0".
6. **Submit for Review** → 8 öğe "Waiting for Review" (26 Eki ~10:20).

Yayın: kullanıcı **otomatik yayın**ı seçti (26 Eki) — onay gelince uygulama
kendiliğinden yayına çıkar.

### Açıklamanın yeni son bölümü

"ÜCRETSİZ KATMAN" bölümünün yerine:

```
PAKETLER VE ABONELİK

Ücretsiz katman: 1 aktif proje ve 2 davet edilmiş ortak — süre sınırı
yok. Ücretli paketler aktif proje sayısına göre: Şantiye (3 proje),
Müteahhit (10 proje), Kurumsal (sınırsız). Ücretli paketlerde ortak
daveti sınırsız. Aylık ya da yıllık alınabilir; güncel fiyatlar
uygulamada gösterilir.

Biten projeyi arşivlediğinizde kontenjanınız boşalır; arşivdeki proje
okunabilir ve dışa aktarılabilir kalır.

Abonelik, dönem bitiminden en az 24 saat önce iptal edilmedikçe otomatik
yenilenir. Ödeme Apple Kimliğinizden alınır; aboneliğinizi Ayarlar →
Apple Kimliği → Abonelikler'den yönetebilir ya da iptal edebilirsiniz.

Kullanım Koşulları: https://benav.com.tr/privacy/insaat-takip-kosullar.html
Gizlilik Politikası: https://benav.com.tr/privacy/insaat-takip.html
```

**Neden bağlantılar açıklamada:** otomatik yenilenen abonelikte Apple,
kullanım koşullarına (EULA) giden çalışır bir bağlantıyı meta veride
istiyor. Koşullar sayfası 25 Ekim'de abonelik kararlarıyla güncellendi
(benav_com deposu); **sayfanın yayına alınması gerekiyor.**

### App Review notu (ek)

Mevcut notun (giriş bilgileri `APP_REVIEW.local.md`te) sonuna:

```
Subscriptions: the app offers auto-renewable subscriptions (one group,
three tiers, monthly and yearly). To reach the purchase screen: Account
(avatar, top right) → "Paketler", or the plan row on the dashboard.
The demo account is on the free tier; trying to create a second active
project also opens the plans screen. Restore Purchases is at the bottom
of that screen. On the free tier only the oldest active project accepts
new records; other active projects are shown read-only with a banner
explaining why. This is intended: all data stays visible and exportable,
and upgrading or archiving a project unlocks the others.
```

**İnceleme hesabını kontrol et:** hesapta birden fazla aktif proje varsa
hakem ilk açılışta salt okunur projeler görür. Yukarıdaki not bunu
açıklıyor; istersen gönderimden önce fazla projeleri arşivleyip hesabı
tek aktif projeye indirebilirsin. O zaman hakem kilitle hiç karşılaşmaz.

### Ret yanıtı (Resolution Center)

```
Thank you for the review. The app now offers auto-renewable subscriptions
via In-App Purchase. All six subscription products have been submitted
for review together with the new build. The purchase screen is reachable
from Account → Paketler.
```

---

## 5 · Gönderimden önce

- [ ] Paid Apps sözleşmesi **Active**
- [ ] Altı ürün "Ready to Submit"
- [ ] Sandbox hesabıyla TestFlight derlemesinde bir satın alma + geri yükleme
      (Ayarlar → Geliştirici → Sandbox Hesabı)
- [ ] Koşullar sayfası yayında (abonelik maddeleri, 25 Eki güncellemesi)
- [ ] Açıklama + inceleme notu güncel
- [ ] Ürünler sürüme eklendi
