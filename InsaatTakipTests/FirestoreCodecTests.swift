import XCTest
import FirebaseFirestore
@testable import InsaatTakip

/// Firestore kodlaması gidiş-dönüş testleri.
///
/// NEDEN BU TESTLER VAR: birim testlerinin tamamı `InMemoryProjectRepository`
/// kullanıyor, yani modellerin FIRESTORE kodlaması onlarda HİÇ KOŞMUYOR.
/// Bu projenin iki kez öğrendiği ders tam olarak bu: "koşmamış kod okunarak
/// doğrulanamaz" (madde 68'de on beş kusur, kodu okuyarak değil KOŞTURARAK
/// bulundu).
///
/// Buradaki her test bir kaydı yazıldığı gibi kodlayıp geri okuyor. Yakaladığı
/// hata sınıfı dar ama pahalı: yeni eklenen VARSAYILAN DEĞERLİ ama opsiyonel
/// OLMAYAN bir alan (türetilmiş çözümleyici varsayılanı kullanmıyor,
/// `keyNotFound` atıyor — madde 80'de ölçüldü), `Date`/`Timestamp` uyuşmazlığı
/// ve enum ham değeri kayması. Üçü de ekranda değil, ancak gerçek veritabanına
/// yazıldıktan SONRA görünürdü.
final class FirestoreCodecTests: XCTestCase {

    private let enc = Firestore.Encoder()
    private let dec = Firestore.Decoder()

    private func gidipGel<T: Codable & Equatable>(_ value: T) throws -> T {
        try dec.decode(T.self, from: try enc.encode(value))
    }

    /// PROJE — madde 80 ve 86'da üç yeni alan eklendi.
    func testProjectRoundTrip() throws {
        let proje = Project(id: UUID(), blockNumber: "145", parcelNumber: "2",
                            district: "Çayırova", city: "Kocaeli",
                            floors: 5, totalApartments: 20,
                            phase: .kabaInsaat, progress: 68,
                            ownerUid: "uid-1", memberUids: ["uid-1", "uid-2"],
                            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                            invite: nil, photoCount: 48,
                            remainingCostEstimate: Kurus.lira(14_500_000))
        var dolu = proje
        dolu.expenseTaxBasis = .dahil
        dolu.salesTaxBasis = .haric

        let geri = try gidipGel(dolu)
        XCTAssertEqual(geri, dolu)
        XCTAssertEqual(geri.remainingCostEstimate, Kurus.lira(14_500_000))
        XCTAssertEqual(geri.expenseTaxBasis, .dahil)
    }

    /// BEYAN EDİLMEMİŞ proje de gidip gelmeli: `nil` alanlar kodlamada hiç
    /// yazılmıyor ve okumada geri `nil` olmalı — "belirtilmedi"nin kendisi.
    func testProjectWithoutOptionalsRoundTrips() throws {
        let proje = Project(id: UUID(), blockNumber: "908", parcelNumber: "7",
                            district: "—", city: "—", floors: 1, totalApartments: 1,
                            phase: .temel, progress: 0, ownerUid: "uid-1",
                            memberUids: ["uid-1"], createdAt: Date(),
                            invite: nil, photoCount: 0)
        let geri = try gidipGel(proje)
        XCTAssertNil(geri.remainingCostEstimate)
        XCTAssertNil(geri.expenseTaxBasis)
        XCTAssertNil(geri.salesTaxBasis)
    }

    /// DAİRE — madde 83'ün blok etiketi + madde 18'in alıcı adı kuralı.
    ///
    /// `buyerName` KODLANMAZ (CodingKeys dışında): kural alan gizleyemediği
    /// için ad daire belgesinde durursa ortağın cihazına inerdi. Test bunu
    /// kodlama sınırında kanıtlıyor — ekranda değil, baytlarda.
    func testApartmentRoundTripAndBuyerNameStaysOut() throws {
        var daire = Apartment(id: UUID(), projectId: UUID(), apartmentNumber: 7,
                              floor: 2, type: "3+1", blockLabel: "A Blok",
                              areaM2: 111.55, status: .sold,
                              buyerName: "Berk Koç", price: Kurus.lira(3_850_000),
                              paidAmount: Kurus.lira(1_000_000),
                              paymentStatus: .taksitli,
                              saleDate: Date(timeIntervalSince1970: 1_700_000_000),
                              deliveryNote: "Teslim edildi")
        let sozluk = try enc.encode(daire)
        XCTAssertNil(sozluk["buyerName"], "alıcı adı daire belgesine yazılmamalı")
        XCTAssertEqual(sozluk["blockLabel"] as? String, "A Blok")

        let geri = try dec.decode(Apartment.self, from: sozluk)
        daire.buyerName = nil          // kodlamada düştüğü için karşılaştırma da düşürüyor
        XCTAssertEqual(geri, daire)
    }

