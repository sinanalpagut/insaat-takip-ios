import SwiftUI

// MARK: - Kayıt İzi (madde 76)
//
// NEDEN BU EKRAN VAR: denetim izi vardı, kural ortağa OKUMA İZNİ veriyordu
// (`auditEntries: allow read: if isMember`) ve `audit(forProject:)` yazılmıştı
// — ama View katmanında ÇAĞIRAN YOKTU. İzi gösteren beş yerin beşi de yalnızca
// yöneticinin açabildiği düzenleme sheet'leriydi.
//
// Yani şeffaflık KURALDA vardı, EKRANDA yoktu. Bu, uygulamanın kendi tanıtım
// cümlesiyle ("Sahadaki her hareket, ortaklarla şeffaf biçimde paylaşılır")
// doğrudan çelişiyordu: ortak rakamların SONUCUNU görüyor ama o rakamın
// DEĞİŞTİRİLDİĞİNİ göremiyordu. 12.500 kg'lık fiş 1.250 kg'a düzeltildiğinde
// ortağın gördüğü tek şey, toplamın sessizce küçülmesiydi.
//
// ROLE GÖRE SÜZÜLMÜYOR ve bu bilinçli: kuralın verdiğinden daha azını
// göstermek, şeffaflık iddiasını ekranda yeniden daraltmak olurdu. Ortak ve
// yönetici AYNI listeyi görüyor.
//
// EKRAN YENİ BİR ŞEY İFŞA ETMİYOR — ölçülerek doğrulandı.
//
// `recordAudit` TEK çağrıda İKİ kayıt yazıyor: `AuditEntry` ve onun ÖZETİNİ
// `meta` alanında taşıyan bir `ActivityItem`. Hareket akışı ortağa zaten açık.
// Yani denetim izinin içeriği bugüne kadar da ortağa ulaşıyordu; eksik olan,
// ona düzgün bir ev ve okunabilir bir biçim vermekti.
//
// GENİŞLEYEN TEK ŞEY ZAMAN PENCERESİ: hareket akışı sunucuda en yeni 200
// kayıtla sınırlı (`FirestoreProjectRepository.activityLimit`), denetim izi
// sınırsız. Ortak artık akıştan düşmüş ESKİ düzeltmeleri de görebiliyor.
// Türü değil, süresi genişliyor.
//
// ALICI ADI SIZMIYOR çünkü denetim izine hiç girmiyor. `BuyerPrivacyTests` bu
// ekran için GENİŞLETİLDİ: önceden yalnızca `updateApartment` yolunu ve
// yalnızca denetim izini tarıyordu. Artık üç yolu birden (`updateApartment`,
// `saveSale` — düzeltme dalı dahil —, `cancelSale`) ve ortağın okuyabildiği
// HER İKİ defteri (denetim izi + hareket akışı) tarıyor. Ekranın güvenliği o
// teste dayanıyor; test düşerse bu ekran da yanlış olur.
//
// Kuralın kendisi de artık test edilmiş durumda (`tests/rules.test.mjs`):
// ortak okur, üye olmayan okuyamaz, ortak yazamaz. Ekranın meşruiyetini veren
// izin bugüne kadar hiçbir testle sabitlenmemişti.

