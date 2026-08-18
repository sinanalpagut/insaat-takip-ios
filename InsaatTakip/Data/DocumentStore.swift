import FirebaseStorage
import Foundation

// MARK: - Belge deposu (madde 23)
//
// `ImageStore` ile AYNI iki katlı deseni izler — önce disk, sonra bulut — ama
// ayrı bir tip olmak zorunda: `ImageStore` baştan sona `UIImage`/JPEG'e bağlı
// (dosya soneki `.jpg` sabit, `cache` yalnızca `jpegData` yazıyor, yükleme
// `contentType`ı `image/jpeg`e kilitliyor). Belge PDF, DWG, XLSX olabiliyor ve
// 50 MB'a kadar çıkabiliyor; o boruya sığmıyor.
//
// EN KRİTİK İŞ BURADA: dosya seçiciden gelen URL GÜVENLİK KAPSAMLI. Kapsam
// yalnızca seçim geri çağrısı boyunca açık; kapandıktan sonra o URL'den tek
// bayt okunamaz. Önceki hâlde `handlePickedFile` kapsamı açıp SADECE dosya
// boyutunu okuyor, kapatıyor ve URL'i atıyordu — yani baytlar daha en başta
// erişilemez oluyordu ve "yükleniyor" çubuğu tamamen sahteydi. `copyIn` bu
// yüzden var: kapsam AÇIKKEN dosyayı uygulamanın kendi alanına kopyalar.
//
// Storage yolu `storage.rules` ile bire bir:
//   projects/{pid}/documents/{docId}        ← UZANTI YOK
//
// Uzantının yolda olmaması bilinçli: kural kardeş Firestore belgesini
// (`partnerVisible` kontrolü için) ancak nesne adı belge kimliğine birebir
// eşitse çözebiliyor. Gerçek ad ve uzantı Firestore belgesinde duruyor;
// indirilen bayt yerel geçici dosyaya o uzantıyla yazılıyor çünkü önizleme
// dosyayı adından tanıyor.

@MainActor
final class DocumentStore {

    private let storage: Storage
    private let directory: URL

    init(storage: Storage = Storage.storage()) {
        self.storage = storage
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        directory = base.appendingPathComponent("DocumentCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
    }

    // MARK: Disk

    /// Yerel kopya. Ad kendini tarif eder (bkz. ImageStore): yeniden yükleme
    /// adayları ayrı bir defter tutmadan dizin taramasıyla bulunuyor.
    private func fileURL(_ projectId: UUID, _ id: UUID) -> URL {
        directory.appendingPathComponent("\(projectId.uuidString)_\(id.uuidString).bin")
    }

    func hasLocalCopy(projectId: UUID, id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(projectId, id).path)
    }

    /// Seçilen dosyayı uygulamanın alanına kopyalar ve baytını döndürür.
    ///
    /// GÜVENLİK KAPSAMI BURADA AÇILIP KAPANIYOR. Çağıran, dönen değerden
    /// sonra URL'i unutabilir — bayt artık bizim.
    ///
    /// Kopyalama `Data(contentsOf:)` ile değil `FileManager.copyItem` ile
    /// yapılıyor: 50 MB'lık bir DWG'yi belleğe almak gerekmiyor ve büyük
    /// dosyada bellek baskısı yaratırdı.
    @discardableResult
    func copyIn(from url: URL, projectId: UUID, id: UUID) throws -> UInt64 {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let destination = fileURL(projectId, id)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: url, to: destination)

        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        return (attributes[.size] as? UInt64) ?? 0
    }

    /// Yerel kopyayı, önizlemenin tanıyacağı ADLA geçici dizine yazar.
    ///
    /// QuickLook ve paylaşma sayfası dosyayı ADINDAN tanıyor: uzantısız bir
    /// dosya "bilinmeyen tür" olarak açılır. Depodaki kopya `.bin` soneki
    /// taşıdığı için önizlemeden önce doğru adla kopyalanması gerekiyor.
    func previewURL(for document: ProjectDocument) -> URL? {
        let source = fileURL(document.projectId, document.id)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }

        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent(document.fullFileName)
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.copyItem(at: source, to: target)
            return target
        } catch {
            return nil
        }
    }

    func delete(projectId: UUID, id: UUID, storagePath: String?) async {
        try? FileManager.default.removeItem(at: fileURL(projectId, id))
        let path = storagePath ?? objectPath(projectId, id)
        do {
            try await storage.reference(withPath: path).delete()
        } catch {
            #if DEBUG
            print("[document] bulut silme atlandı \(path): \(error)")
            #endif
        }
    }

    // MARK: Bulut

    func objectPath(_ projectId: UUID, _ id: UUID) -> String {
        "projects/\(projectId.uuidString)/documents/\(id.uuidString)"
    }

    /// Yerel kopyayı yükler ve Storage yolunu döndürür.
    ///
    /// `putFile` kullanılıyor, `putData` değil: dosya diskten akıtılıyor,
    /// 50 MB'lık bir kopya belleğe alınmıyor.
    func upload(projectId: UUID, id: UUID, contentType: String) async throws -> String {
        let source = fileURL(projectId, id)
        let path = objectPath(projectId, id)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        _ = try await storage.reference(withPath: path)
            .putFileAsync(from: source, metadata: metadata)
        return path
    }

    /// Buluttan indirir ve diske yazar — sonraki açılış ağsız olsun.
    ///
    /// `write(toFile:)` ile doğrudan diske iniyor; belge 50 MB olabildiği için
    /// belleğe alınmıyor. Tavan kuralın sınırıyla aynı.
    func download(path: String, projectId: UUID, id: UUID) async throws {
        let destination = fileURL(projectId, id)
        try? FileManager.default.removeItem(at: destination)
        _ = try await storage.reference(withPath: path)
            .writeAsync(toFile: destination)
    }
}
