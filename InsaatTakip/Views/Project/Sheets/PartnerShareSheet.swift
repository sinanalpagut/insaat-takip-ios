import SwiftUI

// MARK: - Hisse Düzenleme (madde 20, yalnızca yönetici)
//
// Bu ekran açılana kadar `sharePercent` YAZILAMAYAN bir alandı: proje kuran
// kişiye sabit %100, davetle katılana %0 veriliyordu ve değiştirecek ne bir
// fonksiyon ne bir form vardı. Yani gerçek bir projede davet edilen her ortak,
// adının yanında düzeltemeyeceği bir "%0" görüyordu — pay hesabı yazılsaydı da
// herkesin payı 0 ₺ çıkardı.
//
// Yüzde metin alanı DEĞİL adım düğmeleriyle giriliyor: hisse dağılımı nadir ve
// dikkatli yapılan bir işlem, klavyeyle 5 yerine 50 yazmak kolay ve sonucu
// doğrudan ortağın parasını etkiliyor.

struct PartnerShareSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let partner: Partner

    @State private var percent: Int = 0
    @State private var didLoad = false

    /// Diğer ortaklara tanımlı toplam — bu ortağın tavanı bundan çıkar.
    private var othersTotal: Int {
        viewModel.partners(for: partner.projectId)
            .filter { $0.id != partner.id }
            .reduce(0) { $0 + $1.sharePercent }
    }

    private var ceiling: Int { max(0, 100 - othersTotal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Hisse", subtitle: partner.name) { dismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Text("HİSSE YÜZDESİ")
                    .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                    .padding(.top, 18)

                HStack {
                    Text("%\(percent)")
                        .font(.sora(28, .bold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Stepper("", value: $percent, in: 0...ceiling)
                        .labelsHidden()
                        .tint(Palette.accent)
                }
                .padding(.horizontal, 16)
                .frame(height: 64)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
                .padding(.top, 10)

                // Tavan gerekçesiyle birlikte: yönetici neden yukarı
                // çıkamadığını görmeli, düğme sessizce durmamalı.
                Text(othersTotal == 0
                     ? "Bu projedeki tek tanımlı hisse bu."
                     : "Diğer ortaklara %\(othersTotal) tanımlı · bu ortağa en çok %\(ceiling) verilebilir.")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                PrimaryButton(title: "Kaydet") {
                    let role = viewModel.role(inProject: partner.projectId,
                                              for: appState.currentUser)
                    if viewModel.updatePartnerShare(role: role,
                                                    partnerId: partner.id,
                                                    percent: percent) {
                        dismiss()
                    }
                }
                .padding(.top, 22)

                Text("Değişiklik, kimin ne zaman yaptığıyla birlikte değişiklik kaydına yazılır. Ortağın payı sessizce değiştirilemez.")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                let history = viewModel.audit(for: partner.id)
                if !history.isEmpty {
                    Text("DEĞİŞİKLİK KAYDI")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 22)
                    ForEach(history) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.summary)
                                .font(.manrope(12, .semiBold))
                                .foregroundColor(Palette.ink)
                            Text("\(Fmt.shortDate(entry.date)) · \(entry.user)")
                                .font(.manrope(11, .medium))
                                .foregroundColor(Palette.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.page)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            percent = partner.sharePercent
        }
    }
}