    /// ORTAK CARİ HAREKETİ — madde 82. Bu model Firestore'a bugün ilk kez
    /// yazılıyor; kodlaması hiç koşmamıştı.
    func testPartnerLedgerEntryRoundTrip() throws {
        let hareket = PartnerLedgerEntry(id: UUID(), projectId: UUID(),
                                         partnerId: UUID(), kind: .cekilen,
                                         amount: Kurus.lira(750_000),
                                         date: Date(timeIntervalSince1970: 1_700_000_000),
                                         note: "Elden avans", user: "Mehmet Kılıç")
        let geri = try gidipGel(hareket)
        XCTAssertEqual(geri, hareket)
        XCTAssertEqual(geri.kind, .cekilen)
        XCTAssertEqual(geri.signedAmount, Kurus.zero - Kurus.lira(750_000))
    }

    /// Üç hareket türü de ham değerleriyle gidip gelmeli: enum ham değeri
    /// kayarsa eski kayıtlar okunamaz hâle gelir.
    func testLedgerKindRawValuesSurvive() throws {
        for tur in PartnerLedgerEntry.Kind.allCases {
            let hareket = PartnerLedgerEntry(id: UUID(), projectId: UUID(),
                                             partnerId: UUID(), kind: tur,
                                             amount: Kurus.lira(1), date: Date(),
                                             note: "", user: "")
            XCTAssertEqual(try gidipGel(hareket).kind, tur)
        }
    }

    /// DENETİM KAYDI — iç içe dizi taşıyan tek model.
    func testAuditEntryWithNestedChangesRoundTrips() throws {
        let kayit = AuditEntry(id: UUID(), recordId: UUID(), projectId: UUID(),
                               subject: "Ortak cari · Mehmet Kılıç",
                               action: .create,
                               changes: [.init(field: "Sermaye", oldValue: "—",
                                               newValue: "8.000.000 ₺"),
                                         .init(field: "Blok / Etap", oldValue: "—",
                                               newValue: "A Blok")],
                               user: "Mehmet Kılıç",
                               date: Date(timeIntervalSince1970: 1_700_000_000))
        let geri = try gidipGel(kayit)
        XCTAssertEqual(geri.changes.count, 2)
        XCTAssertEqual(geri.changes[1].newValue, "A Blok")
    }

    /// ESKİ DAİRE BELGESİ — `blockLabel` alanı HİÇ YOKKEN yazılmış kayıt.
    /// Gerçek üretim verisinin tamamı böyle; çözümleme patlarsa uygulama
    /// kendi verisini açamaz.
    func testApartmentWithoutBlockLabelDecodes() throws {
        let sozluk: [String: Any] = [
            "id": UUID().uuidString, "projectId": UUID().uuidString,
            "apartmentNumber": 3, "floor": 1, "type": "3+1",
            "status": "available", "price": 0, "paidAmount": 0,
            "deliveryNote": "",
        ]
        let daire = try dec.decode(Apartment.self, from: sozluk)
        XCTAssertEqual(daire.blockLabel, "")
    }

    /// ESKİ PROJE BELGESİ — madde 80/86 alanları hiç yokken yazılmış kayıt.
    func testProjectWithoutNewFieldsDecodes() throws {
        let sozluk: [String: Any] = [
            "id": UUID().uuidString, "blockNumber": "145", "parcelNumber": "2",
            "district": "Çayırova", "city": "Kocaeli", "floors": 5,
            "totalApartments": 20, "phase": "Kaba inşaat", "progress": 68,
            "ownerUid": "uid-1", "memberUids": ["uid-1"],
            "createdAt": Timestamp(date: Date()), "photoCount": 0,
        ]
        let proje = try dec.decode(Project.self, from: sozluk)
        XCTAssertNil(proje.remainingCostEstimate)
        XCTAssertNil(proje.expenseTaxBasis)
        XCTAssertEqual(proje.progress, 68)
    }

    /// MALZEME — türetilen alanlar KODLANMAMALI.
    ///
    /// `totalIn`, `totalOut` ve `accruedCost` fişlerden hesaplanıyor; belgeye
    /// yazılsalardı iki doğruluk kaynağı olur ve biri bayatlardı. Karar
    /// `CodingKeys`te yazılı ama kararı KORUYAN bir şey yoktu: alanı listeye
    /// eklemek tek satır ve kimse fark etmezdi.
    func testMaterialDerivedTotalsAreNotEncoded() throws {
        var malzeme = Material(id: UUID(), projectId: UUID(), code: "Ø12",
                               name: "Demir", subtitle: "Nervürlü inşaat demiri",
                               unit: "kg", unitPrice: Kurus.lira(29), step: 500)
        malzeme.totalIn = 48_000
        malzeme.totalOut = 41_800
        malzeme.accruedCost = Kurus.lira(1_370_000)

        let sozluk = try enc.encode(malzeme)
        XCTAssertNil(sozluk["totalIn"], "türetilen toplam belgeye yazılmamalı")
        XCTAssertNil(sozluk["totalOut"])
        XCTAssertNil(sozluk["accruedCost"])

        // Geri okunan kayıt SIFIR toplamla geliyor ve bu doğru: rakam ham
        // hareketlerden yeniden hesaplanıyor (`recalculateMaterial`).
        let geri = try dec.decode(Material.self, from: sozluk)
        XCTAssertEqual(geri.totalIn, 0)
        XCTAssertEqual(geri.accruedCost, .zero)
        XCTAssertEqual(geri.unitPrice, Kurus.lira(29))
        XCTAssertEqual(geri.code, "Ø12")
    }

}
