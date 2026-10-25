import Foundation
import StoreKit
import CryptoKit

// MARK: - Abonelik (madde 87/c · 25 Eki 2026)
//
// NEDEN ŞİMDİ: 1.0 (169) 2.1(b) ile reddedildi — uygulama paket fiyatlarını
// gösteriyor ama App Store Connect'te tek bir satın alma ürünü yoktu. Yayında
// kullanıcı olmadığı için iki yoldan ödemeyi ilk sürüme bağlamak seçildi:
// fiyatı gizleyip sonradan sınır koymak, sınırsız kullanmış birinden bir şey
// geri almak olurdu.
//
// DOĞRULAMA CİHAZDA, SUNUCUDA DEĞİL. Kota bilerek istemcide (`Quota.swift`
// karar notu) ve App Check zorlamada olduğu için değiştirilmiş bir uygulama
// Firestore'a zaten yazamıyor. StoreKit 2 her işlemi Apple imzasıyla
// (`VerificationResult`) cihazda doğruluyor; imzasız işlem hak vermiyor.
// Sunucu ancak Android/web iOS'ta alınan aboneliği tanımak zorunda kaldığında
// gerekecek — o gün `appAccountToken` köprü olacak (aşağıda).
//
// HAK APPLE KİMLİĞİNE BAĞLI, UYGULAMA HESABINA DEĞİL. Hakkı Firebase uid'ine
// bağlamak hesabını silip aynı numarayla yeniden açan kişiyi, App Store'da
// ödemeye devam ettiği hâlde hakkı tanınmayan bir yere düşürürdü — ve Apple
// "satın alımları geri yükle"nin çalışmasını istiyor. Bedeli: aynı Apple
// Kimliğini paylaşan iki hesap aynı paketi görür. Bu üründe nadir ve zararı
// ödeyenin aleyhine değil.
//
// SATIN ALMA VERİSİ BİZE GELMİYOR: işlemler cihaz ile Apple arasında kalıyor,
// sunucuya yazılmıyor. App Privacy beyanı bu yüzden değişmedi; değişirse
// (sunucu kopyası) "Purchases" türü eklenmeli.

/// Abonelik dönemi.
enum BillingPeriod: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String { self == .monthly ? "Aylık" : "Yıllık" }

    /// Fiyatın yanındaki birim: "749,99 ₺/ay".
    var unit: String { self == .monthly ? "ay" : "yıl" }
}

extension Plan {
    /// Ürün kimliği — kaynağı `monthlyProductId`/`yearlyProductId`.
    func productId(_ period: BillingPeriod) -> String? {
        period == .monthly ? monthlyProductId : yearlyProductId
    }

    /// Mağazadan gelen kimliği pakete ve döneme çevirir. Tanınmayan kimlik
    /// `nil`: başka bir ürüne hak vermek, kişinin ödemediği bir şeyi açmak olur.
    static func match(productId: String) -> (plan: Plan, period: BillingPeriod)? {
        for plan in purchasable {
            for period in BillingPeriod.allCases where plan.productId(period) == productId {
                return (plan, period)
            }
        }
        return nil
    }

    /// Satın alınabilir bütün ürün kimlikleri.
    static var allProductIds: [String] {
        purchasable.flatMap { plan in BillingPeriod.allCases.compactMap { plan.productId($0) } }
    }

    /// Paket büyüklüğü — iki geçerli abonelik yan yana dururken (yükseltme
    /// anı, eski ve yeni dönem) BÜYÜK olan kazanır.
    var rank: Int { Plan.allCases.firstIndex(of: self) ?? 0 }
}

