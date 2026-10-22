import XCTest
import FirebaseFirestore
@testable import InsaatTakip

/// Proje belgesine yazarken ÜYELİK ve DAVET alanlarının korunması.
///
/// HATA: proje belgesi her yazışta TAM olarak gönderiliyordu
/// (`setData(try encode(project))`, merge yok). `Project`in `CodingKeys`i
/// olmadığı için `memberUids` ve `invite` de yükün içindeydi ve yük sahibin
/// CİHAZINDAKİ kopyadan kuruluyordu.
///
/// Sunucudaki `redeemInvite` ortağı `arrayUnion` ile ekliyor. Canlı snapshot
/// dinleyici BİLEREK yok (`RootView.swift`), yani sahibin kopyası yalnızca
/// `load()` ile tazeleniyor. Arada sahip HERHANGİ bir düzenleme yaparsa —
/// ilerleme yüzdesi, KDV tabanı, arşivleme, daire ekleme — sunucudaki liste
/// eski hâliyle eziliyor ve ortak projeyi okuyamaz hâle geliyor. İki tarafa da
/// hata gösterilmiyor.
///
/// NEDEN BELLEK İÇİ DEPO GEÇERLİ BİR MODEL: `InMemoryProjectRepository.upsert`
/// kimlik eşleşince `list[index] = value` diyor — kendi yorumu bunu Firestore'un
/// `setData` davranışı olarak tanımlıyor. `ProjectViewModel.init` deponun anlık
/// kopyasını DEĞER olarak alıyor, yani init'ten sonra depoyu değiştirmek
/// görünümü etkilemiyor: canlı dinleyicinin yokluğunun birebir modeli.
/// `repo.projects[i].memberUids`e elle uid eklemek, sunucudaki `arrayUnion`ın
/// tam karşılığı.
@MainActor
final class ProjectMembershipWriteTests: XCTestCase {

