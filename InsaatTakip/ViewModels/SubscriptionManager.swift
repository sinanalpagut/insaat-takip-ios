import Foundation
import StoreKit
import UIKit

// MARK: - Abonelik durumu (madde 87/c)
//
// `ProjectViewModel`den AYRI: o 4.000 satırı aşan bir veri modeli ve mağaza
// onun işi değil. Buradan çıkan tek şey `entitlement`; görünüm modeli onu
// kota ve yazma kilidi için okuyor (bağlantı `InsaatTakipApp`te, tek satır).

@MainActor
final class SubscriptionManager: ObservableObject {

    /// Kullanıcının hakkı. Açılışta `.resolving` (sınır yok) — gerekçesi
    /// `Entitlement.resolving`ta.
    @Published private(set) var entitlement: Entitlement

    /// Ekrandaki abonelik satırı (yenilenme tarihi, iptal, ödeme sorunu).
    @Published private(set) var status: ActiveSubscription?

    enum OffersState: Equatable { case idle, loading, loaded, failed }
    @Published private(set) var offers: [StoreOffer] = []
    @Published private(set) var offersState: OffersState = .idle

    /// Uçuştaki satın alma — düğmeler kilitli, ikinci dokunuş yok sayılıyor.
    @Published private(set) var purchasingId: String?
    @Published private(set) var restoring = false

    private let store: SubscriptionStore
    /// DEBUG `-plan` argümanı: hak SABİT, mağaza hakkı değiştiremez.
    private let override: Entitlement?
    private var listener: Task<Void, Never>?

    init(store: SubscriptionStore, override: Entitlement? = nil) {
        self.store = store
        self.override = override
        self.entitlement = override ?? .resolving
    }

    deinit { listener?.cancel() }

    /// Uygulama açılır açılmaz çağrılmalı: Apple, uygulama kapalıyken
    /// tamamlanan işlemleri (yenileme, onaylanan "Satın Almak İçin Sor")
    /// `Transaction.updates`ten veriyor ve dinleyen yoksa o işlem askıda kalır.
    func start() {
        guard listener == nil else { return }
        listener = store.observe { [weak self] in await self?.refresh() }
    }

    var canMakePayments: Bool { store.canMakePayments }

    func refresh() async {
        let records = await store.currentRecords()
        if override == nil { entitlement = EntitlementResolver.resolve(records) }
        status = await store.status()
    }

    func loadOffers() async {
        guard offersState != .loading else { return }
        offersState = .loading
        do {
            offers = try await store.loadOffers()
            // Boş liste HATA: ürünler App Store Connect'te yoksa ya da
            // onaylanmadıysa StoreKit sessizce boş döner. Fiyatsız kartı
            // "yüklendi" saymak kişiyi düğmesiz bir ekranda bırakırdı.
            offersState = offers.isEmpty ? .failed : .loaded
            // Durum satırı ürünler üzerinden okunuyor; şimdi okunabilir.
            status = await store.status()
        } catch {
            Diag.log("store.offers", error)
            offersState = .failed
        }
    }

    func offer(_ plan: Plan, _ period: BillingPeriod) -> StoreOffer? {
        offers.first { $0.plan == plan && $0.period == period }
    }

    enum PurchaseOutcome: Equatable {
        case purchased(Plan)
        case pending
        case cancelled
        case failed(PurchaseFailure)
        /// Başka bir işlem sürüyor.
        case busy
    }

    func purchase(_ offer: StoreOffer, uid: String?) async -> PurchaseOutcome {
        guard purchasingId == nil, !restoring else { return .busy }
        purchasingId = offer.id
        defer { purchasingId = nil }
        do {
            let token = uid.map(EntitlementResolver.accountToken(for:))
            switch try await store.purchase(offer.id, accountToken: token) {
            case .purchased:
                await refresh()
                // Hak YENİDEN OKUNARAK söyleniyor, satın alınan ürüne göre
                // değil: düşürme dönem sonunda geçerli olur ve "Şantiye'ye
                // geçtin" demek o an yanlış olurdu.
                if case .plan(let plan) = entitlement { return .purchased(plan) }
                return .purchased(offer.plan)
            case .pending:   return .pending
            case .cancelled: return .cancelled
            }
        } catch {
            if PurchaseFailure.isCancellation(error) { return .cancelled }
            Diag.log("store.purchase", error)
            return .failed(.from(error))
        }
    }

    enum RestoreOutcome: Equatable {
        case restored(Plan)
        case nothingFound
        case cancelled
        case failed(PurchaseFailure)
        case busy
    }

    func restore() async -> RestoreOutcome {
        guard !restoring, purchasingId == nil else { return .busy }
        restoring = true
        defer { restoring = false }
        do {
            try await store.sync()
        } catch {
            if PurchaseFailure.isCancellation(error) { return .cancelled }
            Diag.log("store.sync", error)
            return .failed(.from(error))
        }
        await refresh()
        if case .plan(let plan) = entitlement, plan != .ucretsiz { return .restored(plan) }
        return .nothingFound
    }

    /// Hesap silmede söylenecek ödeme durumu.
    enum BillingNotice: Equatable {
        case none
        /// Otomatik yenileme açık: ödeme Apple'da sürüyor.
        case continues(Plan)
        /// İptal edilmiş; dönem sonunda biter.
        case cancelled(Plan)
    }

    /// HAKTAN DEĞİL YENİLEME DURUMUNDAN (25 Eki bağımsız inceleme). Ödeme
    /// yeniden denenirken (ek süre dışında) `currentEntitlements` boş ve hak
    /// "ücretsiz" görünüyor, ama otomatik yenileme açık: kart güncellenince
    /// Apple ücret alıyor — silinmiş bir hesap için. Durum okunamadıysa ve
    /// hak ücretliyse TEDBİRLİ cümle: "iptal et" demek, ödeme sürerken
    /// susmaktan ucuz.
    var billingNotice: BillingNotice {
        if let status {
            return status.state == .cancelled ? .cancelled(status.plan) : .continues(status.plan)
        }
        if case .plan(let plan) = entitlement, plan != .ucretsiz { return .continues(plan) }
        return .none
    }

    /// Apple'ın abonelik yönetimi sayfası — iptal, dönem ve paket değişikliği.
    ///
    /// Uygulamada iptal düğmesi YOK ve olmamalı: iptal Apple'da yapılıyor;
    /// kendi düğmemiz ancak oraya götürebilir. Sayfa açılamazsa aynı yere
    /// giden bağlantı açılıyor (Apple'ın hesap silme rehberindeki adres).
    func showManageSubscriptions() async {
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
                await refresh()
                return
            } catch {
                Diag.log("store.manage", error)
            }
        }
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            await UIApplication.shared.open(url)
        }
    }
}