/// Mağazadaki satın alınabilir ürün — StoreKit `Product`ının test edilebilir
/// izdüşümü.
///
/// FİYAT MAĞAZADAN, KATALOGDAN DEĞİL. `Plan.monthlyPrice` App Store Connect'e
/// girilecek HEDEF; ekranda gösterilen ve tahsil edilen tutar Apple'ın
/// `displayPrice`ı. Kişinin mağaza bölgesi Türkiye değilse fiyat o ülkenin
/// parasıyla geliyor — katalogdaki lira o kişiye yanlış olurdu.
struct StoreOffer: Identifiable, Equatable {
    let id: String
    let plan: Plan
    let period: BillingPeriod
    /// Apple'ın biçimlediği fiyat ("749,99 ₺") — ekrandaki tek fiyat kaynağı.
    let displayPrice: String
    /// Karşılaştırma için sayısal değer (yıllık tasarruf hesabı).
    let price: Decimal
    /// App Store Connect'te tanıtım teklifi tanımlıysa ve kişi uygunsa
    /// açıklaması ("İlk 1 ay ücretsiz"). Kod teklif uydurmuyor; yalnızca
    /// mağaza ne diyorsa onu söylüyor.
    let introOffer: String?
}

/// Hak kararının girdisi — StoreKit `Transaction`ının özü.
struct EntitlementRecord: Equatable {
    let productId: String
    let revocationDate: Date?
    /// Aynı grupta daha üst bir pakete geçilince eski işlem `isUpgraded`.
    let isUpgraded: Bool
}

/// Etkin aboneliğin ekranda söylenecek hâli.
struct ActiveSubscription: Equatable {
    enum State: Equatable {
        /// Dönem sonunda yenilenecek.
        case renewing
        /// İptal edildi; dönem sonunda bitecek.
        case cancelled
        /// Ödeme alınamadı, Apple tekrar deniyor. Ek süre (grace period)
        /// açıksa hak sürüyor — kişiye ödeme bilgisini güncellemesi söylenmeli.
        case billingIssue
    }
    let plan: Plan
    let period: BillingPeriod
    let state: State
    let expiresAt: Date?
    /// Dönem sonunda geçilecek paket (düşürme bekliyorsa).
    let nextPlan: Plan?
}

enum EntitlementResolver {
    /// Geçerli işlemlerden EN BÜYÜK paket; yoksa ücretsiz katman.
    ///
    /// SÜRE TARİHİNE BAKILMIYOR. `Transaction.currentEntitlements` yalnızca
    /// "subscribed" ve "inGracePeriod" durumundaki abonelikleri veriyor;
    /// ödeme ek süresindeki işlemin bitiş tarihi GEÇMİŞTE olabilir. Burada
    /// tarihe bakmak, kartı yenilenmeyi bekleyen ödeyen kişiyi tam Apple'ın
    /// ona süre tanıdığı anda kilitlemek olurdu. Hangi işlemin geçerli
    /// olduğuna Apple karar veriyor; bu fonksiyon yalnızca paketi seçiyor.
    ///
    /// İptal/iade edilmiş işlem Apple'ın belgesine göre zaten gelmiyor; yine
    /// de `revocationDate` dolu olan atılıyor — iade edilmiş bir ödemeye hak
    /// vermek, savunmasız bırakılmayacak kadar pahalı bir hata.
    static func resolve(_ records: [EntitlementRecord]) -> Entitlement {
        let plans = records
            .filter { $0.revocationDate == nil && !$0.isUpgraded }
            .compactMap { Plan.match(productId: $0.productId)?.plan }
        guard let best = plans.max(by: { $0.rank < $1.rank }) else { return .free }
        return .plan(best)
    }