    /// Yazma kuyruğu boşalana kadar bekler.
    ///
    /// `persist` ateşle-unut bir `Task` açıyor ve `pendingWrites` sayacını
    /// Task'TEN ÖNCE artırıyor; bu yüzden çağrı döndüğünde sayaç zaten >0 ve
    /// yarış yok.
    private func yazmaBitsin(_ vm: ProjectViewModel,
                             file: StaticString = #filePath,
                             line: UInt = #line) async {
        for _ in 0..<200 {
            if vm.pendingWrites == 0 { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("yazma kuyruğu boşalmadı", file: file, line: line)
    }

    private func kur() -> (InMemoryProjectRepository, ProjectViewModel, Int) {
        let repo = InMemoryProjectRepository()
        let vm = ProjectViewModel(repository: repo)
        let index = repo.projects.firstIndex { $0.id == DemoID.cayirova }!
        return (repo, vm, index)
    }

    /// ASIL KUSUR: sahibin sıradan düzenlemesi sunucudaki ortağı düşürmemeli.
    func testIlerlemeGuncellemesiSunucudakiOrtagiDusurmuyor() async {
        let (repo, vm, i) = kur()

        // SUNUCU TARAFI OLAY: ortak davetle katıldı (`redeemInvite` arrayUnion).
        // Görünüm bunu BİLMİYOR — canlı dinleyici yok.
        repo.projects[i].memberUids.append("uid-ortak")

        vm.updateProgress(role: .admin, projectId: DemoID.cayirova,
                          progress: 42, phase: .kabaInsaat)
        await yazmaBitsin(vm)

        XCTAssertTrue(repo.projects[i].memberUids.contains("uid-ortak"),
                      "İlerleme güncellemesi sunucudaki üyelik listesini ezdi")
        // İkinci iddia testin "hiç yazmayarak" yanlış yeşil vermesini engelliyor:
        // `persist` tümden kaldırılsa birinci iddia geçerdi.
        XCTAssertEqual(repo.projects[i].progress, 42, "alan yazması sunucuya gitmedi")
    }

    /// Aynı kusurun ikinci yüzü: davet aynası da eziliyor.
    ///
    /// Davet kodunu proje belgesine `FirebaseInviteService.createInvite` yazıyor;
    /// görünümün kopyasında `invite` henüz `nil` olabilir (uygulama yeniden
    /// açılmış ya da kodu başka cihaz üretmiş). Tam yazma o aynayı siliyor:
    /// kod `invites/{KOD}` otoritesinde geçerli kalıyor ama ekrandan kayboluyor.
    func testArsivlemeDavetAynasiniSilmiyor() async {
        let (repo, vm, i) = kur()

        repo.projects[i].invite = Invite(code: "ABC123", createdAt: Date())

        vm.setArchived(true, role: .admin, projectId: DemoID.cayirova)
        await yazmaBitsin(vm)

        XCTAssertEqual(repo.projects[i].invite?.code, "ABC123",
                       "Arşivleme sunucudaki davet aynasını sildi")
        XCTAssertNotNil(repo.projects[i].archivedAt, "arşiv alanı sunucuya gitmedi")
    }

    /// Daire ekleme de proje belgesini yazıyor (`totalApartments`); aynı kusur.
    func testDaireEklemeOrtagiDusurmuyor() async {
        let (repo, vm, i) = kur()
        let onceki = repo.projects[i].totalApartments

        repo.projects[i].memberUids.append("uid-ortak")

        XCTAssertTrue(vm.addApartment(role: .admin, projectId: DemoID.cayirova),
                      "daire eklenemedi")
        await yazmaBitsin(vm)

        XCTAssertTrue(repo.projects[i].memberUids.contains("uid-ortak"),
                      "Daire ekleme sunucudaki üyelik listesini ezdi")
        XCTAssertEqual(repo.projects[i].totalApartments, onceki + 1,
                       "daire sayacı sunucuya gitmedi")
    }

    // MARK: - Yazma yükünün pinlenmesi

    /// Sunucunun sahibi olduğu alanlar yüke SIZMAMALI.
    ///
    /// Bu testin asıl işi `erasableProjectFields` listesini korumak. O listeye
    /// `memberUids` ya da `invite` eklenirse düzeltme TERSİNE döner: alanlar
    /// yükten zaten çıkarıldığı için `fields[key] == nil` koşulu ikisi için
    /// daima doğru olur ve her düzenleme üyeliği SİLER. Sonuç bugünkü sessiz
    /// düşmeden beter — sahip kendi projesini bile okuyamaz hâle gelir.
    func testDuzenlemeYukuUyeligiVeDavetiTamListeOlarakTasimiyor() throws {
        let repo = InMemoryProjectRepository()
        var proje = repo.projects.first { $0.id == DemoID.cayirova }!
        proje.memberUids = ["sahip", "uid-ortak"]
        proje.invite = Invite(code: "ABC123", createdAt: Date())

        let yuk = try FirestoreProjectRepository.projectFields(proje, writerUid: "sahip")

        XCTAssertNil(yuk["invite"], "davet aynası sıradan düzenleme yüküne sızdı")
        XCTAssertFalse(yuk["memberUids"] is [String],
                       "üyelik TAM LİSTE olarak gönderiliyor — düzeltilen kusur bu")
        XCTAssertTrue(yuk["memberUids"] is FieldValue,
                      "kendini onarma için arrayUnion bekleniyordu")
        XCTAssertNotNil(yuk["progress"], "iş alanları yükte olmalı")

        for alan in FirestoreProjectRepository.serverOwnedProjectFields {
            XCTAssertFalse(FirestoreProjectRepository.erasableProjectFields.contains(alan),
                           "\(alan) silinebilir listesine girmiş — düzeltmeyi tersine çevirir")
        }
    }

    /// Kullanıcının temizlediği opsiyonel alan SİLME sentinel'i taşımalı.
    ///
    /// `merge: true` yükte OLMAYAN alanı sunucuda eski değeriyle bırakıyor;
    /// alanı yükten çıkarmak "sildim" demek değil. Sentinel olmazsa silinen
    /// değer bir sonraki `refresh()`te geri gelir.
    func testTemizlenenOpsiyonelAlanSilmeSentineliTasiyor() throws {
        let repo = InMemoryProjectRepository()
        var proje = repo.projects.first { $0.id == DemoID.cayirova }!
        proje.archivedAt = nil
        proje.remainingCostEstimate = nil
        proje.expenseTaxBasis = nil
        proje.salesTaxBasis = nil

        let bos = try FirestoreProjectRepository.projectFields(proje, writerUid: "sahip")
        for alan in FirestoreProjectRepository.erasableProjectFields {
            XCTAssertTrue(bos[alan] is FieldValue,
                          "\(alan) nil ama yükte silme sentinel'i yok")
        }

        proje.archivedAt = Date()
        let dolu = try FirestoreProjectRepository.projectFields(proje, writerUid: "sahip")
        XCTAssertFalse(dolu["archivedAt"] is FieldValue,
                       "dolu alan yanlışlıkla siliniyor")
    }

    /// TERS YÖN: `removePartner` üyeliği GERÇEKTEN kaldırmalı.
    ///
    /// Düzeltme `memberUids`i sıradan yükten çıkarıyor; bu, ortağı çıkarma
    /// yolunun da çalışmaya devam ettiğini ayrıca kanıtlamayı gerektiriyor.
    /// Yoksa "hiç yazmayarak" ilk üç testi geçip erişim kapısını açık bırakan
    /// bir düzeltme mümkün olurdu.
    func testOrtakCikarmaUyeliginiKaldiriyor() async {
        let (repo, vm, i) = kur()

        // Tohum veride ortakların `userUid`i olmayabilir; üyelik kapısı yalnızca
        // uid varsa kapanıyor, o yüzden uid'i hem kayda hem listeye koyuyoruz.
        guard let ortakIndex = repo.partners.firstIndex(where: {
            $0.projectId == DemoID.cayirova && !$0.isFounder
        }) else { return XCTFail("tohum veride ortak yok") }

        let uid = "uid-cikarilacak"
        repo.partners[ortakIndex].userUid = uid
        repo.projects[i].memberUids.append(uid)

        // Görünümün kendi kopyasında da uid olmalı: `removePartner` kararını
        // kendi `partners` listesine bakarak veriyor.
        let vmIndex = vm.partners.firstIndex { $0.id == repo.partners[ortakIndex].id }!
        vm.partners[vmIndex].userUid = uid

        XCTAssertTrue(vm.removePartner(role: .admin, partnerId: repo.partners[ortakIndex].id),
                      "ortak çıkarılamadı")
        await yazmaBitsin(vm)

        XCTAssertFalse(repo.projects[i].memberUids.contains(uid),
                       "Ortak çıkarıldı ama üyelik kapısı açık kaldı")
    }
}
