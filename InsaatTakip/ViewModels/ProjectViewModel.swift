import SwiftUI

// MARK: - ProjectViewModel
// Uygulamanın tüm iş mantığı ve verisi burada toplanır (MVVM).
// Henüz bir veritabanı bağlı değil; tasarım dosyasındaki senaryoyu birebir
// yansıtan gerçekçi mock verilerle çalışır:
//   · 145 Ada / 2 Parsel (Çayırova) — 20 daire, 12 satış, 9 kalem malzeme
//   · 1287 Ada / 14 Parsel (Nilüfer) — temel aşamasında
//   · 908 Ada / 7 Parsel (Kepez) — teslim aşamasında, tamamı satılmış
// View'lar "dumb" kalır; filtreleme, toplama ve yetki kuralları buradadır.

// Tüm durum güncellemeleri ana aktörde yapılır; @Published alanların arka
// plandan yazılması (SwiftUI'da kararsız davranış) derleyici tarafından engellenir.
@MainActor
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
    @Published var apartmentPhotos: [ApartmentPhoto] = []   // Daire görselleri
    /// Fiş fotoğrafları — hareket kimliğine göre (kamerayla çekilen irsaliye).
    @Published var receiptImages: [UUID: UIImage] = [:]

    /// Ekran altında beliren onay bildirimi.
    @Published var toast: String?

    /// Bildirim zilindeki okunmamış işareti.
    @Published var hasUnreadActivity = true

    private var toastTask: Task<Void, Never>?

    init() {
        loadMockData()
    }

    // MARK: - Üyelik (kim hangi projeyi görür)

    /// Kullanıcının erişebildiği projeler.
    /// · Yönetici → kurduğu projeler (ownerId)
    /// · Ortak    → yalnızca davetle katıldığı projeler (Partner.userId)
    /// Önceden dashboard TÜM projeleri listeliyordu; bir projeye davet edilen
    /// ortak, diğer projelerin alıcı adlarını ve cirosunu da görüyordu.
    func visibleProjects(for user: User?) -> [Project] {
        guard let user else { return [] }
        switch user.role {
        case .admin:
            return projects.filter { $0.ownerId == user.id }
        case .partner:
            let memberOf = Set(partners.filter { $0.userId == user.id }.map(\.projectId))
            return projects.filter { memberOf.contains($0.id) }
        }
    }

    /// Kullanıcı bu projeyi görebiliyor mu? (Derin bağlantı / eski rota koruması)
    func canAccess(projectId: String, user: User?) -> Bool {
        visibleProjects(for: user).contains { $0.id == projectId }
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

    /// Belge tarihlerinden (Fmt.makeDate(12, 1, 2026)) en yenisini bulur; başlıktaki "son yükleme" için.
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

    /// Bir dairenin görselleri (yer tutucular dahil).
    func photos(forApartment apartmentId: String) -> [ApartmentPhoto] {
        apartmentPhotos.filter { $0.apartmentId == apartmentId }
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

    /// Dashboard alt başlığı — yalnızca kullanıcının eriştiği projeleri sayar.
    func dashboardSubtitle(for user: User?) -> String {
        let visible = visibleProjects(for: user)
        let apartmentTotal = visible.reduce(0) { $0 + $1.totalApartments }
        return "\(visible.count) proje · \(apartmentTotal) daire · Bugün \(Fmt.clock()) güncellendi"
    }

    // MARK: - Yönetici işlemleri (yetki kontrolü çağıran ekranda + burada)

    /// Fiş / malzeme hareketi kaydeder. Boş miktar tasarım gereği "Miktar girilmedi" uyarısı verir.
    /// - Returns: Kayıt başarılıysa true.
    @discardableResult
    func addReceipt(role: UserRole, materialId: String, type: MaterialLog.LogType,
                    amountText: String, unitPriceText: String, reference: String,
                    receiptImage: UIImage? = nil) -> Bool {
        guard role == .admin else { return false }   // Ortak veri giremez
        guard let index = materials.firstIndex(where: { $0.id == materialId }) else {
            flash("Malzeme seçilmedi")
            return false
        }

        let amount = Self.parseNumber(amountText)
        guard amount > 0 else {
            flash("Miktar girilmedi")
            return false
        }

        var material = materials[index]
        // Kayda geçen miktar, stoğa uygulanan miktarla daima aynıdır:
        // çıkışta stok yetmiyorsa sessizce kırpmak yerine işlemi reddederiz.
        let effectivePrice: Double

        if type == .entry {
            let newPrice = Self.parseNumber(unitPriceText)
            // Fiyat yalnızca bu girişe uygulanır; geçmiş stok yeniden fiyatlanmaz.
            effectivePrice = newPrice > 0 ? newPrice : material.unitPrice
            material.totalIn += amount
            material.accruedCost += amount * effectivePrice
            if newPrice > 0 { material.unitPrice = newPrice }   // sonraki fişlere ön dolum
        } else {
            guard material.currentStock >= amount else {
                flash("Stok yetersiz · kalan \(Fmt.qty(material.currentStock, unit: material.unit))")
                return false
            }
            effectivePrice = material.unitPrice
            material.totalOut += amount
        }
        materials[index] = material

        let note = reference.isEmpty
            ? (type == .entry ? "İrsaliye kaydı" : "Saha kullanımı")
            : reference
        let log = MaterialLog(id: UUID(), materialId: materialId, type: type,
                              amount: amount, unitPrice: effectivePrice,
                              date: Date(),
                              note: note, user: User.admin.name)
        materialLogs.insert(log, at: 0)
        // Kamerayla çekilen fiş görseli hareketle birlikte saklanır.
        if let receiptImage { receiptImages[log.id] = receiptImage }

        // Hareket akışına düşür.
        let verb = type == .entry ? "giriş" : "çıkış"
        let project = projects.first { $0.id == material.projectId }
        activities.insert(ActivityItem(id: UUID(),
                                       kind: type == .entry ? .materialIn : .materialOut,
                                       title: "\(material.name) · \(Fmt.qty(amount, unit: material.unit)) \(verb)",
                                       meta: "\(project?.title ?? "") · \(note)",
                                       timestamp: Date()), at: 0)
        hasUnreadActivity = true
        flash("Fiş kaydedildi")
        return true
    }

    /// Projenin inşaat ilerlemesini ve yapım aşamasını günceller.
    /// Bu iki alan dashboard kartının en büyük görsel öğesi; düzenlenemediği için
    /// kullanıcının açtığı her proje sonsuza dek "%0 · Temel" görünüyordu.
    func updateProgress(role: UserRole, projectId: String, progress: Int, phase: ProjectPhase) {
        guard role == .admin,
              let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].progress = min(100, max(0, progress))
        projects[index].phase = phase
        flash("İlerleme güncellendi")
    }

    /// Satışı iptal eder; daire tekrar boşa döner.
    /// Yanlış daireye satış işlemek tek dokunuşla mümkün olduğu için geri dönüş şart.
    /// Liste fiyatı (TOKİ gerçek verisi) korunur — satış formunda yeniden önerilir.
    @discardableResult
    func cancelSale(role: UserRole, apartmentId: String) -> Bool {
        guard role == .admin else { return false }
        guard let index = apartments.firstIndex(where: { $0.id == apartmentId }),
              apartments[index].isSold else { return false }

        var apartment = apartments[index]
        let buyer = apartment.buyerName ?? ""
        let price = apartment.price

        apartment.status = .available
        apartment.buyerName = nil
        apartment.paidAmount = 0
        apartment.paymentStatus = nil
        apartment.saleDate = nil
        apartments[index] = apartment

        // İptal de bir harekettir; ortakların akışında görünmeli (şeffaflık).
        let projectTitle = projects.first { $0.id == apartment.projectId }?.title ?? ""
        activities.insert(ActivityItem(id: UUID(), kind: .sale,
                                       title: "Daire No \(apartment.apartmentNumber) satışı iptal edildi",
                                       meta: "\(projectTitle) · \(buyer) · \(Fmt.compactMoney(price))",
                                       timestamp: Date()), at: 0)
        hasUnreadActivity = true
        flash("Satış iptal edildi")
        return true
    }

    /// Projeye yeni malzeme kalemi tanımlar (varsayılan katalog dışındakiler için).
    /// Rozet kodu verilmezse addan türetilir: "Seramik" → "SER".
    @discardableResult
    func addMaterial(role: UserRole, projectId: String, name: String, subtitle: String,
                     unit: String, unitPriceText: String) -> Material? {
        guard role == .admin else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            flash("Malzeme adı girilmedi")
            return nil
        }
        guard !trimmedUnit.isEmpty else {
            flash("Birim girilmedi")
            return nil
        }

        let code = Self.badgeCode(from: trimmedName)
        // Aynı projede aynı kod varsa sonuna sayı eklenir (kimlikler çakışmasın).
        let existingCodes = Set(materials(for: projectId).map(\.code))
        var uniqueCode = code
        var suffix = 2
        while existingCodes.contains(uniqueCode) {
            uniqueCode = "\(code)\(suffix)"
            suffix += 1
        }

        let material = Material(id: "\(projectId)-\(uniqueCode)", projectId: projectId,
                                code: uniqueCode, name: trimmedName,
                                subtitle: subtitle.trimmingCharacters(in: .whitespaces),
                                unit: trimmedUnit,
                                unitPrice: Self.parseNumber(unitPriceText),
                                totalIn: 0, totalOut: 0,
                                step: 10, accruedCost: 0)
        materials.append(material)
        flash("\(trimmedName) eklendi")
        return material
    }

    /// "Nervürlü Demir" → "NER" · "Q" → "Q" (en fazla 3 harf, Türkçe büyük harf).
    static func badgeCode(from name: String) -> String {
        let letters = name.uppercased(with: Fmt.locale).filter { $0.isLetter || $0.isNumber }
        return String(letters.prefix(3))
    }

    /// Daire satışı ekler veya mevcut satış kaydını günceller.
    @discardableResult
    func saveSale(role: UserRole, apartmentId: String, buyerName: String,
                  priceText: String, paidText: String, payment: PaymentStatus, saleDate: Date? = nil) -> Bool {
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
        apartment.saleDate = saleDate ?? apartment.saleDate ?? Date()
        apartments[index] = apartment

        if isNewSale {
            // Akışta hangi projenin dairesi olduğu görünmeli — malzeme kayıtlarıyla aynı düzen.
            let projectTitle = projects.first { $0.id == apartment.projectId }?.title ?? ""
            let payNote: String
            switch payment {
            case .tamamlandi: payNote = "Tahsil edildi"
            case .kapora:     payNote = "Kapora alındı"
            case .taksitli:   payNote = "Taksit planı başladı"
            }
            activities.insert(ActivityItem(id: UUID(), kind: .sale,
                                           title: "Daire No \(apartment.apartmentNumber) satıldı — \(Fmt.compactMoney(price))",
                                           meta: "\(projectTitle) · \(trimmedBuyer) · \(payNote)",
                                           timestamp: Date()), at: 0)
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
                              phase: .temel, progress: 0, ownerId: User.admin.id, invite: nil, photoCount: 0)
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
                                        paymentStatus: nil, saleDate: nil,
                                        deliveryNote: "Yapım sürüyor"))
        }

        // Standart malzeme kataloğu sıfır stokla açılır — aksi halde "Fiş Ekle"
        // formunda seçilecek malzeme olmaz ve kaydetme sessizce başarısız olurdu.
        for item in Self.materialCatalog {
            materials.append(Material(id: "\(project.id)-\(item.code)", projectId: project.id,
                                      code: item.code, name: item.name, subtitle: item.subtitle,
                                      unit: item.unit, unitPrice: item.price,
                                      totalIn: 0, totalOut: 0, step: item.step, accruedCost: 0))
        }

        // Projeyi kuran yönetici, hisse dağılımının tamamıyla ilk ortak olur.
        partners.append(Partner(id: UUID(), projectId: project.id, name: User.admin.name,
                                isFounder: true,
                                joinedAt: Date(),
                                sharePercent: 100, userId: User.admin.id))

        flash("Proje oluşturuldu")
        return project
    }

    /// Yeni projelerde açılan standart malzeme kalemleri (mock verideki katalogla aynı).
    static let materialCatalog: [(code: String, name: String, subtitle: String, unit: String, price: Double, step: Double)] = [
        ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 500),
        ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 50),
        ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 50),
        ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 1_000),
        ("EPS", "Strafor", "5 cm cephe levhası", "m²", 96, 100),
        ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 10),
        ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 20),
        ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 25),
        ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 25),
    ]

    // MARK: Davet kodu

    /// Projeye 48 saat geçerli, tek kullanımlık davet kodu üretir.
    /// Aynı kod başka bir projede kullanımdaysa yeniden üretilir.
    func generateInviteCode(role: UserRole, projectId: String) {
        guard role == .admin,
              let index = projects.firstIndex(where: { $0.id == projectId }) else { return }

        var code = InviteCode.generate()
        let activeCodes = Set(projects.compactMap { $0.invite?.isUsable == true ? $0.invite?.code : nil })
        var attempts = 0
        while activeCodes.contains(code), attempts < 20 {
            code = InviteCode.generate()
            attempts += 1
        }
        projects[index].invite = Invite(code: code, createdAt: Date())
    }

    /// Davet kodunu kullanır: kodu GERÇEK bir projeyle eşler, süresini ve tek
    /// kullanım kuralını denetler, kullanıcıyı o projenin ortağı yapar.
    /// Önceden 6 haneli her kod kabul ediliyor ve kod hiçbir projeye bağlanmıyordu.
    enum JoinResult: Equatable {
        case success(projectTitle: String)
        case notFound        // böyle bir davet yok
        case expired         // 48 saat dolmuş
        case alreadyUsed     // kod harcanmış
        case alreadyMember   // kullanıcı zaten bu projenin ortağı
    }

    func redeemInvite(code rawCode: String, user: User) -> JoinResult {
        let code = InviteCode.sanitize(rawCode)
        guard let index = projects.firstIndex(where: { $0.invite?.code == code }) else {
            return .notFound
        }
        guard let invite = projects[index].invite else { return .notFound }
        if invite.isUsed { return .alreadyUsed }
        if invite.isExpired { return .expired }

        let project = projects[index]
        if partners.contains(where: { $0.projectId == project.id && $0.userId == user.id }) {
            return .alreadyMember
        }

        // Kod harcanır — tek kullanımlık.
        projects[index].invite?.usedAt = Date()
        projects[index].invite?.usedByName = user.name

        // Hisse yüzdesi yönetici tarafından sonradan tanımlanır (Faz 3: ortak cari hesabı).
        partners.append(Partner(id: UUID(), projectId: project.id, name: user.name,
                                isFounder: false,
                                joinedAt: Date(),
                                sharePercent: 0,
                                userId: user.id))

        activities.insert(ActivityItem(id: UUID(), kind: .partnerJoined,
                                       title: "\(user.name) projeye katıldı",
                                       meta: "\(project.title) · davet kodu ile · salt okunur",
                                       timestamp: Date()), at: 0)
        hasUnreadActivity = true
        return .success(projectTitle: project.title)
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
                                  date: Date(),
                                  partnerVisible: partnerVisible)
        documents.insert(doc, at: 0)
        flash("Dosya yüklendi")
    }

    /// Daireye (küçültülmüş) görsel ekler — galeriden veya kameradan.
    func addApartmentPhotos(role: UserRole, apartmentId: String, images: [UIImage]) {
        guard role == .admin, !images.isEmpty else { return }
        let existing = photos(forApartment: apartmentId).count
        for (offset, image) in images.enumerated() {
            apartmentPhotos.append(ApartmentPhoto(id: UUID(), apartmentId: apartmentId,
                                                  label: "Görsel \(existing + offset + 1)",
                                                  image: image))
        }
        flash(images.count == 1 ? "Görsel eklendi" : "\(images.count) görsel eklendi")
    }

    /// Daire görselini siler (yalnızca yönetici).
    func removeApartmentPhoto(role: UserRole, photoId: UUID) {
        guard role == .admin else { return }
        apartmentPhotos.removeAll { $0.id == photoId }
        flash("Görsel silindi")
    }

    /// Galeriden seçilen (küçültülmüş) şantiye fotoğraflarını bu haftaya ekler.
    /// Küçültme çağıran tarafta, arka planda yapılır — burada yalnızca hazır görseller beklenir.
    func addSitePhotos(role: UserRole, projectId: String, images: [UIImage]) {
        guard role == .admin, !images.isEmpty else { return }
        for image in images {
            sitePhotos.insert(SitePhoto(id: UUID(), projectId: projectId,
                                        date: Date(), image: image), at: 0)
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

    /// Seçilen dönemin tarih aralığı. Metin ayrıştırma yerine takvim kullanılır;
    /// yıl sınırı, artık yıl ve ay uzunlukları Foundation'a bırakılır.
    private func dateRange(for period: ReportPeriod) -> (range: DateInterval?, title: String) {
        let calendar = Fmt.calendar
        let now = Date()

        switch period {
        case .buAy:
            let interval = calendar.dateInterval(of: .month, for: now)
            let name = Self.monthNames[calendar.component(.month, from: now) - 1]
            return (interval, name.uppercased(with: Fmt.locale) + " AYI ÖZETİ")

        case .ceyrek:
            let interval = calendar.dateInterval(of: .quarter, for: now)
            let quarter = (calendar.component(.month, from: now) - 1) / 3 + 1
            return (interval, "\(quarter). ÇEYREK ÖZETİ")

        case .tumu:
            return (nil, "PROJE GENELİ ÖZET")   // nil = tarih filtresi yok
        }
    }

    /// Seçilen dönemin özet tablosu.
    func reportSummary(for projectId: String, period: ReportPeriod) -> ReportSummary {
        let (range, title) = dateRange(for: period)

        let sold = apartments(for: projectId).filter { apartment in
            guard apartment.isSold, let saleDate = apartment.saleDate else { return false }
            guard let range else { return true }   // "Tümü"
            return range.contains(saleDate)
        }
        let sales = sold.reduce(0) { $0 + $1.price }
        let collected = sold.reduce(0) { $0 + $1.paidAmount }

        // Malzeme gideri:
        //  · "Tümü" → projenin birikmiş toplam maliyeti (kayıt öncesi alımlar dahil)
        //  · ay/çeyrek → yalnızca o dönemde KAYITLI giriş fişleri, her biri
        //    kendi tarihindeki dondurulmuş fiyatıyla (sonraki zamlar geçmişi değiştirmez)
        let cost: Double
        let materialIds = Set(materials(for: projectId).map(\.id))
        if let range {
            cost = materialLogs.reduce(0) { sum, log in
                guard log.type == .entry, materialIds.contains(log.materialId),
                      range.contains(log.date) else { return sum }
                return sum + log.amount * log.unitPrice
            }
        } else {
            cost = totalMaterialCost(for: projectId)
        }

        return ReportSummary(title: title, soldCount: sold.count,
                             salesTotal: sales, collectedTotal: collected, materialCost: cost)
    }

    /// Son 6 tamamlanmış ayın satış çubukları — yıl sınırını takvim aşar.
    /// (Ocak'ta önceki yılın Tem–Ara'sını gösterir; grafik hiçbir ayda boş kalmaz.)
    func monthlySales(for projectId: String) -> [MonthBar] {
        let calendar = Fmt.calendar
        let sold = apartments(for: projectId).compactMap { $0.isSold ? $0 : nil }

        return (1...6).compactMap { offset in
            // 6 ay geriden bir önceki aya kadar
            guard let monthStart = calendar.date(byAdding: .month, value: offset - 7, to: Date()),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { return nil }

            let total = sold.reduce(0.0) { sum, apartment in
                guard let saleDate = apartment.saleDate, interval.contains(saleDate) else { return sum }
                return sum + apartment.price
            }
            let label = Self.monthNames[calendar.component(.month, from: monthStart) - 1]
            return MonthBar(label: label, value: total)
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
    /// Kapatma işi doğrudan ana aktörde çalışır; @Published güncellemesi
    /// hiçbir zaman arka plandan yapılmaz (Swift 6 uyumlu).
    func flash(_ message: String) {
        toastTask?.cancel()
        withAnimation { toast = message }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self?.toast = nil }
        }
    }

    /// "12.500" / "28,50" gibi tr-TR girdilerini sayıya çevirir.
    /// Çok uzun rakam dizileri Double'da `inf`e taşar ve modele NaN sokar
    /// ("Ciro +∞ ₺", "Kalan NaN"); bu yüzden sonuç sonlu bir aralığa sıkıştırılır.
    static func parseNumber(_ text: String) -> Double {
        let normalized = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value >= 0 else { return 0 }
        return min(value, maxAmount)
    }

    /// Tek bir tutarın / miktarın kabul edilen üst sınırı (1 trilyon).
    static let maxAmount: Double = 1e12
}

// MARK: - Mock Veri
// Tasarım dosyasındaki ekranların birebir veri seti.

extension ProjectViewModel {

    private func loadMockData() {
        // ---- Projeler --------------------------------------------------------
        // "kars309": GERÇEK proje — TOKİ Kars Karacaören 309 Konut, Ada 1224 / Parsel 1,
        // SF-1 Blok 1 (Zemin+2 kat, 12 daire, tamamı 3+1 · 111,55 m² brüt / 88,5 m² net).
        // Kaynak: TOKİ resmî fiyat listesi (29 Ağu 2024) — DemoAssets/ içinde yerel kopyası var.
        // GERÇEK TAKVİM: Karacaören konutlarının teslimatı 5-30 Mayıs 2025'te başladı
        // (toki.gov.tr haberi) — iki blok da Teslim fazında, ilerleme %100.
        projects = [
            Project(id: "p1", blockNumber: "145", parcelNumber: "2", district: "Çayırova", city: "Kocaeli",
                    floors: 5, totalApartments: 20, phase: .kabaInsaat, progress: 68, ownerId: User.admin.id, invite: nil, photoCount: 48),
            Project(id: "p2", blockNumber: "1287", parcelNumber: "14", district: "Nilüfer", city: "Bursa",
                    floors: 4, totalApartments: 12, phase: .temel, progress: 34, ownerId: User.admin.id, invite: nil, photoCount: 12),
            Project(id: "p3", blockNumber: "908", parcelNumber: "7", district: "Kepez", city: "Antalya",
                    floors: 3, totalApartments: 8, phase: .teslim, progress: 96, ownerId: User.admin.id, invite: nil, photoCount: 64),
            Project(id: "kars309", blockNumber: "1224", parcelNumber: "1", district: "Karacaören", city: "Kars",
                    floors: 3, totalApartments: 12, phase: .teslim, progress: 100, ownerId: User.admin.id, invite: nil, photoCount: 0),
            // "kars327": GERÇEK proje — TOKİ Kars Karacaören 327 Konut, Ada 1139 / Parsel 3,
            // GB Blok 1 (1 bodrum + zemin + 4 normal kat, 22 daire, 3+1 · 103,8 m² brüt / 83,9 m² net).
            Project(id: "kars327", blockNumber: "1139", parcelNumber: "3", district: "Karacaören", city: "Kars",
                    floors: 6, totalApartments: 22, phase: .teslim, progress: 100, ownerId: User.admin.id, invite: nil, photoCount: 0),
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
                let scaledIn = (totalIn * factor).rounded()
                materials.append(Material(id: "\(project.id)-\(code)", projectId: project.id,
                                          code: code, name: name, subtitle: subtitle, unit: unit,
                                          unitPrice: price,
                                          totalIn: scaledIn,
                                          totalOut: (totalOut * factor).rounded(),
                                          step: step,
                                          accruedCost: scaledIn * price))
            }
        }

        // kars309 malzemeleri — MÜHENDİSLİK TAHMİNİ (proje bazlı malzeme verisi kamuya açık değildir).
        // Taban: 12 daire × 111,55 m² brüt × 1,15 ortak alan payı ≈ 1.540 m² inşaat alanı.
        // Katsayılar (betonarme konut için yaygın değerler): demir 40 kg/m², beton 0,35 m³/m²,
        // çimento 0,7 torba/m², tuğla 45 adet/m², alçı 0,45 torba/m²; cephe ≈ 810 m² (mantolama),
        // doğrama 12 daire × 7 adet. Proje TESLİM EDİLDİ (May 2025) — stoklar kapanış durumunda.
        let karsMaterials: [(String, String, String, String, Double, Double, Double, Double)] = [
            ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 61_500, 61_200, 500),
            ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 540, 540, 50),
            ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 1_080, 1_060, 50),
            ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 69_500, 69_000, 1_000),
            ("EPS", "Strafor", "5 cm mantolama levhası", "m²", 96, 810, 810, 100),
            ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 84, 84, 10),
            ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 340, 335, 20),
            ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 750, 740, 25),
            ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 690, 685, 25),
        ]
        for (code, name, subtitle, unit, price, totalIn, totalOut, step) in karsMaterials {
            materials.append(Material(id: "kars309-\(code)", projectId: "kars309",
                                      code: code, name: name, subtitle: subtitle, unit: unit,
                                      unitPrice: price, totalIn: totalIn, totalOut: totalOut,
                                      step: step, accruedCost: totalIn * price))
        }

        // kars327 GB Blok 1 malzemeleri — aynı katsayılarla tahmin:
        // 22 daire × 103,8 m² brüt × 1,15 ≈ 2.626 m² inşaat alanı. TESLİM EDİLDİ — kapanış stokları.
        let kars327Materials: [(String, String, String, String, Double, Double, Double, Double)] = [
            ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 105_000, 104_500, 500),
            ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 920, 920, 50),
            ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 1_840, 1_815, 50),
            ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 118_000, 117_000, 1_000),
            ("EPS", "Strafor", "5 cm mantolama levhası", "m²", 96, 1_320, 1_320, 100),
            ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 154, 154, 10),
            ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 580, 572, 20),
            ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 1_260, 1_245, 25),
            ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 1_180, 1_170, 25),
        ]
        for (code, name, subtitle, unit, price, totalIn, totalOut, step) in kars327Materials {
            materials.append(Material(id: "kars327-\(code)", projectId: "kars327",
                                      code: code, name: name, subtitle: subtitle, unit: unit,
                                      unitPrice: price, totalIn: totalIn, totalOut: totalOut,
                                      step: step, accruedCost: totalIn * price))
        }

        // ---- Malzeme hareket geçmişi ----------------------------------------
        // Demir kayıtları ekran 03'teki değerlerin birebir aynısı; diğer kalemler
        // aynı tarih/irsaliye düzeniyle kendi miktarlarından türetilir.
        let admin = User.admin.name
        for material in materials where material.projectId == "p1" {
            if material.code == "Ø12" {
                materialLogs.append(contentsOf: [
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 6_800,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(2, 8, 2026), note: "5. kat perde donatısı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: 12_500,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(28, 7, 2026), note: "İrsaliye #4471 · Yılmaz Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 4_600,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(21, 7, 2026), note: "4. kat döşeme imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: 14_000,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(14, 7, 2026), note: "İrsaliye #4398 · Ege Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 3_900,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(6, 7, 2026), note: "3. kat kolon donatısı", user: admin),
                ])
            } else {
                let round: (Double) -> Double = { value in
                    let unitStep = max(1, material.step / 5)
                    return max(unitStep, (value / unitStep).rounded() * unitStep)
                }
                materialLogs.append(contentsOf: [
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.16),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(2, 8, 2026), note: "5. kat imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: round(material.totalIn * 0.21),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(28, 7, 2026), note: "İrsaliye #4471 · Yılmaz Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.11),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(21, 7, 2026), note: "4. kat imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: round(material.totalIn * 0.28),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(14, 7, 2026), note: "İrsaliye #4398 · Ege Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.09),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(6, 7, 2026), note: "3. kat imalatı", user: admin),
                ])
            }
        }

        // Kars hareketleri — teslim (May 2025) öncesi son imalat kayıtları (temsilî akış).
        // Fiyatlar kayıt anındaki değerlerdir; sonraki zamlar bu kayıtları etkilemez.
        materialLogs.append(contentsOf: [
            MaterialLog(id: UUID(), materialId: "kars309-ALÇ", type: .exit, amount: 120,
                        unitPrice: 210, date: Fmt.makeDate(18, 3, 2025), note: "Saten perdah tamamlandı", user: admin),
            MaterialLog(id: UUID(), materialId: "kars309-EPS", type: .exit, amount: 90,
                        unitPrice: 96, date: Fmt.makeDate(4, 3, 2025), note: "Cephe mantolama kapanışı", user: admin),
            MaterialLog(id: UUID(), materialId: "kars309-Ø12", type: .entry, amount: 9_500,
                        unitPrice: 28.5, date: Fmt.makeDate(11, 2, 2025), note: "İrsaliye #2087 · Kars Demir Çelik", user: admin),
            MaterialLog(id: UUID(), materialId: "kars309-Ø12", type: .exit, amount: 4_200,
                        unitPrice: 28.5, date: Fmt.makeDate(27, 2, 2025), note: "Çevre duvarı donatısı", user: admin),
            MaterialLog(id: UUID(), materialId: "kars327-ALÇ", type: .exit, amount: 150,
                        unitPrice: 210, date: Fmt.makeDate(8, 4, 2025), note: "Son kat saten perdah", user: admin),
            MaterialLog(id: UUID(), materialId: "kars327-PVC", type: .entry, amount: 30,
                        unitPrice: 6_800, date: Fmt.makeDate(21, 3, 2025), note: "İrsaliye #3141 · Serhat PVC", user: admin),
            MaterialLog(id: UUID(), materialId: "kars327-EPS", type: .exit, amount: 160,
                        unitPrice: 96, date: Fmt.makeDate(14, 4, 2025), note: "Güney cephe mantolama kapanışı", user: admin),
        ])

        // ---- Daireler --------------------------------------------------------
        // 145 Ada / 2 Parsel: 12 satış — alıcı, bedel, ödeme ve tahsilat değerleri
        // ekran 04'teki kartların birebir aynısı. (Tahsilat 28,12 M · Kalan 14,53 M)
        let types = [("2+1", "95 m²"), ("3+1", "128 m²"), ("3+1", "132 m²"), ("2+1", "98 m²")]

        // (daireNo, alıcı, bedel, ödeme, tahsil edilen, tarih)
        let p1Sales: [(Int, String, Double, PaymentStatus, Double, Date)] = [
            (1, "Ahmet Yılmaz", 3_150_000, .tamamlandi, 3_150_000, Fmt.makeDate(18, 2, 2026)),
            (2, "Merve Demir", 3_650_000, .tamamlandi, 3_650_000, Fmt.makeDate(2, 3, 2026)),
            (3, "Selim Kaya", 3_700_000, .kapora, 500_000, Fmt.makeDate(14, 3, 2026)),
            (4, "Emre Şahin", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(27, 3, 2026)),
            (5, "Fatma Çelik", 3_300_000, .taksitli, 1_980_000, Fmt.makeDate(5, 4, 2026)),
            (6, "Hakan Aydın", 3_800_000, .taksitli, 2_280_000, Fmt.makeDate(19, 4, 2026)),
            (7, "Berk Koç", 3_850_000, .tamamlandi, 3_850_000, Fmt.makeDate(28, 4, 2026)),
            (8, "Nazlı Arslan", 3_350_000, .kapora, 500_000, Fmt.makeDate(9, 5, 2026)),
            (9, "Rıza Doğan", 3_450_000, .tamamlandi, 3_450_000, Fmt.makeDate(21, 5, 2026)),
            (11, "Tuğçe Öztürk", 3_900_000, .taksitli, 1_510_000, Fmt.makeDate(6, 6, 2026)),
            (13, "Cem Yıldız", 3_550_000, .tamamlandi, 3_550_000, Fmt.makeDate(17, 6, 2026)),
            (17, "Gizem Polat", 3_750_000, .kapora, 500_000, Fmt.makeDate(2, 7, 2026)),
        ]
        let p2Sales: [(Int, String, Double, PaymentStatus, Double, Date)] = [
            (1, "Ahmet Yılmaz", 3_150_000, .tamamlandi, 3_150_000, Fmt.makeDate(22, 2, 2026)),
            (2, "Merve Demir", 3_650_000, .tamamlandi, 3_650_000, Fmt.makeDate(9, 3, 2026)),
            (4, "Selim Kaya", 3_200_000, .kapora, 500_000, Fmt.makeDate(30, 3, 2026)),
            (7, "Emre Şahin", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(12, 4, 2026)),
        ]
        let p3Sales: [(Int, String, Double, PaymentStatus, Double, Date)] = [
            (1, "Kemal Ünal", 3_400_000, .tamamlandi, 3_400_000, Fmt.makeDate(14, 1, 2026)),
            (2, "Zeynep Kaplan", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(26, 1, 2026)),
            (3, "Murat Şen", 3_300_000, .tamamlandi, 3_300_000, Fmt.makeDate(8, 2, 2026)),
            (4, "Elif Kurt", 3_450_000, .tamamlandi, 3_450_000, Fmt.makeDate(24, 2, 2026)),
            (5, "Okan Güler", 3_150_000, .tamamlandi, 3_150_000, Fmt.makeDate(11, 3, 2026)),
            (6, "Derya Aksoy", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(29, 3, 2026)),
            (7, "Sinan Ateş", 3_500_000, .tamamlandi, 3_500_000, Fmt.makeDate(16, 4, 2026)),
            (8, "Pelin Erden", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(3, 5, 2026)),
        ]
        let salesByProject = ["p1": p1Sales, "p2": p2Sales, "p3": p3Sales]

        // Yalnızca kurgu projeler (p1-p3) otomatik üretilir; Kars projeleri aşağıda gerçek veriyle.
        for project in projects where salesByProject[project.id] != nil {
            let sales = salesByProject[project.id] ?? []
            let perFloor = max(1, project.totalApartments / project.floors)
            for n in 1...project.totalApartments {
                let t = types[(n - 1) % types.count]
                let sale = sales.first { $0.0 == n }
                apartments.append(Apartment(id: "\(project.id)-\(n)", projectId: project.id,
                                            apartmentNumber: n,
                                            floor: (n - 1) / perFloor + 1,
                                            type: t.0, area: t.1,
                                            status: sale == nil ? .available : .sold,
                                            buyerName: sale?.1,
                                            price: sale?.2 ?? 0,
                                            paidAmount: sale?.4 ?? 0,
                                            paymentStatus: sale?.3,
                                            saleDate: sale?.5,
                                            deliveryNote: project.phase == .teslim ? "Teslim edildi" : "Anahtar teslim bekliyor"))
            }
        }

        // Daire No 7 (ekran 13): Salon + Mutfak yer tutucu kareleri; No 1: Salon.
        for (apartmentId, labels) in [("p1-7", ["Salon", "Mutfak"]), ("p1-1", ["Salon"])] {
            for label in labels {
                apartmentPhotos.append(ApartmentPhoto(id: UUID(), apartmentId: apartmentId,
                                                      label: label, image: nil))
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
        let karsUnits: [(Int, Int, String?, Double, Double, Date?)] = [
            (1, 0, nil, 1_805_613, 0, nil),
            (2, 0, "Meryem Karaca", 1_902_563, 371_003, Fmt.makeDate(9, 1, 2025)),
            (3, 0, "Hasan Demirtaş", 1_902_563, 371_003, Fmt.makeDate(14, 1, 2025)),
            (4, 0, "Elif Doğan", 1_805_613, 352_093, Fmt.makeDate(16, 1, 2025)),
            (5, 1, nil, 2_051_221, 0, nil),
            (6, 1, "Yusuf Aslan", 2_193_416, 427_715, Fmt.makeDate(7, 1, 2025)),
            (7, 1, "Zehra Çetin", 2_193_416, 427_715, Fmt.makeDate(21, 1, 2025)),
            (8, 1, "Osman Kaya", 2_051_221, 399_986, Fmt.makeDate(23, 1, 2025)),
            (9, 2, nil, 2_025_368, 0, nil),
            (10, 2, "İbrahim Güneş", 2_167_562, 422_678, Fmt.makeDate(28, 1, 2025)),
            (11, 2, "Hatice Yavuz", 2_167_562, 422_678, Fmt.makeDate(30, 1, 2025)),
            (12, 2, "Ali Yıldırım", 2_025_368, 394_950, Fmt.makeDate(31, 1, 2025)),
        ]
        // Teslimatlar 5-30 Mayıs 2025'te yapıldı (TOKİ resmî haberi).
        for (no, floor, buyer, price, paid, date) in karsUnits {
            apartments.append(Apartment(id: "kars309-\(no)", projectId: "kars309",
                                        apartmentNumber: no, floor: floor,
                                        type: "3+1", area: "111,55 m²",
                                        status: buyer == nil ? .available : .sold,
                                        buyerName: buyer,
                                        price: price,
                                        paidAmount: paid,
                                        paymentStatus: buyer == nil ? nil : .taksitli,
                                        saleDate: date,
                                        deliveryNote: buyer == nil ? "Teslime hazır · satışta" : "Teslim edildi · May 2025"))
        }

        // kars327 GB Blok 1 daireleri — GERÇEK VERİ + EMSAL:
        // Kat düzeni: 1. Bodrum (No 1-2), Zemin (3-6), 1-4. Kat (7-22).
        // 12 dairenin bedeli TOKİ listesindeki birebir değerdir (No 1,3,6,9,10,12,13,14,17,19,20,21).
        // İlk kurada satılan 10 dairenin bedeli, kardeş GB bloklarındaki AYNI KONUMLU dairelerin
        // liste fiyatından alınmıştır (emsal). Tahsilat modeli: %10 peşinat + bedel×%0,5 aylık taksit
        // (TOKİ planının birebir oranı) — ilk kura Mar 2024 sözleşme (29 taksit ≈ %24,5),
        // Ara 2024 kurası Oca 2025 sözleşme (19 taksit ≈ %19,5). ALICI ADLARI KURGUDUR.
        // Boş: No 6, 13, 20, 21 (satış formunda gerçek liste fiyatı hazır gelir).
        // (daireNo, kat, alıcı?, bedel, tahsil edilen, sözleşme tarihi?)
        let kars327Units: [(Int, Int, String?, Double, Double, Date?)] = [
            (1, -1, "Ramazan Öz", 1_571_822, 306_505, Fmt.makeDate(3, 1, 2025)),
            (2, -1, "Sevgi Aydemir", 1_539_559, 377_192, Fmt.makeDate(12, 3, 2024)),      // emsal
            (3, 0, "Kadir Bulut", 1_781_526, 347_398, Fmt.makeDate(8, 1, 2025)),
            (4, 0, "Nuray Ekinci", 1_781_526, 436_474, Fmt.makeDate(14, 3, 2024)),        // emsal
            (5, 0, "Veli Şimşek", 1_717_002, 420_665, Fmt.makeDate(15, 3, 2024)),         // emsal
            (6, 0, nil, 1_733_133, 0, nil),
            (7, 1, "Fadime Uçar", 2_028_870, 497_073, Fmt.makeDate(18, 3, 2024)),         // emsal
            (8, 1, "Selçuk Erol", 1_910_575, 468_091, Fmt.makeDate(19, 3, 2024)),         // emsal
            (9, 1, "Melike Sarı", 1_835_297, 357_883, Fmt.makeDate(13, 1, 2025)),
            (10, 1, "Harun Tekin", 1_953_592, 380_950, Fmt.makeDate(16, 1, 2025)),
            (11, 2, "Gülay Erdem", 2_066_510, 506_295, Fmt.makeDate(21, 3, 2024)),        // emsal
            (12, 2, "Ferhat Koçak", 1_948_215, 379_902, Fmt.makeDate(20, 1, 2025)),
            (13, 2, nil, 1_872_936, 0, nil),
            (14, 2, "Şule Aksu", 1_991_231, 388_290, Fmt.makeDate(22, 1, 2025)),
            (15, 3, "Tarık Ünver", 2_012_739, 493_121, Fmt.makeDate(22, 3, 2024)),        // emsal
            (16, 3, "Aysel Turan", 2_088_018, 511_564, Fmt.makeDate(25, 3, 2024)),        // emsal
            (17, 3, "Bülent Işık", 1_894_444, 369_417, Fmt.makeDate(24, 1, 2025)),
            (18, 3, "Nazan Kurt", 1_969_723, 482_582, Fmt.makeDate(26, 3, 2024)),         // emsal
            (19, 4, "Erdal Yaman", 2_050_378, 399_824, Fmt.makeDate(27, 1, 2025)),
            (20, 4, nil, 1_932_083, 0, nil),
            (21, 4, nil, 1_856_805, 0, nil),
            (22, 4, "Songül Ateş", 1_975_100, 483_900, Fmt.makeDate(28, 3, 2024)),        // emsal
        ]
        for (no, floor, buyer, price, paid, date) in kars327Units {
            apartments.append(Apartment(id: "kars327-\(no)", projectId: "kars327",
                                        apartmentNumber: no, floor: floor,
                                        type: "3+1", area: "103,8 m²",
                                        status: buyer == nil ? .available : .sold,
                                        buyerName: buyer,
                                        price: price,
                                        paidAmount: paid,
                                        paymentStatus: buyer == nil ? nil : .taksitli,
                                        saleDate: date,
                                        deliveryNote: buyer == nil ? "Teslime hazır · satışta" : "Teslim edildi · May 2025"))
        }

        // ---- Ortaklar (ekran 05) --------------------------------------------
        // Kurucu her projede aynı yöneticidir; diğer ortaklar projeye göre değişir.
        // Uygulamayı kullanan ortak hesabı (User.partner = Serkan Aydın) yalnızca
        // p1 ve kars309'a davetlidir — üyelik filtresinin çalıştığı buradan görülür.
        let partnerSets: [String: [(String, Bool, Date, Int, UUID?)]] = [
            "p1": [
                ("Mehmet Kılıç", true, Fmt.makeDate(4, 1, 2026), 40, User.admin.id),
                ("Serkan Aydın", false, Fmt.makeDate(12, 3, 2026), 25, User.partner.id),
                ("Ayşe Tuna", false, Fmt.makeDate(3, 4, 2026), 20, nil),
                ("Burak Erdoğan", false, Fmt.makeDate(21, 4, 2026), 15, nil),
            ],
            "p2": [
                ("Mehmet Kılıç", true, Fmt.makeDate(18, 2, 2026), 60, User.admin.id),
                ("Hakan Yücel", false, Fmt.makeDate(2, 3, 2026), 40, nil),
            ],
            "p3": [
                ("Mehmet Kılıç", true, Fmt.makeDate(11, 11, 2025), 50, User.admin.id),
                ("Ayşe Tuna", false, Fmt.makeDate(20, 11, 2025), 50, nil),
            ],
            "kars309": [
                ("Mehmet Kılıç", true, Fmt.makeDate(12, 8, 2024), 55, User.admin.id),
                ("Serkan Aydın", false, Fmt.makeDate(6, 1, 2025), 45, User.partner.id),
            ],
            "kars327": [
                ("Mehmet Kılıç", true, Fmt.makeDate(12, 8, 2024), 70, User.admin.id),
                ("Burak Erdoğan", false, Fmt.makeDate(9, 1, 2025), 30, nil),
            ],
        ]
        for project in projects {
            for (name, founder, joined, share, userId) in partnerSets[project.id] ?? [] {
                partners.append(Partner(id: UUID(), projectId: project.id, name: name,
                                        isFounder: founder, joinedAt: joined,
                                        sharePercent: share, userId: userId))
            }
        }

        // ---- Belgeler (ekran 11) --------------------------------------------
        let p1Documents: [(ProjectDocument.Group, ProjectDocument.FileType, String, String, Double, Date, Bool)] = [
            (.mimari, .pdf, "Vaziyet Planı", "v3", 4.2, Fmt.makeDate(12, 1, 2026), true),
            (.mimari, .pdf, "Kat Planları (1–5)", "v5", 11.8, Fmt.makeDate(3, 2, 2026), true),
            (.mimari, .dwg, "Cephe Görünüşleri", "v2", 8.6, Fmt.makeDate(3, 2, 2026), true),
            (.statik, .pdf, "Statik Hesap Raporu", "v2", 22.4, Fmt.makeDate(18, 1, 2026), true),
            (.statik, .pdf, "Zemin Etüdü", "v1", 6.1, Fmt.makeDate(4, 1, 2026), true),
            (.ruhsat, .pdf, "Yapı Ruhsatı", "v1", 1.3, Fmt.makeDate(22, 1, 2026), true),
            (.ruhsat, .pdf, "İskân Başvurusu", "taslak", 0.8, Fmt.makeDate(14, 7, 2026), false),
        ]
        for (group, type, name, version, size, date, visible) in p1Documents {
            documents.append(ProjectDocument(id: UUID(), projectId: "p1", group: group, fileType: type,
                                             name: name, versionText: version, sizeMB: size,
                                             date: date, partnerVisible: visible))
        }
        // Diğer projelerde küçük birer dosya seti.
        for pid in ["p2", "p3"] {
            documents.append(contentsOf: [
                ProjectDocument(id: UUID(), projectId: pid, group: .mimari, fileType: .pdf,
                                name: "Vaziyet Planı", versionText: "v1", sizeMB: 3.4,
                                date: Fmt.makeDate(22, 1, 2026), partnerVisible: true),
                ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat, fileType: .pdf,
                                name: "Yapı Ruhsatı", versionText: "v1", sizeMB: 1.1,
                                date: Fmt.makeDate(30, 1, 2026), partnerVisible: true),
            ])
        }

        // kars309 + kars327 belgeleri — TOKİ'nin kamuya açık gerçek evrakları (toki.gov.tr/satis).
        // Fiyat listesi ve duyuru her iki Karacaören projesini de kapsar.
        for pid in ["kars309", "kars327"] {
            documents.append(contentsOf: [
                ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat, fileType: .pdf,
                                name: "TOKİ 83 Konut Fiyat Listesi", versionText: "resmî", sizeMB: 0.2,
                                date: Fmt.makeDate(29, 8, 2024), partnerVisible: true),
                ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat, fileType: .pdf,
                                name: "Satış-Kura Duyurusu", versionText: "resmî", sizeMB: 0.1,
                                date: Fmt.makeDate(16, 12, 2024), partnerVisible: true),
                ProjectDocument(id: UUID(), projectId: pid, group: .sozlesme, fileType: .pdf,
                                name: "Sözleşme Dönemi Bilgilendirmesi", versionText: "resmî", sizeMB: 0.1,
                                date: Fmt.makeDate(2, 1, 2025), partnerVisible: true),
            ])
        }

        // ---- Hareket akışı (ekran 07) ---------------------------------------
        activities = [
            ActivityItem(id: UUID(), kind: .materialIn, title: "Demir · 12.500 kg giriş",
                         meta: "145 Ada / 2 Parsel · İrsaliye #4471", timestamp: Fmt.daysAgo(0, hour: 9, minute: 24)),
            ActivityItem(id: UUID(), kind: .sale, title: "Daire No 17 satıldı — 3,75 M ₺",
                         meta: "145 Ada / 2 Parsel · Gizem Polat · Kapora alındı", timestamp: Fmt.daysAgo(0, hour: 8, minute: 10)),
            ActivityItem(id: UUID(), kind: .materialOut, title: "Çimento · 180 torba çıkış",
                         meta: "145 Ada / 2 Parsel · 5. kat şap", timestamp: Fmt.daysAgo(1, hour: 16, minute: 40)),
            ActivityItem(id: UUID(), kind: .partnerJoined, title: "Burak Erdoğan projeye katıldı",
                         meta: "145 Ada / 2 Parsel · davet kodu ile · salt okunur", timestamp: Fmt.daysAgo(1, hour: 11, minute: 2)),
            ActivityItem(id: UUID(), kind: .materialIn, title: "Pimapen · 42 adet giriş",
                         meta: "908 Ada / 7 Parsel · İrsaliye #2210", timestamp: Fmt.daysAgo(3, hour: 10, minute: 0)),
            ActivityItem(id: UUID(), kind: .materialOut, title: "Kum · 24 ton çıkış",
                         meta: "145 Ada / 2 Parsel · Cephe sıva", timestamp: Fmt.daysAgo(3, hour: 10, minute: 0)),
        ]

        // ---- Şantiye fotoğraf yuvaları (ekran 09) ---------------------------
        // Gün sayısı bugüne göre verilir; "bu hafta / geçen hafta" ayrımını
        // SitePhoto tarihten hesaplar (sabit bayrak yarın yanlış olurdu).
        for days in [0, 0, 1, 2, 3, 3] {
            sitePhotos.append(SitePhoto(id: UUID(), projectId: "p1",
                                        date: Fmt.daysAgo(days), image: nil))
        }
        for days in [8, 9, 10, 11, 12, 13] {
            sitePhotos.append(SitePhoto(id: UUID(), projectId: "p1",
                                        date: Fmt.daysAgo(days), image: nil))
        }
    }
}
