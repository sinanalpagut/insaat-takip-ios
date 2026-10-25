import XCTest
import StoreKit
import StoreKitTest
@testable import InsaatTakip

/// Abonelik — hak kararı, satın alma akışı ve mağaza yapılandırması
/// (madde 87/c · 25 Eki 2026).
///
/// ÜÇ KATMAN, ÜÇ AYRI KANIT:
///   1. `EntitlementResolver` saf: hangi işlemden hangi hak çıkar.
///   2. `SubscriptionManager` sahte mağazayla: satın alma, vazgeçme, bekleme,
///      hata ve geri yüklemenin kullanıcıya ne söylediği.
///   3. `AppStoreSubscriptionStore` GERÇEK StoreKit ile (`SKTestSession` +
///      `Config/InsaatTakip.storekit`): ürün kimlikleri, dönemler ve işlem →
///      hak zinciri Apple'ın kendi çerçevesinde.
@MainActor
final class SubscriptionTests: XCTestCase {

    // MARK: - 1. Hak kararı

    private func kayit(_ id: String, iade: Bool = false, yukseltildi: Bool = false) -> EntitlementRecord {
        EntitlementRecord(productId: id, revocationDate: iade ? Date() : nil, isUpgraded: yukseltildi)
    }

    func testUrunKimligiPaketeVeDonemeGeriDonuyor() {
        for plan in Plan.purchasable {
            for donem in BillingPeriod.allCases {
                let id = try! XCTUnwrap(plan.productId(donem))
                let eslesme = Plan.match(productId: id)
                XCTAssertEqual(eslesme?.plan, plan)
                XCTAssertEqual(eslesme?.period, donem)
            }
        }
        XCTAssertNil(Plan.match(productId: "com.baska.uygulama.pro"))
        XCTAssertEqual(Plan.allProductIds.count, 6)
    }

    func testIslemYoksaUcretsizKatman() {
        XCTAssertEqual(EntitlementResolver.resolve([]), .free)
    }

    /// Yükseltme anında iki geçerli işlem yan yana durabilir; BÜYÜK kazanır.
    func testEnBuyukPaketKazaniyor() {
        let hak = EntitlementResolver.resolve([kayit(Plan.santiye.monthlyProductId!),
                                               kayit(Plan.kurumsal.yearlyProductId!),
                                               kayit(Plan.muteahhit.monthlyProductId!)])
        XCTAssertEqual(hak, .plan(.kurumsal))
    }

    /// İade edilmiş ödemeye hak verilmez.
    func testIadeEdilenIslemHakVermiyor() {
        let hak = EntitlementResolver.resolve([kayit(Plan.kurumsal.monthlyProductId!, iade: true),
                                               kayit(Plan.santiye.monthlyProductId!)])
        XCTAssertEqual(hak, .plan(.santiye))
    }

    func testYukseltilmisEskiIslemSayilmiyor() {
        let hak = EntitlementResolver.resolve([kayit(Plan.kurumsal.monthlyProductId!, yukseltildi: true)])
        XCTAssertEqual(hak, .free)
    }

    /// Tanınmayan ürün hak AÇMAZ — kişinin ödemediği bir paketi açmak olurdu.
    func testTaninmayanUrunHakVermiyor() {
        XCTAssertEqual(EntitlementResolver.resolve([kayit("com.baska.uygulama.pro")]), .free)
    }

    /// Hesap işareti: aynı uid her yerde aynı, farklı uid farklı; UUID
    /// biçimi geçerli (StoreKit geçersiz işareti reddediyor).
    func testHesapIsaretiKararliVeAyirt() {
        let a1 = EntitlementResolver.accountToken(for: "uid-a")
        let a2 = EntitlementResolver.accountToken(for: "uid-a")
        let b = EntitlementResolver.accountToken(for: "uid-b")
        XCTAssertEqual(a1, a2)
        XCTAssertNotEqual(a1, b)
        let u = a1.uuid
        XCTAssertEqual(u.6 >> 4, 0x8, "sürüm biti")
        XCTAssertEqual(u.8 >> 6, 0b10, "RFC 4122 varyantı")
        XCTAssertFalse(a1.uuidString.contains("uid-a"))
    }

