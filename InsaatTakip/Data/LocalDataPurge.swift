import Foundation
import FirebaseFirestore

// MARK: - Cihazdaki verinin silinmesi (madde 68)
//
// Onay ekranı kullanıcıya şunu söylüyor: "malzeme, gider, tahsilat, FOTOĞRAF ve
// BELGELER — kalıcı olarak silinecek". Sunucu tarafı bunu yapıyordu; CİHAZ
// tarafı yapmıyordu. Silinen hesabın fotoğrafları `ImageCache`, belgeleri
// `DocumentCache` altında, Firestore'un kalıcı önbelleği ise kendi dosyalarında
// duruyordu — ALICI ADLARI dahil, yani KVKK kapsamındaki kişisel veri.
//
// Bu, "toplam doğru, detay yanlış" ailesinin bir üyesi: sunucudaki silme
// kusursuz çalışıyor, kullanıcıya söylenen cümle yine de yalan oluyor. Cihazı
// devreden ya da aynı telefonda başka bir hesap açan kişi için fark gerçek.
//
// SIRA: önce dosyalar, en sonda Firestore. Firestore'un `terminate()` çağrısı
// örneği kullanılamaz hâle getiriyor ve `clearPersistence()` yalnızca ondan
// sonra çalışıyor; ikisi de en sona bırakıldı ki daha erken bir hata, dosya
// temizliğini engellemesin.
//
// HATALAR YUTULUYOR ve bu bilinçli: buraya gelindiğinde sunucu tarafı BİTMİŞ
// durumda. Yerel bir dosya silinemedi diye kullanıcıya "hesabın silinemedi"
// demek, olan bitenin tersini söylemek olurdu. Yutulan hata sessiz kalmıyor:
// DEBUG'da yazdırılıyor.

enum LocalDataPurge {

    static func afterAccountDeletion() async {
        remove(ImageStore.cacheDirectory)
        remove(DocumentStore.cacheDirectory)
        await clearFirestoreCache()
    }

    private static func remove(_ url: URL) {
        do { try FileManager.default.removeItem(at: url) }
        catch CocoaError.fileNoSuchFile { /* zaten yok */ }
        catch {
            #if DEBUG
            print("LocalDataPurge: \(url.lastPathComponent) silinemedi — \(error)")
            #endif
        }
    }

    /// Firestore'un disk önbelleği.
    ///
    /// `terminate()` ÖNCE gelmek zorunda — SDK `clearPersistence()`i yalnızca
    /// durdurulmuş bir örnekte kabul ediyor. `terminate()` örneği önbellekten
    /// düşürdüğü için sonraki `Firestore.firestore()` çağrısı YENİ ve
    /// kullanılabilir bir örnek veriyor; yani silmeden sonra tekrar hesap açan
    /// kullanıcı için uygulama çalışır durumda kalıyor.
    private static func clearFirestoreCache() async {
        let db = Firestore.firestore()
        do {
            try await db.terminate()
            try await db.clearPersistence()
        } catch {
            #if DEBUG
            print("LocalDataPurge: Firestore önbelleği temizlenemedi — \(error)")
            #endif
        }
    }
}
