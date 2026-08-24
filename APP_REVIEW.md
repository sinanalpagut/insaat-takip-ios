# App Review — gözden geçirenin uygulamaya girebilmesi

**Madde 69.** Uygulamaya girmenin tek yolu bir Türkiye numarasına gelen SMS.
Apple'ın gözden geçireni Türkiye numarası kullanmıyor ve kullanmasını
bekleyemeyiz; not bırakılmazsa ilk ekran geçilemez ve gönderim
**Guideline 2.1 — App Completeness** ile geri döner. Bu bir tercih değil,
gönderimin ön koşulu.

Aynı gözden geçiren **Guideline 5.1.1(v)** gereği hesap silmeyi de dener.
Silme akışının yeri aşağıda yazılı; denemesi ve hesabı gerçekten silmesi
beklenen davranış.

---

## 1 · Firebase test telefon numarası (konsol işi, tek seferlik)

Firebase Console → **Authentication → Sign-in method → Phone → Phone numbers
for testing**.

Buraya yazılan numara için Firebase:

- **SMS GÖNDERMEZ** — gerçek bir aboneye hiçbir mesaj gitmez, ücret çıkmaz,
- **APNs sessiz bildirimi ve reCAPTCHA İSTEMEZ** — yani uygulamanın gerçek
  cihazda çalışması için gereken doğrulama zincirini atlar,
- girilen sabit kodu geçerli sayar.

**İSTEMCİDE HİÇBİR DEĞİŞİKLİK GEREKMİYOR.** `FirebaseAuthService.sendCode`
sıradan `PhoneAuthProvider.verifyPhoneNumber(_:uiDelegate:)` çağırıyor;
beyaz listedeki numara için Firebase doğrulama kimliğini SMS göndermeden
döndürüyor. `appVerificationDisabledForTesting` gibi bir hata ayıklama
anahtarına gerek yok — o anahtar yayın derlemesinde tehlikeli olurdu, çünkü
uygulama doğrulamasını tümden kapatır.

Numara **+90** ile başlamak zorunda: `PhoneFormat.e164` yalnızca Türkiye
biçimini üretiyor (bilinçli — bkz. `AuthService.swift`). Beyaz listedeki
numaranın gerçek bir hatta karşılık gelmesi gerekmiyor.

> Gerçek numara ve kod **bu dosyada YOK**: depo herkese açık ve o ikili, demo
> hesaba girmeye yeten bir kimlik bilgisi. Değerler `APP_REVIEW.local.md`
> içinde (git dışı) ve App Store Connect → Review Notes alanında duruyor.

## 2 · App Store Connect → App Review Information

**Sign-In required** işaretlenir. Kullanıcı adı/şifre alanları telefon
girişinde işe yaramadığı için asıl bilgi **Notes** alanına yazılır:

```
Giriş telefon numarası + SMS kodu ile yapılıyor (yalnızca Türkiye numaraları).
Gözden geçirme için SMS göndermeyen bir test numarası tanımlandı:

  Telefon : +90 5XX XXX XX XX      ← APP_REVIEW.local.md'den
  Kod     : XXXXXX                 ← APP_REVIEW.local.md'den

Adımlar:
  1. Uygulamayı açın, "Telefonla devam et".
  2. Numarayı yazın, "Kod Gönder". (SMS BEKLEMEYİN — bu numara için
     gönderilmiyor.)
  3. Yukarıdaki sabit kodu girin.
  4. İlk girişte ad sorulur; herhangi bir ad yazılabilir.

Hesap silme (Guideline 5.1.1(v)):
  Ana ekran → sağ üstteki profil düğmesi → "Hesabı Sil".
  Güvenlik için numara yeniden doğrulanır (aynı sabit kod geçerlidir),
  ardından hesap ve tüm verisi sunucudan kalıcı olarak silinir.

Uygulama Türkçe; hedef kullanıcı Türkiye'deki müteahhitler.
```

## 3 · Gözden geçiren giriş yaptıktan sonra ne görüyor?

Boş hesapla giren biri yalnızca "Henüz projen yok" görür. Bu teknik olarak
doğru çalışan bir ekran ama gözden geçirene uygulamanın ne yaptığını
göstermiyor — 2.1 reddinin ikinci biçimi tam olarak bu.

Bu yüzden test hesabı **önceden kurulmuş bir demo projeyle** teslim edilir:
gözden geçiren giriş yaptığı anda daireleri, malzeme hareketlerini,
giderleri ve taksit planını görür.

**DEMO PROJEDE GERÇEK ALICI ADI OLMAZ.** Alıcı adları KVKK kapsamında kişisel
veri; gözden geçirene gösterilen veri baştan sona uydurma olmak zorunda.
Gerçek müşteri verisi taşıyan bir projeye test hesabını ortak olarak eklemek
de aynı sebeple yapılmaz — ortak salt okur olsa bile alıcı adlarını görmez,
ama tutarları ve daire kayıtlarını görür.

## 4 · Silmenin gözden geçirende çalıştığı nasıl biliniyor?

Silme yolu madde 68'de baştan sona denetlendi ve on üç kusuru düzeltildi;
sunucu tarafı emülatör testleriyle sabit (`tests/functions.test.mjs`),
istemci tarafındaki hata çevirisi birim testleriyle
(`InsaatTakipTests/AccountDeletionErrorTests.swift`).

Test numarasının silme akışında da çalışması ayrıca önemli: yeniden kimlik
doğrulama `reauthenticate(with:)` kullanıyor ve beyaz listedeki numara için
o da SMS beklemiyor. Yani gözden geçiren hesabı gerçekten silebiliyor —
silemezse 5.1.1(v) karşılanmamış olur.
