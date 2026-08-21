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
// `Fmt.makeDate` zaten bu deseni kullanıyor. Gece yarısına sabitlenseydi:
//   (1) yaz saati geçişinde tarih bir gün kayardı (aya ay eklerken gece yarısı
//       23:00'a düşer ve gün geri gider);
//   (2) cihaz saat dilimi farklıysa aynı vade iki kullanıcıda farklı güne
//       düşerdi.
//
// (2)'NİN KAPSAMI SINIRLI, ölçüldü: Türkiye'de (+03) 12:00'ye çapalanan vade
// 09:00 UTC'dir, dolayısıyla koruma UTC+14'ten UTC−07'ye kadar tutuyor;
// UTC−10 ve batısında (Honolulu, Midway) gün yine bir geri kayıyor. Türk
// müteahhit uygulaması için pratikte erişilmez, ama çapa "her saat diliminde
// güvenli" DEĞİL — öyle yazmak yanlış bir güven verirdi.
//
// ÜÇÜNCÜ BİR GEREKÇE DAHA YAZILIYDI: `DateInterval.contains`in iki uçtan
// kapsayıcı olması yüzünden ay sınırındaki vadenin iki döneme birden
// sayılması. O kusur artık kendi katmanında çözülü (`ProjectViewModel.inPeriod`
// yarı açık denetim yapıyor); çapayla telafi edilmesi zaten yanlış katmandı.

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

    /// Bir vadenin mahsup sonrası durumu.
    struct Settlement: Identifiable {
        let installment: Installment
        /// Bu vadeye düşen tahsilat (0 … `installment.amount`).
        let paid: Kurus

        var id: UUID { installment.id }
        var unpaid: Kurus { installment.amount - paid }
        var isSettled: Bool { unpaid == .zero }
        var isPartial: Bool { paid > .zero && unpaid > .zero }

        /// Vadesi geçmiş VE kapanmamış mı — gün düzeyinde.
        func isOverdue(today: Date = Date()) -> Bool {
            guard !isSettled else { return false }
            return Fmt.calendar.startOfDay(for: installment.dueDate)
                < Fmt.calendar.startOfDay(for: today)
        }
    }

    /// FIFO mahsup: toplam tahsilatı vadelere sırayla dağıtır.
    ///
    /// TEK KAYNAK. Aynı döngü önce `status(for:collected:today:)` içinde, sonra
    /// `ReminderScheduler.reschedule` içinde ikinci kez yazılmıştı; ödeme planı
    /// ekranı üçüncüsünü gerektirecekti. Üç kopya, birinin değişip diğerlerinin
    /// kalması demek — ve bu mantık "hangi taksit kapandı" sorusunun TEK
    /// cevabı olduğu için ayrışması sessiz bir tutarsızlık üretirdi.
    ///
    /// `collected` dairenin TOPLAM tahsilatı (`Apartment.paidAmount`); ödeme
    /// kayıtlarında hangi taksidi kapattığı yazılı olmadığı için (bkz. yukarıdaki
    /// FIFO notu) dağıtım sıradan türetiliyor.
    static func settle(_ installments: [Installment], collected: Kurus) -> [Settlement] {
        var remaining = collected
        return installments.sorted { $0.sequence < $1.sequence }.map { item in
            let paid = remaining >= item.amount ? item.amount : remaining
            remaining = remaining - paid
            return Settlement(installment: item, paid: paid)
        }
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
        var overdue = Kurus.zero
        var oldestOverdue: Date?
        var next: Installment?

        // Mahsup `settle`den geliyor — döngü burada TEKRAR YAZILMIYOR.
        for row in settle(plan, collected: collected) where !row.isSettled {
            if next == nil { next = row.installment }
            let dueDay = Fmt.calendar.startOfDay(for: row.installment.dueDate)
            if dueDay < startOfToday {
                overdue = overdue + row.unpaid
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
    /// Taksitler `Kurus.split(_:into:)` ile EŞİT bölünüyor: toplamları bedele
    /// birebir eşit VE aralarındaki fark en fazla 1 kuruş. İki güvence ayrı
    /// ayrı gerekli — eski kod toplamı tutturuyor ama eşitliği bozuyordu.
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
        // PLANIN İLK SATIRI `firstDueDate`E DÜŞER. Önceden taksitler koşulsuz
        // `value: index + 1` ile üretiliyordu, yani peşinat YOKKEN kullanıcının
        // DatePicker'da "İlk vade" diye seçtiği tarihe HİÇBİR taksit düşmüyordu:
        // plan bir ay ileri kayıyor, son vade de bir ay sarkıyordu. Parametre
        // adı, ekran etiketi ve özet metni üçü birden o tarihi vaat ederken
        // üretilen veri başka tarih taşıyordu — "yanıltıcı rakam yasak"
        // ilkesinin doğrudan ihlali.
        //
        // Peşinat VARSA ilk satır odur (sequence 0) ve taksitler bir ay sonra
        // başlar; peşinat yoksa ilk satır 1. taksittir. Her iki durumda da
        // satırlar `firstDueDate`ten başlayıp birer ay arayla ilerliyor.
        let hasDownPayment = downPayment > .zero
        if downPayment > .zero {
            result.append(Installment(id: UUID(), projectId: projectId,
                                      apartmentId: apartmentId, sequence: 0,
                                      dueDate: firstDueDate, amount: downPayment))
        }

        let rest = price - downPayment
        // EŞİT bölme — yüzde ÜZERİNDEN DEĞİL. Önceden burada
        // `byPercents: Array(repeating: 100 / count, ...)` vardı; `100 / count`
        // tam sayı bölmesi olduğu için 12 taksitte yüzdeler toplamı 96 çıkıyor,
        // eksik kalan %4 de "kalanı sona ekle" telafisiyle SON taksite biniyordu.
        // Sonuç: 12 taksitte son taksit %50, 36 taksitte 15 KAT şişkin. Toplam
        // her zaman bedele eşit çıktığı için ekranda hiçbir şey yanlış
        // görünmüyordu; bozulan şey taksitlerin eşitliğiydi.
        let amounts = Kurus.split(rest, into: count)

        for index in 0..<count {
            let monthOffset = hasDownPayment ? index + 1 : index
            let due = Fmt.calendar.date(byAdding: .month, value: monthOffset,
                                        to: firstDueDate) ?? firstDueDate
            result.append(Installment(id: UUID(), projectId: projectId,
                                      apartmentId: apartmentId,
                                      sequence: index + 1,
                                      dueDate: due, amount: amounts[index]))
        }
        return result
    }
}
