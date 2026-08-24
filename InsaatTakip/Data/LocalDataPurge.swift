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
// FIRESTORE ÖNBELLEĞİ SİLME ANINDA TEMİZLENMİYOR, SONRAKİ AÇILIŞTA
// TEMİZLENİYOR — ve bunun bedeli pahalıya öğrenildi.
//
// İlk yazımda burada `terminate()` + `clearPersistence()` çağrılıyordu ve
// yorumda "terminate örneği önbellekten düşürdüğü için sonraki
// `Firestore.firestore()` YENİ bir örnek verir" yazıyordu. Bu doğru ama
// KONUYLA İLGİSİZ: `ProjectViewModel` uygulama ömrü boyunca yaşayan bir
// `@StateObject` ve içindeki depo, Firestore örneğini `init`te YAKALIYOR.
// `terminate()` o yakalanmış örneği öldürüyor, dolayısıyla kullanıcı hesabını
// silip tekrar giriş yaptığında uygulama
// `FIRIllegalStateException: The client has already been terminated.`
// ile ÇÖKÜYORDU. Gerçek cihaz turunda birebir bu yaşandı.
//
// Firebase'in kendi belgesi zaten şunu söylüyor: `clearPersistence()`
// istemci BAŞLAMAMIŞKEN çağrılmalı — "uygulama kapatıldıktan sonra ya da ilk
// kurulduğunda". Doğru yer burası değil, AÇILIŞ. Silme anında yalnızca bir
// bayrak bırakılıyor; `AppDelegate` bir sonraki açılışta, Firestore'a hiç
// dokunulmadan önce temizliği yapıyor.
//
// BİLİNEN SINIR ve açıkça yazılıyor: önbellek, uygulama bir daha açılana
// kadar diskte kalıyor. Kapanan pencere şu: oturum düşmüş, veri uygulamadan
// erişilemez ve fotoğraflar ile belgeler ZATEN silinmiş durumda. Alternatif
// çökmekti; çökmek hiçbir gerekçeyle kabul edilebilir bir davranış değil.
//
// HATALAR YUTULUYOR ve bu bilinçli: buraya gelindiğinde sunucu tarafı BİTMİŞ
// durumda. Yerel bir dosya silinemedi diye kullanıcıya "hesabın silinemedi"
// demek, olan bitenin tersini söylemek olurdu. Yutulan hata sessiz kalmıyor:
// DEBUG'da yazdırılıyor.

enum LocalDataPurge {

    /// Silme anında koşan kısım: DOSYALAR.
    static func afterAccountDeletion() {
        remove(ImageStore.cacheDirectory)
        remove(DocumentStore.cacheDirectory)
        UserDefaults.standard.set(true, forKey: pendingKey)
    }

    private static let pendingKey = "firestoreCachePurgePending"

    /// Açılışta koşan kısım: FIRESTORE ÖNBELLEĞİ.
    ///
    /// `AppDelegate`ten, `FirebaseApp.configure()`dan hemen sonra ve Firestore
    /// ilk kez KULLANILMADAN önce çağrılıyor. Bekleyen bir silme yoksa hiçbir
    /// şey yapmıyor — her açılışta önbelleği silmek, uygulamayı her seferinde
    /// sıfırdan veri çekmeye zorlardı.
    static func purgeFirestoreCacheIfPending() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: pendingKey) else { return }
        Firestore.firestore().clearPersistence { error in
            if let error {
                #if DEBUG
                print("LocalDataPurge: Firestore önbelleği temizlenemedi — \(error)")
                #endif
                return   // bayrak DURUYOR: sonraki açılışta tekrar denenir
            }
            defaults.set(false, forKey: pendingKey)
        }
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

}
