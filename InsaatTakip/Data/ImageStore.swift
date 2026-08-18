import FirebaseStorage
import UIKit

// MARK: - Görsel deposu (madde 17)
//
// İKİ KATLI: önce DİSK, sonra BULUT. Sıra bilinçli —
//
//   1. Disk ANINDA: kullanıcı fotoğrafı eklediği an JPEG diske yazılır.
//      Önceden görseller yalnızca RAM'deydi ve her yeniden başlatmada
//      kayboluyordu; kullanıcı "kaydedildi" sanıyordu. Disk, uygulama ölse de
//      pikselleri tutar ve yarım kalan yükleme sonraki açılışta buradan
//      yeniden denenir.
//   2. Bulut ARKADA: yükleme bitince Firestore belgesine `storagePath`
//      yazılır. Yolun varlığı = buluttaki tek gerçek; "bekliyor" durumu
//      cihaza özgüdür ve DİSKTE dosya var + belgede yol yok ile ifade edilir.
//
// DOSYA ADI KENDİNİ TARİF EDER: `{kova}_{projectId}_{id}.jpg`. Yeniden
// yükleme adayları ayrı bir defter olmadan dizin taramasıyla bulunur —
// defter tutulsaydı defterle diskin ayrışması yeni bir hata sınıfı olurdu.
//
// Storage yolları `storage.rules` ile bire bir:
//   projects/{pid}/{sitePhotos|apartmentPhotos|receipts|paymentReceipts}/{id}.jpg

enum ImageBucket: String, CaseIterable {
    case sitePhotos
    case apartmentPhotos
    /// Malzeme ve gider fişi — ortağa AÇIK. Ortak zaten aynı harcamayı
    /// listede görüyor; fişi de görmesi şeffaflığın parçası.
    case receipts
    /// Tahsilat dekontu — yalnızca YÖNETİCİ. Dekontun üstünde gönderenin adı
    /// (çoğu kez IBAN'ı da) yazıyor; bu, `buyers/{apartmentId}` ile ortaktan
    /// ayrılan ALICI KİMLİĞİDİR (madde 18). Malzeme fişiyle aynı kovada
    /// dursaydı, Firestore'da kapatılan sızıntı Storage'dan geri açılırdı.
    case paymentReceipts
}

@MainActor
final class ImageStore {

    private let storage: Storage
    private let directory: URL

    /// JPEG kalitesi: 1200px'te 0.8, tipik 200-500 KB üretir — kuralın 4 MB
    /// tavanının çok altında, ekran için ayırt edilemez.
    private static let jpegQuality: CGFloat = 0.8

    init(storage: Storage = Storage.storage()) {
        self.storage = storage
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        directory = base.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
    }

    // MARK: Disk

    private func fileURL(_ bucket: ImageBucket, _ projectId: UUID, _ id: UUID) -> URL {
        directory.appendingPathComponent(
            "\(bucket.rawValue)_\(projectId.uuidString)_\(id.uuidString).jpg")
    }

    /// Görseli diske yazar. `false` dönerse ÇAĞIRAN ilgilenmek zorunda:
    /// diskte dosya yoksa yükleme `fallback` ile beslenmeli (bkz. `upload`),
    /// yoksa piksel yalnızca bellekte kalır ve ilk yeniden açılışta uçar.
    @discardableResult
    func cache(_ image: UIImage, bucket: ImageBucket, projectId: UUID, id: UUID) -> Bool {
        guard let data = image.jpegData(compressionQuality: Self.jpegQuality) else { return false }
        do {
            try data.write(to: fileURL(bucket, projectId, id), options: .atomic)
            return true
        } catch {
            #if DEBUG
            print("[image] disk yazılamadı \(bucket.rawValue)/\(id): \(error)")
            #endif
            return false
        }
    }

