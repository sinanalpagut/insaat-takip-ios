import XCTest
@testable import InsaatTakip

/// Yedekten geri yükleme — madde 75.
///
/// NEDEN BU TESTLER VAR: `Yedek.json` üretiliyordu ama okuyan tek satır kod
/// yoktu. Geri dönüşü olmayan bir yedek güvence değil VAAT: kullanıcı
/// "yedeğim var" diye rahatlıyor, telefonu kaybolduğunda elinde açamadığı bir
/// dosya kalıyor. Aşağıdaki testler dosyanın gerçekten geri döndüğünü ve
/// dönerken NEYİ DEĞİŞTİRDİĞİNİ sabitliyor.
@MainActor
final class BackupRestoreTests: XCTestCase {

    private let eskiSahip = "eski-uid"
    private let ortakUid = "ortak-uid"

    private func yeniKullanici() -> User {
        User(id: "yeni-uid", name: "Geri Yükleyen", role: .admin, phone: "+905550000001")
    }

    /// Elle kurulmuş yedek: rakamları biliniyor, demo veriye bağlı değil.
    ///
    /// İçine BİLEREK iki sahipsiz kayıt kondu (olmayan malzemeye ait hareket,
    /// olmayan daireye ait tahsilat) ve malzemenin TÜRETİLEN toplamları
    /// bozuldu — ikisi de ayrı birer testin konusu.
    private func yedekKur() -> ProjectExporter.Backup {
        let pid = UUID(), mid = UUID(), aid = UUID()
        let tarih = Date(timeIntervalSince1970: 1_750_000_000)

        let proje = Project(id: pid, blockNumber: "145", parcelNumber: "2",
                            district: "Gebze", city: "Kocaeli",
                            floors: 4, totalApartments: 12,
                            phase: .temel, progress: 0,
                            ownerUid: eskiSahip,
                            memberUids: [eskiSahip, ortakUid],
                            createdAt: tarih, invite: nil, photoCount: 7)

        var malzeme = Material(id: mid, projectId: pid, code: "KUM", name: "Kum",
                               subtitle: "Yıkanmış dere kumu", unit: "ton",
                               unitPrice: Kurus.kurus(95_000), step: 1)
        // BOZUK türetilmiş değerler: geri yükleme bunlara GÜVENMEMELİ.
        malzeme.totalIn = 999
        malzeme.accruedCost = Kurus.kurus(99_999_900)

        let hareket = MaterialLog(id: UUID(), projectId: pid, materialId: mid,
                                  type: .entry, amount: 12,
                                  unitPrice: Kurus.kurus(95_000),
                                  date: tarih, note: "İrsaliye #1", user: "Yönetici")
        let sahipsizHareket = MaterialLog(id: UUID(), projectId: pid,
                                          materialId: UUID(),   // böyle bir malzeme yok
                                          type: .entry, amount: 5,
                                          unitPrice: Kurus.kurus(10_000),
                                          date: tarih, note: "yetim", user: "Yönetici")

        let daire = Apartment(id: aid, projectId: pid, apartmentNumber: 1, floor: 1,
                              type: "3+1", areaM2: 120, status: .sold,
                              buyerName: nil, price: Kurus.kurus(385_000_000),
                              paidAmount: .zero, paymentStatus: .taksitli,
                              saleDate: tarih, deliveryNote: "Yapım sürüyor")

        let tahsilat = Payment(id: UUID(), projectId: pid, apartmentId: aid,
                               amount: Kurus.kurus(85_000_000), date: tarih,
                               method: .pesinat, note: "Sözleşme peşinatı", user: "Yönetici")
        let sahipsizTahsilat = Payment(id: UUID(), projectId: pid,
                                       apartmentId: UUID(),   // böyle bir daire yok
                                       amount: Kurus.kurus(1_000_00), date: tarih,
                                       method: .nakit, note: "yetim", user: "Yönetici")

        let taksit = Installment(id: UUID(), projectId: pid, apartmentId: aid,
                                 sequence: 1, dueDate: tarih,
                                 amount: Kurus.kurus(25_000_000))

        var ortak = Partner(id: UUID(), projectId: pid, name: "Serkan Aydın",
                            isFounder: false, joinedAt: tarih, sharePercent: 30)
        ortak.userUid = ortakUid

        let belge = ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat,
                                    fileType: .pdf, name: "Vaziyet Planı",
                                    versionText: "v1", sizeMB: 1.2, date: tarih,
                                    partnerVisible: true)

