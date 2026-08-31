import SwiftUI

// MARK: - Ortak Cari Hareketi (madde 82) — yalnızca yönetici
//
// Sermaye, çekilen/avans ve kâr dağıtımı. ÜÇÜ DE NAKİT HAREKETİ, inşaat
// maliyeti DEĞİL: bugüne kadar bir dağıtımı kaydetmenin tek yolu ".diger"
// kategorisinde bir giderdi ve o kayıt, dağıtımın dayandığı net rakamı bütün
// ortaklar için birden düşürüyordu.

struct PartnerLedgerSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID
    /// Belirli bir ortağın kartından açıldıysa o ortak seçili gelir.
    let partnerId: UUID?

    @State private var selectedPartnerId: UUID?
    @State private var kind: PartnerLedgerEntry.Kind = .sermaye
    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var didLoad = false

    private var partners: [Partner] {
        viewModel.partners(for: projectId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Cari Hareket",
                        subtitle: viewModel.projects.first { $0.id == projectId }?.title) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("ORTAK")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    FlowLayout(spacing: 9) {
                        ForEach(partners) { partner in
                            partnerChip(partner)
                        }
                    }
                    .padding(.top, 10)

                    Text("HAREKET")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 20)

                    FlowLayout(spacing: 9) {
                        ForEach(PartnerLedgerEntry.Kind.allCases) { option in
                            kindChip(option)
                        }
                    }
                    .padding(.top, 10)

                    // YÖN CÜMLESİ: "sermaye" ve "çekilen" kelimeleri tek
                    // başına hangi tarafa aktığını söylemiyor; para
                    // hareketinde yön yanlış anlaşılırsa bakiye ters döner.
                    Text(kind == .sermaye
                         ? "Ortak → kasa. Bakiyesini ARTIRIR."
                         : "Kasa → ortak. Bakiyesini AZALTIR.")
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .padding(.top, 8)

                    field("TUTAR (₺)", text: $amountText,
                          placeholder: "Örn. 500.000", keyboard: .decimalPad)
                        .padding(.top, 18)

                    // ÖRNEK SEÇİLEN TÜRE UYUYOR: "Kâr dağıtımı" seçiliyken
                    // "Örn. sermaye katkısı" yazan bir kutu, kullanıcıya
                    // yanlış içerik öneriyor.
                    field("NOT", text: $note, placeholder: notePlaceholder)
                        .padding(.top, 14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("TARİH")
                            .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                    .padding(.top, 14)

                    // KAPSAM YAZILI: bu kaydın giderden farkı, kullanıcının
                    // bugüne kadar yaptığı şeyin tam tersi olduğu için
                    // söylenmek zorunda.
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "info.circle")
                            .iconFont(11, weight: .medium)
                            .padding(.top, 1)
                        Text("Bu kayıt inşaat gideri DEĞİLDİR: malzeme/gider toplamlarına "
                             + "ve dönem netine girmez. Ortağa ödenen parayı gider olarak "
                             + "yazmak, bütün ortakların payını birden düşürür.")
                            .font(.manrope(11, .medium))
                            .lineSpacing(2)
                    }
                    .foregroundColor(Palette.textTertiary)
                    .padding(.top, 16)

                    PrimaryButton(title: "Kaydet") { save() }
                        .padding(.top, 20)

                    Spacer(minLength: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .sheetHeight(0.85)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            selectedPartnerId = partnerId ?? partners.first?.id
        }
    }

    private var notePlaceholder: String {
        switch kind {
        case .sermaye: return "Örn. Nisan sermaye katkısı"
        case .cekilen: return "Örn. Elden avans"
        case .dagitim: return "Örn. 2026 birinci dönem kâr payı"
        }
    }

    private func save() {
        guard let selectedPartnerId else {
            viewModel.flash("Ortak seçilmedi")
            return
        }
        let saved = viewModel.addLedgerEntry(
            role: viewModel.role(inProject: projectId, for: appState.currentUser),
            projectId: projectId, partnerId: selectedPartnerId,
            kind: kind, amountText: amountText, date: date, note: note)
        if saved { dismiss() }
    }

    private func partnerChip(_ partner: Partner) -> some View {
        let selected = selectedPartnerId == partner.id
        return Button {
            selectedPartnerId = partner.id
        } label: {
            Text(partner.name)
                .font(.manrope(12.5, .bold))
                .foregroundColor(selected ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1))
                .cornerRadius(9)
        }
    }

    private func kindChip(_ option: PartnerLedgerEntry.Kind) -> some View {
        let selected = kind == option
        return Button {
            kind = option
        } label: {
            Text(option.rawValue)
                .font(.manrope(12.5, .bold))
                .foregroundColor(selected ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1))
                .cornerRadius(9)
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.manrope(14, .bold))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }
}
