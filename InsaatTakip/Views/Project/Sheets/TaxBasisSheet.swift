import SwiftUI

// MARK: - KDV Beyanı (madde 80) — yalnızca yönetici
//
// BU BİR DEFTER DEĞİL, KAYIT SÖZLEŞMESİ. Uygulama vergi HESAPLAMIYOR:
// indirilecek/hesaplanan KDV defteri, oran alanı, beyanname dönemi ve
// düzeltme kayıtları demek olurdu. Burada yapılan tek şey, girilen rakamın
// NE OLDUĞUNU kaydetmek — bugün neredeyse bedava, yarın imkânsız.

struct TaxBasisSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    @State private var expense: TaxBasis?
    @State private var sales: TaxBasis?
    @State private var didLoad = false

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "KDV Beyanı", subtitle: project?.title) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Uygulama vergi HESAPLAMAZ. Burada yalnızca girdiğin "
                         + "rakamların ne olduğunu beyan ediyorsun; tutarlar "
                         + "olduğu gibi kalır, hiçbir toplam değişmez.")
                        .font(.manrope(12, .medium))
                        .foregroundColor(Palette.textMuted)
                        .lineSpacing(3)
                        .padding(.top, 16)

                    // GİDER VE SATIŞ AYRI SORULUYOR, çünkü sahada gerçekten
                    // ayrılar: fiş "KDV dahil" tutarla giriliyor (fişin
                    // üstünde yazan rakam o), daire bedeli ise genellikle KDV
                    // hariç konuşuluyor. Tek soru olsaydı cevabın yarısı
                    // yalan olurdu.
                    picker("GİDER TARAFI", subtitle: "Fiş, malzeme birim fiyatı, gider tutarı",
                           value: $expense)
                        .padding(.top, 20)

                    picker("SATIŞ TARAFI", subtitle: "Daire liste ve satış bedelleri",
                           value: $sales)
                        .padding(.top, 20)

                    // GEÇMİŞ KAYITLAR DEĞİŞMİYOR ve bu yazılı olmalı: beyanı
                    // bugün değiştiren kullanıcı, dünkü fişlerin de dönüştüğünü
                    // sanmamalı. Uygulama hiçbir rakama dokunmuyor; değişiklik
                    // kayıt izine tarihiyle yazılıyor.
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "info.circle")
                            .iconFont(11, weight: .medium)
                            .padding(.top, 1)
                        Text("Beyanı değiştirmek daha önce girilmiş tutarları DEĞİŞTİRMEZ. "
                             + "Değişiklik, tarihiyle birlikte Kayıt İzi'ne yazılır.")
                            .font(.manrope(11, .medium))
                            .lineSpacing(2)
                    }
                    .foregroundColor(Palette.textTertiary)
                    .padding(.top, 20)

                    PrimaryButton(title: "Kaydet") {
                        viewModel.setTaxBasis(role: viewModel.role(inProject: projectId,
                                                                   for: appState.currentUser),
                                              projectId: projectId,
                                              expense: expense, sales: sales)
                        dismiss()
                    }
                    .padding(.top, 22)

                    Spacer(minLength: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .sheetHeight(0.78)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .onAppear {
            guard !didLoad, let project else { return }
            didLoad = true
            expense = project.expenseTaxBasis
            sales = project.salesTaxBasis
        }
    }

    private func picker(_ title: String, subtitle: String,
                        value: Binding<TaxBasis?>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            Text(subtitle)
                .font(.manrope(11.5, .medium))
                .foregroundColor(Palette.textTertiary)

            // "Belirtilmedi" DE BİR SEÇENEK olarak duruyor: kullanıcı emin
            // değilse geri dönebilmeli. Uydurma bir beyan, beyansızlıktan
            // kötüdür — çünkü sonrasında sorgulanmaz.
            FlowLayout(spacing: 9) {
                // nil = "Belirtilmedi" ve listede İLK sırada: beyan yokluğu
                // varsayılan durum, seçeneklerin arasına gizlenmemeli.
                ForEach([TaxBasis?.none, .some(.dahil), .some(.haric)], id: \.self) { option in
                    chip(option, value: value)
                }
            }
        }
    }

    private func chip(_ option: TaxBasis?, value: Binding<TaxBasis?>) -> some View {
        let selected = value.wrappedValue == option
        return Button {
            value.wrappedValue = option
        } label: {
            Text(option.label)
                .font(.manrope(12.5, .bold))
                .foregroundColor(selected ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(9)
        }
    }
}
