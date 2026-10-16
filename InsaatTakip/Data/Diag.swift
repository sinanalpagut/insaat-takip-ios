import Foundation

// MARK: - Tanı günlüğü (madde 71 · 16 Eki 2026)
//
// NEDEN VAR: uygulamanın tanı satırlarının tamamı `#if DEBUG` içindeydi,
// yani RELEASE DERLEMESİ SESSİZDİ. Bugün bunun bedeli ödendi: App Attest
// cihazda çalışmıyordu ve uygulama hiçbir şey söylemeden açılıyordu; arıza
// ancak `#if DEBUG` taşımayan bir satır eklenince göründü.
//
// App Check ZORLAMASI açıldığı için bu körlük artık daha pahalı: reddedilen
// bir istek kullanıcıya "veriler yüklenemedi" diye görünür ve NEDENİ hiçbir
// yerde yazmaz. Kural reddi mi, App Check reddi mi, eksik indeks mi, ağ mı —
// dördü aynı ekranı üretiyor ama dördünün çözümü ayrı.
//
// CRASHLYTICS BİLEREK ERTELENDİ (madde 30), yani sahadaki bir hatanın
// görünebildiği başka kanal yok. Bu satırlar cihaz kabloya takılıyken
// `devicectl ... --console` ile okunuyor.
//
// NE YAZILMIYOR: kullanıcı verisi. Yalnızca hatanın KİMLİĞİ — alan adı, kod
// ve sistemin verdiği açıklama. Daire numarası, alıcı adı, tutar ya da
// belge içeriği bu satırlara girmiyor.
//
// KABUL EDİLEN TAKAS: Firestore'un bazı hataları (eksik indeks) açıklama
// metninde konsol adresini taşıyor ve o adres proje kimliğini içeriyor.
// Proje kimliği zaten uygulama paketinin içinde olduğu için bu yeni bir
// açığa çıkarma değil; teşhis değeri ağır basıyor.

enum Diag {

    /// Hata tanısını yazar — RELEASE'DE DE.
    ///
    /// `etiket` köşeli parantezli kısa bir ad: "refresh", "image", "invite".
    /// Günlükte aranabilir olması için sabit tutulmalı.
    static func log(_ etiket: String, _ error: Error) {
        let ns = error as NSError
        print("[\(etiket)] HATA · \(ns.domain) · kod \(ns.code) · \(ns.localizedDescription)")
    }

    /// Serbest metinli tanı satırı — RELEASE'DE DE.
    static func log(_ etiket: String, _ mesaj: String) {
        print("[\(etiket)] \(mesaj)")
    }
}