    // MARK: - 2. Satın alma akışı (sahte mağaza)

    @MainActor
    private final class SahteMagaza: SubscriptionStore {
        var kayitlar: [EntitlementRecord] = []
        var teklifler: [StoreOffer] = []
        var satinAlmaSonucu: Result<PurchaseResult, Error> = .success(.purchased)
        var satinAlinca: String?
        var gelenIsaret: UUID?
        var syncHatasi: Error?
        var bekletilen: CheckedContinuation<Void, Never>?
        var bekle = false
        var canMakePayments = true
        var durum: ActiveSubscription?

        func loadOffers() async throws -> [StoreOffer] { teklifler }
        func currentRecords() async -> [EntitlementRecord] { kayitlar }
        func status() async -> ActiveSubscription? { durum }
        func purchase(_ offerId: String, accountToken: UUID?) async throws -> PurchaseResult {
            gelenIsaret = accountToken
            if bekle { await withCheckedContinuation { bekletilen = $0 } }
            let sonuc = try satinAlmaSonucu.get()
            if sonuc == .purchased {
                kayitlar = [EntitlementRecord(productId: offerId, revocationDate: nil, isUpgraded: false)]
            }
            return sonuc
        }
        func sync() async throws { if let syncHatasi { throw syncHatasi } }
        func observe(_ onChange: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
            Task { await onChange() }
        }
    }

    private func teklif(_ plan: Plan, _ donem: BillingPeriod = .monthly) -> StoreOffer {
        StoreOffer(id: plan.productId(donem)!, plan: plan, period: donem,
                   displayPrice: "x", price: 1, introOffer: nil)
    }

    func testAcilistaHakBilinmiyorSonraMagazadanGeliyor() async {
        let magaza = SahteMagaza()
        magaza.kayitlar = [kayit(Plan.muteahhit.monthlyProductId!)]
        let yonetici = SubscriptionManager(store: magaza)
        XCTAssertEqual(yonetici.entitlement, .resolving)
        await yonetici.refresh()
        XCTAssertEqual(yonetici.entitlement, .plan(.muteahhit))
    }

    /// DEBUG `-plan`: hak sabit, mağaza değiştiremez.
    func testSabitlenmisHakMagazayaRagmenDegismiyor() async {
        let magaza = SahteMagaza()
        let yonetici = SubscriptionManager(store: magaza, override: .plan(.kurumsal))
        await yonetici.refresh()
        XCTAssertEqual(yonetici.entitlement, .plan(.kurumsal))
    }

    func testSatinAlmaHakkiAciyorVeHesapIsaretiniGonderiyor() async {
        let magaza = SahteMagaza()
        let yonetici = SubscriptionManager(store: magaza)
        await yonetici.refresh()
        XCTAssertEqual(yonetici.entitlement, .free)

        let sonuc = await yonetici.purchase(teklif(.santiye), uid: "uid-1")

        XCTAssertEqual(sonuc, .purchased(.santiye))
        XCTAssertEqual(yonetici.entitlement, .plan(.santiye))
        XCTAssertEqual(magaza.gelenIsaret, EntitlementResolver.accountToken(for: "uid-1"))
        XCTAssertNil(yonetici.purchasingId, "işlem bitti ama düğmeler kilitli kaldı")
    }

    /// Vazgeçmek HATA DEĞİL: uyarı kutusu açılmamalı.
    func testVazgecmeHataGosterilmiyor() async {
        let magaza = SahteMagaza()
        magaza.satinAlmaSonucu = .failure(StoreKitError.userCancelled)
        let yonetici = SubscriptionManager(store: magaza)
        let sonuc = await yonetici.purchase(teklif(.santiye), uid: nil)
        XCTAssertEqual(sonuc, .cancelled)
    }

