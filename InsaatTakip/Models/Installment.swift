import Foundation

// MARK: - Taksit (vade) — madde 21
//
// `Payment` yalnızca GERÇEKLEŞMİŞ ödemeyi tutuyor: para geldi, şu kadar, şu
// tarihte. Beklenen ödeme diye bir kavram yoktu — dolayısıyla "gecikmiş
// tahsilat" sorusu cevaplanamıyordu. `PaymentStatus.taksitli` etiketi vardı
// ama arkasında hiçbir veri yoktu: taksit sayısı, tutarı, vadesi hiçbir yerde
// yazılı değildi. Bu kayıt o boşluğu dolduruyor.
//
// VADE ÖĞLEN 12:00'DE. Gün sınırına 12 saat uzak durmak bilinçli — projede
// `Fmt.makeDate` zaten bu deseni kullanıyor. Gece yarısına sabitlenseydi üç
// ayrı yerden ısırırdı: (1) yaz saati geçişinde tarih bir gün kayar,
// (2) `DateInterval.contains` iki uçtan kapsayıcı olduğu için ay sınırındaki
// vade iki aya birden sayılır ve "bu ay vadesi gelen" toplamı sessizce şişer,
// (3) cihaz saat dilimi farklıysa aynı vade iki kullanıcıda farklı güne düşer.

struct Installment: Codable, Identifiable, Equatable {

    let id: UUID
    /// Firestore yolu için — bkz. MaterialLog.projectId.
    let projectId: UUID
    let apartmentId: UUID

    /// Plandaki sırası: 0 = peşinat, 1..n = taksitler.
    ///
    /// Sıra ÖNEMLİ: hangi ödemenin hangi vadeyi kapattığı bu sırayla
    /// türetiliyor (bkz. aşağıdaki FIFO notu).
    var sequence: Int

    /// Vade tarihi (öğlen 12:00).
    var dueDate: Date

    /// Beklenen tutar.
    var amount: Kurus

    /// Ekranda görünen ad: "Peşinat" / "3. taksit".
    var label: String {
        sequence == 0 ? "Peşinat" : "\(sequence). taksit"
    }

    var dueDateText: String { Fmt.shortDate(dueDate) }
}

// MARK: - Mahsup (hangi ödeme hangi vadeyi kapatıyor)
//
// FIFO — YABANCI ANAHTAR YOK. `Payment`e `installmentId` eklemek ilk bakışta
// daha kesin görünüyor ama sahada yanlış doldurulur: müteahhit parayı geldiği
// gibi giriyor, "bu hangi taksit" sorusunu her seferinde doğru cevaplaması
// beklenemez ve yanlış işaretlenen bir ödeme gecikme listesini sessizce
// bozardı. Bunun yerine TOPLAM tahsilat vadeleri sırayla kapatıyor:
// belirlenimci, yeni alan istemiyor, ve Türkiye'de alacak takibinin fiilî
// mantığı da bu.
//
// Sonuç olarak `Payment` modeline HİÇ dokunulmuyor.

extension Installment {

    /// Bir dairenin vade durumu.
    struct Status {
        /// Vadesi geçmiş ve hâlâ kapanmamış tutar.
        let overdue: Kurus
        /// Gecikmiş en eski vadenin üstünden geçen gün. Gecikme yoksa nil.
        let overdueDays: Int?
        /// Sıradaki kapanmamış vade (gecikmiş olabilir).
        let next: Installment?
        /// Sıradaki vadeye kalan gün — geçmişse negatif. Vade yoksa nil.
        let daysToNext: Int?
    }

    /// Bir dairenin vadelerini toplam tahsilatla karşılaştırır.
    ///
    /// `collected` dairenin TOPLAM tahsilatı (`Apartment.paidAmount`).
    /// Vadeler sırayla kapatılıyor; kapanmayan ilk vade "sıradaki", vadesi
    /// bugünden ÖNCEKİ kapanmamış vadelerin toplamı "gecikmiş".
    ///
    /// Karşılaştırma GÜN düzeyinde: `vade < Date()` yazılsaydı bugün vadesi
    /// olan bir taksit sabah gecikmemiş, akşam gecikmiş görünürdü.
    static func status(for installments: [Installment],
                       collected: Kurus,
                       today: Date = Date()) -> Status {
        let plan = installments.sorted { $0.sequence < $1.sequence }
        guard !plan.isEmpty else {
            return Status(overdue: .zero, overdueDays: nil, next: nil, daysToNext: nil)
        }

        let startOfToday = Fmt.calendar.startOfDay(for: today)
        var remaining = collected
        var overdue = Kurus.zero
        var oldestOverdue: Date?
        var next: Installment?

        for item in plan {
            if remaining >= item.amount {
                remaining = remaining - item.amount
                continue
            }
            // Bu vade kısmen ya da hiç kapanmamış.
            let unpaid = item.amount - remaining
            remaining = .zero
            if next == nil { next = item }

            let dueDay = Fmt.calendar.startOfDay(for: item.dueDate)
            if dueDay < startOfToday {
                overdue = overdue + unpaid
                if oldestOverdue == nil { oldestOverdue = dueDay }
            }
        }

        let overdueDays = oldestOverdue.flatMap {
            Fmt.calendar.dateComponents([.day], from: $0, to: startOfToday).day
        }
        let daysToNext = next.flatMap {
            Fmt.calendar.dateComponents([.day],
                                        from: startOfToday,
                                        to: Fmt.calendar.startOfDay(for: $0.dueDate)).day
        }
        return Status(overdue: overdue, overdueDays: overdueDays,
                      next: next, daysToNext: daysToNext)
    }

    /// Satış bedelinden plan üretir: peşinat + eşit aylık taksitler.
    ///
    /// Kuruş artığı `Kurus.split` ile dağıtılıyor, yani taksitlerin toplamı
    /// bedele BİREBİR eşit — 3 taksite bölünen bir bedelde son taksite kalan
    /// kuruşun eklenmesi gibi sessiz sapmalar olmuyor.
    static func plan(apartmentId: UUID, projectId: UUID,
                     price: Kurus, downPayment: Kurus,
                     count: Int, firstDueDate: Date) -> [Installment] {
        guard count > 0, price > downPayment else {
            guard downPayment > .zero else { return [] }
            return [Installment(id: UUID(), projectId: projectId,
                                apartmentId: apartmentId, sequence: 0,
                                dueDate: firstDueDate, amount: downPayment)]
        }

        var result: [Installment] = []
        if downPayment > .zero {
            result.append(Installment(id: UUID(), projectId: projectId,
                                      apartmentId: apartmentId, sequence: 0,
                                      dueDate: firstDueDate, amount: downPayment))
        }

        let rest = price - downPayment
        let shares = Kurus.split(rest, byPercents: Array(repeating: 100 / count, count: count))
        // `split` yüzde tabanlı; eşit bölmede kalan kuruşu telafi et.
        let distributed = shares.reduce(Kurus.zero, +)
        var amounts = shares
        if distributed != rest, let last = amounts.indices.last {
            amounts[last] = amounts[last] + (rest - distributed)
        }

        for index in 0..<count {
            let due = Fmt.calendar.date(byAdding: .month, value: index + 1,
                                        to: firstDueDate) ?? firstDueDate
            result.append(Installment(id: UUID(), projectId: projectId,
                                      apartmentId: apartmentId,
                                      sequence: index + 1,
                                      dueDate: due, amount: amounts[index]))
        }
        return result
    }
}
