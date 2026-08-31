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
    ///
    /// İŞARET AYRI TUTULUYOR: önceden `lira = raw / 100` yazıyordu ve tam sayı
    /// bölmesi sıfıra doğru kırptığı için −1 ile −99 kuruş arasındaki her değer
    /// lira kısmını 0 yapıyor, `abs` da kuruşu pozitife çeviriyordu — eksi
    /// işareti tamamen kayboluyordu (`-50` → `"0,50"`). Bir zarar rakamı
    /// dışa aktarmada kâra dönüşüyordu.
    static func money(_ value: Kurus) -> String {
        let sign = value.raw < 0 ? "-" : ""
        let magnitude = abs(value.raw)
        return "\(sign)\(magnitude / 100),\(String(format: "%02d", magnitude % 100))"
    }

    /// Miktar (kg, m³, torba): ondalık virgül, gereksiz sıfır yok.
    ///
    /// TAM YAZILIR, 2 ondalığa KIRPILMAZ. Kırpıldığında satır kendi içinde
    /// tutmuyordu: "Tutar" sütunu `Kurus.cost` ile TAM miktardan hesaplanıyor,
    /// dolayısıyla Excel'de `=Miktar*BirimFiyat` yazan müşavir satırdaki
    /// Tutar'ı bulamıyordu (12,345 m³ → "12,35" yazılıp 30.245,25 ₺ ile yan
    /// yana duruyordu). Dışa aktarma bir VERİ dosyası; gösterim kısaltması
    /// ekranın işi, dosyanın değil.
    static func quantity(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        if value == value.rounded() && abs(value) < 1e15 { return String(Int64(value)) }
        // %g gereksiz sıfır bırakmaz; 15 anlamlı hane Double'ın taşıyabildiği
        // her miktarı geri okunabilir biçimde yazar.
        return String(format: "%.15g", value).replacingOccurrences(of: ".", with: ",")
    }

    static func date(_ value: Date) -> String { dateFormatter.string(from: value) }

    /// Sütun başlığına eklenen beyan: " (KDV dahil)". Beyan yoksa ek de yok —
    /// "(belirtilmedi)" başlığı, olmayan bir bilgiyi varmış gibi gösterirdi.
    static func taxSuffix(_ basis: TaxBasis?) -> String {
        guard let basis else { return "" }
        return " (\(basis.label))"
    }

    /// CSV alanı kaçışlama. Ayraç, tırnak ya da satır sonu içeren alan
    /// tırnaklanır; içerideki tırnak ikilenir. Bu olmadan bir açıklamadaki
    /// noktalı virgül sütunları kaydırır ve dosyanın geri kalanı bozulur.
    ///
    /// SATIR SONU `unicodeScalars` ÜZERİNDEN aranıyor: Swift'te `"\r\n"` TEK
    /// grapheme kümesidir, dolayısıyla `text.contains("\n")` CRLF içeren bir
    /// metinde **false** döner. Excel'den kopyalanmış iki satırlık bir açıklama
    /// (Excel CRLF kullanır) tırnaklanmadan yazılıyordu: satır ikiye bölünüyor
    /// ve o noktadan sonraki BÜTÜN sütunlar kayıyordu. Yalnız `\r` de
    /// (klasik Mac satır sonu) aynı sebeple kaçırılıyordu.
    static func field(_ text: String) -> String {
        guard text.contains(separator) || text.contains("\"")
                || text.unicodeScalars.contains(where: { $0 == "\n" || $0 == "\r" })
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

    /// Malzeme hareketleri.
    ///
    /// DEVİR SATIRLARI ŞART: ekrandaki "Malzeme gideri" `Material.accruedCost`
    /// üzerinden geliyor ve o `openingCost + fişler` diye tanımlı. Bu dosya
    /// yalnızca `logs`u gezdiği için devir hiçbir satırda görünmüyordu; aynı adı
    /// taşıyan iki rakam ayrışıyor, mali müşavir "Tutar" sütununu toplayınca
    /// ekrandakinin çok altında bir sayı buluyordu. Hiç fişi olmayan ama devri
    /// olan projede fark %100'e çıkıyordu.
    ///
    /// Devir bir TÜRETİLMİŞ toplam değil, ham açılış kaydıdır — o yüzden
    /// dosyaya toplam olarak değil, kendi satırı olarak giriyor.
    static func materialLogsCSV(logs: [MaterialLog], materials: [Material]) -> String {
        let byId = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        // AÇILIŞ İKİ SATIR OLABİLİR. `Material.recalculate` açılışı iki ayrı
        // büyüklükte tutuyor: `totalIn = openingIn + girişler`,
        // `totalOut = openingOut + çıkışlar`. Yalnız `openingIn` yazıldığında
        // dosyadan "Devir + Giriş − Çıkış" diye kalan stok hesaplayan okuyucu
        // tüketilmiş açılış stoğunu hiç görmüyor ve rakam şişiyordu — üstelik
        // "Devir" satırının varlığı "açılış tam olarak burada" izlenimi verdiği
        // için eksiklik artık sorgulanmıyordu.
        let openingRows = materials
            .filter { $0.openingCost != .zero || $0.openingIn != 0 || $0.openingOut != 0 }
            .sorted { $0.name < $1.name }
            .flatMap { material -> [[String]] in
                var out: [[String]] = []
                if material.openingCost != .zero || material.openingIn != 0 {
                    out.append(["", material.name, material.code, "Devir",
                                quantity(material.openingIn), material.unit,
                                "", money(material.openingCost),
                                "Açılış devri (fiş öncesi)", ""])
                }
                if material.openingOut != 0 {
                    // Tür "Çıkış": stok hesabında açılış tüketimi de çıkıştır.
                    // Tutar BOŞ — maliyet yalnızca `openingCost`ta sayılıyor,
                    // burada da yazılsa çift sayılırdı.
                    out.append(["", material.name, material.code, "Çıkış",
                                quantity(material.openingOut), material.unit,
                                "", "", "Açılış devri (çıkış)", ""])
                }
                return out
            }
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
                // TUTAR YALNIZCA MALİYET SATIRLARINDA. Ekrandaki "Malzeme
                // gideri" `accruedCost` = `openingCost + GİRİŞ fişleri`;
                // çıkış fişlerine de tutar yazıldığında sütun toplamı ekranla
                // ayrışıyordu ve devir satırları eklenince mutlak hata
                // büyümüştü. Çıkışın parasal değeri kaybolmuyor: satırda
                // Miktar ve Birim Fiyat duruyor, çarpımı okuyucunun elinde.
                log.type == .entry ? money(total) : "",
                log.note,
                log.user,
            ]
        }
        return csv(header: ["Tarih", "Malzeme", "Kod", "Tür", "Miktar", "Birim",
                            "Birim Fiyat", "Tutar", "Açıklama", "Kaydeden"],
                   rows: openingRows + rows)
    }

    /// KDV TABANI SÜTUN BAŞLIĞINDA (madde 80): dosyayı açan mali müşavir
    /// projenin beyanını göremez, yalnızca sayıları görür. "Tutar" başlığı
    /// tek başına, o rakamın KDV dahil mi hariç mi olduğunu söylemiyor ve
    /// müşavirin bunu tahmin etmesi gerekiyordu. Ekrandaki alan etiketiyle
    /// aynı desen: beyan, rakamın YANINDA durur.
    static func expensesCSV(_ expenses: [Expense], taxBasis: TaxBasis? = nil) -> String {
        let rows = expenses.sorted { $0.date > $1.date }.map { expense in
            [date(expense.date), expense.category.rawValue, money(expense.amount),
             expense.payee, expense.note, expense.user]
        }
        return csv(header: ["Tarih", "Kategori", "Tutar\(taxSuffix(taxBasis))",
                            "Ödenen", "Açıklama", "Kaydeden"],
                   rows: rows)
    }

    /// Satışlar. `includeBuyer` YALNIZCA yöneticide true — gerekçe dosya
    /// başındaki GİZLİLİK notunda.
    static func apartmentsCSV(_ apartments: [Apartment], includeBuyer: Bool,
                              taxBasis: TaxBasis? = nil) -> String {
        let rows = apartments.sorted { $0.apartmentNumber < $1.apartmentNumber }
            .map { apartment -> [String] in
                // KAPSAM: "Satış Bedeli / Tahsil Edilen / Kalan Alacak"
                // sütunları YALNIZCA satılan daireyi dolduruyor — ekranın
                // `countsAsRevenue` süzgeciyle birebir aynı. Önceden üç sütun
                // da TÜM daireleri dolduruyordu: boş daire `price` alanında
                // LİSTE fiyatı taşıdığı için "Kalan" sütununun toplamı ekrandaki
                // "Kalan alacak"tan %40'a varan oranda şişik çıkıyordu. Sütun adı
                // ekranla aynıydı, saydığı şey değildi.
                //
                // Bilgi KAYBOLMUYOR: liste fiyatı kendi sütununda duruyor,
                // rezerve dairenin kaporası da — o gerçek nakit (`isCommitted`).
                // Ayrıştırmak, sütunu boşaltmaktan da tek bir "Bedel" sütununda
                // iki farklı şeyi toplamaktan da dürüst.
                let satildi = apartment.countsAsRevenue
                var values = [
                    String(apartment.apartmentNumber),
                    // BLOK SÜTUNU (madde 83): mali müşavir dosyayı blok
                    // bazında süzebilsin. Ekranda kırılım yalnızca birden
                    // çok etiket varsa görünüyor ama CSV'de sütun HER ZAMAN
                    // var — süzülecek bir dosyada sütunun bazen olup bazen
                    // olmaması, şablonu her seferinde bozardı.
                    apartment.blockLabel,
                    Apartment.floorLabel(for: apartment.floor),
                    apartment.type,
                    apartment.areaM2.map { quantity($0) } ?? "",
                    apartment.status.label,
                    // LİSTE FİYATI SATILAN DAİREDE BOŞ. `saveSale` satılan
                    // dairede `price` alanının ÜSTÜNE satış bedelini yazıyor,
                    // yani orada `price` artık liste fiyatı değil. İki sütuna
                    // da yazıldığında satılan her satır aynı parayı iki farklı
                    // başlık altında tekrar ediyordu ve "Liste Fiyatı" sütun
                    // toplamı ekranda karşılığı olmayan bir karışıma dönüşüyordu.
                    satildi ? "" : money(apartment.price),
                    satildi ? money(apartment.price) : "",
                    satildi ? money(apartment.paidAmount) : "",
                    satildi ? money(max(.zero, apartment.price - apartment.paidAmount)) : "",
                    apartment.status == .reserved ? money(apartment.paidAmount) : "",
                    apartment.saleDate.map(date) ?? "",
                ]
                if includeBuyer { values.append(apartment.buyerName ?? "") }
                return values
            }
        // "Liste Fiyatı" ile "Satış Bedeli" AYRI sütunlar: boş daire de liste
        // fiyatı taşır ama o ciro değildir. Tek sütunda toplanınca ekrandaki
        // satış rakamıyla dosyadaki toplam ayrışıyordu.
        let ek = taxSuffix(taxBasis)
        var header = ["Daire No", "Blok / Etap", "Kat", "Tip", "Brüt m²", "Durum",
                      "Liste Fiyatı\(ek)", "Satış Bedeli\(ek)", "Tahsil Edilen",
                      "Kalan Alacak", "Kapora", "Satış Tarihi"]
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
        /// Taksit planı (madde 21). Madde 26'dan SONRA eklendi ve yedeğe
        /// alınması unutulmuştu — gerçek cihaz turunda dışa aktarılan dosya
        /// denetlenirken yakalandı.
        let taksitler: [Installment]
        let ortaklar: [Partner]
        let belgeler: [ProjectDocument]
        let alicilar: [ApartmentBuyer]
        let denetimIzi: [AuditEntry]
    }

    /// Yedeğin şema sürümü. Değiştiğinde ESKİ uygulama yeni dosyayı REDDETMELİ,
    /// yarım okumamalı — madde 56'nın yedek dosyasındaki karşılığı.
    static let backupVersion = 1

    /// Yedek okunamama sebepleri. Hepsi kullanıcıya AYRI cümleyle söyleniyor:
    /// "dosya okunamadı" tek başına kişiye ne yapacağını söylemiyor.
    enum BackupError: LocalizedError, Equatable {
        /// JSON çözülemedi — dosya bozuk ya da yedek değil.
        case unreadable
        /// Dosya bu uygulamanın anlamadığı bir sürümden.
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "Dosya okunamadı · geçerli bir yedek değil"
            case .unsupportedVersion(let v):
                return "Yedek sürüm \(v) · bu uygulama sürüm \(backupVersion) okuyor"
            }
        }
    }

    /// JSON yedeğini çözer.
    ///
    /// SÜRÜM ÖNCE DENETLENİYOR ve bilinmeyen sürüm REDDEDİLİYOR. Yarım okumak
    /// en kötü sonuç olurdu: yeni sürümde eklenmiş bir koleksiyon sessizce
    /// düşer, kullanıcı verisinin tamamının geldiğini sanır ve eksiği ancak
    /// aylar sonra bir rakam tutmadığında fark eder.
    static func decodeBackup(_ data: Data) throws -> Backup {
        struct VersionProbe: Decodable { let surum: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else {
            throw BackupError.unreadable
        }
        guard probe.surum == backupVersion else {
            throw BackupError.unsupportedVersion(probe.surum)
        }
        do { return try decoder.decode(Backup.self, from: data) }
        catch { throw BackupError.unreadable }
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