    /// Onay bekleyen satın alma hakkı AÇMAZ — onay gelince güncelleme açar.
    func testBekleyenSatinAlmaHakAcmiyor() async {
        let magaza = SahteMagaza()
        magaza.satinAlmaSonucu = .success(.pending)
        let yonetici = SubscriptionManager(store: magaza)
        await yonetici.refresh()
        let sonuc = await yonetici.purchase(teklif(.kurumsal), uid: nil)
        XCTAssertEqual(sonuc, .pending)
        XCTAssertEqual(yonetici.entitlement, .free)
    }

    func testAgHatasiAdlandiriliyor() async {
        let magaza = SahteMagaza()
        magaza.satinAlmaSonucu = .failure(StoreKitError.networkError(URLError(.notConnectedToInternet)))
        let yonetici = SubscriptionManager(store: magaza)
        let sonuc = await yonetici.purchase(teklif(.santiye), uid: nil)
        XCTAssertEqual(sonuc, .failed(.network))
    }

    /// Uçuşta satın alma varken ikincisi BAŞLAMAZ: iki Apple penceresi üst
    /// üste açılır ve kişi iki pakete birden ödeme yapabilirdi.
    func testUcustakiSatinAlmaVarkenIkincisiBaslamiyor() async {
        let magaza = SahteMagaza()
        magaza.bekle = true
        let yonetici = SubscriptionManager(store: magaza)
        let ilk = Task { await yonetici.purchase(teklif(.santiye), uid: nil) }
        for _ in 0..<200 where magaza.bekletilen == nil { try? await Task.sleep(nanoseconds: 5_000_000) }
        let ikinci = await yonetici.purchase(teklif(.kurumsal), uid: nil)
        XCTAssertEqual(ikinci, .busy)
        let geriYukleme = await yonetici.restore()
        XCTAssertEqual(geriYukleme, .busy)
        magaza.bekletilen?.resume()
        _ = await ilk.value
    }

    func testGeriYuklemeBulamazsaSoyluyor() async {
        let yonetici = SubscriptionManager(store: SahteMagaza())
        let sonuc = await yonetici.restore()
        XCTAssertEqual(sonuc, .nothingFound)
    }

    func testGeriYuklemeBulursaPaketiSoyluyor() async {
        let magaza = SahteMagaza()
        magaza.kayitlar = [kayit(Plan.muteahhit.yearlyProductId!)]
        let yonetici = SubscriptionManager(store: magaza)
        let sonuc = await yonetici.restore()
        XCTAssertEqual(sonuc, .restored(.muteahhit))
    }

    /// Mağaza boş liste dönerse (ürün ASC'de yok/onaysız) ekran "yüklendi"
    /// demiyor — fiyatsız, düğmesiz kart sessizce kalırdı.
    func testBosUrunListesiHataSayiliyor() async {
        let yonetici = SubscriptionManager(store: SahteMagaza())
        await yonetici.loadOffers()
        XCTAssertEqual(yonetici.offersState, .failed)
    }

    /// HESAP SİLMEDE ÖDEME SÜRÜYORSA SÖYLENMELİ — hak açık olmasa bile.
    /// Ödeme yeniden denenirken (ek süre dışında) `currentEntitlements` boş,
    /// yani hak "ücretsiz" görünüyor; ama otomatik yenileme açık ve Apple
    /// kartı güncellenince ücret alıyor. Uyarı haktan değil yenileme
    /// durumundan çıkmalı.
    func testOdemeYenidenDenenirkenSilmeUyarisiCikiyor() async {
        let magaza = SahteMagaza()
        magaza.durum = ActiveSubscription(plan: .santiye, period: .monthly, state: .billingIssue,
                                          expiresAt: Date().addingTimeInterval(-86_400), nextPlan: nil)
        let yonetici = SubscriptionManager(store: magaza)
        await yonetici.refresh()
        XCTAssertEqual(yonetici.entitlement, .free)
        XCTAssertEqual(yonetici.billingNotice, .continues(.santiye))
    }

