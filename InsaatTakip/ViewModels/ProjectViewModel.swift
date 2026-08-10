import SwiftUI

// MARK: - ProjectViewModel
// Uygulamanın tüm iş mantığı ve verisi burada toplanır (MVVM).
// Henüz bir veritabanı bağlı değil; tasarım dosyasındaki senaryoyu birebir
// yansıtan gerçekçi mock verilerle çalışır:
//   · 145 Ada / 2 Parsel (Çayırova) — 20 daire, 12 satış, 9 kalem malzeme
//   · 1287 Ada / 14 Parsel (Nilüfer) — temel aşamasında
//   · 908 Ada / 7 Parsel (Kepez) — teslim aşamasında, tamamı satılmış
// View'lar "dumb" kalır; filtreleme, toplama ve yetki kuralları buradadır.

final class ProjectViewModel: ObservableObject {

    // MARK: Yayınlanan durum

    @Published var projects: [Project] = []
    @Published var materials: [Material] = []          // Tüm projelerin malzemeleri
    @Published var materialLogs: [MaterialLog] = []    // Giriş / çıkış kayıtları
    @Published var apartments: [Apartment] = []        // Tüm projelerin daireleri
    @Published var partners: [Partner] = []            // Ortaklar (hisse dağılımı)
    @Published var documents: [ProjectDocument] = []   // Plan & proje dosyaları
    @Published var activities: [ActivityItem] = []     // Hareket / bildirim akışı
    @Published var sitePhotos: [SitePhoto] = []        // Şantiye fotoğraf yuvaları

    /// Ekran altında beliren onay bildirimi.
    @Published var toast: String?

    /// Bildirim zilindeki okunmamış işareti.
    @Published var hasUnreadActivity = true

    private var toastTask: Task<Void, Never>?

    init() {
        loadMockData()
    }

    // MARK: - Proje bazlı erişim (filtreleme ViewModel'de, View'da değil)

    func materials(for projectId: String) -> [Material] {
        materials.filter { $0.projectId == projectId }
    }

    func logs(for materialId: String) -> [MaterialLog] {
        materialLogs.filter { $0.materialId == materialId }
    }

    func apartments(for projectId: String) -> [Apartment] {
        apartments
            .filter { $0.projectId == projectId }
            .sorted { $0.apartmentNumber < $1.apartmentNumber }
    }

    func partners(for projectId: String) -> [Partner] {
        partners.filter { $0.projectId == projectId }
    }

    /// Belgeler — ortak yalnızca "Ortaklar görebilsin" açık olanları görür.
    func documents(for projectId: String, role: UserRole) -> [ProjectDocument] {
        documents.filter { $0.projectId == projectId && (role == .admin || $0.partnerVisible) }
    }

    /// Belge tarihlerinden ("12 Oca 2026") en yenisini bulur; başlıktaki "son yükleme" için.
    /// İçinde bulunulan yıla aitse yıl gösterilmez ("14 Tem"), değilse tam tarih döner.
    func lastUploadText(for projectId: String, role: UserRole) -> String? {
        let currentYear = Calendar.current.component(.year, from: Date())
        let parsed: [(Int, Int, Int, String)] = documents(for: projectId, role: role).compactMap { doc in
            let parts = doc.dateText.split(separator: " ")
            guard parts.count >= 2,
                  let day = Int(parts[0]),
                  let monthIndex = Self.monthNames.firstIndex(of: String(parts[1])) else { return nil }
            let year = parts.count > 2 ? (Int(parts[2]) ?? currentYear) : currentYear
            return (year, monthIndex + 1, day, doc.dateText)
        }
        guard let newest = parsed.max(by: { ($0.0, $0.1, $0.2) < ($1.0, $1.1, $1.2) }) else { return nil }
        if newest.0 == currentYear {
            return "\(newest.2) \(Self.monthNames[newest.1 - 1])"
        }
        return newest.3
    }

    func photos(for projectId: String) -> [SitePhoto] {
        sitePhotos.filter { $0.projectId == projectId }
    }

    // MARK: - Özet rakamlar

    /// Toplam satış cirosu (yalnızca satılan dairelerin bedelleri).
    /// Not: Boş daireler liste fiyatı taşıyabilir (TOKİ gerçek verisi) — ciroya girmez.
    func totalSales(for projectId: String) -> Double {
        apartments(for: projectId).filter(\.isSold).reduce(0) { $0 + $1.price }
    }

    /// Toplam malzeme gideri (giren × birim fiyat).
    func totalMaterialCost(for projectId: String) -> Double {
        materials(for: projectId).reduce(0) { $0 + $1.totalCost }
    }

    /// Net = satış − malzeme gideri.
    func netAmount(for projectId: String) -> Double {
        totalSales(for: projectId) - totalMaterialCost(for: projectId)
    }

    func soldCount(for projectId: String) -> Int {
        apartments(for: projectId).filter(\.isSold).count
    }

    /// Tahsil edilen toplam.
    func collectedAmount(for projectId: String) -> Double {
        apartments(for: projectId).reduce(0) { $0 + $1.paidAmount }
    }

