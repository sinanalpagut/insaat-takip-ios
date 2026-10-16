import SwiftUI

// MARK: - İlk açılış tanıtımı
//
// NEDEN VAR: uygulamayı ilk açan kişi tek cümle görüyordu ("Ada / parsel
// bazlı malzeme ve satış takibi") ve ne işe yaradığını anlamadan telefon
// numarası isteniyordu. Numara istemek güven isteyen bir adım; karşılığında
// ne verdiğini söylemeden istemek, ilk engelin en yüksek olduğu yere
// konması demek.
//
// ÜÇ EKRAN, DAHA FAZLASI DEĞİL. Her ekran uygulamanın GERÇEKTEN yaptığı bir
// şeyi anlatıyor; vaat yok. Dördüncü bir ekran eklemek istendiğinde sorulacak
// soru şu: bunun kodda karşılığı var mı, yoksa reklam mı?
//
// ATLANABİLİR VE BİR KEZ. Zorunlu tanıtım, acelesi olan kullanıcıyı
// cezalandırır; tekrar eden tanıtım ise reklamdır (gerekçesi `Plan.swift`te
// reklam kararıyla aynı).
//
// SON EKRANDA NE OLMADIĞI DA YAZIYOR. "Vergi hesaplamaz, muhasebe defteri
// değildir" cümlesi kullanım koşullarında var ve beklentiyi EN BAŞTA kurmak,
// kullanıcının üç ay sonra "ben bunu muhasebe sanıyordum" demesinden iyi.
// Ürünü küçültmüyor; neyi iyi yaptığını netleştiriyor.

struct IntroView: View {
    /// Tanıtım görüldü mü. SÜRÜMLÜ: içerik esaslı biçimde değişirse anahtar
    /// da değişir ve tanıtım bir kez daha gösterilir. Sürümsüz bir anahtar,
    /// yeni anlatımı hiçbir mevcut kullanıcıya gösteremezdi.
    static let gorulduAnahtari = "intro.gorulduV1"

    static var gorulduMu: Bool {
        UserDefaults.standard.bool(forKey: gorulduAnahtari)
    }

    let bitti: () -> Void

    @State private var sayfa = 0

    private struct Adim {
        let ikon: String
        let baslik: String
        let govde: String
    }

    // METİNLER KODDA DOĞRULANABİLİR OLMALI. Üçü de uygulamanın var olan
    // ekranlarına karşılık geliyor: daire/gider/tahsilat kayıtları, ortak
    // salt okur erişimi (güvenlik kurallarıyla uygulanıyor) ve dönem raporu
    // + Excel çıktısı. Olmayan bir şey yazılamaz.
    private let adimlar = [
        Adim(ikon: "building.2",
             baslik: "Şantiyenin tamamı tek yerde",
             govde: "Daireler, satışlar, tahsilatlar, giderler ve malzeme hareketleri. "
                  + "Hangi daire satıldı, ne kadar tahsil edildi, para nereye gitti — "
                  + "hepsi aynı yerde durur."),
        Adim(ikon: "eye",
             baslik: "Ortağın da aynı rakamları görür",
             govde: "Davet ettiğin ortak projeyi görür ama hiçbir kaydı değiştiremez. "
                  + "Herkes aynı tabloya bakar. Daire alıcılarının adları ortaklara "
                  + "gösterilmez."),
        Adim(ikon: "doc.text",
             baslik: "Dönem raporu bir dokunuş",
             govde: "PDF ve Excel çıktısı hazır gelir; mali müşavirine göndereceğin "
                  + "tablo için ayrıca uğraşmazsın."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ATLA her zaman görünür ve ÜSTTE: aşağıdaki düğmeye ulaşmak için
            // üç ekran ilerlemek zorunda kalmak, atlamayı imkânsız kılardı.
            HStack {
                Spacer()
                Button("Atla") { kapat() }
                    .font(.manrope(13.5, .semiBold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 14)

            TabView(selection: $sayfa) {
                ForEach(adimlar.indices, id: \.self) { i in
                    adimGorunumu(adimlar[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if sayfa < adimlar.count - 1 {
                    withAnimation { sayfa += 1 }
                } else {
                    kapat()
                }
            } label: {
                Text(sayfa < adimlar.count - 1 ? "Devam" : "Başlayalım")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(Palette.accent)
                    .cornerRadius(14)
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.ink.ignoresSafeArea())
    }

    private func adimGorunumu(_ adim: Adim) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // İÇERİK YUKARI YASLI, ortalanmış DEĞİL. Ortalanınca metin bloğu
            // kısa olduğu için ekranın üst üçte biri boş kalıyor ve sayfa
            // "yarım yüklenmiş" gibi görünüyordu. Üstteki boşluk sınırlı,
            // alttaki esnek: başlık göz hizasına geliyor.
            Spacer(minLength: 0).frame(maxHeight: 34)

            Image(systemName: adim.ikon)
                .iconFont(26, weight: .regular)
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Palette.accent)
                .cornerRadius(20)

            Text(adim.baslik)
                .font(.sora(25, .bold))
                .foregroundColor(.white)
                // BÜYÜK YAZI BOYUTUNDA KESİLMİYOR: başlık ürünün tek cümlelik
                // vaadi; kesilirse anlamı gider (AX5 turunun dersi).
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)

            Text(adim.govde)
                .font(.manrope(14.5, .medium))
                .foregroundColor(.white.opacity(0.62))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            // SON EKRANDA SINIR CÜMLESİ.
            if adim.ikon == "doc.text" {
                Text("İnşaat Takip bir kayıt aracıdır: vergi hesaplamaz, "
                     + "muhasebe defteri yerine geçmez.")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(.white.opacity(0.42))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kapat() {
        UserDefaults.standard.set(true, forKey: Self.gorulduAnahtari)
        bitti()
    }
}
