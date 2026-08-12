import SwiftUI

// MARK: - Malzeme Hareket Detayı (Ekran 03)
// Karta dokununca açılan alt sayfa: rozet + ad + hassas birim fiyat,
// GİREN / KULLANILAN / KALAN kutuları ve SON HAREKETLER listesi.

struct MaterialLogSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let materialId: UUID

    /// Dokunulan fiş fotoğrafının tam ekran önizlemesi.
    @State private var previewedReceipt: SharePayloadImage?
    /// Düzenlenmek üzere açılan hareket.
    @State private var editingLog: MaterialLog?
    /// Silme onayı — tek dokunuşla veri kaybı olmasın.
    @State private var pendingDelete: MaterialLog?

    private var material: Material? {
        viewModel.materials.first { $0.id == materialId }
    }

    private var isAdmin: Bool { appState.currentUser?.role == .admin }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let material {
                // Başlık: rozet + ad + birim fiyat + kapat
                HStack(spacing: 12) {
                    CodeBadge(code: material.code, critical: material.isCritical)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(material.name)
                            .font(.sora(22, .bold))
                            .foregroundColor(Palette.ink)
                        Text("\(material.subtitle) · \(Fmt.unitPriceExact(material.unitPrice, unit: material.unit))")
                            .font(.manrope(12.5, .medium))
                            .foregroundColor(Palette.textSecondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Palette.textMuted)
                            .frame(width: 40, height: 40)
                            .background(Palette.fillMuted)
                            .cornerRadius(13)
                    }
                }
                .padding(.top, 24)

                // GİREN / KULLANILAN / KALAN kutuları
                HStack(spacing: 9) {
                    statTile("Giren", Fmt.qty(material.totalIn),
                             background: Palette.fillSubtle,
                             labelColor: Palette.textTertiary, valueColor: Palette.ink)
                    statTile("Kullanılan", Fmt.qty(material.totalOut),
                             background: Palette.fillSubtle,
                             labelColor: Palette.textTertiary, valueColor: Palette.ink)
                    statTile("Kalan", Fmt.qty(material.currentStock),
                             background: material.isCritical ? Palette.alertTint : Palette.accentTint,
                             labelColor: material.isCritical ? Palette.alertInk : Palette.accent,
                             valueColor: material.isCritical ? Palette.alertInk : Palette.accent)
                }
                .padding(.top, 18)

                HStack(alignment: .firstTextBaseline) {
                    Text("Son Hareketler")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    Spacer()
                    if isAdmin {
                        Text("Düzeltmek için basılı tut")
                            .font(.manrope(10.5, .medium))
                            .foregroundColor(Palette.textTertiary)
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 4)

                // Giriş / çıkış kayıtları
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        let entries = viewModel.logs(for: materialId)
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, log in
                            logRow(log, unit: material.unit)
                            if index < entries.count - 1 {
                                Divider().overlay(Palette.divider)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .sheet(item: $editingLog) { log in
            if let projectId = material?.projectId {
                ReceiptSheet(projectId: projectId, editingLogId: log.id)
            }
        }
        .alert("Fiş silinsin mi?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { log in
            Button("Vazgeç", role: .cancel) { }
            Button("Sil", role: .destructive) {
                viewModel.deleteReceipt(role: appState.currentUser?.role ?? .partner, logId: log.id)
            }
        } message: { log in
            Text("\(log.signedAmount(unit: material?.unit ?? "")) · \(log.note)\nStok ve maliyet yeniden hesaplanır; işlem değişiklik kaydına geçer.")
        }
        .fullScreenCover(item: $previewedReceipt) { payload in
            // ZStack hizası tüm çocuklara uygulandığı için görsel üste yapışıyordu;
            // görsel ortalanır, kapat butonu ayrı bir overlay olarak üste konur.
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: payload.image)
                    .resizable()
                    .scaledToFit()
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    previewedReceipt = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                }
                .padding(20)
            }
        }
    }

    private func statTile(_ label: String, _ value: String,
                          background: Color, labelColor: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .smallCapsLabel(size: 9.5, color: labelColor, tracking: 1.0)
            Text(value)
                .font(.sora(16, .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .cornerRadius(12)
    }

    /// Hareket satırı: 26px yön rozeti, not, "tarih · kullanıcı", işaretli miktar.
    /// Fiş kamerayla çekildiyse notun yanında küçük bir önizleme çıkar.
    private func logRow(_ log: MaterialLog, unit: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: log.type == .entry ? "arrow.down" : "arrow.up")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(log.type == .entry ? Palette.success : Palette.textFaded)
                .frame(width: 26, height: 26)
                .background(log.type == .entry ? Palette.successTint : Palette.fillMuted)
                .cornerRadius(9)

            if let receipt = viewModel.receiptImages[log.id] {
                Image(uiImage: receipt)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipped()
                    .cornerRadius(9)
                    .onTapGesture { previewedReceipt = SharePayloadImage(image: receipt) }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(log.note)
                    .font(.manrope(13, .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(log.dateText) · \(log.user)")
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textSecondary)
                    // Sonradan düzeltilen kayıt sessizce değişmiş görünmesin.
                    if !viewModel.audit(for: log.id).isEmpty {
                        Text("düzenlendi")
                            .font(.manrope(9.5, .bold))
                            .foregroundColor(Palette.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Palette.fillMuted)
                            .cornerRadius(5)
                    }
                }
            }

            Spacer()

            Text(log.signedAmount(unit: unit))
                .font(.sora(13, .bold))
                .foregroundColor(log.type == .entry ? Palette.success : Palette.textMuted)
        }
        .padding(.vertical, 12)
        // Boş alan da dokunulabilir olsun (aksi halde yalnızca metne basmak gerekir).
        .contentShape(Rectangle())
        .contextMenu {
            if isAdmin {
                Button {
                    editingLog = log
                } label: {
                    Label("Düzenle", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    pendingDelete = log
                } label: {
                    Label("Sil", systemImage: "trash")
                }
            }
        }
    }
}

/// Tam ekran fiş önizlemesi için kimlikli sarmalayıcı.
struct SharePayloadImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
