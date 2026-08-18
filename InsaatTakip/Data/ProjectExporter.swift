import Foundation

// MARK: - Dışa aktarma (madde 26)
//
// Bugünkü tek çıktı tek sayfalık PDF (ReportView.exportPDF). Mali müşavir PDF
// istemiyor, SATIR SATIR veri istiyor — müteahhit bu yüzden paralel Excel
// tutmaya devam ediyor ve uygulamanın varlık sebebiyle çelişiyor.
//
// ═══ TÜRKÇE EXCEL'İN ÜÇ TUZAĞI ═══
//
// 1. AYRAÇ NOKTALI VİRGÜL. Türkçe yerel ayarda ondalık ayracı VİRGÜL olduğu
//    için Excel virgülle ayrılmış dosyayı tek sütuna yapıştırır. Standart
//    "CSV" virgül kullanır ama burada doğru olan `;` — Excel'in tr-TR'de
//    beklediği ayraç bu.
//
// 2. UTF-8 BOM ŞART. BOM olmadan Excel dosyayı Windows-1254 sanıp ş, ğ, İ, ı
//    karakterlerini bozuyor: "Şantiye" → "Ã…Å¾antiye". Üç baytlık işaret
//    (EF BB BF) bunu tek başına çözüyor.
//
// 3. SAYI TÜRKÇE ONDALIKLA. `1234.56` Türkçe Excel'de METİN olarak okunur ve
//    toplama girmez; `1234,56` sayı olur. Binlik ayracı YAZILMIYOR — Excel
//    kendi biçimlendirmesini uygular, biz yazarsak yine metne döner.
//
// ═══ GİZLİLİK ═══
//
// Satış dosyasında ALICI ADI sütunu YALNIZCA yöneticide. Ortakta `buyerName`
// zaten nil geliyor (madde 18: kimlik ayrı belgede), ama sütunun varlığı bile
// karara bağlı: rapor ekranı ortağa açık ve dışa aktarma oradan tetikleniyor.
// Sütun koşulsuz yazılsaydı, Firestore'da kapatılan kimlik ortağın elindeki
// Excel dosyasına düşerdi.

struct ProjectExporter {

    /// Excel'in tr-TR'de beklediği ayraç. Gerekçe yukarıda.
    private static let separator = ";"
    /// UTF-8 işareti — Türkçe karakterler bozulmasın.
    private static let bom = "\u{FEFF}"
    /// Excel satır sonu olarak CRLF bekliyor.
    private static let newline = "\r\n"

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Fmt.locale
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    // MARK: Biçimlendirme

    /// Para: kuruştan liraya, ondalık VİRGÜL, binlik ayracı YOK.
    static func money(_ value: Kurus) -> String {
        let lira = value.raw / 100
        let kurus = abs(value.raw % 100)
        return "\(lira),\(String(format: "%02d", kurus))"
    }

