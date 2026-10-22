import Foundation

// MARK: - Davet akışı sözleşmesi
//
// Repository ve AuthService'teki aynı dikiş: protokol + sahte + gerçek.
//
// NEDEN AYRI BİR SERVİS: davet, sistemdeki tek "kullanıcı kendi yetkisini
// yükseltiyor" işlemi. Güvenlik kuralları bunu bilerek reddediyor —
// `memberUids`'e yazma yalnızca sahibe açık, ve davet edilen kişi henüz üyesi
// olmadığı projeyi okuyamadığı için kodu istemcide doğrulaması da imkânsız.
// Dolayısıyla KULLANMA bir Cloud Function çağrısı; ÜRETME ise yöneticinin kendi
// projesine yazması, onu kural çözüyor.
//
// Bu asimetri kasıtlı ve iki uç ayrı yollardan gidiyor: `createInvite` doğrudan
// Firestore'a yazar, `redeemInvite` callable'a gider.

/// Davet kullanmanın sonucu.
struct InviteRedemption: Equatable {
    let projectId: UUID
    let projectTitle: String
    /// Kişi zaten üyeydi — HATA DEĞİL. Aynı bağlantıya iki kez dokunmak bir
    /// arıza değil; kullanıcıya "zaten ortağısın" denir ve proje açılır.
    let alreadyMember: Bool
}

enum InviteError: LocalizedError, Equatable, CaseIterable {
    /// Sunucu oturumu kabul etmedi — işlevin KENDİ `signed-in-required`
    /// anahtarı. İstemcide oturum hiç yoksa ekran çağrıdan önce kendisi
    /// söylüyor; buraya gelen durum "oturum var sanılıyor ama geçmiyor".
    case notSignedIn
    case badFormat
    case notFound
    case expired
    case alreadyUsed
    /// Davet ortada kalmış (projesi silinmiş) ya da bozuk. Kullanıcının hatası değil.
    case inviteBroken
    case network
    /// İstek, işlev gövdesine HİÇ GİRMEDEN reddedildi (madde 2).
    ///
    /// Çerçeve (`firebase-functions` `wrapOnCallHandler`) oturum ve App Check
    /// kapılarını gövdeden önce denetliyor ve reddettiğinde kendi metnini
    /// ("Unauthenticated") yazıyor. En sık sebep kötü bağlantı: App Check
    /// jetonu alınamazsa iOS SDK'sı hatayı yutup başlığa bir YER TUTUCU jeton
    /// koyuyor, çerçeve onu geçersiz (INVALID — "missing" değil; sunucu
    /// günlüğünde bu kelimeyle aranmalı) sayıp reddediyor. Aynı yanıt geçersiz
    /// oturum jetonunda da geliyor ve istemci ikisini AYIRT EDEMİYOR — metin bu
    /// yüzden tek bir neden iddia etmiyor.
    ///
    /// Eskiden `.notSignedIn`e, oradan SESSİZCE `.notFound`a gidiyordu:
    /// arızada GEÇERLİ HER KOD "Böyle bir davet kodu yok" gösteriliyordu.
    case requestRejected
    /// Yanıt gelmedi (madde 3) — istemcinin 70 sn zaman aşımı ya da sunucu
    /// 504'ü. SDK ikisini de `.deadlineExceeded` yapıyor.
    ///
    /// Eskiden `.expired`a gidiyordu: geçerli kod "süresi doldu · yeni kod
    /// iste" gösteriliyor ve yönetici gereksiz yere yeni kod üretiyordu.
    /// Gerçek süre dolumu işlevden HER ZAMAN `code-expired` anahtarıyla
    /// geliyor ve anahtar eşlemesinde yakalanıyor; buraya düşmüyor.
    case timedOut
    /// Sunucunun oran sınırı (`too-many-attempts`): 15 dakikalık SABİT
    /// pencerede 10 başarısız deneme. Eskiden eşlenmemişti; kişi genel bir
    /// hata görüp denemeye devam ediyordu. `.timedOut`un "bir kez daha dene"
    /// demesiyle bu sınıra ulaşma olasılığı arttığı için ikisi birlikte geldi.
    case tooManyAttempts
    case unknown