    /// Kalan alacak toplamı.
    func outstandingAmount(for projectId: String) -> Double {
        totalSales(for: projectId) - collectedAmount(for: projectId)
    }

    /// Dashboard alt başlığı: "3 proje · 40 daire · Bugün 09:24 güncellendi"
    var dashboardSubtitle: String {
        let apartmentTotal = projects.reduce(0) { $0 + $1.totalApartments }
        return "\(projects.count) proje · \(apartmentTotal) daire · Bugün \(Fmt.clock()) güncellendi"
    }

    // MARK: - Yönetici işlemleri (yetki kontrolü çağıran ekranda + burada)

    /// Fiş / malzeme hareketi kaydeder. Boş miktar tasarım gereği "Miktar girilmedi" uyarısı verir.
    /// - Returns: Kayıt başarılıysa true.
    @discardableResult
    func addReceipt(role: UserRole, materialId: String, type: MaterialLog.LogType,
                    amountText: String, unitPriceText: String, reference: String) -> Bool {
        guard role == .admin else { return false }   // Ortak veri giremez
        guard let index = materials.firstIndex(where: { $0.id == materialId }) else { return false }

        let amount = Self.parseNumber(amountText)
        guard amount > 0 else {
            flash("Miktar girilmedi")
            return false
        }

        var material = materials[index]
        if type == .entry {
            material.totalIn += amount
            // Birim fiyat girildiyse son alış fiyatı olarak güncellenir.
            let newPrice = Self.parseNumber(unitPriceText)
            if newPrice > 0 { material.unitPrice = newPrice }
        } else {
            material.totalOut = min(material.totalIn, material.totalOut + amount)
        }
        materials[index] = material

        let note = reference.isEmpty
            ? (type == .entry ? "İrsaliye kaydı" : "Saha kullanımı")
            : reference
        let log = MaterialLog(id: UUID(), materialId: materialId, type: type,
                              amount: amount, dateText: Fmt.shortDate(),
                              note: note, user: User.admin.name)
        materialLogs.insert(log, at: 0)

        // Hareket akışına düşür.
        let verb = type == .entry ? "giriş" : "çıkış"
        let project = projects.first { $0.id == material.projectId }
        activities.insert(ActivityItem(id: UUID(),
                                       kind: type == .entry ? .materialIn : .materialOut,
                                       title: "\(material.name) · \(Fmt.qty(amount, unit: material.unit)) \(verb)",
                                       meta: "\(project?.title ?? "") · \(note)",
                                       timeText: Fmt.clock(),
                                       section: .bugun), at: 0)
        hasUnreadActivity = true
        flash("Fiş kaydedildi")
        return true
    }

    /// Daire satışı ekler veya mevcut satış kaydını günceller.
    @discardableResult
    func saveSale(role: UserRole, apartmentId: String, buyerName: String,
                  priceText: String, paidText: String, payment: PaymentStatus, dateText: String? = nil) -> Bool {
        guard role == .admin else { return false }
        guard let index = apartments.firstIndex(where: { $0.id == apartmentId }) else { return false }

        let price = Self.parseNumber(priceText)
        let trimmedBuyer = buyerName.trimmingCharacters(in: .whitespaces)
        guard price > 0, !trimmedBuyer.isEmpty else {
            flash(price <= 0 ? "Satış bedeli girilmedi" : "Alıcı adı girilmedi")
            return false
        }

        var apartment = apartments[index]
        let isNewSale = !apartment.isSold
        apartment.status = .sold
        apartment.buyerName = trimmedBuyer
        apartment.price = price
        apartment.paymentStatus = payment
        apartment.paidAmount = payment == .tamamlandi ? price : min(price, Self.parseNumber(paidText))
        apartment.saleDateText = dateText ?? apartment.saleDateText ?? Fmt.shortDate()
        apartments[index] = apartment

        if isNewSale {
            let project = projects.first { $0.id == apartment.projectId }
            let payNote: String
            switch payment {
            case .tamamlandi: payNote = "Tahsil edildi"
            case .kapora:     payNote = "Kapora alındı"
            case .taksitli:   payNote = "Taksit planı başladı"
            }
            activities.insert(ActivityItem(id: UUID(), kind: .sale,
                                           title: "Daire No \(apartment.apartmentNumber) satıldı — \(Fmt.compactMoney(price))",
                                           meta: "\(trimmedBuyer) · \(payNote)",
                                           timeText: Fmt.clock(),
                                           section: .bugun), at: 0)
            hasUnreadActivity = true
        }
        flash(isNewSale ? "Satış kaydedildi" : "Satış kaydı güncellendi")
        return true
    }

