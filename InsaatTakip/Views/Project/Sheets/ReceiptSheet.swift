import SwiftUI

// MARK: - Fiş / Malzeme Ekleme (Ekran 06, yalnızca yönetici)
// Segment: "Giriş · Şantiyeye" / "Çıkış · Kullanım". Malzeme çipleri,
// miktar + birim fiyat alanları, canlı "Toplam tutar" satırı, fiş no ve Kaydet.

struct ReceiptSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: String

    @State private var direction: MaterialLog.LogType = .entry
    @State private var selectedMaterialId: String?
    @State private var quantityText = ""
    @State private var unitPriceText = ""
    @State private var referenceText = ""
    /// Kamerayla çekilen fiş görseli (küçültülmüş).
    @State private var receiptImage: UIImage?
    @State private var showCamera = false
    @State private var showNewMaterial = false
    /// Fişten cihaz üstü OCR ile okunanlar (arka planda çalışır).
    @State private var reading: ReceiptScanner.Reading?
    @State private var isScanning = false

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    private var materials: [Material] {
        viewModel.materials(for: projectId)
    }

    private var selectedMaterial: Material? {
        materials.first { $0.id == selectedMaterialId } ?? materials.first
    }

    /// Canlı toplam: miktar × birim fiyat.
    private var totalAmount: Double {
        ProjectViewModel.parseNumber(quantityText) * ProjectViewModel.parseNumber(unitPriceText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Malzeme / Fiş Ekle",
                        subtitle: project?.title) { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    segmentControl
                        .padding(.top, 16)

                    Text("Malzeme")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 18)

                    // Malzeme seçim çipleri (seçili: bakır kenarlık + tint)
                    // + sonda "Yeni Malzeme": katalog dışı kalemler için.
                    FlowLayout(spacing: 9) {
                        ForEach(materials) { material in
                            materialChip(material)
                        }
                        newMaterialChip
                    }
                    .padding(.top, 10)

                    // Miktar + birim fiyat
                    HStack(alignment: .top, spacing: 10) {
                        inputField("MİKTAR (\(selectedMaterial?.unit ?? ""))",
                                   text: $quantityText, placeholder: "12.500")
                        inputField("BİRİM FİYAT (₺)",
                                   text: $unitPriceText, placeholder: "28,50")
                    }
                    .padding(.top, 16)

                    // Canlı toplam tutar
                    HStack {
                        Text("Toplam tutar")
                            .font(.manrope(13, .semiBold))
                            .foregroundColor(Palette.textMuted)
                        Spacer()
                        Text(Fmt.money(totalAmount))
                            .font(.sora(16, .bold))
                            .foregroundColor(Palette.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Palette.accentTint)
                    .cornerRadius(12)
                    .padding(.top, 12)

                    Text("Fiş / İrsaliye")
                        .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                        .padding(.top, 16)

                    // Elle not + kamerayla fişi fotoğraflama
                    HStack(spacing: 10) {
                        TextField("Örn. İrsaliye #4482 · Yılmaz Yapı", text: $referenceText)
                            .font(.manrope(13.5, .semiBold))
                            .foregroundColor(Palette.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(Palette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))

                        Button {
                            showCamera = true
                        } label: {
                            Image(systemName: receiptImage == nil ? "camera.fill" : "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(receiptImage == nil ? Palette.accent : .white)
                                .frame(width: 52, height: 52)
                                .background(receiptImage == nil ? Palette.accentTint : Palette.success)
                                .cornerRadius(13)
                        }
                    }
                    .padding(.top, 8)

                    // Çekilen fişin küçük önizlemesi + fişten okunanlar
                    if let receiptImage {
                        VStack(spacing: 0) {
                            HStack(spacing: 11) {
                                Image(uiImage: receiptImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipped()
                                    .cornerRadius(10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fiş fotoğrafı eklendi")
                                        .font(.manrope(12.5, .semiBold))
                                        .foregroundColor(Palette.textMuted)
                                    if isScanning {
                                        Text("Fiş okunuyor…")
                                            .font(.manrope(11, .medium))
                                            .foregroundColor(Palette.textTertiary)
                                    }
                                }
                                Spacer()
                                if isScanning {
                                    ProgressView().scaleEffect(0.8)
                                }
                                Button {
                                    self.receiptImage = nil
                                    self.reading = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Palette.textMuted)
                                        .frame(width: 30, height: 30)
                                        .background(Palette.fillMuted)
                                        .cornerRadius(9)
                                }
                            }

                            if let reading, reading.hasAnything {
                                scanResultRow(reading)
                            }
                        }
                        .padding(10)
                        .background(Palette.fillSubtle)
                        .cornerRadius(13)
                        .padding(.top, 10)
                    }

                    PrimaryButton(title: "Kaydet") { save() }
                        .padding(.top, 20)

                    Spacer().frame(height: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .presentationDetents([.fraction(0.82)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .onAppear {
            // Tasarımdaki gibi: seçili malzemenin güncel birim fiyatı hazır gelir.
            if selectedMaterialId == nil { selectedMaterialId = materials.first?.id }
            syncUnitPrice()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { image in
                    receiptImage = image
                    showCamera = false
                    scanReceipt(image)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNewMaterial) {
            NewMaterialSheet(projectId: projectId) { created in
                // Yeni kalem hemen seçili gelsin, fiyatı forma dolsun.
                selectedMaterialId = created.id
                syncUnitPrice()
            }
        }
    }

    // MARK: Fişten okuma

    /// Fotoğraf çekilir çekilmez arka planda OCR başlatır; arayüzü bloklamaz.
    private func scanReceipt(_ image: UIImage) {
        reading = nil
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let result = ReceiptScanner.scan(image)
            await MainActor.run {
                isScanning = false
                reading = result
                // Firma / tarih bilgisi fiş notu boşsa doğrudan doldurulur —
                // bu alan zaten serbest metin, yanlışsa kullanıcı düzeltir.
                if referenceText.isEmpty {
                    let parts = [result.supplier, result.dateText].compactMap { $0 }
                    if !parts.isEmpty { referenceText = parts.joined(separator: " · ") }
                }
            }
        }
    }

    /// Okunan değerleri gösterir. Tutar ASLA otomatik uygulanmaz; kullanıcı onaylar.
    private func scanResultRow(_ reading: ReceiptScanner.Reading) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(Palette.border).padding(.vertical, 2)

            HStack(spacing: 6) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 11, weight: .semibold))
                Text("Fişten okundu")
                    .font(.manrope(10.5, .extraBold))
                    .tracking(0.8)
                    .textCase(.uppercase)
            }
            .foregroundColor(Palette.accent)

            if let total = reading.total {
                Button {
                    applyScannedTotal(total)
                } label: {
                    HStack(spacing: 8) {
                        Text("Toplam \(Fmt.money(total))")
                            .font(.sora(13, .bold))
                            .foregroundColor(Palette.ink)
                        Spacer()
                        Text("Uygula")
                            .font(.manrope(11.5, .bold))
                            .foregroundColor(Palette.accent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Palette.surface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border, lineWidth: 1))
                }
            }

            Text(reading.total == nil
                 ? "Tutar okunamadı — elle girebilirsin."
                 : "Miktarı girdikten sonra \"Uygula\" birim fiyatı hesaplar. Değerleri kontrol et.")
                .font(.manrope(10.5, .medium))
                .foregroundColor(Palette.textTertiary)
        }
    }

    /// Okunan toplamı forma uygular: miktar girilmişse birim fiyatı hesaplar.
    private func applyScannedTotal(_ total: Double) {
        let quantity = ProjectViewModel.parseNumber(quantityText)
        guard quantity > 0 else {
            viewModel.flash("Önce miktarı gir, sonra uygula")
            return
        }
        let unitPrice = total / quantity
        unitPriceText = unitPrice == unitPrice.rounded()
            ? Fmt.qty(unitPrice)
            : String(format: "%.2f", unitPrice).replacingOccurrences(of: ".", with: ",")
        viewModel.flash("Birim fiyat fişten hesaplandı")
    }

    /// Katalog dışı kalem eklemek için kesikli çip.
    private var newMaterialChip: some View {
        Button {
            showNewMaterial = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text("Yeni Malzeme")
                    .font(.manrope(12.5, .bold))
            }
            .foregroundColor(Palette.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Palette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .cornerRadius(9)
        }
    }

    // MARK: Parçalar

    /// "Giriş · Şantiyeye" / "Çıkış · Kullanım" segmenti.
    private var segmentControl: some View {
        HStack(spacing: 4) {
            segmentButton("Giriş · Şantiyeye", .entry)
            segmentButton("Çıkış · Kullanım", .exit)
        }
        .padding(4)
        .background(Palette.fillMuted)
        .cornerRadius(13)
    }

    private func segmentButton(_ title: String, _ value: MaterialLog.LogType) -> some View {
        Button {
            direction = value
        } label: {
            Text(title)
                .font(.manrope(12.5, .bold))
                .foregroundColor(direction == value ? Palette.ink : Palette.textFaded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(direction == value ? Palette.surface : Color.clear)
                .cornerRadius(9)
                .shadow(color: direction == value ? Color(hex: 0x22262E, alpha: 0.12) : .clear,
                        radius: 3, x: 0, y: 1)
        }
    }

    private func materialChip(_ material: Material) -> some View {
        let selected = material.id == selectedMaterial?.id
        return Button {
            selectedMaterialId = material.id
            syncUnitPrice()
        } label: {
            Text(material.name)
                .font(.manrope(12.5, .bold))
                .foregroundColor(selected ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(9)
        }
    }

    private func inputField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.sora(16, .bold))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }

    // MARK: Aksiyonlar

    /// Seçilen malzemenin kayıtlı birim fiyatını alana yazar.
    private func syncUnitPrice() {
        guard let material = selectedMaterial else { return }
        let price = material.unitPrice
        unitPriceText = price == price.rounded()
            ? Fmt.qty(price)
            : Fmt.qty(price).replacingOccurrences(of: " ", with: "")
        if price != price.rounded() {
            // Ondalıklı fiyatlar "28,50" biçiminde gösterilir.
            unitPriceText = String(format: "%.2f", price).replacingOccurrences(of: ".", with: ",")
        }
    }

    private func save() {
        let saved = viewModel.addReceipt(role: appState.currentUser?.role ?? .partner,
                                         materialId: selectedMaterial?.id ?? "",
                                         type: direction,
                                         amountText: quantityText,
                                         unitPriceText: unitPriceText,
                                         reference: referenceText,
                                         receiptImage: receiptImage)
        if saved { dismiss() }
    }
}