    /// Kullanıcıya gösterilen metin. Cloud Function'ın döndürdüğü kodlar
    /// makine okunur (`code-used`, `code-expired`…); Türkçeye çeviri BURADA
    /// yapılıyor ki sunucu mesajları arayüze sızmasın.
    ///
    /// Metinler BİRBİRİNDEN ve `AuthError` metinlerinden ayrı olmak zorunda
    /// (`InviteErrorMappingTests` denetliyor): giriş ekranında "Uygulama
    /// doğrulaması yapılamadı · bildirim ayarları eksik" gören kişi burada
    /// benzer bir cümle görse bildirim ayarlarını kurcalamaya giderdi.
    var errorDescription: String? {
        switch self {
        case .notSignedIn:     return "Oturumun düşmüş · çıkıp tekrar gir"
        // Sunucunun `code-format`ı neredeyse yalnızca istemcinin kabul edip
        // sunucunun sildiği harflerden (Türkçe karakterler) doğuyor; ekranda
        // altı dolu kutu varken "6 haneli olmalı" kişiye bir şey söylemiyordu.
        case .badFormat:       return "Kodda geçersiz karakter var"
        case .notFound:        return "Böyle bir davet kodu yok"
        case .expired:         return "Kodun süresi doldu · yöneticiden yeni kod iste"
        case .alreadyUsed:     return "Bu kod daha önce kullanılmış"
        case .inviteBroken:    return "Davet geçersiz · yöneticiye bildir"
        case .network:         return "Bağlantı yok"
        case .requestRejected: return "İstek doğrulanamadı · kod denenmedi"
        case .timedOut:        return "Yanıt gelmedi · aynı kodu bir kez daha dene"
        // "Başarısız", "hatalı" değil: sunucu sayacı kodla ilgisi olmayan
        // başarısızlıkları da sayıyor.
        case .tooManyAttempts: return "Çok fazla başarısız deneme · biraz bekle"
        case .unknown:         return "Projeye katılınamadı"
        }
    }

    /// Kişinin ne yapacağı — tek satıra sığmayan durumlar için.
    ///
    /// Bu metinler 2,6 saniyelik toast'a değil kalıcı bir uyarıya gidiyor:
    /// "kodu tekrar girme, bağlantıyı kontrol et, düzelmezse çıkış-giriş"
    /// sırası bir şeritte okunamıyor. `nil` olanlar kodun kendisiyle ilgili
    /// hatalar; onların eylemi başlıkta yazıyor.
    ///
    /// "App Store'dan güncelle" BİLEREK YOK: ilk kullanıcılar bu hatayı
    /// gördüğünde güncellenecek bir sürüm olmayabilir. Üçüncü adımı yapıp
    /// sorunun sürdüğünü gören kişi o andan sonra metnin tamamına güvenmez.
    var recoverySuggestion: String? {
        switch self {
        case .requestRejected:
            // Kod hakkında OLUMLU hüküm de yok: "kodda sorun yok" demek, kod
            // okunmadığı hâlde hüküm vermek olurdu ve bağlantı düzelince aynı
            // kod "kod yok" alırsa iki mesaj birbirini yalanlardı.
            return "Sunucu isteği kodu okumadan reddetti; kod denenmedi ve harcanmadı. "
                 + "Bağlantını kontrol et, uygulamayı kapatıp aç ve aynı kodu tekrar dene. "
                 + "Bağlantın iyiyken de sürerse Hesap > Oturumu Kapat ile çıkıp telefon numaranla yeniden gir."
        case .timedOut:
            // DURMA KURALI var: "bir kez daha", sonra yer değiştir. Sınırsız
            // tekrar, sunucuya ulaşıp patlayan her denemeyi oran sınırına
            // sayar.
            return "Katılım sunucuda tamamlanmış olabilir, yeni kod isteme. "
                 + "Aynı kodu bir kez daha dene; zaten ortak olduysan uygulama bunu söyleyecek. "
                 + "Yine yanıt gelmezse bağlantının daha iyi olduğu bir yerde dene."
        case .tooManyAttempts:
            return "Güvenlik için denemeler kısa süreliğine durduruldu; en geç 15 dakika içinde yeniden açılır. "
                 + "Daha önce \"kod yok\" gördüysen kodu yöneticinden doğru aldığından emin ol."
        case .notSignedIn:
            return "Sunucu oturumunu kabul etmedi. Hesap > Oturumu Kapat ile çıkıp "
                 + "telefon numaranla yeniden gir, sonra aynı kodu dene."
        case .network:
            // Kesin konuşmuyor: istek gönderildikten sonra kopan bağlantıda
            // sunucu katılımı tamamlamış olabilir.
            return "Bağlantı koptu; katılım tamamlanmış olabilir. İnternete bağlanınca aynı kodu "
                 + "tekrar dene — zaten ortak olduysan uygulama bunu söyleyecek."
        case .inviteBroken:
            return "Bu davetin bağlı olduğu proje bulunamadı. Yöneticinden yeni bir kod iste."
        case .unknown:
            // "Yöneticine bildir" DEĞİL: bu daldaki hataların hiçbirini proje
            // yöneticisi düzeltemez.
            return "Sorunun kodla ilgisi olup olmadığı belli değil. Biraz sonra aynı kodu tekrar dene; "
                 + "sürerse Hesap > Geri bildirim gönder'den bildir."
        case .badFormat, .notFound, .expired, .alreadyUsed:
            return nil
        }
    }

