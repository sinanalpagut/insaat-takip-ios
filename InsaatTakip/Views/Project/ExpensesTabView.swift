import SwiftUI

// MARK: - Giderler Sekmesi
// Malzeme dışı maliyet kalemleri: işçilik, taşeron, arsa, ruhsat-harç,
// makine, yakıt. Üstte toplam + kategori kırılımı, altında kronolojik liste.

struct ExpensesTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    /// Tam ekranda açılan gider fişi.
    @State private var previewedReceipt: SharePayloadImage?

    let projectId: UUID

    private var expenses: [Expense] { viewModel.expenses(for: projectId) }
    /// Proje bazlı rol (bkz. Project.role(for:)).
    private var isAdmin: Bool {
        viewModel.projects.first { $0.id == projectId }?
            .role(for: appState.currentUser) == .admin
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 11) {
                if expenses.isEmpty {
                    emptyState.padding(.top, 16)
                } else {
                    summaryCard.padding(.top, 16)

                    HStack {
                        Text("Gider Kayıtları")
                            .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        Spacer()
                        Text("\(expenses.count) kayıt")
                            .font(.manrope(12, .semiBold))
                            .foregroundColor(Palette.textSecondary)
                    }
                    .padding(.top, 4)

                    ForEach(expenses) { expense in
                        ExpenseRowView(
                            expense: expense,
                            hasReceipt: expense.receiptPath != nil,
                            receipt: viewModel.receiptImages[expense.id],
                            onReceiptAppear: {
                                viewModel.imageNeeded(bucket: .receipts, photoId: expense.id)
                            },
                            onReceiptTap: { previewedReceipt = SharePayloadImage(image: $0) })
                            .contextMenu {
                                if isAdmin {
                                    Button(role: .destructive) {
                                        viewModel.deleteExpense(role: isAdmin ? .admin : .partner,
                                                                id: expense.id)
                                    } label: {
                                        Label("Gideri sil", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .receiptPreview($previewedReceipt)
    }

    // MARK: Özet

    private var summaryCard: some View {
        let breakdown = viewModel.expenseBreakdown(for: projectId)
        let total = viewModel.totalOtherExpenses(for: projectId)
        let materialCost = viewModel.totalMaterialCost(for: projectId)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Malzeme Dışı Gider")
                        .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.1)
                    Text(Fmt.compactMoney(total))
                        .font(.sora(26, .bold))
                        .foregroundColor(Palette.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Toplam Maliyet")
                        .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.1)
                    Text(Fmt.compactMoney(materialCost + total))
                        .font(.sora(18, .bold))
                        .foregroundColor(Palette.alertInk)
                }
            }

            // Malzeme / diğer gider oranı
            // Para/para bölmesi ORAN üretir; Kurus'ta `/` tanımlı olmadığı için
            // dönüşüm açıkça yazılır — tam sayı bölmesiyle 0/1'e yuvarlanma riski yok.
            ProgressBarView(fraction: (materialCost + total) > .zero
                                ? Double(materialCost.raw) / Double((materialCost + total).raw) : 0,
                            fill: Palette.accent,
                            track: Palette.alertInk.opacity(0.35))
                .padding(.top, 14)

            HStack {
                Text("Malzeme \(Fmt.compactMoney(materialCost))")
                Spacer()
                Text("Diğer \(Fmt.compactMoney(total))")
            }
            .font(.manrope(11.5, .medium))
            .foregroundColor(Palette.textMuted)
            .padding(.top, 8)

            if !breakdown.isEmpty {
                Divider().overlay(Palette.divider).padding(.top, 13)

                // En büyük üç kalem
                HStack(spacing: 0) {
                    ForEach(breakdown.prefix(3), id: \.category) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.category.shortName)
                                .smallCapsLabel(size: 9.5, color: Palette.textTertiary, tracking: 0.9)
                            Text(Fmt.compactMoney(item.total))
                                .font(.sora(14, .bold))
                                .foregroundColor(Palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hammer")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Palette.textTertiary)
            Text("Henüz gider kaydı yok")
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.ink)
            Text(isAdmin
                 ? "İşçilik, taşeron, arsa ve harç giderlerini buraya girersen \"Net\" rakamı gerçeği yansıtır"
                 : "Yönetici gider girdikçe burada görünecek")
                .font(.manrope(11.5, .medium))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .frame(height: 190)
        .background(Palette.fillSubtle)
        .cornerRadius(16)
        .dashedBorder(Palette.dashed, radius: 16)
    }
}

// MARK: - Gider satırı

struct ExpenseRowView: View {
    let expense: Expense
    var hasReceipt: Bool
    /// Fiş görseli — elde varsa küçük resim, yoksa yer tutucu.
    var receipt: UIImage?
    /// Yer tutucu ekranda göründüğünde indirmeyi ister.
    var onReceiptAppear: () -> Void = {}
    /// Fişe dokunulduğunda tam ekran açar.
    var onReceiptTap: (UIImage) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Palette.alertInk)
                .frame(width: 40, height: 40)
                .background(Palette.alertTint)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(expense.category.rawValue)
                        .font(.manrope(14, .bold))
                        .foregroundColor(Palette.ink)
                    if hasReceipt {
                        Image(systemName: "paperclip")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Palette.textTertiary)
                    }
                }
                Text(expense.detailText.isEmpty ? expense.dateText
                                                : "\(expense.detailText) · \(expense.dateText)")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Fiş görseli ORTAĞA DA AÇIK: `storage.rules` malzeme/gider fişini
            // üyeye okutuyor ve ortak aynı harcamayı listede zaten görüyor.
            // Önceden yalnızca bir ataç rozeti vardı, o da BU CİHAZIN belleğine
            // bakıyordu: fiş bulutta dururken ikinci cihazda ve ortakta "fiş
            // yok" görünüyordu.
            if hasReceipt {
                if let receipt {
                    Image(uiImage: receipt)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture { onReceiptTap(receipt) }
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(Palette.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(Palette.fillMuted)
                        .cornerRadius(8)
                        .task(id: expense.id) { onReceiptAppear() }
                }
            }

            Text(Fmt.compactMoney(expense.amount))
                .font(.sora(14.5, .bold))
                .foregroundColor(Palette.alertInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Palette.surface)
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.border, lineWidth: 1))
    }
}