struct AuditTrailView: View {
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    private var entries: [AuditEntry] {
        viewModel.audit(forProject: projectId)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if entries.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    // TEMBEL: uzun projede yüzlerce kayıt olur; hepsini baştan
                    // çizmenin görünür bir faydası yok.
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(gruplar, id: \.baslik) { grup in
                            Text(grup.baslik)
                                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                                .padding(.top, 20)
                                .padding(.bottom, 10)

                            VStack(spacing: 10) {
                                ForEach(grup.kayitlar) { entry in
                                    AuditRow(entry: entry)
                                }
                            }
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // MARK: Gruplama

    private struct Grup {
        let baslik: String
        let kayitlar: [AuditEntry]
    }

    /// Kayıtlar GÜNE göre gruplanıyor.
    ///
    /// Gün başlıkları "Bugün / Dün / tarih" biçiminde: denetim izinde asıl
    /// soru "ne zaman değişti" ve bir müteahhit için o soru takvim gününde
    /// cevaplanıyor, saat başında değil.
    private var gruplar: [Grup] {
        let sirali = entries      // `audit(forProject:)` zaten yeniden eskiye
        var sonuc: [Grup] = []
        for entry in sirali {
            let baslik = Self.gunBasligi(entry.trueDate)
            if let son = sonuc.last, son.baslik == baslik {
                sonuc[sonuc.count - 1] = Grup(baslik: baslik,
                                              kayitlar: son.kayitlar + [entry])
            } else {
                sonuc.append(Grup(baslik: baslik, kayitlar: [entry]))
            }
        }
        return sonuc
    }

    static func gunBasligi(_ date: Date) -> String {
        if Fmt.calendar.isDateInToday(date) { return "Bugün" }
        if Fmt.calendar.isDateInYesterday(date) { return "Dün" }
        return Fmt.shortDate(date)
    }

    // MARK: Başlık

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                DarkHeaderButton(systemName: "chevron.left", label: "Geri") { dismiss() }
                Spacer()
            }
            .padding(.top, 6)

            Text("Kayıt İzi")
                .font(.sora(26, .bold))
                .foregroundColor(.white)
                .padding(.top, 14)

            // KAPSAM SATIRI RAKAMLA. "Kayıt İzi" tek başına neyi kapsadığını
            // söylemiyor; ortağın gördüğü listenin projenin TAMAMI olduğunu
            // bilmesi gerekiyor.
            Text(kapsamMetni)
                .font(.manrope(12.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 5)
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.ink)
        .clipShape(RoundedCorners(radius: 22, corners: [.bottomLeft, .bottomRight]))
    }

    private var kapsamMetni: String {
        let baslik = project?.title ?? ""
        let sayi = entries.count
        return sayi == 0 ? baslik : "\(baslik) · \(sayi) değişiklik"
    }

    // MARK: Boş durum

    /// BOŞ OLMAK KUSUR DEĞİL, DURUM. Yeni bir projede hiç düzeltme olmamış
    /// olması iyi haber; ekran bunu suçlayıcı değil açıklayıcı söylüyor.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal")
                .iconFont(22, weight: .medium)
                .foregroundColor(Palette.accent)
                .frame(width: 54, height: 54)
                .background(Palette.accentTint)
                .cornerRadius(17)

            Text("Henüz düzeltme yok")
                .font(.sora(17, .bold))
                .foregroundColor(Palette.ink)

            Text("Bir kayıt düzeltildiğinde ya da silindiğinde burada görünür: ne değişti, eski değeri neydi, kim yaptı.")
                .font(.manrope(12.5, .medium))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.bottom, 60)
    }
}

// MARK: - Satır

private struct AuditRow: View {
    let entry: AuditEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.action.icon)
                .iconFont(13, weight: .semibold)
                .foregroundColor(rozetRengi)
                .frame(width: 30, height: 30)
                .background(rozetZemini)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(entry.subject)
                        .font(.manrope(13, .bold))
                        .foregroundColor(Palette.ink)
                    Text(entry.action.rawValue)
                        .font(.manrope(11, .semiBold))
                        .foregroundColor(rozetRengi)
                }

                // ESKİ DEĞER DE GÖSTERİLİYOR. Yalnızca yeni değeri göstermek
                // denetim izi olmazdı: "12.500 kg" satırı, o rakamın az önce
                // 1.250 kg'dan değiştirildiğini söylemiyor.
                ForEach(entry.changes) { change in
                    Text(change.text)
                        .font(.manrope(12, .medium))
                        .foregroundColor(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("\(entry.user) · \(Fmt.clock(entry.trueDate))")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textFaded)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Palette.surface)
        .cornerRadius(15)
    }

    private var rozetRengi: Color {
        switch entry.action {
        case .delete: return Palette.alertInk
        case .create: return Palette.success
        case .update: return Palette.accent
        }
    }

    private var rozetZemini: Color {
        rozetRengi.opacity(0.12)
    }
}