    /// Yeni proje (ada/parsel) oluşturur; daireleri boş olarak açar.
    @discardableResult
    func addProject(role: UserRole, block: String, parcel: String, district: String,
                    city: String, floors: Int, apartmentCount: Int) -> Project? {
        guard role == .admin else { return nil }
        let trimmedBlock = block.trimmingCharacters(in: .whitespaces)
        let trimmedParcel = parcel.trimmingCharacters(in: .whitespaces)
        guard !trimmedBlock.isEmpty, !trimmedParcel.isEmpty else {
            flash("Ada ve parsel girilmedi")
            return nil
        }

        let project = Project(id: UUID().uuidString,
                              blockNumber: trimmedBlock, parcelNumber: trimmedParcel,
                              district: district.isEmpty ? "—" : district,
                              city: city.isEmpty ? "—" : city,
                              floors: max(1, floors), totalApartments: max(1, apartmentCount),
                              phase: .temel, progress: 0, inviteCode: nil, photoCount: 0)
        projects.append(project)

        // Daireler boş (satılmamış) olarak oluşturulur; kat = 4 daire varsayımıyla.
        let perFloor = max(1, Int((Double(project.totalApartments) / Double(project.floors)).rounded(.up)))
        let types = [("2+1", "95 m²"), ("3+1", "128 m²"), ("3+1", "132 m²"), ("2+1", "98 m²")]
        for n in 1...project.totalApartments {
            let t = types[(n - 1) % types.count]
            apartments.append(Apartment(id: "\(project.id)-\(n)", projectId: project.id,
                                        apartmentNumber: n, floor: (n - 1) / perFloor + 1,
                                        type: t.0, area: t.1, status: .available,
                                        buyerName: nil, price: 0, paidAmount: 0,
                                        paymentStatus: nil, saleDateText: nil,
                                        deliveryNote: "Yapım sürüyor", imageLabels: []))
        }
        flash("Proje oluşturuldu")
        return project
    }

    // MARK: Davet kodu