    /// Uygulama hesabını Apple'a göstermeden bağlayan işaret.
    ///
    /// Satın almaya `appAccountToken` olarak ekleniyor ve Apple onu her
    /// yenilemede geri veriyor. Bugün HAK KARARINDA KULLANILMIYOR (yukarıdaki
    /// gerekçe); işi, bir gün sunucu bildirimleri geldiğinde ödemeyi hesaba
    /// bağlayabilmek. Uid'in kendisi değil, ondan TÜRETİLEN bir UUID: Apple
    /// hesabın kimliğini görmüyor, tersine çevrilemiyor ve aynı uid her
    /// cihazda aynı işareti üretiyor.
    static func accountToken(for uid: String) -> UUID {
        var b = Array(SHA256.hash(data: Data("insaattakip.appAccountToken:\(uid)".utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x80   // sürüm 8 (uygulamaya özgü)
        b[8] = (b[8] & 0x3F) | 0x80   // RFC 4122 varyantı
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

// MARK: - Mağaza

enum PurchaseResult: Equatable {
    case purchased
    /// Onay bekliyor: Aile Paylaşımı'nda "Satın Almak İçin Sor" ya da banka
    /// doğrulaması. Hak, onay gelince `Transaction.updates` ile açılıyor.
    case pending
    case cancelled
}

/// Satın alma ve geri yüklemenin kullanıcıya söylenecek hataları.
enum PurchaseFailure: Error, Equatable {
    case network
    /// Ekran Süresi ya da cihaz yönetimi satın almayı kapatmış.
    case notAllowed
    /// Ürün bu mağaza bölgesinde yok ya da mağazadan yüklenemedi.
    case unavailable
    /// Apple imzası doğrulanamadı — hak VERİLMEDİ.
    case verification
    case unknown

    var title: String {
        switch self {
        case .network:      return "Bağlantı yok"
        case .notAllowed:   return "Satın alma kapalı"
        case .unavailable:  return "Paket şu an alınamıyor"
        case .verification: return "Satın alma doğrulanamadı"
        case .unknown:      return "Satın alma tamamlanamadı"
        }
    }

    var message: String {
        switch self {
        case .network:
            return "App Store'a ulaşılamadı. Bağlantını kontrol edip tekrar dene; ücret alınmadı."
        case .notAllowed:
            return "Bu cihazda uygulama içi satın alma kapalı. Ayarlar → Ekran Süresi → "
                 + "İçerik ve Gizlilik Sınırlamaları'ndan açılabilir."
        case .unavailable:
            return "Paket App Store'dan yüklenemedi. Biraz sonra tekrar dene."
        case .verification:
            return "Apple'dan gelen işlem doğrulanamadığı için paket açılmadı. Ücret alındıysa "
                 + "\"Satın alımları geri yükle\" ile tekrar dene."
        case .unknown:
            return "App Store işlemi tamamlamadı. Ücret alındıysa \"Satın alımları geri yükle\" "
                 + "ile tekrar dene."
        }
    }

    /// StoreKit hatasını kullanıcı diline çevirir. Vazgeçme hata değil;
    /// çağıran onu ayrıca ele alıyor.
    static func from(_ error: Error) -> PurchaseFailure {
        if let e = error as? PurchaseFailure { return e }
        if let e = error as? StoreKitError {
            switch e {
            case .networkError:             return .network
            case .notAvailableInStorefront: return .unavailable
            default:                        return .unknown
            }
        }
        if let e = error as? Product.PurchaseError {
            switch e {
            case .purchaseNotAllowed:  return .notAllowed
            case .productUnavailable:  return .unavailable
            default:                   return .unknown
            }
        }
        if (error as NSError).domain == NSURLErrorDomain { return .network }
        return .unknown
    }

    /// Kullanıcı vazgeçti mi — hata olarak gösterilmemeli.
    static func isCancellation(_ error: Error) -> Bool {
        if let e = error as? StoreKitError, case .userCancelled = e { return true }
        return false
    }
}

/// Mağazanın uygulamaya bakan yüzü. Gerçeği `AppStoreSubscriptionStore`;
/// testler ve DEBUG gösterim için sahtesi var.
@MainActor
protocol SubscriptionStore: AnyObject {
    func loadOffers() async throws -> [StoreOffer]
    func currentRecords() async -> [EntitlementRecord]
    func status() async -> ActiveSubscription?
    func purchase(_ offerId: String, accountToken: UUID?) async throws -> PurchaseResult
    /// "Satın alımları geri yükle" — Apple Kimliğiyle eşitleme.
    func sync() async throws
    var canMakePayments: Bool { get }
    /// Uygulama dışından gelen değişiklikleri (yenileme, iade, onaylanan
    /// "Satın Almak İçin Sor") dinler.
    func observe(_ onChange: @escaping @MainActor () async -> Void) -> Task<Void, Never>
}

/// StoreKit 2 ile gerçek mağaza.
@MainActor
final class AppStoreSubscriptionStore: SubscriptionStore {
    private var products: [String: Product] = [:]

    var canMakePayments: Bool { AppStore.canMakePayments }

    func loadOffers() async throws -> [StoreOffer] {
        let loaded = try await Product.products(for: Plan.allProductIds)
        for p in loaded { products[p.id] = p }
        var offers: [StoreOffer] = []
        for product in loaded {
            guard let (plan, period) = Plan.match(productId: product.id) else { continue }
            offers.append(StoreOffer(id: product.id, plan: plan, period: period,
                                     displayPrice: product.displayPrice, price: product.price,
                                     introOffer: await Self.introText(product)))
        }
        return offers.sorted { ($0.plan.rank, $0.period.rawValue) < ($1.plan.rank, $1.period.rawValue) }
    }

    /// Tanıtım teklifi YALNIZCA kişi uygunsa söyleniyor: daha önce deneme
    /// kullanmış birine "ilk ay ücretsiz" demek, ilk faturada yalana döner.
    private static func introText(_ product: Product) async -> String? {
        guard let sub = product.subscription, let offer = sub.introductoryOffer,
              await sub.isEligibleForIntroOffer else { return nil }
        let sure = periodText(offer.period, count: offer.periodCount)
        switch offer.paymentMode {
        case .freeTrial: return "İlk \(sure) ücretsiz"
        default:         return "İlk \(sure) \(offer.displayPrice)"
        }
    }

    private static func periodText(_ p: Product.SubscriptionPeriod, count: Int) -> String {
        let n = p.value * max(count, 1)
        switch p.unit {
        case .day:   return "\(n) gün"
        case .week:  return "\(n) hafta"
        case .month: return "\(n) ay"
        case .year:  return "\(n) yıl"
        @unknown default: return "\(n) dönem"
        }
    }

    func currentRecords() async -> [EntitlementRecord] {
        var records: [EntitlementRecord] = []
        for await result in Transaction.currentEntitlements {
            // İMZASIZ İŞLEM HAK VERMİYOR — sahte ya da bozuk kayıt olabilir.
            guard case .verified(let tx) = result, tx.productType == .autoRenewable else { continue }
            records.append(EntitlementRecord(productId: tx.productID,
                                             revocationDate: tx.revocationDate,
                                             isUpgraded: tx.isUpgraded))
        }
        return records
    }

    func status() async -> ActiveSubscription? {
        // Grup durumu herhangi bir ürün üzerinden okunuyor. Ürünler henüz
        // yüklenmediyse yükleniyor: hesap silme uyarısı bu duruma bakıyor ve
        // paket ekranı hiç açılmamış olabilir. Ağ yoksa durum boş kalır,
        // hak kararı etkilenmez.
        if products.isEmpty, let loaded = try? await Product.products(for: Plan.allProductIds) {
            for p in loaded { products[p.id] = p }
        }
        guard let product = products.values.first,
              let statuses = try? await product.subscription?.status else { return nil }
        var best: ActiveSubscription?
        for s in statuses {
            guard case .verified(let tx) = s.transaction,
                  case .verified(let renewal) = s.renewalInfo,
                  let (plan, period) = Plan.match(productId: tx.productID) else { continue }
            let state: ActiveSubscription.State
            switch s.state {
            case .subscribed:
                state = renewal.willAutoRenew ? .renewing : .cancelled
            case .inGracePeriod, .inBillingRetryPeriod:
                state = .billingIssue
            default:
                continue   // süresi dolmuş ya da iade edilmiş: gösterilecek abonelik yok
            }
            let next = renewal.autoRenewPreference.flatMap { Plan.match(productId: $0)?.plan }
            let durum = ActiveSubscription(plan: plan, period: period, state: state,
                                           expiresAt: tx.expirationDate,
                                           nextPlan: next == plan ? nil : next)
            if best == nil || plan.rank > best!.plan.rank { best = durum }
        }
        return best
    }

    func purchase(_ offerId: String, accountToken: UUID?) async throws -> PurchaseResult {
        let product: Product
        if let cached = products[offerId] {
            product = cached
        } else if let fetched = try await Product.products(for: [offerId]).first {
            products[offerId] = fetched
            product = fetched
        } else {
            throw PurchaseFailure.unavailable
        }
        var options: Set<Product.PurchaseOption> = []
        if let accountToken { options.insert(.appAccountToken(accountToken)) }

        switch try await product.purchase(options: options) {
        case .success(let verification):
            guard case .verified(let tx) = verification else {
                // İmzasız: hak verilmiyor ve işlem BİTİRİLMİYOR — StoreKit onu
                // bir sonraki açılışta yeniden sunsun.
                throw PurchaseFailure.verification
            }
            await tx.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func observe(_ onChange: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        Task {
            // Uygulama kapalıyken tamamlanmış ama bitirilmemiş işlemler önce.
            for await result in Transaction.unfinished {
                if case .verified(let tx) = result { await tx.finish() }
            }
            await onChange()
            for await result in Transaction.updates {
                if case .verified(let tx) = result { await tx.finish() }
                await onChange()
            }
        }
    }
}

#if DEBUG
/// Ekran görüntüsü ve elle deneme için sahte mağaza (`-store fake`).
///
/// Simülatöre `simctl` ile kurulan uygulama Xcode'un StoreKit yapılandırmasını
/// görmüyor; paket ekranının fiyatlı hâli bunsuz hiç açılamıyordu. Fiyatlar
/// `Config/InsaatTakip.storekit` ile aynı olmalı — o dosya App Store
/// Connect'teki fiyatların kopyası.
@MainActor
final class DemoSubscriptionStore: SubscriptionStore {
    private var owned: String?
    var canMakePayments: Bool { true }

    func loadOffers() async throws -> [StoreOffer] {
        Plan.purchasable.flatMap { plan in
            BillingPeriod.allCases.compactMap { period -> StoreOffer? in
                guard let id = plan.productId(period),
                      let fiyat = period == .monthly ? plan.monthlyPrice : plan.yearlyPrice
                else { return nil }
                let tutar = Decimal(fiyat.raw) / 100
                return StoreOffer(id: id, plan: plan, period: period,
                                  displayPrice: Self.appleBicimi(tutar),
                                  price: tutar, introOffer: nil)
            }
        }
    }

    /// StoreKit'in Türkiye mağazasındaki `displayPrice` biçimi ("₺749,99").
    ///
    /// `Fmt.money` DEĞİL: o kuruşu yuvarlıyor ve 749,99 ₺'yi "750 ₺" yazıyordu
    /// — App Review'a giden abonelik görseli bu ekrandan çekiliyor ve hakeme
    /// tahsil edilmeyecek bir tutar göstermiş olurduk (25 Eki'de görüldü).
    private static func appleBicimi(_ tutar: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "tr_TR")
        f.currencyCode = "TRY"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: tutar as NSDecimalNumber) ?? "\(tutar)"
    }

    func currentRecords() async -> [EntitlementRecord] {
        owned.map { [EntitlementRecord(productId: $0, revocationDate: nil, isUpgraded: false)] } ?? []
    }

    func status() async -> ActiveSubscription? {
        guard let owned, let (plan, period) = Plan.match(productId: owned) else { return nil }
        return ActiveSubscription(plan: plan, period: period, state: .renewing,
                                  expiresAt: Date().addingTimeInterval(30 * 86_400), nextPlan: nil)
    }

    func purchase(_ offerId: String, accountToken: UUID?) async throws -> PurchaseResult {
        owned = offerId
        return .purchased
    }

    func sync() async throws {}

    func observe(_ onChange: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        Task { await onChange() }
    }
}
#endif
