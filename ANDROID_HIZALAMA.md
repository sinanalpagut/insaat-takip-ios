# Android hizalama notu — 22 → 26 Ekim 2026 iOS değişiklikleri

Android portu (`../inşaattakipAndroid`) 22 Ekim'de duraklatıldı; kullanıcı
26 Ekim'de iOS ile **eşzamanlı** sürdürme kararı verdi. Bu not, o aradaki iOS
değişikliklerini ve Android'i **şimdiden** etkileyen sunucu değişikliklerini
toplar. Kaynak iOS deposudur; ayrıntı her maddenin commit'inde ve `ANALIZ.md`de.

iOS 1.0 (252) 26 Ekim'de abonelikle birlikte incelemeye gönderildi
(`ASC_ABONELIK.md`).

---

## 1 · Yayındaki sunucu — Android'i BUGÜN etkiliyor

25 Ekim'de dağıtıldı (kullanıcı onayıyla). Android aynı Firebase projesini
kullandığı için bunlar Android için de geçerli:

| Değişiklik | Android için anlamı |
|---|---|
| **Kural:** proje belgesinde `establishToken` (dize, ≤64) kurulumda serbest, **sonradan eklenemez/değiştirilemez** | Android kurulumda işaret göndermiyorsa sorun yok (zorunlu değil). Var olan belgeye bu alanı yazmaya çalışmamalı. |
| **Kural:** proje belgesindeki `invite` aynası ya TAM ya HİÇ: varsa `code` dize + `createdAt` zaman damgası olmalı | DOĞRULANDI (26 Eki, salt okuma): Android aynayı `update("invite", {code, createdAt: Timestamp})` ile yazıyor — biçime uyuyor. Yarım harita (yalnız `code`) reddedilirdi. |
| **Kural:** sahip kendi projesinin `invites/{KOD}` belgesini okuyabilir (`get`/`list`, `projectId` eşitlikli) | Yeni yetenek; Android kullanmak zorunda değil. |
| **`redeemInvite`:** aynı projenin daha YENİ (kesin büyük `createdAt`) bir kodu varsa eski kod → `deadline-exceeded`, mesaj `code-expired`, `details.reason = "replaced"` | DOĞRULANDI: Android `code-expired` → `Expired` (`data/InviteService.kt`); davranış doğru, değişiklik gerekmez. |
| **`redeemInvite`:** kod kullanılınca, proje aynası bu kodu gösteriyorsa `invite.usedAt` sunucu saatiyle yazılıyor (`usedByName` YAZILMIYOR — KVKK) | Android `Invite.usedAt`i zaten taşıyor (`model/Partner.kt`); okuma bozulmaz. Ekran "kullanıldı" gösterebilir. |
| **`deleteAccount`:** davetler artık proje belgesinden ÖNCE siliniyor | İstemci değişikliği gerekmez. |

Kural testleri: `tests/rules.test.mjs` ("169 uyumluluk bekçisi" bloğu eski
istemcilerin kırılmadığını da sınıyor), `tests/functions.test.mjs` (M6a/M6b).

---

## 2 · iOS istemci değişiklikleri (Android'in birebir alması gerekenler)

### 2a. Davet ve yazma düzeltmeleri — 22 Ekim (Android raporunun karşılığı)
| Commit | Konu | Android durumu (rapordan) |
|---|---|---|
| `a72b139` | Proje yazması `memberUids`/`invite` taşımıyor; `.project` merge, üyelik `arrayUnion/arrayRemove`, ayna ayrı kanal, silinen opsiyonel alana `FieldValue.delete()` | Android `ProjectWritePlan.kt` ile zaten yaptı — **silme sentinel'i** (`archivedAt`, `remainingCostEstimate`, `expenseTaxBasis`, `salesTaxBasis` nil → delete) Android'de var mı kontrol et. |
| `68b8f36` + `ceb1731` | Davet hata eşlemesi: çerçeve reddi (anahtarsız `unauthenticated`/`deadline-exceeded`/`not-found`) kod hakkında hüküm DEĞİL → `requestRejected`/`timedOut`/`unknown`; anahtarsız 429 "çok deneme" DEĞİL; hesap silmede anahtarsız 401/403 SMS döngüsü kurmuyor | Android'in eşlemesi aynı ilkeye göre gözden geçirilmeli (`InviteErrorMappingTests.swift` tablo gibi okunur). |
| `073ef55` | Davet kodu sunucu onayından önce ekranda gösterilmiyor; üretim sürerken ikinci dokunuş yok sayılıyor; hata önceki geçerli kodu silmiyor | Android `unconfirmedInviteCodes` ile benzerini yaptı — "yer tutucu kod göstermeme" ilkesini kontrol et. |
| `c859a15` | Madde 6 sunucu tarafı (yukarıda §1) | — |

