import XCTest
import FirebaseFirestore
@testable import InsaatTakip

/// Yazma damgaları — madde 55.
///
/// Her yazılan belgeye `updatedAt` (SUNUCU zamanı), `updatedBy` (uid) ve
/// `updatedFrom` (oturum) ekleniyor. Bu testlerin işi, eklemenin OKUMA yolunu
/// bozmadığını kanıtlamak: modeller bu alanları tanımıyor ve çözümleyici
/// onlara takılırsa TEK bir belge tüm uygulamayı boşaltır (bkz. madde 56 —
/// `fetch` tek çözülemeyen belgede fırlatıyor, ekranda hiçbir proje kalmıyor).
final class WriteStampTests: XCTestCase {

    /// Modelin tanımadığı alanlar çözümlemeyi DÜŞÜRMEMELİ.
    func testUnknownFieldsDoNotBreakDecoding() throws {
        let dec = Firestore.Decoder()
        let pid = UUID().uuidString

        let daire: [String: Any] = [
            "id": UUID().uuidString, "projectId": pid,
            "apartmentNumber": 3, "floor": 1, "type": "3+1",
            "status": "available", "price": 350_000_000, "paidAmount": 0,
            "deliveryNote": "",
            // ── damgalar: modelde karşılığı YOK
            "updatedAt": Timestamp(date: Date()),
            "updatedBy": "uid-123",
            "updatedFrom": UUID().uuidString,
        ]
        let a = try dec.decode(Apartment.self, from: daire)
        XCTAssertEqual(a.apartmentNumber, 3)
        XCTAssertEqual(a.price.raw, 350_000_000)

        let gider: [String: Any] = [
            "id": UUID().uuidString, "projectId": pid,
            "category": "İşçilik", "amount": 8_500_000,
            "date": Timestamp(date: Date()), "payee": "", "note": "", "user": "sinan",
            "updatedAt": Timestamp(date: Date()),
            "updatedBy": "uid-123",
            "updatedFrom": UUID().uuidString,
        ]
        let e = try dec.decode(Expense.self, from: gider)
        XCTAssertEqual(e.amount.raw, 8_500_000)
    }

    /// Damga alanları modele SIZMAMALI: yedeğe ve dışa aktarmaya girerlerse
    /// dosya, kullanıcının anlamadığı iç alanlar taşırdı.
    func testStampsAreNotPartOfTheModel() throws {
        let enc = Firestore.Encoder()
        let a = Apartment(id: UUID(), projectId: UUID(), apartmentNumber: 1,
                          floor: 1, type: "2+1", areaM2: 95, status: .available,
                          price: .lira(1_000_000), paidAmount: .zero,
                          deliveryNote: "")
        let alanlar = try enc.encode(a)
        XCTAssertNil(alanlar["updatedAt"])
        XCTAssertNil(alanlar["updatedBy"])
        XCTAssertNil(alanlar["updatedFrom"])
    }
}
