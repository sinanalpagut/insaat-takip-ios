import XCTest
@testable import InsaatTakip

/// Aylık satış grafiğinin kapsadığı dönem.
///
/// NEDEN BU TEST VAR: dönem raporunun ÜSTÜNDE "Satış geliri 3.850.000 ₺"
/// yazarken hemen ALTINDAKİ grafikte bütün çubuklar sıfırdı. İkisi de
/// doğruydu — grafik penceresi bu ayı dışarıda bırakıyordu — ama ekran
/// kullanıcıya iki farklı şey söylüyordu. Gerçek fiş turunda görüldü.
@MainActor
final class MonthlySalesTests: XCTestCase {

    /// BUGÜN yapılan satış grafiğin SON çubuğunda görünmeli.
    func testSaleTodayAppearsInLastBar() {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        let proje = vm.projects.first!

        let oncekiToplam = vm.monthlySales(for: proje.id).last?.value ?? .zero
        guard let bos = vm.apartments(for: proje.id).first(where: { !$0.isCommitted }) else {
            return XCTFail("zemin: boş daire bulunamadı")
        }
        XCTAssertTrue(vm.saveSale(role: .admin, apartmentId: bos.id,
                                  buyerName: "Deneme Alıcı",
                                  priceText: "1000", paidText: "1000",
                                  payment: .tamamlandi, saleDate: Date()))

        let bars = vm.monthlySales(for: proje.id)
        XCTAssertEqual(bars.count, 6)
        XCTAssertEqual(bars.last?.value, oncekiToplam + Kurus.kurus(1_000_00),
                       "bugünkü satış son çubukta görünmüyor")
    }

    /// Son çubuğun etiketi İÇİNDE BULUNULAN ay olmalı.
    func testLastBarIsCurrentMonth() {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        let proje = vm.projects.first!
        let buAy = Fmt.calendar.component(.month, from: Date())
        let beklenen = ProjectViewModel.monthNames[buAy - 1]
        XCTAssertEqual(vm.monthlySales(for: proje.id).last?.label, beklenen)
    }
}