    func testIptalEdilmisAbonelikteFarkliCumle() async {
        let magaza = SahteMagaza()
        magaza.kayitlar = [kayit(Plan.muteahhit.monthlyProductId!)]
        magaza.durum = ActiveSubscription(plan: .muteahhit, period: .monthly, state: .cancelled,
                                          expiresAt: Date().addingTimeInterval(86_400), nextPlan: nil)
        let yonetici = SubscriptionManager(store: magaza)
        await yonetici.refresh()
        XCTAssertEqual(yonetici.billingNotice, .cancelled(.muteahhit))
    }

    /// Durum okunamadıysa ama hak ücretliyse TEDBİRLİ: "ödeme sürer" denir.
    func testDurumBilinmiyorsaTedbirliUyari() async {
        let magaza = SahteMagaza()
        magaza.kayitlar = [kayit(Plan.kurumsal.yearlyProductId!)]
        let yonetici = SubscriptionManager(store: magaza)
        await yonetici.refresh()
        XCTAssertEqual(yonetici.billingNotice, .continues(.kurumsal))
    }

    func testAbonelikYoksaUyariYok() async {
        let yonetici = SubscriptionManager(store: SahteMagaza())
        await yonetici.refresh()
        XCTAssertEqual(yonetici.billingNotice, .none)
    }

    // MARK: - 3. Mağaza yapılandırması

