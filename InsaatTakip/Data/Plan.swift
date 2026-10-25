import Foundation

// MARK: - Abonelik paketleri (madde 87)
//
// FİYAT VE SINIR TEK YERDE. İkisi ayrı dursaydı — fiyat bir ekranda, sınır
// `Quota`da — birini değiştirip diğerini unutmak serbest olurdu ve kullanıcı
// parasını ödediği paketin vermediği bir sınıra çarpardı.
//
// GELİR MODELİ YALNIZCA ABONELİK: REKLAM YOK (15 Eki 2026 kararı). Üç sebebi
// var ve üçü de teknik:
//   1. Uygulama müteahhidin cirosunu, ortaklarının payını ve alıcı adlarını
//      gösteriyor. Bu ekranların yanında reklam, ürünün tek sattığı şeyi —
//      güveni — zayıflatır.
//   2. Reklam SDK'larının tamamı izleme yapar. `PrivacyInfo.xcprivacy` bugün
//      `NSPrivacyTracking = false` diyor ve App Store'da "veri izlemiyor"
//      etiketiyle görünüyor; reklam eklemek o beyanı BOZAR, etiketi
//      değiştirir ve kullanıcıya verilen sözü geri alır.
//   3. Reklam geliri abonelik gelirini zayıflatır: ödeyen kullanıcı neden
//      hâlâ reklam gördüğünü sorar, ödemeyen de ödemek için sebep bulamaz.
//
// FİYATLAR 15 Eki 2026'da onaylandı. Çapa başka uygulama DEĞİL, mali müşavir
// ücreti: müteahhit "şu uygulama şu kadarmış" diye değil "ayda şuna şu kadar
// veriyorum" diye düşünüyor.