    /// Miktar (kg, m³, torba): ondalık virgül, gereksiz sıfır yok.
    static func quantity(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.2f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    static func date(_ value: Date) -> String { dateFormatter.string(from: value) }

    /// CSV alanı kaçışlama. Ayraç, tırnak ya da satır sonu içeren alan
    /// tırnaklanır; içerideki tırnak ikilenir. Bu olmadan bir açıklamadaki
    /// noktalı virgül sütunları kaydırır ve dosyanın geri kalanı bozulur.
    static func field(_ text: String) -> String {
        guard text.contains(separator) || text.contains("\"") || text.contains("\n")
        else { return text }
        return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func row(_ values: [String]) -> String {
        values.map(field).joined(separator: separator)
    }

    private static func csv(header: [String], rows: [[String]]) -> String {
        bom + ([row(header)] + rows.map(row)).joined(separator: newline) + newline
    }

    // MARK: Tablolar

    static func materialLogsCSV(logs: [MaterialLog], materials: [Material]) -> String {
        let byId = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        let rows = logs.sorted { $0.date > $1.date }.map { log -> [String] in
            let material = byId[log.materialId]
            let total = Kurus.cost(quantity: log.amount, unitPrice: log.unitPrice)
            return [
                date(log.date),
                material?.name ?? "—",
                material?.code ?? "",
                log.type == .entry ? "Giriş" : "Çıkış",
                quantity(log.amount),
                material?.unit ?? "",
                money(log.unitPrice),
                money(total),
                log.note,
                log.user,
            ]
        }
        return csv(header: ["Tarih", "Malzeme", "Kod", "Tür", "Miktar", "Birim",
                            "Birim Fiyat", "Tutar", "Açıklama", "Kaydeden"],
                   rows: rows)
    }

    static func expensesCSV(_ expenses: [Expense]) -> String {
        let rows = expenses.sorted { $0.date > $1.date }.map { expense in
            [date(expense.date), expense.category.rawValue, money(expense.amount),
             expense.payee, expense.note, expense.user]
        }
        return csv(header: ["Tarih", "Kategori", "Tutar", "Ödenen", "Açıklama", "Kaydeden"],
                   rows: rows)
    }

    /// Satışlar. `includeBuyer` YALNIZCA yöneticide true — gerekçe dosya
    /// başındaki GİZLİLİK notunda.
    static func apartmentsCSV(_ apartments: [Apartment], includeBuyer: Bool) -> String {
        let rows = apartments.sorted { $0.apartmentNumber < $1.apartmentNumber }
            .map { apartment -> [String] in
                var values = [
                    String(apartment.apartmentNumber),
                    Apartment.floorLabel(for: apartment.floor),
                    apartment.type,
                    apartment.areaM2.map { quantity($0) } ?? "",
                    apartment.status.label,
                    money(apartment.price),
                    money(apartment.paidAmount),
                    money(max(.zero, apartment.price - apartment.paidAmount)),
                    apartment.saleDate.map(date) ?? "",
                ]
                if includeBuyer { values.append(apartment.buyerName ?? "") }
                return values
            }
        var header = ["Daire No", "Kat", "Tip", "Brüt m²", "Durum", "Bedel",
                      "Tahsil Edilen", "Kalan", "Satış Tarihi"]
        if includeBuyer { header.append("Alıcı") }
        return csv(header: header, rows: rows)
    }

    static func paymentsCSV(_ payments: [Payment], apartments: [Apartment]) -> String {
        let byId = Dictionary(uniqueKeysWithValues: apartments.map { ($0.id, $0) })
        let rows = payments.sorted { $0.date > $1.date }.map { payment in
            [date(payment.date),
             byId[payment.apartmentId].map { String($0.apartmentNumber) } ?? "—",
             money(payment.amount),
             payment.method.rawValue,
             payment.note,
             payment.user]
        }
        return csv(header: ["Tarih", "Daire No", "Tutar", "Yöntem", "Açıklama", "Kaydeden"],
                   rows: rows)
    }

    // MARK: JSON yedeği

    /// Tüm projeyi tek dosyada taşıyan yedek.
    ///
    /// ALICI KİMLİĞİ AYRI DİZİDE. `Apartment.CodingKeys` `buyerName`i bilinçli
    /// olarak dışarıda bırakıyor (madde 18: kimlik `buyers/{apartmentId}`
    /// belgesinde yaşıyor ve ortağın cihazına hiç inmiyor). Yedek o kodlamayı
    /// kullandığı için alıcı adları KENDİLİĞİNDEN düşerdi — ve "yedek" adı
    /// altında eksik bir dosya vermek, kullanıcının veri kaybını fark
    /// etmeyeceği bir yalan olurdu. Bu yüzden yönetici yedeğinde alıcılar
    /// AYRI bir dizide açıkça taşınıyor; ortak yedeğinde dizi boş kalıyor ve
    /// dosyanın kendisi bunu `alıcılarDahil: false` ile söylüyor.
    struct Backup: Codable {
        let surum: Int
        let olusturma: Date
        let aliciDahil: Bool
        let proje: Project
        let malzemeler: [Material]
        let malzemeHareketleri: [MaterialLog]
        let giderler: [Expense]
        let daireler: [Apartment]
        let tahsilatlar: [Payment]
        let ortaklar: [Partner]
        let belgeler: [ProjectDocument]
        let alicilar: [ApartmentBuyer]
        let denetimIzi: [AuditEntry]
    }

    static func backupJSON(_ backup: Backup) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }

    /// JSON yedeğini geçici dizine yazar.
    static func writeData(_ data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: Dosyaya yazma

    /// Geçici dizine yazar ve paylaşılacak URL'i döndürür.
    ///
    /// Ad projeyle birlikte anlamlı: paylaşma sayfasından WhatsApp'a düşen
    /// dosyanın "export.csv" değil "145-Ada-2-Parsel-Giderler.csv" olması
    /// gerekiyor — mali müşavir beş projeden hangisi olduğunu ad'dan anlasın.
    static func write(_ contents: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    /// Dosya adında kullanılamayacak karakterleri temizler.
    static func safeName(_ text: String) -> String {
        text.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}
