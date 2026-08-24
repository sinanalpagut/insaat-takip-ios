import XCTest
@testable import InsaatTakip

/// Hesap silindiğinde CİHAZDA kalan veri — madde 68.
///
/// NEDEN BU TESTLER VAR: onay ekranı "fotoğraf ve belgeler kalıcı olarak
/// silinecek" diyor. Sunucu tarafı bunu yapıyordu, cihaz tarafı yapmıyordu;
/// yani sunucudaki silme kusursuz çalışırken kullanıcıya söylenen cümle yine
/// de yalandı.
///
/// İlk düzeltme burada Firestore'u `terminate()` ediyordu ve GERÇEK CİHAZDA
/// ÇÖKMEYE yol açtı: uygulama ömrü boyunca yaşayan depo, kapatılmış örneği
/// kullanmaya devam ediyor. O yüzden Firestore önbelleği artık silme anında
/// değil, BAYRAKLA sonraki açılışa devredilerek temizleniyor. Aşağıdaki
/// testler bayrağın gerçekten bırakıldığını ve dosyaların gerçekten
/// silindiğini sabitliyor — ikisi de sessizce başarısız olabilecek adımlar.
@MainActor
final class LocalDataPurgeTests: XCTestCase {

    private var markerURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("firestore-cache-purge-pending")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: markerURL)
        super.tearDown()
    }

    /// Görsel ve belge önbellek dizinleri TOPLUCA gidiyor.
    ///
    /// Dizin yolu iki yerde yazılsaydı ayrışabilirdi: silme yanlış klasörü
    /// süpürür, fotoğraflar sessizce kalırdı. Bu test yolun tek kaynağını da
    /// dolaylı olarak koruyor — mağazalar kendi `cacheDirectory`sini
    /// kullanıyor, temizlik de aynısını.
    func testCachesAreRemoved() throws {
        let fm = FileManager.default
        for dir in [ImageStore.cacheDirectory, DocumentStore.cacheDirectory] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let dosya = dir.appendingPathComponent("sahte.bin")
            try Data([1, 2, 3]).write(to: dosya)
            XCTAssertTrue(fm.fileExists(atPath: dosya.path), "zemin: dosya yazılmış olmalı")
        }

        LocalDataPurge.afterAccountDeletion()

        XCTAssertFalse(fm.fileExists(atPath: ImageStore.cacheDirectory.path))
        XCTAssertFalse(fm.fileExists(atPath: DocumentStore.cacheDirectory.path))
    }

    /// Firestore önbelleği için BAYRAK bırakılıyor.
    ///
    /// Bayrak bırakılmazsa temizlik hiç koşmaz ve alıcı adları (KVKK) cihazda
    /// kalır — üstelik kimse fark etmez, çünkü ekranda hiçbir iz yok.
    func testFirestorePurgeIsFlaggedForNextLaunch() {
        try? FileManager.default.removeItem(at: markerURL)
        XCTAssertFalse(LocalDataPurge.isPurgePending, "zemin: işaret yok")

        LocalDataPurge.afterAccountDeletion()

        XCTAssertTrue(LocalDataPurge.isPurgePending)
        // İŞARET DİSKTE OLMAK ZORUNDA, yalnızca bellekte değil: uygulama
        // silmeden hemen sonra öldürülürse temizlik yine de koşmalı.
        // `UserDefaults` sürümü tam burada sessizce kaybediyordu.
        XCTAssertTrue(FileManager.default.fileExists(atPath: markerURL.path))
    }

    /// Bekleyen bir silme YOKKEN açılış temizliği hiçbir şey yapmamalı.
    ///
    /// Her açılışta önbelleği silmek, uygulamayı her seferinde sıfırdan veri
    /// çekmeye zorlardı: sahada kapsama zayıfken açılış ekranı boş kalırdı.
    func testLaunchPurgeIsNoOpWithoutPendingFlag() {
        try? FileManager.default.removeItem(at: markerURL)
        LocalDataPurge.purgeFirestoreCacheIfPending()
        XCTAssertFalse(LocalDataPurge.isPurgePending)
    }

    /// Dizin zaten yoksa temizlik hata vermemeli.
    ///
    /// Hiç fotoğraf yüklememiş bir kullanıcıda `ImageCache` hiç oluşmamış
    /// olabilir; orada patlamak, hesabı silinmiş kişiye "silinemedi" demek
    /// olurdu.
    func testPurgeIsSafeWhenDirectoriesAreAbsent() {
        try? FileManager.default.removeItem(at: ImageStore.cacheDirectory)
        try? FileManager.default.removeItem(at: DocumentStore.cacheDirectory)
        LocalDataPurge.afterAccountDeletion()   // patlamamalı
        XCTAssertTrue(LocalDataPurge.isPurgePending)
    }
}