    func cached(bucket: ImageBucket, projectId: UUID, id: UUID) -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL(bucket, projectId, id)) else { return nil }
        return UIImage(data: data)
    }

    /// Diskte duran tüm görseller. Açılışta "yolu olmayan belge + diskte
    /// dosya" kesişimi yeniden yükleme kuyruğunu verir.
    func localEntries(bucket: ImageBucket) -> [(projectId: UUID, id: UUID)] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return [] }
        let prefix = bucket.rawValue + "_"
        return names.compactMap { name in
            guard name.hasPrefix(prefix), name.hasSuffix(".jpg") else { return nil }
            let core = name.dropFirst(prefix.count).dropLast(4)
            let parts = core.split(separator: "_")
            guard parts.count == 2,
                  let projectId = UUID(uuidString: String(parts[0])),
                  let id = UUID(uuidString: String(parts[1])) else { return nil }
            return (projectId, id)
        }
    }

    // MARK: Bulut

    /// Nesnenin Storage yolu. Belirlenimci: belgede yol yazılı olmasa da
    /// hesaplanabilir — silme bu güvenceye dayanıyor.
    private func objectPath(_ bucket: ImageBucket, _ projectId: UUID, _ id: UUID) -> String {
        "projects/\(projectId.uuidString)/\(bucket.rawValue)/\(id.uuidString).jpg"
    }

    /// Diskteki kopyayı Storage'a yükler; başarıda nesnenin yolunu döndürür.
    /// Öncelik DİSKTE: bellekteki kopyayla ayrışırsa (yeniden açılış) doğru
    /// kaynak disktir.
    ///
    /// `fallback` diskte dosya YOKKEN devreye girer. Bu dal olmadan, depolaması
    /// dolu bir telefonda `cache` sessizce başarısız oluyor ve fotoğraf ne
    /// diske ne buluta gidiyordu — üstelik kullanıcıya "sonra yeniden
    /// denenecek" deniyordu, oysa yeniden deneme diskteki dosyaya bakıyor ve
    /// o dosya hiç oluşmamış oluyordu. Şantiyede çekilen kare tamamen
    /// kayboluyordu.
    func upload(bucket: ImageBucket, projectId: UUID, id: UUID,
                fallback: UIImage? = nil) async throws -> String {
        let data: Data
        if let onDisk = try? Data(contentsOf: fileURL(bucket, projectId, id)) {
            data = onDisk
        } else if let inMemory = fallback?.jpegData(compressionQuality: Self.jpegQuality) {
            data = inMemory
        } else {
            // Gerçek hatayı yut ma: çağıran neyin eksik olduğunu görsün.
            data = try Data(contentsOf: fileURL(bucket, projectId, id))
        }
        let path = objectPath(bucket, projectId, id)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"   // kural yalnızca JPEG kabul ediyor
        _ = try await storage.reference(withPath: path).putDataAsync(data, metadata: metadata)
        return path
    }

    /// Storage'dan indirir ve diske de yazar — bir sonraki açılış ağsız olsun.
    func download(path: String, bucket: ImageBucket, projectId: UUID, id: UUID) async throws -> UIImage? {
        // 8 MB tavan: kural 4 MB üstünü zaten yazdırmıyor; tavan yalnızca
        // beklenmedik büyüklükte bir nesnenin belleği şişirmesine karşı.
        let data = try await storage.reference(withPath: path).data(maxSize: 8 * 1024 * 1024)
        try? data.write(to: fileURL(bucket, projectId, id), options: .atomic)
        return UIImage(data: data)
    }

    /// Diskten ve buluttan siler.
    ///
    /// `storagePath` nil olsa bile bulut DENENİR: yol belirlenimci
    /// (`projects/{pid}/{kova}/{id}.jpg`), yani belgede yol yazılı olmasa da
    /// nesnenin nerede olacağı bilinir. Bu şart, çünkü silme anında bir yükleme
    /// uçuşta olabilir: yol henüz belgeye yazılmamıştır ama nesne birazdan
    /// buluta düşer. Yalnızca yazılı yola bakılsaydı, kullanıcının sildiği
    /// görsel projenin HER üyesinin okuyabildiği bir yetim nesne olarak
    /// bulutta kalırdı.
    func delete(bucket: ImageBucket, projectId: UUID, id: UUID, storagePath: String?) async {
        try? FileManager.default.removeItem(at: fileURL(bucket, projectId, id))
        let path = storagePath ?? objectPath(bucket, projectId, id)
        do { try await storage.reference(withPath: path).delete() }
        catch {
            #if DEBUG
            print("[image] bulut silinemedi \(path): \(error)")
            #endif
        }
    }
}
