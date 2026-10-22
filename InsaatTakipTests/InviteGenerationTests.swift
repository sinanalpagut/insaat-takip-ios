import XCTest
@testable import InsaatTakip

/// Davet kodu üretimi — ekran yalnızca SUNUCUDA VAR OLAN kodu göstermeli.
///
/// KUSUR (madde 5): `generateInviteCode` yerel bir kod A üretip hemen
/// `project.invite`e yazıyordu; ekranda görünüyor, kopyalanıp WhatsApp'tan
/// paylaşılabiliyordu. Ama A HİÇBİR YERE yazılmıyordu: `createInvite` kendi
/// içinde AYRI bir kod B üretip onu yazıyor. Çevrimiçiyken A birkaç yüz
/// milisaniye görünüp B ile değişiyordu; o pencerede paylaşılan A geçersizdi.
///
/// ÇEVRİMDIŞI DAHA KÖTÜ: `createInvite` bir Firestore partisi ve
/// `await batch.commit()` ağ yokken HATA FIRLATMIYOR, sunucu onayına kadar
/// ASKIDA KALIYOR. Yani `catch` hiç çalışmıyor ve A süresiz ekranda
/// kalıyordu — paylaşılabilir ve asla geçerli olmayacak bir kod.
///
/// Hata hâlinde ise `invite = nil` yapılıyordu: yeni kod üretmeyi deneyip
/// başaramayan sahip, elindeki HÂLÂ GEÇERLİ kodu da ekrandan kaybediyordu.
///
/// Sahte servis `createInvite`i bir devam noktasında BEKLETİYOR — askıda
/// kalan `commit`in birebir modeli.
@MainActor
final class InviteGenerationTests: XCTestCase {

    private final class BekletenDavet: InviteService {
        var devam: CheckedContinuation<String, Error>?
        var cagriSayisi = 0
        func createInvite(projectId: UUID, ownerUid: String) async throws -> String {
            cagriSayisi += 1
            return try await withCheckedThrowingContinuation { devam = $0 }
        }
        func redeem(code: String) async throws -> InviteRedemption { throw InviteError.unknown }
    }

    private func bekle(_ kosul: () -> Bool, _ mesaj: String,
                       file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if kosul() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail(mesaj, file: file, line: line)
    }

    private func kur() -> (BekletenDavet, ProjectViewModel, Int) {
        let davet = BekletenDavet()
        let vm = ProjectViewModel(repository: InMemoryProjectRepository(), invites: davet)
        let i = vm.projects.firstIndex { $0.id == DemoID.cayirova }!
        return (davet, vm, i)
    }

    /// Sunucu yanıt vermeden ekranda kod OLMAMALI.
    func testSunucuYanitlamadanKodGosterilmiyor() async {
        let (davet, vm, i) = kur()
        XCTAssertNil(vm.projects[i].invite)

        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)
        await bekle({ davet.devam != nil }, "createInvite çağrılmadı")

        // ASKIDA: `commit` dönmedi. Ekranda paylaşılabilir bir kod olmamalı.
        XCTAssertNil(vm.projects[i].invite,
                     "sunucuya yazılmamış bir kod ekranda gösteriliyor")
        XCTAssertTrue(vm.invitePending.contains(DemoID.cayirova),
                      "ekran 'hazırlanıyor' durumunu göremiyor")

        davet.devam?.resume(returning: "XYZ234")
        await bekle({ vm.projects[i].invite?.code == "XYZ234" },
                    "sunucunun yazdığı kod ekrana gelmedi")
        await bekle({ !vm.invitePending.contains(DemoID.cayirova) },
                    "'hazırlanıyor' durumu temizlenmedi")
    }

    /// Bekleyen üretim varken ikinci dokunuş yeni bir yazma başlatmamalı.
    ///
    /// Çevrimdışıyken kişi "olmadı" sanıp tekrar basıyor; iki parti kuyruğa
    /// girer, bağlantı gelince İKİ kod birden geçerli olur ve ekranda hangisinin
    /// kalacağı yarışa kalır.
    func testBeklerkenIkinciDokunusYeniYazmaBaslatmiyor() async {
        let (davet, vm, _) = kur()
        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)
        await bekle({ davet.devam != nil }, "createInvite çağrılmadı")

        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)
        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(davet.cagriSayisi, 1, "bekleyen üretim varken yeni yazma başladı")

        davet.devam?.resume(returning: "XYZ234")
        await bekle({ !vm.invitePending.contains(DemoID.cayirova) }, "üretim bitmedi")
    }

    /// Yeni kod üretilirken ÖNCEKİ kod ekranda yerel bir uydurmayla
    /// değiştirilmemeli.
    func testYeniKodBeklenirkenOncekiKodUydurmaylaDegismiyor() async {
        let (davet, vm, i) = kur()
        vm.projects[i].invite = Invite(code: "ESK234", createdAt: Date())

        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)
        await bekle({ davet.devam != nil }, "createInvite çağrılmadı")

        let gorunen = vm.projects[i].invite?.code
        XCTAssertTrue(gorunen == nil || gorunen == "ESK234",
                      "ekranda sunucuda olmayan '\(gorunen ?? "")' kodu var")

        davet.devam?.resume(returning: "YEN234")
        await bekle({ vm.projects[i].invite?.code == "YEN234" }, "yeni kod gelmedi")
    }

    /// Üretim başarısız olursa önceki, HÂLÂ GEÇERLİ kod kaybolmamalı.
    func testHataOncekiGecerliKoduSilmiyor() async {
        let (davet, vm, i) = kur()
        vm.projects[i].invite = Invite(code: "ESK234", createdAt: Date())

        vm.generateInviteCode(role: .admin, projectId: DemoID.cayirova)
        await bekle({ davet.devam != nil }, "createInvite çağrılmadı")
        davet.devam?.resume(throwing: NSError(domain: "test", code: 7))

        await bekle({ vm.toast != nil }, "hata kullanıcıya söylenmedi")
        XCTAssertEqual(vm.projects[i].invite?.code, "ESK234",
                       "başarısız üretim, sunucuda hâlâ geçerli olan kodu ekrandan sildi")
        await bekle({ !vm.invitePending.contains(DemoID.cayirova) },
                    "hata sonrası 'hazırlanıyor' durumu takılı kaldı")
    }
}