    /// Kalıcı uyarının başlığı — yalnızca DURUM.
    ///
    /// `errorDescription` toast için "durum · eylem" kalıbında; uyarıda eylemi
    /// açıklama satırı taşıdığı için başlıkta tekrarı gereksiz gürültüydü.
    var alertTitle: String {
        switch self {
        case .requestRejected: return "İstek reddedildi"
        case .timedOut:        return "Yanıt gelmedi"
        case .tooManyAttempts: return "Denemeler durduruldu"
        case .notSignedIn:     return "Oturum geçersiz"
        case .network:         return "Bağlantı koptu"
        case .inviteBroken:    return "Davet geçersiz"
        case .unknown:         return "Projeye katılınamadı"
        case .badFormat, .notFound, .expired, .alreadyUsed:
            return errorDescription ?? "Projeye katılınamadı"
        }
    }

    /// Hata KODUN KENDİSİ hakkında bir hüküm mü?
    ///
    /// Yalnızca bunlar kod kutularını kırmızıya boyar. Geri kalanlarda kod
    /// ya hiç okunmadı ya da okunup okunmadığını bilmiyoruz; kutuları
    /// boyamak kişiye "kodu yanlış girdin" der ve onu yanlış eyleme iter.
    var isCodeFault: Bool {
        switch self {
        case .badFormat, .notFound, .expired, .alreadyUsed: return true
        default: return false
        }
    }

    /// Cloud Function'ın `message` alanındaki sabit anahtarı hataya çevirir.
    /// İşlev bilerek makine okunur anahtar döndürüyor: metin döndürseydi
    /// sunucudaki bir metin değişikliği arayüzü sessizce bozardı.
    static func fromFunctionCode(_ code: String) -> InviteError {
        switch code {
        case "signed-in-required": return .notSignedIn
        case "code-format":        return .badFormat
        case "code-not-found":     return .notFound
        case "code-expired":       return .expired
        case "code-used":          return .alreadyUsed
        case "invite-broken", "project-missing": return .inviteBroken
        case "too-many-attempts":  return .tooManyAttempts
        default:                   return .unknown
        }
    }
}

@MainActor
protocol InviteService {

    /// Yönetici projeye davet kodu üretir.
    ///
    /// İki belge, tek parti: `invites/{KOD}` (işlevin tek `get` ile bulacağı
    /// otorite kayıt) + `projects/{pid}.invite` (yöneticinin ekranda göreceği
    /// ayna). Ayna bilinçli bir çoğaltma: kod okuma HERKESE kapalı olduğu için
    /// sahip bile `invites/{KOD}`'u okuyamaz.
    ///
    /// - Returns: üretilen ham kod (tiresiz, 6 karakter).
    func createInvite(projectId: UUID, ownerUid: String) async throws -> String

    /// Davet kodunu kullanır. Cloud Function çağrısı.
    func redeem(code: String) async throws -> InviteRedemption
}
