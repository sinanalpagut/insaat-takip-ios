import SwiftUI

// MARK: - Ortaklar Sekmesi (Ekran 05)
// Ortak satırları: 40px baş harf avatarı (yönetici = ink, ortak = bakır tint),
// ad + rol, katılım tarihi, sağda bakır hisse yüzdesi.
// Ortak rolündeyken salt-okunur açıklaması gösterilir; davet FAB'ı yalnızca yöneticide.

struct PartnersTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    let projectId: UUID

    /// Hissesi düzenlenen ortak (yalnızca yönetici).
    @State private var editingPartner: Partner?

    /// PROJE BAZLI rol — global rol DEĞİL. `appState.isAdmin` her gerçek
    /// oturuma `.admin` veriyor (rol artık projede yaşıyor, kullanıcıda değil —
    /// madde 16j); global bakılınca davetle katılan ORTAK burada yönetici
    /// muamelesi görür.
    private var isAdmin: Bool {
        viewModel.role(inProject: projectId, for: appState.currentUser) == .admin
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                let partners = viewModel.partners(for: projectId)
                let shareTotal = partners.reduce(0) { $0 + $1.sharePercent }

                HStack {
                    Text("Hisse Dağılımı")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    Spacer()
                    // Gerçek toplam; %100'ü tutmuyorsa uyarı rengiyle belirtilir.
                    Text("%\(shareTotal) tanımlı")
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(shareTotal == 100 ? Palette.textSecondary : Palette.alertInk)
                }
                .padding(.top, 16)

                // "Payın" kartı — oturumu açan kişinin KENDİ ortak kaydı için.
                // Yöneticinin de bir Partner kaydı var (kurucu), o yüzden kart
                // role göre değil KAYDA göre çıkıyor.
                if let mine = viewModel.partnerRecord(in: projectId, for: appState.currentUser) {
                    shareCard(mine)
                        .padding(.top, 4)
                }

                ForEach(partners) { partner in
                    PartnerRowView(partner: partner)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Hisse düzenleme YALNIZCA yöneticide. Bu yol açılana
                            // kadar sharePercent hiç girilemiyordu: kurucu sabit
                            // %100, davetle katılan %0.
                            if isAdmin { editingPartner = partner }
                        }
                }

                // Ortak görünümü: davet yetkisinin kimde olduğunu açıklayan not.
                if !isAdmin {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Palette.accent)
                            .padding(.top, 1)
                        Text("Bu projeyi salt okunur takip ediyorsun. Yeni ortak daveti yalnızca yönetici tarafından yapılabilir.")
                            .font(.manrope(12, .medium))
                            .foregroundColor(Palette.textMuted)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.accentTint.opacity(0.55))
                    .cornerRadius(14)
                    .padding(.top, 6)
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .sheet(item: $editingPartner) { partner in
            PartnerShareSheet(partner: partner)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Payın kartı

    /// Ortağın kendi payı — projenin ZATEN gösterdiği rakamların paya bölünmüş
    /// hâli. Tek satırlık bir "payın şu kadar" YOK; gerekçesi
    /// `ProjectViewModel.share(of:)` yorumunda.
    @ViewBuilder
    private func shareCard(_ partner: Partner) -> some View {
        let project = viewModel.projects.first { $0.id == projectId }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Payın")
                    .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                Spacer()
                Text("%\(partner.sharePercent)")
                    .font(.sora(15, .bold))
                    .foregroundColor(Palette.accent)
            }

            if let share = viewModel.share(of: partner) {
                shareRow("Satıştan", share.sales, Palette.ink)
                shareRow("Girilen giderden", -share.cost, Palette.alertInk)
                Divider().padding(.vertical, 8)
                shareRow("Aradaki fark", share.difference, Palette.ink, bold: true)

                Text("KASA")
                    .smallCapsLabel(size: 9.5, color: Palette.textFaded, tracking: 1.1)
                    .padding(.top, 14)
                shareRow("Tahsil edilenden", share.collected, Palette.success)
                shareRow("Kalan alacaktan", share.outstanding, Palette.textSecondary)

                // Kapsam kutusu. "Aradaki fark" kâr DEĞİL: gelir tarafı satılan
                // dairenin tam bedelini bugün yazıyor, gider tarafı yalnızca
                // bugüne kadar girileni. Kalan inşaat maliyeti henüz düşülmedi.
                Text(scopeText(progress: project?.progress ?? 0,
                               deposits: viewModel.depositAmount(for: projectId)))
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            } else {
                // Sıfırlarla dolu bir kart, tanımsız hisseyi "payın yok" diye
                // gösterirdi. Davetle katılan ortak %0 ile geliyor.
                Text("Hissen henüz tanımlanmadı. Yönetici hisse dağılımını girdiğinde payına düşen tutarlar burada görünecek.")
                    .font(.manrope(12, .medium))
                    .foregroundColor(Palette.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border, lineWidth: 1))
    }

    private func shareRow(_ label: String, _ value: Kurus,
                          _ color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.manrope(bold ? 13 : 12.5, bold ? .bold : .medium))
                .foregroundColor(bold ? Palette.ink : Palette.textSecondary)
            Spacer()
            Text(Fmt.money(value))
                .font(.sora(bold ? 15 : 13.5, .bold))
                .foregroundColor(color)
        }
        .padding(.top, 8)
    }

    /// Neyin dahil OLMADIĞI. Madde 1'in dersi: eksik kapsamlı bir rakam,
    /// kapsamı yazılmadığında yanıltıcıdır.
    private func scopeText(progress: Int, deposits: Kurus) -> String {
        var parts = ["Bu tutarlar uygulamaya girilen kayıtlardan hesaplanır."]
        if progress < 100 {
            parts.append("İnşaatın kalan maliyeti (%\(progress) tamamlandı) HENÜZ DÜŞÜLMEDİ — \"aradaki fark\" kâr değildir.")
        }
        // Kapora kasadadır ama DAĞITILABİLİR DEĞİLDİR: satış bozulursa geri
        // gider. Rakama girmiyor; girmediğini söylemek de kapsamın parçası.
        if deposits > .zero {
            parts.append("Rezerve dairelerin \(Fmt.money(deposits)) kaporası kasadadır ama iade edilebilir olduğu için paya girmez.")
        }
        parts.append("Vergi, finansman gideri ve tedarikçi vadesi dahil değildir.")
        parts.append("Ortakların koyduğu sermaye ve çektiği para henüz uygulamada tutulmuyor.")
        return parts.joined(separator: " ")
    }
}

// MARK: - Ortak satırı

struct PartnerRowView: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: 12) {
            Text(partner.initials)
                .font(.manrope(13, .extraBold))
                .foregroundColor(partner.isFounder ? .white : Palette.accent)
                .frame(width: 40, height: 40)
                .background(partner.isFounder ? Palette.ink : Palette.accentTint)
                .cornerRadius(13)

            VStack(alignment: .leading, spacing: 3) {
                Text(partner.name)
                    .font(.manrope(13.5, .bold))
                    .foregroundColor(Palette.ink)
                Text(partner.joinedText)
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Text("%\(partner.sharePercent)")
                .font(.sora(15, .bold))
                .foregroundColor(Palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Palette.surface)
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.border, lineWidth: 1))
    }
}
