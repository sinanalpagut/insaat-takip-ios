import SwiftUI

// MARK: - Ortak karşılama (katıldıktan sonra bir kez)
//
// NEDEN ŞERİT YETMİYOR: katılma başarılı olunca 2,6 saniyelik bir şerit
// çıkıyordu — "<proje> · salt okunur erişim". Ortağın bilmesi gereken şey
// o şeride sığmıyor ve şerit söndükten sonra geriye hiçbir iz kalmıyor.
// Aynı karar yedekten geri yüklemede de verilmişti: birkaç rakam ve iki
// uyarı taşıyan sonuç, kaybolan bir şeride emanet edilemez.
//
// NEDEN ÖNEMLİ: ortak, uygulamayı İLK KEZ başkasının projesinde görüyor ve
// hiçbir şeyi değiştiremediğini fark ettiğinde bunu KUSUR sanıyor. "Neden
// düzenleyemiyorum" sorusunun cevabı daveti kabul ettikten SONRA değil,
// hemen o anda verilmeli.
//
// NE YAZILIYORSA KODDA KARŞILIĞI VAR. Göreceklerinin listesi ortağın
// gerçekten okuyabildiği koleksiyonlar; göremeyeceği şey (alıcı adları)
// güvenlik kurallarıyla ayrı belgede tutuluyor. Vaat yok.
//
// `katil.html` İLE AYNI CÜMLELER: davet bağlantısından gelen ortak aynı
// şeyi web sayfasında okumuştu. İkisinin ayrışması, aynı kişiye iki farklı
// söz vermek olurdu.

struct PartnerWelcomeSheet: View {
    let projectTitle: String
    let kapat: () -> Void

    private let gorecekleri = [
        "Dairelerin durumu: satılan, boş, kapora",
        "Giderler, malzemeler ve fişler",
        "Tahsilatlar ve taksit planları",
        "Ortak cari hesabı ve payın",
        "Dönem raporu, PDF ve Excel çıktısı",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Projeye katıldın",
                        subtitle: projectTitle) { kapat() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {

                    bolum(baslik: "Neler görürsün",
                          ikon: "checkmark",
                          renk: Palette.accent,
                          satirlar: gorecekleri)

                    // SINIRLAR AYRI KARTTA VE AYNI AĞIRLIKTA. Küçük bir dipnot
                    // olsaydı okunmaz, okunmayınca da "uygulama bozuk" sanılırdı.
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Neler yapamazsın")
                            .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)

                        satir("Hiçbir kaydı değiştiremez, silemez veya ekleyemezsin",
                              ikon: "xmark", renk: Palette.textMuted)
                        satir("Daire alıcılarının adları sana gösterilmez",
                              ikon: "xmark", renk: Palette.textMuted)

                        Text("Bu kısıtlar uygulamada gizlemekle değil, sunucudaki "
                             + "güvenlik kurallarıyla uygulanır.")
                            .font(.manrope(11.5, .medium))
                            .foregroundColor(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface)
                    .cornerRadius(15)

                    // RAKAMLARIN KAYNAĞI SÖYLENİYOR: ortak bir tutarı yanlış
                    // bulduğunda uygulamayı değil, projeyi yöneten kişiyi
                    // araması gerektiğini bilmeli.
                    Text("Gördüğün rakamlar projeyi yöneten kişinin girdiği "
                         + "kayıtlardan hesaplanır. Bir tutar sana yanlış "
                         + "görünüyorsa ona danış.")
                        .font(.manrope(12, .medium))
                        .foregroundColor(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)

                    PrimaryButton(title: "Projeyi aç") { kapat() }
                        .padding(.top, 2)

                    Spacer().frame(height: 16)
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.page)
        .sheetHeight(0.82)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
    }

    private func bolum(baslik: String, ikon: String, renk: Color,
                       satirlar: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(baslik)
                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
            ForEach(satirlar, id: \.self) { s in
                satir(s, ikon: ikon, renk: renk)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .cornerRadius(15)
    }

    private func satir(_ metin: String, ikon: String, renk: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: ikon)
                .iconFont(11, weight: .bold)
                .foregroundColor(renk)
                .padding(.top, 2)
            Text(metin)
                .font(.manrope(12.5, .medium))
                .foregroundColor(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