### 2b. Yedekten geri yükleme — `02e9544`, `3ba68cd`
Geri yükleme canlı projenin üzerine YAZAMIYOR: kurulum rastgele
`establishToken` taşıyor, sunucuya önce soruluyor (`probeProject`), yarım
kalan yalnız boş kabukta devam ediyor. Android'de dışa aktarma/geri yükleme
henüz taşınmadı; taşınırken bu tasarım esas alınmalı
(`ProjectViewModel.restore`, `BackupRestoreTests.swift`).

### 2c. Abonelik ve yazma kilidi — 25 Ekim (`5422b59`, `86e720b`, `e4782ef`)
**En büyük değişiklik.** Kullanıcı kararları (25 Eki):
- Ücretsiz katman: **1 aktif proje, 2 davetli ortak** (ortak = projeye ERİŞEN
  kişi; `userUid`'siz geri yüklenmiş kayıt sayılmaz). Ücretli: Şantiye 3,
  Müteahhit 10, Kurumsal sınırsız proje; ortak sınırsız.
- **Arşivdeki proje SALT OKUNUR.** Arşivden çıkarma da kotaya tabi.
- **Sınırın üstünde EN ESKİ N aktif proje (createdAt, eşitlikte id) yazılabilir,
  fazlası salt okunur.** Okuma ve dışa aktarma ASLA kapanmaz; arşivleme ve
  ortak çıkarma HER ZAMAN açık; geri yükleme kotaya tabi.
- Kapı: `ProjectViewModel.writeBlock(for:)` + 27 yazma yolunda `yazmaAcik`;
  ekranlarda `canEdit` (görünürlük `isAdmin`de kalıyor); kilit şeridi
  (`ProjectDetailView`), kartta "Salt okunur · paket sınırı".
- Testler: `ProjectWriteLockTests.swift` (her yazma yolu tek tek),
  `QuotaTests.swift`, `SubscriptionTests.swift`.

**Neden Android için kritik:** kota bilerek İSTEMCİDE (`Quota.swift` karar
notu). Kilit Android'de yoksa Android, ücretsiz katmanın deliği olur: aynı
hesap Android'den sınırsız proje açar ve iOS o projeleri salt okunur gösterir.

### 2d. Diğer
- `Entitlement.preLaunchUnlimited` → `.resolving` (hak henüz bilinmiyor =
  sınır yok, açılışın ilk anı).
- Paketler ekranı fiyatı mağazadan okuyor; sonuç mesajı ekranın içinde
  (`e4782ef`).
- Hesap silme ekranı aboneliği olana "ödeme Apple'da sürer, önce iptal et"
  diyor (Apple kuralı; Play'de karşılığı "Google Play'de sürer").
- Kullanım koşulları güncellendi (benav.com.tr, 25 Eki): arşiv salt okunur,
  sınır üstü salt okunur, hesap silmek aboneliği iptal etmez.

---

## 3 · KULLANICININ KARARI GEREKEN KONU: platformlar arası hak

iOS'ta hak **cihazda, Apple Kimliğine bağlı** (StoreKit 2, sunucu kopyası YOK).
Sonuç:
- iOS'ta ödeyen kişi Android'de açınca Android onun aboneliğini **bilemez** —
  ücretsiz katman görür ve fazla projeleri salt okunur olur.
- Android'de satış Play Billing ister; onu da iOS bilemez.

Seçenekler (karar kullanıcıda; iOS notu `Subscriptions.swift` başı):
1. **Sunucu kopyası:** App Store Server Notifications + Play RTDN →
   `users/{uid}/entitlement` (sunucu yazar, istemci okur). Doğru ve kalıcı
   çözüm; iOS'ta `appAccountToken` (uid'den türetilmiş UUID) bunun için
   şimdiden gönderiliyor. App Privacy beyanına "Purchases" eklenmesi gerekir.
2. **Geçici:** Android'de önce yalnız ücretsiz katman kuralları (kilit dahil),
   satın alma yok; ödeme ve platformlar arası hak sunucu kopyasıyla birlikte.

Kilit kurallarının (2c) kendisi seçimden bağımsız olarak Android'e taşınmalı.

---

## 4 · iOS'ta sırada bekleyen (Android ile eşzamanlı planlanmalı)

- **Davet aynası istemci aşaması (iOS 1.1):** proje çözümünden önce ham
  sözlükten `invite` atılacak (tüm roller); davet ekranı kodu `invites`
  koleksiyonundan okuyacak; `createInvite` aynayı yazmayıp `invite:
  FieldValue.delete()` gönderecek. Android de aynı anda geçmeli; yoksa bir
  platform aynayı yazarken diğeri siler.
- Ayrı açık maddeler (ikisi de sunucu): kilitli projede önceden üretilmiş
  davet kodu 48 saat geçerli ve iptal edilemiyor; geri yüklenmiş ortağı
  yeniden davet etmek ikinci ortak belgesi kuruyor.
