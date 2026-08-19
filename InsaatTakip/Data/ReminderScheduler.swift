import UserNotifications

// MARK: - Vade hatırlatıcı (madde 21)
//
// Projedeki İLK yerel bildirim yüzeyi ve ilk izin akışı.
//
// ═══ NEDEN SUNUCU PUSH'U DEĞİL ═══
// Sunucu push'u zamanlanmış Cloud Function + kullanıcı başına FCM jetonu +
// jeton koleksiyonu + güvenlik kuralı + emülatör testi demek; maddenin
// kapsamını ikiye katlardı. Asıl ihtiyaç müteahhidin KENDİ telefonunun onu
// uyarması ve yerel bildirim bunu karşılıyor. FirebaseAuth
// `UNUserNotificationCenter`'a hiç dokunmuyor, dolayısıyla telefon girişini
// bozma riski de yok.
//
// ═══ 64 BİLDİRİM SINIRI ═══
// iOS uygulama başına en çok 64 BEKLEYEN yerel bildirim tutuyor; fazlası
// SESSİZCE atılıyor. Taksit başına bildirim kurulsaydı 12 daire × 12 taksit =
// 144 istek olurdu ve iOS bunların 80'ini hiç kurmadan çöpe atardı —
// kullanıcı da hangi vadelerin hatırlatılacağını asla bilemezdi. Bu, projede
// baştan beri reddedilen sessiz kırpma sınıfının ta kendisi.
//
// Çözüm: GÜNE GÖRE TOPLAMA. Aynı gün vadesi gelen daireler tek bildirimde
// birleşiyor ("3 dairenin taksidi bugün · toplam 742.500 ₺"). Hem istek
// sayısı 64'ün çok altına iniyor hem de kullanıcı arka arkaya on kez
// titreşmiyor.

@MainActor
final class ReminderScheduler {

    /// Kurulacak en fazla gün sayısı. 64'lük sistem sınırının belirgin
    /// altında: kalan pay, ileride başka bildirim türü eklenirse yer kalsın.
    private static let maxDays = 30

    /// Bildirim saati — sabah 09:00. Vade öğlen 12:00'e sabitli (bkz.
    /// Installment), hatırlatma ondan önce gelmeli ki kullanıcının günü var.
    private static let hour = 9

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Kullanıcının bildirim izni durumu.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// İzin ister. Zaten karar verilmişse yeniden SORMAZ — iOS ikinci kez
    /// diyalog göstermiyor ve sormak sessiz bir hayır üretirdi.
    ///
    /// İzin İLK PLAN KURULDUĞUNDA isteniyor, açılışta değil: açılışta
    /// sorulsaydı FirebaseAuth'un kendi APNs kaydıyla üst üste gelir ve
    /// kullanıcı SMS beklerken "İzin Verme"ye basardı.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Bekleyen vadeler için hatırlatma kurar.
    ///
    /// ÖNCE HEPSİNİ SİLİYOR: plan değişince (bedel düzeltildi, taksit sayısı
    /// değişti, satış iptal edildi) eski hatırlatmalar bellekte kalırdı ve
    /// kullanıcı artık var olmayan bir vade için uyarı alırdı. Yeniden kurmak
    /// tek tutarlı yol.
    func reschedule(installments: [Installment], apartments: [Apartment],
                    collectedByApartment: [UUID: Kurus]) async {
        center.removeAllPendingNotificationRequests()

        guard await authorizationStatus() != .denied else { return }

        // Kapanmamış vadeler: her daire için FIFO mahsuptan sonra kalanlar.
        var pending: [(due: Date, apartmentNumber: Int, amount: Kurus)] = []
        let byApartment = Dictionary(grouping: installments, by: \.apartmentId)

        for (apartmentId, plan) in byApartment {
            guard let apartment = apartments.first(where: { $0.id == apartmentId }) else { continue }
            var remaining = collectedByApartment[apartmentId] ?? .zero
            for item in plan.sorted(by: { $0.sequence < $1.sequence }) {
                if remaining >= item.amount {
                    remaining = remaining - item.amount
                    continue
                }
                let unpaid = item.amount - remaining
                remaining = .zero
                // GEÇMİŞ vadeye hatırlatma kurulmaz: iOS geçmiş tarihli
                // tetikleyiciyi zaten atıyor, üstelik gecikmiş tutar ekrandaki
                // listede duruyor.
                if item.dueDate > Date() {
                    pending.append((item.dueDate, apartment.apartmentNumber, unpaid))
                }
            }
        }

        // Güne göre topla — 64 sınırının gerekçesi dosya başında.
        let grouped = Dictionary(grouping: pending) {
            Fmt.calendar.startOfDay(for: $0.due)
        }

        #if DEBUG
        let days = grouped.keys.count
        print("[reminder] \(pending.count) açık vade → \(days) gün, " +
              "kurulacak: \(min(days, Self.maxDays)) (sistem sınırı 64)")
        #endif

        for day in grouped.keys.sorted().prefix(Self.maxDays) {
            guard let items = grouped[day] else { continue }
            let total = items.reduce(Kurus.zero) { $0 + $1.amount }
            let content = UNMutableNotificationContent()
            content.title = "Tahsilat vadesi"
            content.body = items.count == 1
                ? "No \(items[0].apartmentNumber) · \(Fmt.money(total))"
                : "\(items.count) daire · toplam \(Fmt.money(total))"
            content.sound = .default

            var components = Fmt.calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = Self.hour
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "vade-\(day.timeIntervalSince1970)",
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Tüm hatırlatmaları kaldırır (oturum kapatma).
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
