import Foundation

// MARK: - Ortak Cari Hesabı (madde 82)
//
// ORTAKLIK VAADİNİN TAM MERKEZİ. Bugüne kadar `share(of:)` hesap TUTMUYOR,
// proje toplamlarını yüzdeyle DİLİMLİYORDU: 8 M ₺ koyan ortakla hiç para
// koymamış ortak birebir aynı "Payın %50" kartını görüyordu ve bakabileceği
// başka yer yoktu.
//
// Daha ağırı: bir dağıtımı kaydetmenin TEK yolu `.diger` kategorisinde bir
// giderdi. `netAmount = satış − (malzeme + diğer gider)` olduğu için ortağa
// para ödemek inşaat maliyeti gibi görünüyor ve dağıtımın dayandığı rakamı
// BÜTÜN ortaklar için birden düşürüyordu — uygulamanın ürettiği rakam, kendi
// sebep olduğu ortaklık ihtilafının dayanağı oluyordu.
//
// Kaybedilen şey ayrıca VERİ: adi ortaklıkta sermaye ve avans çekimlerinin
// çoğu elden dönüyor; müşavirin defterinde yok, Excel'de yok. 18 ay sonra
// banka dekontlarından geriye kurmak mümkün değil.

/// Ortağın kasayla arasındaki tek bir hareket.
struct PartnerLedgerEntry: Codable, Identifiable, Equatable {

    /// Hareket türü. ÜÇÜ DE NAKİT/FİNANSMAN hareketi — hiçbiri inşaat
    /// maliyeti değil ve hiçbiri `netAmount`a girmiyor (bkz. dosya sonundaki
    /// korkuluk notu).
    enum Kind: String, Codable, CaseIterable, Identifiable {
        /// Ortak → kasa. Sermaye koyma.
        case sermaye = "Sermaye"
        /// Kasa → ortak. Kâr dağıtımı değil, avans/ön çekim.
        case cekilen = "Çekilen / avans"
        /// Kasa → ortak. Kâr payı dağıtımı.
        case dagitim = "Kâr dağıtımı"

        var id: String { rawValue }

        /// Bakiyeye etkisi: sermaye ARTIRIR, çekim ve dağıtım AZALTIR.
        ///
        /// Tek bir işaretli tutar alanı yerine tür + pozitif tutar tutuluyor:
        /// eksi işaretli bir para alanı, formda "-500.000" yazmayı unutan
        /// kullanıcıda sessizce ters yönde bir kayıt üretirdi.
        var increasesBalance: Bool { self == .sermaye }

        var icon: String {
            switch self {
            case .sermaye: return "arrow.down.circle.fill"
            case .cekilen: return "arrow.up.circle"
            case .dagitim: return "arrow.up.forward.circle.fill"
            }
        }
    }

    let id: UUID
    /// Firestore yolu için — bkz. MaterialLog.projectId.
    let projectId: UUID
    let partnerId: UUID
    var kind: Kind
    /// HER ZAMAN POZİTİF; yön `kind`ten geliyor.
    var amount: Kurus
    var date: Date
    var note: String        // "Nisan sermaye katkısı", "Elden avans"
    var user: String        // Kaydı giren

    var dateText: String { Fmt.shortDate(date) }

    /// Bakiyeye işaretli katkı.
    var signedAmount: Kurus {
        kind.increasesBalance ? amount : .zero - amount
    }
}

// MARK: - Ortak bakiyesi

/// Tek ortağın cari hesap özeti.
///
/// BU BİR "DAĞITILABİLİR KÂR" HESABI DEĞİL ve olmayacak. Defter açılır
/// açılmaz sorulacak ilk soru "ne dağıtabilirim" olacak; o soru madde 86'nın
/// kalan inşaat maliyetini, satılmamış stoğun gerçekleşme oranını ve vergi
/// yükünü ister. Buradaki bakiye çok daha dar ve kesin bir şey söylüyor:
/// ortak bu projeye NE KOYDU, NE ÇEKTİ, arada ne kaldı.
struct PartnerBalance: Equatable {
    var capital: Kurus = .zero      // toplam sermaye
    var withdrawn: Kurus = .zero    // toplam çekilen/avans
    var distributed: Kurus = .zero  // toplam kâr dağıtımı

    /// Ortağın kasada duran net katkısı: sermaye − (çekilen + dağıtım).
    /// Eksiye düşebilir ve düşmeli: koyduğundan fazlasını çekmiş ortak,
    /// ortaklığa borçludur ve rakam bunu söylemek zorunda.
    var net: Kurus { capital - withdrawn - distributed }

    var isEmpty: Bool { capital == .zero && withdrawn == .zero && distributed == .zero }
}
