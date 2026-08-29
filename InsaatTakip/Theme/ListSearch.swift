import Foundation

// MARK: - Liste araması ve dönem süzgeci (madde 79)
//
// Arama YALNIZCA dairelerde vardı. Giderler, malzeme hareketleri ve hareket
// akışı gözle taranıyordu — ve o listeler dairelerin aksine SINIRSIZ büyüyor:
// daire sayısı projede sabit, gider ve fiş sayısı her gün artıyor.
//
// TEK DAVRANIŞ, ÜÇ LİSTE. Her ekranın kendi eşleştirme kuralını yazması,
// aynı sorgunun bir sekmede bulup diğerinde bulamaması demekti. Kural burada,
// tek yerde.

enum ListSearch {

    /// Arama karşılaştırması için metni sadeleştirir.
    ///
    /// TÜRKÇE YEREL AYARLA küçültülüyor: `"İRSALİYE".lowercased()` varsayılan
    /// yerel ayarda "i̇rsaliye" (birleşik nokta) üretiyor ve kullanıcının
    /// yazdığı "irsaliye" ile EŞLEŞMİYOR. Aynı tuzak `I → ı` yönünde de var.
    ///
    /// AKSAN DA KATLANIYOR: müteahhit klavyeden "cimento" ya da "sirket"
    /// yazdığında "Çimento" ve "Şirket" bulunmalı. Türkçe karakterleri
    /// bulmak için Türkçe karakter yazmayı şart koşmak, aramanın işini
    /// kullanıcıya devretmek olurdu.
    static func normalize(_ text: String) -> String {
        // ADIM 1 — i AİLESİ ÖNCE VE ELLE. Bu sıra bir tercih değil,
        // zorunluluk; testle öğrenildi.
        //
        // `folding(.diacriticInsensitive)` "İ"nin noktasını bir AKSAN sanıp
        // siliyor ve "I" üretiyor; ardından Türkçe küçültme "I"yı NOKTASIZ
        // "ı" yapıyor. Sonuç: "İRSALİYE" → "ırsalıye", kullanıcının yazdığı
        // "irsaliye" ile EŞLEŞMİYOR. Türkçede noktanın harfi değiştirdiği,
        // Unicode katlamasının ise onu süs sandığı yer tam burası.
        //
        // Dördünü de ("i", "ı", "İ", "I") tek harfe indiriyoruz. Aramada bu
        // DOĞRU davranış: "yil" yazan "yıl"ı, "yıl" yazan "YIL"ı bulmalı —
        // hangi i'yi yazdığını hatırlamak kullanıcının işi değil.
        let iAilesi = text
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
            .replacingOccurrences(of: "ı", with: "i")

        // ADIM 2 — kalan aksanlar (ç, ş, ğ, ö, ü). Artık noktalı i kalmadığı
        // için katlama zarar veremez.
        return iAilesi
            .folding(options: .diacriticInsensitive, locale: Fmt.locale)
            .lowercased(with: Fmt.locale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sorgu, alanlardan HERHANGİ BİRİNDE geçiyor mu?
    ///
    /// Boş sorgu HER ŞEYİ eşleştiriyor: süzgeç yokken liste kırpılmamalı.
    static func matches(_ query: String, in fields: [String]) -> Bool {
        let q = normalize(query)
        guard !q.isEmpty else { return true }
        return fields.contains { normalize($0).contains(q) }
    }
}

/// Tarih aralığı süzgeci.
///
/// Dört seçenek, daha fazlası değil: müteahhidin sorduğu soru "bu ay ne
/// harcadım", "bu sezon ne girdi", "bu yıl toplam ne oldu". Serbest tarih
/// aralığı seçici bunların üçünü de daha çok dokunuşla veriyor ve dördüncü
/// bir soruya cevap vermiyor.
enum ListPeriod: String, CaseIterable, Identifiable {
    case tumu = "Tümü"
    case buAy = "Bu ay"
    case sonUcAy = "Son 3 ay"
    case buYil = "Bu yıl"

    var id: String { rawValue }

    /// Tarih bu dönemin içinde mi?
    ///
    /// `now` DIŞARIDAN alınıyor: "bu ay" tanımı çalışma anına bağlı ve
    /// testte sabitlenmeden doğrulanamaz. Bu projede aynı hata bir kez
    /// yaşandı — "son 7 gün" etiketi vardı, süzgeç yoktu (madde 54).
    func contains(_ date: Date, now: Date = Date()) -> Bool {
        let cal = Fmt.calendar
        switch self {
        case .tumu:
            return true
        case .buAy:
            return cal.isDate(date, equalTo: now, toGranularity: .month)
        case .sonUcAy:
            // ÜÇ AY ÖNCESİNİN AY BAŞI — "90 gün" değil. Müteahhit "son 3 ay"
            // derken takvim aylarını kastediyor; gün sayısıyla hesaplamak
            // ayın 31'inde farklı, 1'inde farklı bir pencere verirdi.
            guard let bas = cal.date(byAdding: .month, value: -2, to: now),
                  let ayBasi = cal.dateInterval(of: .month, for: bas)?.start
            else { return true }
            return date >= ayBasi && date <= now
        case .buYil:
            return cal.isDate(date, equalTo: now, toGranularity: .year)
        }
    }
}
