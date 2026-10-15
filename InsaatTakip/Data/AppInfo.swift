import Foundation
import UIKit

// MARK: - Sürüm ve destek bilgisi (madde 72)
//
// Uygulama içinde ne sürüm satırı ne destek yolu vardı: `CFBundleShortVersionString`
// okuyan tek satır kod yoktu. Crashlytics de bilinçli olarak ertelenmiş
// durumda — ikisi birleşince sahadaki bir hata İKİ KANALDAN DA görünmez
// oluyordu: kullanıcı bildiremiyor, geliştirici ölçemiyor.

enum AppInfo {

    /// "1.0 (169)" — mağaza sürümü ve build numarası.
    ///
    /// İKİSİ BİRDEN gösteriliyor. Yalnızca "1.0" yazmak destek için işe
    /// yaramaz: aynı sürüm numarasıyla onlarca build gönderiliyor ve hatanın
    /// hangisinde olduğu ancak build numarasıyla ayrılıyor.
    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    /// Destek adresi. Alan adı kullanıcının kendi alan adı; kişisel e-posta
    /// depoya girmiyor.
    static let supportAddress = "info@benav.com.tr"

    /// Gizlilik politikası adresi — madde 27'ye bağlı.
    ///
    /// `nil` olduğu sürece satır GÖSTERİLMİYOR. Çalışmayan bir bağlantı
    /// koymak, hiç koymamaktan kötü: kullanıcı dokunur, boş sayfa görür ve
    /// uygulamanın bakımsız olduğunu düşünür. Madde 27 kapanınca burası tek
    /// satırlık bir değişiklik.
    static let privacyPolicyURL: URL? = nil

    /// Destek e-postasının gövdesi — TANI BİLGİSİ ÖNCEDEN DOLU.
    ///
    /// "Uygulama açılmıyor" diye gelen bir e-posta ile çalışılamıyor. Sürüm,
    /// iOS sürümü ve cihaz modeli olmadan hatanın hangi derlemede olduğu
    /// bilinemez — ve kullanıcıdan bunları sormak, cevabı günlerce geciktirir.
    /// Crash raporu olmadığı için bu satırlar tek tanı kaynağı.
    static var supportMailURL: URL? {
        let govde = """


        ─────────────
        Lütfen bu satırları silmeyin; sorunu bulmamıza yarıyor.
        Uygulama: \(versionText)
        iOS: \(UIDevice.current.systemVersion)
        Cihaz: \(deviceIdentifier)
        """
        var parcalar = URLComponents()
        parcalar.scheme = "mailto"
        parcalar.path = supportAddress
        parcalar.queryItems = [
            URLQueryItem(name: "subject", value: "İnşaat Takip · geri bildirim"),
            URLQueryItem(name: "body", value: govde),
        ]
        return parcalar.url
    }

    /// "iPhone14,2" gibi donanım kimliği.
    ///
    /// `UIDevice.current.model` yalnızca "iPhone" diyor — hangi model olduğunu
    /// söylemiyor ve bir hata raporunda işe yaramıyor.
    static var deviceIdentifier: String {
        var sistem = utsname()
        uname(&sistem)
        let ayna = Mirror(reflecting: sistem.machine)
        let ad = ayna.children.reduce(into: "") { sonuc, eleman in
            guard let deger = eleman.value as? Int8, deger != 0 else { return }
            sonuc.append(Character(UnicodeScalar(UInt8(deger))))
        }
        return ad.isEmpty ? "bilinmiyor" : ad
    }
}