    /// Projeye 48 saat geçerli, tek kullanımlık davet kodu üretir.
    func generateInviteCode(role: UserRole, projectId: String) {
        guard role == .admin,
              let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].inviteCode = InviteCode.generate()
    }

    /// Ortağın girdiği kodu doğrular (mock: 6 haneli her kod kabul edilir).
    func validateJoinCode(_ code: String) -> Bool {
        InviteCode.sanitize(code).count == 6
    }

    func copyInviteCode(_ raw: String) {
        UIPasteboard.general.string = InviteCode.formatted(raw)
        flash("Davet kodu kopyalandı")
    }

    func copyInviteLink(_ raw: String) {
        UIPasteboard.general.string = "https://" + InviteCode.link(raw)
        flash("Bağlantı kopyalandı")
    }

    /// WhatsApp ile davet paylaşımı; uygulama yoksa kullanıcı bilgilendirilir.
    func shareInviteViaWhatsApp(project: Project, raw: String) {
        let message = "\(project.title) projesini takip etmen için davet kodun: \(InviteCode.formatted(raw))\nhttps://\(InviteCode.link(raw))"
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "whatsapp://send?text=\(encoded)"),
              UIApplication.shared.canOpenURL(url) else {
            flash("WhatsApp bulunamadı")
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: Belge ve fotoğraf

    /// Yükleme sayfasından yeni belge ekler.
    func addDocument(role: UserRole, projectId: String, group: ProjectDocument.Group,
                     fileName: String, sizeMB: Double, versionNote: String, partnerVisible: Bool) {
        guard role == .admin else { return }
        let ext = (fileName as NSString).pathExtension.lowercased()
        let type: ProjectDocument.FileType = ext == "dwg" ? .dwg : (["jpg", "jpeg", "png", "heic"].contains(ext) ? .jpg : .pdf)
        let baseName = (fileName as NSString).deletingPathExtension
        let doc = ProjectDocument(id: UUID(), projectId: projectId, group: group,
                                  fileType: type,
                                  name: baseName.isEmpty ? fileName : baseName,
                                  versionText: versionNote.isEmpty ? "v1" : versionNote,
                                  sizeMB: max(0.1, sizeMB),
                                  dateText: Fmt.shortDate(),
                                  partnerVisible: partnerVisible)
        documents.insert(doc, at: 0)
        flash("Dosya yüklendi")
    }

    /// Galeriden seçilen şantiye fotoğraflarını bu haftaya ekler.
    func addSitePhotos(role: UserRole, projectId: String, images: [Data]) {
        guard role == .admin, !images.isEmpty else { return }
        for data in images {
            sitePhotos.insert(SitePhoto(id: UUID(), projectId: projectId,
                                        dateText: String(Fmt.shortDate().dropLast(5)),
                                        isCurrentWeek: true, imageData: data), at: 0)
        }
        if let index = projects.firstIndex(where: { $0.id == projectId }) {
            projects[index].photoCount += images.count
        }
        flash(images.count == 1 ? "Fotoğraf eklendi" : "\(images.count) fotoğraf eklendi")
    }

    // MARK: - Rapor (Ekran 10)

    enum ReportPeriod: String, CaseIterable {
        case buAy = "Bu ay"
        case ceyrek = "Çeyrek"
        case tumu = "Tümü"
    }

    struct ReportSummary {
        var title: String            // "3. ÇEYREK ÖZETİ"
        var soldCount: Int
        var salesTotal: Double
        var collectedTotal: Double
        var materialCost: Double
        var net: Double { salesTotal - materialCost }
    }

    struct MonthBar: Identifiable {
        let id = UUID()
        var label: String            // "Şub"
        var value: Double            // Ay toplam satış (₺)
    }

    static let monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    /// "18 Şub 2026" → ay numarası (1-12).
    private static func month(of dateText: String?) -> Int? {
        guard let text = dateText else { return nil }
        let parts = text.split(separator: " ")
        guard parts.count >= 2, let index = monthNames.firstIndex(of: String(parts[1])) else { return nil }
        return index + 1
    }

    /// Seçilen dönemin özet tablosu. (Bugün: 10 Ağu 2026 senaryosu — dönemler buna göre.)
    func reportSummary(for projectId: String, period: ReportPeriod) -> ReportSummary {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let quarter = (currentMonth - 1) / 3 + 1
        let months: ClosedRange<Int>
        let title: String
        switch period {
        case .buAy:
            months = currentMonth...currentMonth
            title = Self.monthNames[currentMonth - 1].uppercased(with: Fmt.locale) + " AYI ÖZETİ"
        case .ceyrek:
            months = ((quarter - 1) * 3 + 1)...(quarter * 3)
            title = "\(quarter). ÇEYREK ÖZETİ"
        case .tumu:
            months = 1...12
            title = "PROJE GENELİ ÖZET"
        }

        let sold = apartments(for: projectId).filter {
            guard $0.isSold, let m = Self.month(of: $0.saleDateText) else { return false }
            return months.contains(m)
        }
        let sales = sold.reduce(0) { $0 + $1.price }
        let collected = sold.reduce(0) { $0 + $1.paidAmount }

        // Malzeme gideri: dönem içindeki giriş kayıtları × birim fiyat.
        // "Tümü" seçiliyken toplam malzeme maliyeti kullanılır.
        let cost: Double
        if period == .tumu {
            cost = totalMaterialCost(for: projectId)
        } else {
            let projectMaterials = materials(for: projectId)
            cost = materialLogs.reduce(0) { sum, log in
                guard log.type == .entry,
                      let material = projectMaterials.first(where: { $0.id == log.materialId }),
                      let m = Self.month(of: log.dateText), months.contains(m) else { return sum }
                return sum + log.amount * material.unitPrice
            }
        }

        return ReportSummary(title: title, soldCount: sold.count,
                             salesTotal: sales, collectedTotal: collected, materialCost: cost)
    }

    /// Son 6 tamamlanmış ayın satış çubukları (Şub…Tem).
    func monthlySales(for projectId: String) -> [MonthBar] {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let range = (max(1, currentMonth - 6))..<currentMonth
        let sold = apartments(for: projectId).filter(\.isSold)
        return range.map { m in
            let total = sold.reduce(0.0) { sum, apt in
                Self.month(of: apt.saleDateText) == m ? sum + apt.price : sum
            }
            return MonthBar(label: Self.monthNames[m - 1], value: total)
        }
    }

    // MARK: - Hareket akışı filtresi (Ekran 07)

    enum ActivityFilter: String, CaseIterable {
        case tumu = "Tümü"
        case malzeme = "Malzeme"
        case satis = "Satış"
    }

    func activities(filter: ActivityFilter) -> [ActivityItem] {
        switch filter {
        case .tumu:    return activities
        case .malzeme: return activities.filter(\.isMaterial)
        case .satis:   return activities.filter(\.isSale)
        }
    }

    func markActivityRead() {
        hasUnreadActivity = false
    }

    // MARK: - Toast

    /// 2,6 saniye görünen onay bildirimi.
    func flash(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { self?.toast = nil } }
        }
    }

    /// "12.500" / "28,50" gibi tr-TR girdilerini sayıya çevirir.
    static func parseNumber(_ text: String) -> Double {
        let normalized = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }
}

// MARK: - Mock Veri
// Tasarım dosyasındaki ekranların birebir veri seti.

extension ProjectViewModel {