    private var yapilandirmaURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/InsaatTakip.storekit")
    }

    /// `Config/InsaatTakip.storekit` App Store Connect'in AYNASI: yerel
    /// denemeler ve aşağıdaki StoreKit testleri bu dosyayla koşuyor. Katalog
    /// ile ayrışırsa testler gerçekte olmayan bir mağazayı sınamış olur.
    func testYapilandirmaKatalogIleAyni() throws {
        let veri = try Data(contentsOf: yapilandirmaURL)
        let kok = try XCTUnwrap(JSONSerialization.jsonObject(with: veri) as? [String: Any])
        let gruplar = try XCTUnwrap(kok["subscriptionGroups"] as? [[String: Any]])
        XCTAssertEqual(gruplar.count, 1, "paketler TEK grupta olmalı — yoksa iki pakete birden abone olunur")
        let urunler = try XCTUnwrap(gruplar[0]["subscriptions"] as? [[String: Any]])
        XCTAssertEqual(Set(urunler.compactMap { $0["productID"] as? String }), Set(Plan.allProductIds))

        for urun in urunler {
            let id = try XCTUnwrap(urun["productID"] as? String)
            let (plan, donem) = try XCTUnwrap(Plan.match(productId: id))
            XCTAssertEqual(urun["recurringSubscriptionPeriod"] as? String,
                           donem == .monthly ? "P1M" : "P1Y", id)
            let hedef = try XCTUnwrap(donem == .monthly ? plan.monthlyPrice : plan.yearlyPrice)
            let fiyat = try XCTUnwrap(Decimal(string: urun["displayPrice"] as? String ?? ""))
            XCTAssertEqual(fiyat, Decimal(hedef.raw) / 100, "\(id): yapılandırma fiyatı katalogdan farklı")
            // Aile Paylaşımı KAPALI: bir kez açılınca App Store Connect'te geri alınamıyor.
            XCTAssertEqual(urun["familyShareable"] as? Bool, false, id)
            // Grup düzeyi: 1 = en üst. Büyük paket küçük sayıda olmalı ki
            // geçiş Apple'da "yükseltme" (hemen) sayılsın.
            let duzey = try XCTUnwrap(urun["groupNumber"] as? Int)
            XCTAssertEqual(duzey, Plan.purchasable.count - Plan.purchasable.firstIndex(of: plan)!, id)
        }
    }

    // MARK: - 4. Gerçek StoreKit (SKTestSession)
    //
    // KOMUT SATIRINDA ATLANABİLİR, XCODE İÇİNDE KOŞAR. `xcodebuild test`
    // şemanın `.storekit` yapılandırmasını simülatördeki StoreKit hizmetine
    // aktarmıyor (Apple forumu 826971; 25 Eki'de iOS 26.4 simülatöründe
    // görüldü: "not installed for development", oturum komutları
    // `SKInternalErrorDomain 3`). O ortamda bu testler YANLIŞ YEŞİL vermesin
    // diye gerekçesiyle ATLANIYOR; Xcode'dan (⌘U) çalıştırınca tam koşuyor.
    //
    // Satın alma OTURUMUN komutuyla yapılıyor (`buyProduct`), uygulamanın
    // `purchase` yolu ile değil: o yol Apple'ın onay penceresini açıyor ve
    // test, dokunacak kimse olmadığı için sonsuza kadar bekliyordu.
    // `purchase` yolunun kendisi sahte mağazayla (yukarıda) ve 25 Eki'de
    // simülatörde elle denendi: pencere "Şantiye · Aylık" ürününü gösterdi,
    // satın alma "You're all set" ile tamamlandı.

    private static let cliNotu = "StoreKit yapılandırması bu ortamda simülatöre aktarılmadı "
        + "(xcodebuild bilinen sorunu) — Xcode içinden ⌘U ile çalıştır"

    private func oturum() throws -> SKTestSession {
        let s = try SKTestSession(contentsOf: yapilandirmaURL)
        s.resetToDefaultState()
        s.disableDialogs = true
        s.clearTransactions()
        return s
    }

    private func satinAl(_ s: SKTestSession, _ id: String) async throws {
        do {
            if #available(iOS 17.0, *) {
                _ = try await s.buyProduct(identifier: id, options: [])
            } else {
                try s.buyProduct(productIdentifier: id)
            }
        } catch {
            throw XCTSkip("\(Self.cliNotu) (\(error))")
        }
    }

    /// Altı ürün mağazadan geliyor ve doğru pakete/döneme bağlanıyor.
    func testGercekMagazaAltiUrunuYukluyor() async throws {
        let s = try oturum()
        defer { s.clearTransactions() }
        let teklifler = try await AppStoreSubscriptionStore().loadOffers()
        try XCTSkipIf(teklifler.isEmpty, Self.cliNotu)
        XCTAssertEqual(teklifler.count, 6)
        for t in teklifler {
            XCTAssertEqual(Plan.match(productId: t.id)?.plan, t.plan)
            XCTAssertFalse(t.displayPrice.isEmpty)
        }
    }

    /// İşlem → hak zinciri gerçek StoreKit'te: satın al → paket; süre dolar
    /// → ücretsiz katman; yükselt → büyük paket.
    func testGercekMagazaIslemdenHak() async throws {
        let s = try oturum()
        defer { s.clearTransactions() }
        let magaza = AppStoreSubscriptionStore()
        let teklifler = try await magaza.loadOffers()
        try XCTSkipIf(teklifler.isEmpty, Self.cliNotu)

        let santiye = Plan.santiye.monthlyProductId!
        try await satinAl(s, santiye)
        let alininca = await magaza.currentRecords()
        XCTAssertEqual(EntitlementResolver.resolve(alininca), .plan(.santiye))

        try await satinAl(s, Plan.kurumsal.monthlyProductId!)
        let yukselince = await magaza.currentRecords()
        XCTAssertEqual(EntitlementResolver.resolve(yukselince), .plan(.kurumsal))

        try s.expireSubscription(productIdentifier: Plan.kurumsal.monthlyProductId!)
        try s.expireSubscription(productIdentifier: santiye)
        let dolunca = await magaza.currentRecords()
        XCTAssertEqual(EntitlementResolver.resolve(dolunca), .free,
                       "süresi dolan abonelik hâlâ hak veriyor")
    }
}