enum Plan: String, Codable, CaseIterable, Identifiable {
    case ucretsiz
    case santiye
    case muteahhit
    case kurumsal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ucretsiz:  return "Ücretsiz"
        case .santiye:   return "Şantiye"
        case .muteahhit: return "Müteahhit"
        case .kurumsal:  return "Kurumsal"
        }
    }

    /// Aynı anda tutulabilecek AKTİF proje sayısı. `nil` = sınırsız.
    ///
    /// ARŞİVLENMİŞ PROJE SAYILMIYOR (bkz. `Quota`): inşaat yıllarca sürüyor ve
    /// biten projenin kayıtları vergi/muhasebe için duruyor. Arşivi saymak,
    /// kullanıcıyı yeni proje açabilmek için kendi geçmişini silmeye iterdi.
    var activeProjectLimit: Int? {
        switch self {
        case .ucretsiz:  return 1
        case .santiye:   return 3
        case .muteahhit: return 10
        case .kurumsal:  return nil
        }
    }

    /// Davet edilebilecek ortak sayısı. `nil` = sınırsız.
    ///
    /// ÜCRETLİ PAKETLERDE SINIRSIZ: ortak başına ücret ALINMIYOR. Ortak salt
    /// okur ve parayı ödeyen müteahhit; kişi başına ücret, müteahhidi daha az
    /// ortak davet etmeye iter — yani ürünü ayıran tek şeyi, ortakla
    /// şeffaflığı vergilendirmek olur. Üstelik uygulamayı gören her ortak
    /// potansiyel müteahhit müşteri: büyüme döngüsüne ücret konmuş olurdu.
    ///
    /// ÜCRETSİZDE 2: fiyat değil, ücretsiz katmanın GENİŞLİĞİ. Dar başlıyor
    /// çünkü sınırı gevşetmek bedava, sıkmak imkânsız.
    var invitedPartnerLimit: Int? {
        switch self {
        case .ucretsiz: return 2
        default:        return nil
        }
    }

    /// Aylık ücret. `nil` = ücretsiz paket.
    ///
    /// BU RAKAM App Store Connect'e GİRİLECEK HEDEF, ekrandaki fiyat DEĞİL
    /// (25 Eki 2026). Ekran ve tahsilat Apple'ın `displayPrice`ını kullanıyor
    /// (`StoreOffer`): kişinin mağaza bölgesi başka bir ülkeyse fiyat o ülkenin
    /// parasıyla geliyor ve Apple vergi değişikliğinde fiyatı kendisi
    /// ayarlayabiliyor. Katalog ile konsol ayrışırsa kullanıcı yine doğru
    /// rakamı görür; ayrışmayı yakalamak `Config/InsaatTakip.storekit`
    /// karşılaştırmasının işi (`SubscriptionTests`).
    var monthlyPrice: Kurus? {
        switch self {
        case .ucretsiz:  return nil
        case .santiye:   return .lira(749)
        case .muteahhit: return .lira(1_499)
        case .kurumsal:  return .lira(4_999)
        }
    }

    /// Yıllık ücret = ON AYIN fiyatı (iki ay bedava).
    ///
    /// RAKAM BURADA AÇIKÇA YAZILI, hesaplanmıyor: `Kurus`ta çarpma operatörü
    /// bilerek yok (madde 1) ve fiyat etiketi okunduğu gibi olmalı. Kuralın
    /// korunmasını `PlanTests` üstleniyor — on ayı tutmayan bir yıllık fiyat
    /// testi kırmızıya döndürür.
    ///
    /// Yıllığın iki işi var: iletişimi kolay ("iki ay bedava") ve Firebase
    /// maliyetini önden karşılıyor.
    var yearlyPrice: Kurus? {
        switch self {
        case .ucretsiz:  return nil
        case .santiye:   return .lira(7_490)
        case .muteahhit: return .lira(14_990)
        case .kurumsal:  return .lira(49_990)
        }
    }

    /// App Store Connect'te oluşturulacak ürün kimlikleri.
    ///
    /// BURADA YAZILI OLMASI BİLİNÇLİ: kimlikler konsolda elle giriliyor ve
    /// tek harf farkı satın almanın sessizce çalışmaması demek. Tek doğruluk
    /// kaynağı bu dosya; konsol buna göre doldurulacak.
    var monthlyProductId: String? {
        monthlyPrice == nil ? nil : "com.sinanalpagut.insaattakip.\(rawValue).aylik"
    }

    var yearlyProductId: String? {
        yearlyPrice == nil ? nil : "com.sinanalpagut.insaattakip.\(rawValue).yillik"
    }

    /// Satın alınabilir paketler — ücretsiz katman listede yok.
    static var purchasable: [Plan] { allCases.filter { $0.monthlyPrice != nil } }

    // MARK: - Ekranda gösterilen vaat (15 Eki 2026)

    /// Paketi diğerlerinden AYIRAN satırlar.
    ///
    /// EKRANDA ELLE YAZILMIYOR, KATALOGDAN ÜRETİLİYOR. Fiyat tablosu burada,
    /// tanıtım metni ekranda dursaydı, bir sınırı değiştirip ekrandaki vaadi
    /// güncellemeyi unutmak serbest olurdu — ve kullanıcı, ekranda okuduğu
    /// sayıyı vermeyen bir pakete para ödemiş olurdu.
    ///
    /// YALNIZCA GERÇEKTEN FARKLI OLAN İKİ ŞEY YAZIYOR. Paketler arasında
    /// özellik farkı YOK; değişen tek şey bu iki sayı. "Öncelikli destek"
    /// gibi üçüncü bir madde uydurmak ilk destek e-postasında yalana
    /// dönerdi — üstelik satın alma kararını o yalan verdirmiş olurdu.
    var highlights: [String] {
        [activeProjectLimit.map { "\($0) aktif proje" } ?? "Sınırsız aktif proje",
         invitedPartnerLimit.map { "\($0) ortak daveti" } ?? "Sınırsız ortak daveti"]
    }

    /// HER PAKETTE OLAN ŞEYLER — paket farkı değil, ürünün tamamının sözü.
    ///
    /// Paket kartlarının İÇİNDE değil ayrı duruyor: bunlar ücretsiz katmanda
    /// da var ve kartlara kopyalansaydı ücretsiz kullanıcı, zaten sahip
    /// olduğu şeyler için ödeme yapması gerektiğini sanırdı.
    ///
    /// DÖRT MADDENİN DÖRDÜ DE KODDA KARŞILIĞI OLAN ŞEYLER: daire/gider/
    /// malzeme sayısında hiçbir sınır yok, ortak erişimi güvenlik kurallarıyla
    /// salt okur, rapor ve Excel çıktısı mevcut, reklam SDK'sı hiç bağlı değil
    /// (`PrivacyInfo.xcprivacy` izleme yok diyor). Buraya doğrulanamayan bir
    /// madde eklenemez.
    static let commonFeatures = [
        "Sınırsız daire, gider, malzeme ve belge kaydı",
        "Ortaklar salt okur — rakamlar herkeste aynı",
        "Dönem raporu, PDF ve Excel çıktısı",
        "Reklam yok, veri izleme yok",
    ]
}