    private func loadMockData() {
        // ---- Projeler --------------------------------------------------------
        // "kars309": GERÇEK proje — TOKİ Kars Karacaören 309 Konut, Ada 1224 / Parsel 1,
        // SF-1 Blok 1 (Zemin+2 kat, 12 daire, tamamı 3+1 · 111,55 m² brüt / 88,5 m² net).
        // Kaynak: TOKİ resmî fiyat listesi (29 Ağu 2024) — DemoAssets/ içinde yerel kopyası var.
        // İlerleme %88 tahminidir (kura 19 Ara 2024, sözleşmeler Oca 2025; teslim öncesi ince işler).
        projects = [
            Project(id: "p1", blockNumber: "145", parcelNumber: "2", district: "Çayırova", city: "Kocaeli",
                    floors: 5, totalApartments: 20, phase: .kabaInsaat, progress: 68, inviteCode: nil, photoCount: 48),
            Project(id: "p2", blockNumber: "1287", parcelNumber: "14", district: "Nilüfer", city: "Bursa",
                    floors: 4, totalApartments: 12, phase: .temel, progress: 34, inviteCode: nil, photoCount: 12),
            Project(id: "p3", blockNumber: "908", parcelNumber: "7", district: "Kepez", city: "Antalya",
                    floors: 3, totalApartments: 8, phase: .teslim, progress: 96, inviteCode: nil, photoCount: 64),
            Project(id: "kars309", blockNumber: "1224", parcelNumber: "1", district: "Karacaören", city: "Kars",
                    floors: 3, totalApartments: 12, phase: .inceIsler, progress: 88, inviteCode: nil, photoCount: 0),
        ]

        // ---- Malzemeler (9 kalem × 3 proje) ---------------------------------
        // (kod, ad, açıklama, birim, birim fiyat, giren, çıkan, adım)
        let baseMaterials: [(String, String, String, String, Double, Double, Double, Double)] = [
            ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 48_000, 41_800, 500),
            ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 1_850, 1_640, 50),
            ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 1_240, 1_060, 50),
            ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 78_000, 68_600, 1_000),
            ("EPS", "Strafor", "5 cm cephe levhası", "m²", 96, 2_400, 1_460, 100),
            ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 186, 144, 10),
            ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 320, 272, 20),
            ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 900, 590, 25),
            ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 640, 420, 25),
        ]
        // p2 ve p3 daha küçük projeler: miktarlar ölçeklenir, fiyatlar aynı kalır.
        let scales: [String: Double] = ["p1": 1.0, "p2": 0.52, "p3": 0.44]
        for project in projects {
            guard let factor = scales[project.id] else { continue }   // kars309 aşağıda ayrı
            for (code, name, subtitle, unit, price, totalIn, totalOut, step) in baseMaterials {
                materials.append(Material(id: "\(project.id)-\(code)", projectId: project.id,
                                          code: code, name: name, subtitle: subtitle, unit: unit,
                                          unitPrice: price,
                                          totalIn: (totalIn * factor).rounded(),
                                          totalOut: (totalOut * factor).rounded(),
                                          step: step))
            }
        }

        // kars309 malzemeleri — MÜHENDİSLİK TAHMİNİ (proje bazlı malzeme verisi kamuya açık değildir).
        // Taban: 12 daire × 111,55 m² brüt × 1,15 ortak alan payı ≈ 1.540 m² inşaat alanı.
        // Katsayılar (betonarme konut için yaygın değerler): demir 40 kg/m², beton 0,35 m³/m²,
        // çimento 0,7 torba/m², tuğla 45 adet/m², alçı 0,45 torba/m²; cephe ≈ 810 m² (mantolama),
        // doğrama 12 daire × 7 adet. Kullanım (çıkan), %88 fiziki ilerlemeyle uyumlu tutuldu.
        let karsMaterials: [(String, String, String, String, Double, Double, Double, Double)] = [
            ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 61_500, 58_000, 500),
            ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 540, 540, 50),
            ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 1_080, 940, 50),
            ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 69_500, 66_000, 1_000),
            ("EPS", "Strafor", "5 cm mantolama levhası", "m²", 96, 810, 690, 100),
            ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 84, 78, 10),
            ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 340, 305, 20),
            ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 750, 700, 25),
            ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 690, 560, 25),
        ]
        for (code, name, subtitle, unit, price, totalIn, totalOut, step) in karsMaterials {
            materials.append(Material(id: "kars309-\(code)", projectId: "kars309",
                                      code: code, name: name, subtitle: subtitle, unit: unit,
                                      unitPrice: price, totalIn: totalIn, totalOut: totalOut, step: step))
        }

        // ---- Malzeme hareket geçmişi ----------------------------------------
        // Demir kayıtları ekran 03'teki değerlerin birebir aynısı; diğer kalemler
        // aynı tarih/irsaliye düzeniyle kendi miktarlarından türetilir.
        let admin = User.admin.name
        for material in materials where material.projectId == "p1" {
            if material.code == "Ø12" {
                materialLogs.append(contentsOf: [
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 6_800,
                                dateText: "02 Ağu 2026", note: "5. kat perde donatısı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: 12_500,
                                dateText: "28 Tem 2026", note: "İrsaliye #4471 · Yılmaz Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 4_600,
                                dateText: "21 Tem 2026", note: "4. kat döşeme imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: 14_000,
                                dateText: "14 Tem 2026", note: "İrsaliye #4398 · Ege Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 3_900,
                                dateText: "06 Tem 2026", note: "3. kat kolon donatısı", user: admin),
                ])
            } else {
                let round: (Double) -> Double = { value in
                    let unitStep = max(1, material.step / 5)
                    return max(unitStep, (value / unitStep).rounded() * unitStep)
                }
                materialLogs.append(contentsOf: [
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.16),
                                dateText: "02 Ağu 2026", note: "5. kat imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: round(material.totalIn * 0.21),
                                dateText: "28 Tem 2026", note: "İrsaliye #4471 · Yılmaz Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.11),
                                dateText: "21 Tem 2026", note: "4. kat imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: round(material.totalIn * 0.28),
                                dateText: "14 Tem 2026", note: "İrsaliye #4398 · Ege Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.09),
                                dateText: "06 Tem 2026", note: "3. kat imalatı", user: admin),
                ])
            }
        }

        // kars309 hareketleri — son teslimat/kullanım kayıtları (temsilî akış).
        materialLogs.append(contentsOf: [
            MaterialLog(id: UUID(), materialId: "kars309-Ø12", type: .exit, amount: 4_200,
                        dateText: "29 Tem 2026", note: "Çatı parapet donatısı", user: admin),
            MaterialLog(id: UUID(), materialId: "kars309-Ø12", type: .entry, amount: 9_500,
                        dateText: "15 Tem 2026", note: "İrsaliye #2087 · Kars Demir Çelik", user: admin),
            MaterialLog(id: UUID(), materialId: "kars309-ALÇ", type: .exit, amount: 120,
                        dateText: "05 Ağu 2026", note: "2. kat saten perdah", user: admin),
            MaterialLog(id: UUID(), materialId: "kars309-EPS", type: .exit, amount: 90,
                        dateText: "01 Ağu 2026", note: "Kuzey cephe mantolama", user: admin),
        ])

        // ---- Daireler --------------------------------------------------------
        // 145 Ada / 2 Parsel: 12 satış — alıcı, bedel, ödeme ve tahsilat değerleri
        // ekran 04'teki kartların birebir aynısı. (Tahsilat 28,12 M · Kalan 14,53 M)
        let types = [("2+1", "95 m²"), ("3+1", "128 m²"), ("3+1", "132 m²"), ("2+1", "98 m²")]

        // (daireNo, alıcı, bedel, ödeme, tahsil edilen, tarih)
        let p1Sales: [(Int, String, Double, PaymentStatus, Double, String)] = [
            (1, "Ahmet Yılmaz", 3_150_000, .tamamlandi, 3_150_000, "18 Şub 2026"),
            (2, "Merve Demir", 3_650_000, .tamamlandi, 3_650_000, "02 Mar 2026"),
            (3, "Selim Kaya", 3_700_000, .kapora, 500_000, "14 Mar 2026"),
            (4, "Emre Şahin", 3_200_000, .tamamlandi, 3_200_000, "27 Mar 2026"),
            (5, "Fatma Çelik", 3_300_000, .taksitli, 1_980_000, "05 Nis 2026"),
            (6, "Hakan Aydın", 3_800_000, .taksitli, 2_280_000, "19 Nis 2026"),
            (7, "Berk Koç", 3_850_000, .tamamlandi, 3_850_000, "28 Nis 2026"),
            (8, "Nazlı Arslan", 3_350_000, .kapora, 500_000, "09 May 2026"),
            (9, "Rıza Doğan", 3_450_000, .tamamlandi, 3_450_000, "21 May 2026"),
            (11, "Tuğçe Öztürk", 3_900_000, .taksitli, 1_510_000, "06 Haz 2026"),
            (13, "Cem Yıldız", 3_550_000, .tamamlandi, 3_550_000, "17 Haz 2026"),
            (17, "Gizem Polat", 3_750_000, .kapora, 500_000, "02 Tem 2026"),
        ]
        let p2Sales: [(Int, String, Double, PaymentStatus, Double, String)] = [
            (1, "Ahmet Yılmaz", 3_150_000, .tamamlandi, 3_150_000, "22 Şub 2026"),
            (2, "Merve Demir", 3_650_000, .tamamlandi, 3_650_000, "09 Mar 2026"),
            (4, "Selim Kaya", 3_200_000, .kapora, 500_000, "30 Mar 2026"),
            (7, "Emre Şahin", 3_200_000, .tamamlandi, 3_200_000, "12 Nis 2026"),
        ]
        let p3Sales: [(Int, String, Double, PaymentStatus, Double, String)] = [
            (1, "Kemal Ünal", 3_400_000, .tamamlandi, 3_400_000, "14 Oca 2026"),
            (2, "Zeynep Kaplan", 3_200_000, .tamamlandi, 3_200_000, "26 Oca 2026"),
            (3, "Murat Şen", 3_300_000, .tamamlandi, 3_300_000, "08 Şub 2026"),
            (4, "Elif Kurt", 3_450_000, .tamamlandi, 3_450_000, "24 Şub 2026"),
            (5, "Okan Güler", 3_150_000, .tamamlandi, 3_150_000, "11 Mar 2026"),
            (6, "Derya Aksoy", 3_200_000, .tamamlandi, 3_200_000, "29 Mar 2026"),
            (7, "Sinan Ateş", 3_500_000, .tamamlandi, 3_500_000, "16 Nis 2026"),
            (8, "Pelin Erden", 3_200_000, .tamamlandi, 3_200_000, "03 May 2026"),
        ]
        let salesByProject = ["p1": p1Sales, "p2": p2Sales, "p3": p3Sales]

        for project in projects where project.id != "kars309" {
            let sales = salesByProject[project.id] ?? []
            let perFloor = max(1, project.totalApartments / project.floors)
            for n in 1...project.totalApartments {
                let t = types[(n - 1) % types.count]
                let sale = sales.first { $0.0 == n }
                // Daire No 7 (ekran 13): Salon + Mutfak görsel yuvaları dolu.
                let labels: [String] = (project.id == "p1" && n == 7) ? ["Salon", "Mutfak"]
                    : (project.id == "p1" && n == 1) ? ["Salon"] : []
                apartments.append(Apartment(id: "\(project.id)-\(n)", projectId: project.id,
                                            apartmentNumber: n,
                                            floor: (n - 1) / perFloor + 1,
                                            type: t.0, area: t.1,
                                            status: sale == nil ? .available : .sold,
                                            buyerName: sale?.1,
                                            price: sale?.2 ?? 0,
                                            paidAmount: sale?.4 ?? 0,
                                            paymentStatus: sale?.3,
                                            saleDateText: sale?.5,
                                            deliveryNote: project.phase == .teslim ? "Teslim edildi" : "Anahtar teslim bekliyor",
                                            imageLabels: labels))
            }
        }

        // kars309 daireleri — GERÇEK VERİ (TOKİ fiyat listesi, 29 Ağu 2024):
        // Kat ve daire bazlı satış bedelleri (KDV hariç) listedeki birebir değerlerdir.
        // Zemin: No 1-4 · 1. Kat: No 5-8 · 2. Kat: No 9-12; tamamı 3+1, 111,55 m² brüt.
        // Satış kurgusu: kura 19 Ara 2024 → sözleşmeler Oca 2025'te imzalandı (9 daire);
        // tahsilat = %10 peşinat + Şub 2025–Ağu 2026 arası 19 aylık taksit (TOKİ planı,
        // MMA artışı ihmal edilmiştir). ALICI ADLARI KURGUDUR (gerçek alıcılar gizlidir).
        // No 1, 5, 9 satışta boş; liste fiyatları satış formunda hazır gelir.
        // (daireNo, kat, alıcı?, bedel, tahsil edilen, sözleşme tarihi?)
        let karsUnits: [(Int, Int, String?, Double, Double, String?)] = [
            (1, 0, nil, 1_805_613, 0, nil),
            (2, 0, "Meryem Karaca", 1_902_563, 371_003, "09 Oca 2025"),
            (3, 0, "Hasan Demirtaş", 1_902_563, 371_003, "14 Oca 2025"),
            (4, 0, "Elif Doğan", 1_805_613, 352_093, "16 Oca 2025"),
            (5, 1, nil, 2_051_221, 0, nil),
            (6, 1, "Yusuf Aslan", 2_193_416, 427_715, "07 Oca 2025"),
            (7, 1, "Zehra Çetin", 2_193_416, 427_715, "21 Oca 2025"),
            (8, 1, "Osman Kaya", 2_051_221, 399_986, "23 Oca 2025"),
            (9, 2, nil, 2_025_368, 0, nil),
            (10, 2, "İbrahim Güneş", 2_167_562, 422_678, "28 Oca 2025"),
            (11, 2, "Hatice Yavuz", 2_167_562, 422_678, "30 Oca 2025"),
            (12, 2, "Ali Yıldırım", 2_025_368, 394_950, "31 Oca 2025"),
        ]
        for (no, floor, buyer, price, paid, date) in karsUnits {
            apartments.append(Apartment(id: "kars309-\(no)", projectId: "kars309",
                                        apartmentNumber: no, floor: floor,
                                        type: "3+1", area: "111,55 m²",
                                        status: buyer == nil ? .available : .sold,
                                        buyerName: buyer,
                                        price: price,
                                        paidAmount: paid,
                                        paymentStatus: buyer == nil ? nil : .taksitli,
                                        saleDateText: date,
                                        deliveryNote: "İnce işler sürüyor · teslim bekleniyor",
                                        imageLabels: []))
        }

        // ---- Ortaklar (ekran 05) --------------------------------------------
        let partnerSet: [(String, Bool, String, Int)] = [
            ("Mehmet Kılıç", true, "Proje kurucusu · 04 Oca 2026", 40),
            ("Serkan Aydın", false, "Katıldı · 12 Mar 2026", 25),
            ("Ayşe Tuna", false, "Katıldı · 03 Nis 2026", 20),
            ("Burak Erdoğan", false, "Katıldı · 21 Nis 2026", 15),
        ]
        for project in projects {
            for (name, founder, joined, share) in partnerSet {
                partners.append(Partner(id: UUID(), projectId: project.id, name: name,
                                        isFounder: founder, joinedText: joined, sharePercent: share))
            }
        }

        // ---- Belgeler (ekran 11) --------------------------------------------
        let p1Documents: [(ProjectDocument.Group, ProjectDocument.FileType, String, String, Double, String, Bool)] = [
            (.mimari, .pdf, "Vaziyet Planı", "v3", 4.2, "12 Oca 2026", true),
            (.mimari, .pdf, "Kat Planları (1–5)", "v5", 11.8, "03 Şub 2026", true),
            (.mimari, .dwg, "Cephe Görünüşleri", "v2", 8.6, "03 Şub 2026", true),
            (.statik, .pdf, "Statik Hesap Raporu", "v2", 22.4, "18 Oca 2026", true),
            (.statik, .pdf, "Zemin Etüdü", "v1", 6.1, "04 Oca 2026", true),
            (.ruhsat, .pdf, "Yapı Ruhsatı", "v1", 1.3, "22 Oca 2026", true),
            (.ruhsat, .pdf, "İskân Başvurusu", "taslak", 0.8, "14 Tem 2026", false),
        ]
        for (group, type, name, version, size, date, visible) in p1Documents {
            documents.append(ProjectDocument(id: UUID(), projectId: "p1", group: group, fileType: type,
                                             name: name, versionText: version, sizeMB: size,
                                             dateText: date, partnerVisible: visible))
        }
        // Diğer projelerde küçük birer dosya seti.
        for pid in ["p2", "p3"] {
            documents.append(contentsOf: [
                ProjectDocument(id: UUID(), projectId: pid, group: .mimari, fileType: .pdf,
                                name: "Vaziyet Planı", versionText: "v1", sizeMB: 3.4,
                                dateText: "22 Oca 2026", partnerVisible: true),
                ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat, fileType: .pdf,
                                name: "Yapı Ruhsatı", versionText: "v1", sizeMB: 1.1,
                                dateText: "30 Oca 2026", partnerVisible: true),
            ])
        }

        // kars309 belgeleri — TOKİ'nin kamuya açık gerçek evrakları (toki.gov.tr/satis).
        documents.append(contentsOf: [
            ProjectDocument(id: UUID(), projectId: "kars309", group: .ruhsat, fileType: .pdf,
                            name: "TOKİ 83 Konut Fiyat Listesi", versionText: "resmî", sizeMB: 0.2,
                            dateText: "29 Ağu 2024", partnerVisible: true),
            ProjectDocument(id: UUID(), projectId: "kars309", group: .ruhsat, fileType: .pdf,
                            name: "Satış-Kura Duyurusu", versionText: "resmî", sizeMB: 0.1,
                            dateText: "16 Ara 2024", partnerVisible: true),
            ProjectDocument(id: UUID(), projectId: "kars309", group: .sozlesme, fileType: .pdf,
                            name: "Sözleşme Dönemi Bilgilendirmesi", versionText: "resmî", sizeMB: 0.1,
                            dateText: "02 Oca 2025", partnerVisible: true),
        ])

        // ---- Hareket akışı (ekran 07) ---------------------------------------
        activities = [
            ActivityItem(id: UUID(), kind: .materialIn, title: "Demir · 12.500 kg giriş",
                         meta: "145 Ada / 2 Parsel · İrsaliye #4471", timeText: "09:24", section: .bugun),
            ActivityItem(id: UUID(), kind: .sale, title: "Daire No 17 satıldı — 3,75 M ₺",
                         meta: "Gizem Polat · Kapora alındı", timeText: "08:10", section: .bugun),
            ActivityItem(id: UUID(), kind: .materialOut, title: "Çimento · 180 torba çıkış",
                         meta: "145 Ada / 2 Parsel · 5. kat şap", timeText: "16:40", section: .dun),
            ActivityItem(id: UUID(), kind: .partnerJoined, title: "Burak Erdoğan projeye katıldı",
                         meta: "Davet kodu ile · salt okunur", timeText: "11:02", section: .dun),
            ActivityItem(id: UUID(), kind: .materialIn, title: "Pimapen · 42 adet giriş",
                         meta: "908 Ada / 7 Parsel · İrsaliye #2210", timeText: "Sal", section: .buHafta),
            ActivityItem(id: UUID(), kind: .materialOut, title: "Kum · 24 ton çıkış",
                         meta: "145 Ada / 2 Parsel · Cephe sıva", timeText: "Pzt", section: .buHafta),
            ActivityItem(id: UUID(), kind: .materialOut, title: "Alçı · 120 torba çıkış",
                         meta: "1224 Ada / 1 Parsel · 2. kat saten perdah", timeText: "Çar", section: .buHafta),
        ]

        // ---- Şantiye fotoğraf yuvaları (ekran 09) ---------------------------
        let currentWeek = ["05 Ağu", "05 Ağu", "04 Ağu", "03 Ağu", "02 Ağu", "02 Ağu"]
        let lastWeek = ["29 Tem", "28 Tem", "27 Tem", "26 Tem", "25 Tem", "24 Tem"]
        for date in currentWeek {
            sitePhotos.append(SitePhoto(id: UUID(), projectId: "p1", dateText: date,
                                        isCurrentWeek: true, imageData: nil))
        }
        for date in lastWeek {
            sitePhotos.append(SitePhoto(id: UUID(), projectId: "p1", dateText: date,
                                        isCurrentWeek: false, imageData: nil))
        }
    }
}
