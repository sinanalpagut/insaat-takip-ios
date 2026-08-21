import XCTest
@testable import InsaatTakip

/// Taksit planı ve FIFO mahsup — madde 21, 32, 35, 36.
final class InstallmentTests: XCTestCase {

    private let projectId = UUID()
    private let apartmentId = UUID()

    private func gun(_ y: Int, _ a: Int, _ g: Int) -> Date {
        Fmt.calendar.date(from: DateComponents(year: y, month: a, day: g))!
    }

    // MARK: plan — üç güvence, tüm girdi uzayında

    /// Plan üç şeyi BİRLİKTE garanti etmeli: toplam bedele eşit, taksitler
    /// eşit (±1 kuruş), ve planın İLK SATIRI seçilen ilk vadeye düşer.
    ///
    /// Üçü de ayrı ayrı kırılmıştı ve hiçbiri toplam denetimiyle yakalanamıyordu.
    /// Satış formu 1...240 arası her taksit sayısına izin veriyor; bu yüzden
    /// tarama da tüm aralığı geziyor — eski kod yalnızca 100'ün tam
    /// bölenlerinde (9 değer) doğru sonuç veriyordu.
    func testPlanInvariantsAcrossEntireInputSpace() {
        var fiyatlar: [Int64] = []
        for lira in [750_000, 1_200_000, 1_837_499, 2_450_001, 3_999_997, 12_345_679] {
            fiyatlar += [Int64(lira) * 100, Int64(lira) * 100 + 37, Int64(lira) * 100 + 99]
        }
        let pesinatlar: [Int64] = [0, 5_000_000, 33_333_333]
        let ilkVade = gun(2026, 9, 1)
        var vaka = 0

        for fiyat in fiyatlar {
            for pesinat in pesinatlar where fiyat > pesinat {
                for count in 1...240 {
                    vaka += 1
                    let plan = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                                price: .kurus(fiyat), downPayment: .kurus(pesinat),
                                                count: count, firstDueDate: ilkVade)
                    XCTAssertEqual(plan.reduce(Kurus.zero) { $0 + $1.amount }.raw, fiyat,
                                   "toplam ≠ bedel (fiyat=\(fiyat) peşinat=\(pesinat) n=\(count))")

                    let taksitler = plan.filter { $0.sequence > 0 }.map(\.amount.raw)
                    XCTAssertEqual(taksitler.count, count)
                    XCTAssertLessThanOrEqual((taksitler.max() ?? 0) - (taksitler.min() ?? 0), 1,
                                             "taksitler eşit değil (fiyat=\(fiyat) n=\(count))")

                    let ilkSatir = plan.min { $0.sequence < $1.sequence }!
                    XCTAssertTrue(Fmt.calendar.isDate(ilkSatir.dueDate, inSameDayAs: ilkVade),
                                  "ilk satır seçilen vadeye düşmüyor (peşinat=\(pesinat) n=\(count))")
                }
            }
        }
        XCTAssertEqual(vaka, 12_960, "girdi uzayı beklenenden küçük — tarama daraldı mı?")
    }

    /// Peşinat YOKSA ilk satır 1. taksittir ve seçilen tarihe düşer.
    ///
    /// KUSUR: vadeler koşulsuz `value: index + 1` ile üretiliyordu; peşinatsız
    /// satışta kullanıcının "İlk vade" diye seçtiği tarihe HİÇBİR taksit
    /// düşmüyor, plan bir ay ileri kayıyordu. Parametre adı, ekran etiketi ve
    /// özet metni üçü birden yanlış tarihi vaat ediyordu.
    func testFirstDueDateWithoutDownPayment() {
        let secilen = gun(2026, 9, 1)
        let plan = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                    price: .lira(1_200_000), downPayment: .zero,
                                    count: 12, firstDueDate: secilen)
        XCTAssertEqual(plan.first?.sequence, 1)
        XCTAssertTrue(Fmt.calendar.isDate(plan.first!.dueDate, inSameDayAs: secilen))
        // 12 taksit, son vade 11 ay sonra — bir ay sarkma YOK.
        XCTAssertTrue(Fmt.calendar.isDate(plan.last!.dueDate, inSameDayAs: gun(2027, 8, 1)))
    }

    /// Peşinat VARSA ilk satır peşinattır; taksitler bir ay sonra başlar.
    func testFirstDueDateWithDownPayment() {
        let secilen = gun(2026, 9, 1)
        let plan = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                    price: .lira(1_200_000), downPayment: .lira(200_000),
                                    count: 12, firstDueDate: secilen)
        XCTAssertEqual(plan.first?.sequence, 0)
        XCTAssertTrue(Fmt.calendar.isDate(plan.first!.dueDate, inSameDayAs: secilen))
        XCTAssertTrue(Fmt.calendar.isDate(plan[1].dueDate, inSameDayAs: gun(2026, 10, 1)))
    }

    /// Ay sonu: çapa SABİT kaldığı için gün kırpılsa da sonraki aylarda geri
    /// dönüyor — kalıcı kayma yok.
    func testMonthEndDoesNotDriftPermanently() {
        let plan = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                    price: .lira(1_200_000), downPayment: .zero,
                                    count: 6, firstDueDate: gun(2026, 1, 31))
        let gunler = plan.map { Fmt.calendar.component(.day, from: $0.dueDate) }
        XCTAssertEqual(gunler, [31, 28, 31, 30, 31, 30])
    }

    /// Bedel peşinata eşit ya da altındaysa taksit üretilmez.
    func testDegenerateInputs() {
        let sadecePesinat = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                             price: .lira(100_000), downPayment: .lira(100_000),
                                             count: 12, firstDueDate: gun(2026, 9, 1))
        XCTAssertEqual(sadecePesinat.filter { $0.sequence > 0 }.count, 0)

        let planYok = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                       price: .zero, downPayment: .zero,
                                       count: 0, firstDueDate: gun(2026, 9, 1))
        XCTAssertTrue(planYok.isEmpty)
    }

    // MARK: settle — FIFO mahsup

    /// Mahsubun dört değişmezi ve `status` ile tutarlılığı.
    ///
    /// `settle` TEK KAYNAK: aynı FIFO döngüsü önce `status`, sonra
    /// `ReminderScheduler` içinde yazılıydı ve ödeme planı ekranı üçüncüsünü
    /// gerektirecekti. Üç kopya, birinin değişip diğerlerinin kalması demek.
    func testSettlementInvariants() {
        let bugun = gun(2026, 8, 21)
        for count in [1, 3, 12, 36] {
            for pesinat in [Int64(0), 20_000_000] {
                let plan = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                            price: .lira(3_600_000), downPayment: .kurus(pesinat),
                                            count: count, firstDueDate: gun(2026, 2, 15))
                let planToplam = plan.reduce(Kurus.zero) { $0 + $1.amount }.raw
                for k in 0...9 {
                    let tahsilat = Kurus.kurus(planToplam * Int64(k) / 8)   // k=9 → fazla ödeme
                    let satirlar = Installment.settle(plan, collected: tahsilat)

                    // 1) dağıtılan = min(tahsilat, plan toplamı)
                    XCTAssertEqual(satirlar.reduce(Kurus.zero) { $0 + $1.paid }.raw,
                                   min(tahsilat.raw, planToplam))
                    // 2) hiçbir satır kendi tutarından fazla ya da negatif almaz
                    XCTAssertFalse(satirlar.contains { $0.paid.raw < 0 || $0.paid > $0.installment.amount })
                    // 3) FIFO: ilk açık satırdan sonra kapanmış satır olmaz
                    if let ilkAcik = satirlar.firstIndex(where: { !$0.isSettled }) {
                        XCTAssertFalse(satirlar[ilkAcik...].contains { $0.isSettled },
                                       "FIFO bozuldu (n=\(count) k=\(k))")
                    }
                    // 4) status ile settle aynı şeyi söyler
                    let durum = Installment.status(for: plan, collected: tahsilat, today: bugun)
                    let gecikmis = satirlar.filter { $0.isOverdue(today: bugun) }
                        .reduce(Kurus.zero) { $0 + $1.unpaid }
                    XCTAssertEqual(durum.overdue, gecikmis, "gecikme ayrıştı (n=\(count) k=\(k))")
                    XCTAssertEqual(durum.next?.id,
                                   satirlar.first { !$0.isSettled }?.installment.id)
                }
            }
        }
    }

    /// Kısmi ödeme: vade AÇIK kalır ve kalan tutar doğru hesaplanır.
    /// Gerçek cihazdaki vaka: 4.000.000 ₺ / 200.000 ₺ peşinat / 12 taksit,
    /// 450.000 ₺ tahsilat → 1. taksitte kalan 66.666,67 ₺.
    func testPartialSettlementMatchesProductionCase() {
        let plan = Installment.plan(apartmentId: apartmentId, projectId: projectId,
                                    price: .lira(4_000_000), downPayment: .lira(200_000),
                                    count: 12, firstDueDate: gun(2026, 8, 19))
        let satirlar = Installment.settle(plan, collected: .lira(450_000))
        XCTAssertTrue(satirlar[0].isSettled)                       // peşinat kapandı
        XCTAssertTrue(satirlar[1].isPartial)                       // 1. taksit kısmi
        XCTAssertEqual(satirlar[1].unpaid.raw, 6_666_667)          // kalan 66.666,67 ₺
        XCTAssertEqual(satirlar[1].installment.amount.raw, 31_666_667)
        XCTAssertEqual(satirlar.last!.installment.amount.raw, 31_666_666)
    }
}