        let denetim = AuditEntry(id: UUID(), recordId: aid, projectId: pid,
                                 subject: "Daire No 1", action: .update,
                                 changes: [.init(field: "Bedel", oldValue: "0", newValue: "3.850.000")],
                                 user: "Yönetici", date: tarih)

        return ProjectExporter.Backup(
            surum: ProjectExporter.backupVersion, olusturma: tarih, aliciDahil: true,
            proje: proje, malzemeler: [malzeme],
            malzemeHareketleri: [hareket, sahipsizHareket],
            giderler: [], daireler: [daire],
            tahsilatlar: [tahsilat, sahipsizTahsilat],
            taksitler: [taksit], ortaklar: [ortak], ortakCari: nil, belgeler: [belge],
            alicilar: [ApartmentBuyer(apartmentId: aid, projectId: pid, name: "Berk Koç")],
            denetimIzi: [denetim])
    }

    private func turAt(_ yedek: ProjectExporter.Backup) throws -> ProjectExporter.Backup {
        let data = try XCTUnwrap(ProjectExporter.backupJSON(yedek))
        return try ProjectExporter.decodeBackup(data)
    }

    private func vm() -> ProjectViewModel {
        let vm = ProjectViewModel(repository: InMemoryProjectRepository())
        vm.actingUser = .admin
        return vm
    }

    // MARK: Mutlu yol

    /// JSON'a yazılıp geri okunan yedek, kayıtlarıyla birlikte dönmeli.
    func testRoundTripRestoresRecords() throws {
        let yedek = try turAt(yedekKur())
        let ozet = try XCTUnwrap(vm().restore(from: yedek, user: yeniKullanici()))

        XCTAssertEqual(ozet.projectTitle, "145 Ada / 2 Parsel")
        XCTAssertEqual(ozet.apartments, 1)
        XCTAssertEqual(ozet.materialLogs, 1)      // biri sahipsizdi
        XCTAssertEqual(ozet.payments, 1)          // biri sahipsizdi
        XCTAssertEqual(ozet.installments, 1)
        XCTAssertEqual(ozet.partners, 1)
        XCTAssertEqual(ozet.buyers, 1)
        XCTAssertEqual(ozet.auditEntries, 1)
        XCTAssertTrue(ozet.buyersIncluded)
    }

    /// SAHİPLİK GERİ YÜKLEYENE GEÇMELİ.
    ///
    /// Yedeğin asıl senaryosu "telefon kayboldu, yeni hesapla giriyorum".
    /// `ownerUid` eski hesapta kalsaydı kurallar geri yükleyen kişiyi de
    /// dışarıda bırakırdı: dosya elde, veri erişilemez.
    func testOwnershipMovesToRestoringUser() throws {
        let model = vm()
        let yedek = try turAt(yedekKur())
        let kullanici = yeniKullanici()
        _ = model.restore(from: yedek, user: kullanici)

        let proje = try XCTUnwrap(model.projects.first { $0.id == yedek.proje.id })
        XCTAssertEqual(proje.ownerUid, kullanici.id)
        XCTAssertEqual(proje.memberUids, [kullanici.id])
        XCTAssertNil(proje.invite, "eski davet kodu artık sunucuda yok")
        XCTAssertEqual(proje.photoCount, 0, "fotoğraflar geri gelmiyor")
        XCTAssertFalse(proje.isArchived)
    }

    /// ORTAĞIN ERİŞİMİ GERİ VERİLMEZ, adı ve hissesi kalır.
    ///
    /// Bir dosyanın içeriğine bakarak birine erişim açmak, davet akışının tüm
    /// denetimini atlamak olurdu.
    func testPartnerAccessIsNotRestored() throws {
        let model = vm()
        let yedek = try turAt(yedekKur())
        _ = model.restore(from: yedek, user: yeniKullanici())

        let ortak = try XCTUnwrap(model.partners(for: yedek.proje.id).first)
        XCTAssertEqual(ortak.name, "Serkan Aydın")
        XCTAssertEqual(ortak.sharePercent, 30)
        XCTAssertNil(ortak.userUid, "üyelik bağlantısı kopmalı")
    }

    /// TÜRETİLEN RAKAMLAR YEDEKTEN OKUNMAZ, HAM KAYITTAN HESAPLANIR.
    ///
    /// Yedekteki malzeme toplamları bilerek bozuldu (999 ton / 999.999 ₺).
    /// Geri yükleme onlara güvenseydi stok ekranı ilk açılışta yalan söylerdi.
    func testDerivedTotalsAreRecomputedNotTrusted() throws {
        let model = vm()
        let yedek = try turAt(yedekKur())
        _ = model.restore(from: yedek, user: yeniKullanici())

        let malzeme = try XCTUnwrap(model.materials(for: yedek.proje.id).first)
        XCTAssertEqual(malzeme.totalIn, 12, "toplam giren hareketten hesaplanmalı")
        XCTAssertEqual(malzeme.accruedCost, Kurus.kurus(1_140_000), "12 × 950 ₺")
    }

    /// Tahsil edilen tutar da ham tahsilatlardan hesaplanmalı.
    func testCollectedAmountIsRecomputed() throws {
        let model = vm()
        let yedek = try turAt(yedekKur())
        _ = model.restore(from: yedek, user: yeniKullanici())

        let daire = try XCTUnwrap(model.apartments(for: yedek.proje.id).first)
        XCTAssertEqual(daire.paidAmount, Kurus.kurus(85_000_000))
        XCTAssertEqual(daire.buyerName, "Berk Koç", "alıcı adı daireye bağlanmalı")
    }

    // MARK: Reddedilen durumlar

    /// AYNI PROJE DURUYORSA GERİ YÜKLEME YAPILMAZ.
    ///
    /// Üzerine yazmak, yedekten YENİ olan veriyi geri dönüşsüz yok etmek
    /// olurdu. Birleştirme de yok: iki kaydın hangisinin doğru olduğunu kimse
    /// bilemez.
    func testExistingProjectIsNotOverwritten() throws {
        let model = vm()
        let yedek = try turAt(yedekKur())
        XCTAssertNotNil(model.restore(from: yedek, user: yeniKullanici()))
        XCTAssertNil(model.restore(from: yedek, user: yeniKullanici()),
                     "ikinci geri yükleme reddedilmeli")
        XCTAssertEqual(model.projects.filter { $0.id == yedek.proje.id }.count, 1)
    }

    /// ORTAK GERİ YÜKLEYEMEZ — yazma yetkisi yönetici işi.
    func testPartnerCannotRestore() throws {
        let yedek = try turAt(yedekKur())
        let ortak = User(id: "x", name: "Ortak", role: .partner, phone: "+905550000002")
        XCTAssertNil(vm().restore(from: yedek, user: ortak))
    }

    /// SAHİPSİZ KAYITLAR DÜŞÜRÜLÜR VE SAYILIR.
    ///
    /// Sessizce alınsalardı toplamlar hiçbir ekranda açıklanamayan bir farkla
    /// şişerdi; sessizce atılsalardı kullanıcı eksiği hiç öğrenemezdi.
    func testOrphanRecordsAreDroppedAndCounted() throws {
        let yedek = try turAt(yedekKur())
        let ozet = try XCTUnwrap(vm().restore(from: yedek, user: yeniKullanici()))
        XCTAssertEqual(ozet.droppedRecords, 2)
    }

    /// BELGELER GERİ GELMEZ ve sayısı SÖYLENİR.
    ///
    /// Yedek belgelerin kaydını taşıyor, dosyasını değil; kaydı geri yüklemek
    /// dokunulduğunda açılmayan satırlar üretirdi.
    func testDocumentsAreReportedNotRestored() throws {
        let model = vm()
        let yedek = try turAt(yedekKur())
        let ozet = try XCTUnwrap(model.restore(from: yedek, user: yeniKullanici()))
        XCTAssertEqual(ozet.skippedDocuments, 1)
        XCTAssertTrue(model.documents.filter { $0.projectId == yedek.proje.id }.isEmpty)
    }

    // MARK: Dosya katmanı

    /// BİLİNMEYEN SÜRÜM REDDEDİLİR — yarım okumak en kötü sonuç olurdu.
    func testUnsupportedVersionIsRefused() throws {
        let bozuk = """
        {"surum": 99, "olusturma": "2026-08-24T00:00:00Z"}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try ProjectExporter.decodeBackup(bozuk)) { error in
            XCTAssertEqual(error as? ProjectExporter.BackupError, .unsupportedVersion(99))
        }
    }

    /// ESKİ SÜRÜM YEDEK HÂLÂ OKUNUYOR — sürüm denetimi ASİMETRİK.
    ///
    /// Madde 82 yedeğe ortak cari hesabını ekleyip sürümü 2'ye çıkardı. Eski
    /// eşitlik koşulu (`surum == backupVersion`) korunsaydı, kullanıcının
    /// kendi SÜRÜM 1 yedekleri o gün okunamaz hâle gelirdi: veri kaybını
    /// önlemek için konmuş bir kural veri kaybına sebep olurdu.
    ///
    /// Yönler AYRI: eskide kaybolacak bir şey yok (o dosyada cari hesap
    /// gerçekten yoktu), yenide sessizce düşen bir koleksiyon var — o yüzden
    /// yeni sürüm hâlâ reddediliyor (üstteki test).
    func testOlderVersionBackupStillDecodes() throws {
        let pid = UUID().uuidString
        let aid = UUID().uuidString
        // SÜRÜM 1 dosyası: `ortakCari` alanı HİÇ YOK.
        let eski = """
        {"surum":1,"olusturma":"2026-08-24T00:00:00Z","aliciDahil":false,
         "proje":{"id":"\(pid)","blockNumber":"145","parcelNumber":"2",
                  "district":"—","city":"—","floors":1,"totalApartments":1,
                  "phase":"Temel","progress":0,"ownerUid":"u1","memberUids":["u1"],
                  "createdAt":"2026-01-01T00:00:00Z","photoCount":0},
         "malzemeler":[],"malzemeHareketleri":[],"giderler":[],
         "daireler":[{"id":"\(aid)","projectId":"\(pid)","apartmentNumber":1,
                      "floor":1,"type":"3+1","status":"available",
                      "price":0,"paidAmount":0,"deliveryNote":""}],
         "tahsilatlar":[],"taksitler":[],"ortaklar":[],"belgeler":[],
         "alicilar":[],"denetimIzi":[]}
        """.data(using: .utf8)!

        let yedek = try ProjectExporter.decodeBackup(eski)
        XCTAssertEqual(yedek.surum, 1)
        XCTAssertNil(yedek.ortakCari, "sürüm 1'de cari hesap YOK — boş dizi değil, yokluk")
        XCTAssertEqual(yedek.daireler.count, 1)
    }

    /// Eski sürüm yedek gerçekten GERİ YÜKLENİYOR — yalnızca çözülmesi yetmez.
    func testOlderVersionBackupRestores() throws {
        let pid = UUID().uuidString
        let aid = UUID().uuidString
        let eski = """
        {"surum":1,"olusturma":"2026-08-24T00:00:00Z","aliciDahil":false,
         "proje":{"id":"\(pid)","blockNumber":"908","parcelNumber":"7",
                  "district":"—","city":"—","floors":1,"totalApartments":1,
                  "phase":"Temel","progress":0,"ownerUid":"u1","memberUids":["u1"],
                  "createdAt":"2026-01-01T00:00:00Z","photoCount":0},
         "malzemeler":[],"malzemeHareketleri":[],"giderler":[],
         "daireler":[{"id":"\(aid)","projectId":"\(pid)","apartmentNumber":1,
                      "floor":1,"type":"3+1","status":"available",
                      "price":0,"paidAmount":0,"deliveryNote":""}],
         "tahsilatlar":[],"taksitler":[],"ortaklar":[],"belgeler":[],
         "alicilar":[],"denetimIzi":[]}
        """.data(using: .utf8)!

        let yedek = try ProjectExporter.decodeBackup(eski)
        let model = vm()
        let ozet = try XCTUnwrap(model.restore(from: yedek, user: yeniKullanici()))
        XCTAssertEqual(ozet.apartments, 1)
        XCTAssertEqual(ozet.ledgerEntries, 0, "olmayan cari hesap sıfır sayılmalı, çökmemeli")
        XCTAssertTrue(model.projects.contains { $0.id.uuidString == pid })
    }

    /// Bozuk dosya SEBEBİYLE reddedilir.
    func testCorruptFileIsRefused() {
        let bozuk = Data("bu bir yedek değil".utf8)
        XCTAssertThrowsError(try ProjectExporter.decodeBackup(bozuk)) { error in
            XCTAssertEqual(error as? ProjectExporter.BackupError, .unreadable)
        }
    }

    /// Sürümü doğru ama gövdesi eksik dosya da reddedilmeli — sürüm kapısını
    /// geçmek tek başına dosyayı geçerli yapmıyor.
    func testTruncatedFileIsRefused() {
        let yarim = Data("""
        {"surum": 1, "olusturma": "2026-08-24T00:00:00Z"}
        """.utf8)
        XCTAssertThrowsError(try ProjectExporter.decodeBackup(yarim)) { error in
            XCTAssertEqual(error as? ProjectExporter.BackupError, .unreadable)
        }
    }

    // MARK: Kullanıcıya söylenen cümle

    /// ÖZET GELMEYENİ DE SÖYLEMELİ.
    ///
    /// "Geri yüklendi" deyip belgelerin gelmediğini yutmak, doğru bir cümleyle
    /// yanlış bir izlenim bırakmak olurdu — bu uygulamanın tekrar tekrar
    /// düzelttiği hatanın aynısı.
    func testMessageStatesWhatDidNotComeBack() throws {
        let ozet = try XCTUnwrap(vm().restore(from: turAt(yedekKur()), user: yeniKullanici()))
        let metin = ozet.message

        XCTAssertTrue(metin.contains("145 Ada / 2 Parsel"))
        XCTAssertTrue(metin.contains("1 daire"))
        XCTAssertTrue(metin.contains("belge GERİ YÜKLENMEDİ"))
        XCTAssertTrue(metin.contains("kayıt atlandı"))
        XCTAssertTrue(metin.contains("yeniden davet"))
    }

    /// Alıcı adı içermeyen yedek (ortak görünümünden alınmış) SÖYLENMELİ:
    /// yönetici, alıcıların neden boş olduğunu yoksa anlamaz.
    func testMessageWarnsWhenBuyersMissing() throws {
        var yedek = yedekKur()
        yedek = ProjectExporter.Backup(
            surum: yedek.surum, olusturma: yedek.olusturma, aliciDahil: false,
            proje: yedek.proje, malzemeler: yedek.malzemeler,
            malzemeHareketleri: yedek.malzemeHareketleri, giderler: yedek.giderler,
            daireler: yedek.daireler, tahsilatlar: yedek.tahsilatlar,
            taksitler: yedek.taksitler, ortaklar: yedek.ortaklar,
            ortakCari: yedek.ortakCari,
            belgeler: yedek.belgeler, alicilar: [], denetimIzi: yedek.denetimIzi)

        let ozet = try XCTUnwrap(vm().restore(from: turAt(yedek), user: yeniKullanici()))
        XCTAssertFalse(ozet.buyersIncluded)
        XCTAssertTrue(ozet.message.contains("Alıcı adları yedeğe girmemiş"))
    }

    /// Temiz bir yedekte GEREKSİZ uyarı çıkmamalı — her seferinde uyaran bir
    /// özet, okunmayan bir özet olur.
    func testMessageIsQuietWhenNothingWasLost() throws {
        let pid = UUID()
        let tarih = Date(timeIntervalSince1970: 1_750_000_000)
        let proje = Project(id: pid, blockNumber: "900", parcelNumber: "7",
                            district: "—", city: "—", floors: 1, totalApartments: 1,
                            phase: .temel, progress: 0, ownerUid: eskiSahip,
                            memberUids: [eskiSahip], createdAt: tarih,
                            invite: nil, photoCount: 0)
        let daire = Apartment(id: UUID(), projectId: pid, apartmentNumber: 1, floor: 1,
                              type: "—", areaM2: nil, status: .available,
                              buyerName: nil, price: .zero, paidAmount: .zero,
                              paymentStatus: nil, saleDate: nil, deliveryNote: "")
        let temiz = ProjectExporter.Backup(
            surum: ProjectExporter.backupVersion, olusturma: tarih, aliciDahil: true,
            proje: proje, malzemeler: [], malzemeHareketleri: [], giderler: [],
            daireler: [daire], tahsilatlar: [], taksitler: [], ortaklar: [],
            ortakCari: nil, belgeler: [], alicilar: [], denetimIzi: [])

        let ozet = try XCTUnwrap(vm().restore(from: turAt(temiz), user: yeniKullanici()))
        let metin = ozet.message
        XCTAssertFalse(metin.contains("GERİ YÜKLENMEDİ"))
        XCTAssertFalse(metin.contains("atlandı"))
        XCTAssertFalse(metin.contains("yeniden davet"))
        XCTAssertFalse(metin.contains("Alıcı adları"))
    }

    // MARK: Silmeden önce dışa aktarma (madde 75'in ikinci cümlesi)

    /// SAHİBİ OLUNAN projeler dışa aktarılır.
    func testExportCoversOwnedProjects() {
        let model = vm()
        let urls = model.exportOwnedFiles(user: .admin)
        XCTAssertFalse(urls.isEmpty, "yöneticinin projeleri dışa aktarılmalı")
        XCTAssertTrue(urls.contains { $0.lastPathComponent.hasSuffix("-Yedek.json") },
                      "geri yüklenebilir yedek dosyası da üretilmeli")
    }

    /// ORTAK OLUNAN PROJELER ALINMAZ.
    ///
    /// O projeler hesap silinince SİLİNMİYOR (kullanıcı yalnızca listeden
    /// düşüyor) ve başkasının verisini indirmek bu akışın işi değil. Global
    /// role bakılsaydı ortak olunan proje de yönetici kapsamıyla dışa aktarılır
    /// ve alıcı adları (KVKK) dosyaya girerdi.
    func testExportSkipsProjectsUserDoesNotOwn() {
        let model = vm()
        let baskasi = User(id: "baska-uid", name: "Başkası", role: .admin,
                           phone: "+905550000003")
        XCTAssertTrue(model.exportOwnedFiles(user: baskasi).isEmpty)
    }

    /// Oturum yoksa dosya üretilmez — sahiplik çözülemiyor.
    func testExportNeedsAUser() {
        XCTAssertTrue(vm().exportOwnedFiles(user: nil).isEmpty)
    }
}
