import SwiftUI
import PhotosUI

// MARK: - Daire Detayı & Görselleri (Ekran 13)
// Satılmış daire kartına dokununca açılır: satış bedeli bloğu (yeşil),
// GÖRSELLER şeridi (dolu yuvalar + admin için "Görsel Ekle"),
// Ödeme / Teslim durumu satırları ve yöneticiye "Satış Kaydını Düzenle" CTA'sı.

struct ApartmentDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let apartmentId: UUID
    /// "Satış Kaydını Düzenle" — üst görünüm satış formunu açar.
    var onEdit: (UUID) -> Void
    /// "Daire Bilgisini Düzenle" — üst görünüm daire formunu açar.
    var onEditInfo: (UUID) -> Void

    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showCancelConfirm = false
    @State private var showPayment = false
    /// Düzenlenen tahsilat (madde 64).
    @State private var editingPayment: Payment?
    /// Silinmesi ONAY BEKLEYEN tahsilat (madde 64).
    ///
    /// Önceden `contextMenu` doğrudan siliyordu: uzun basıp "Tahsilatı sil"e
    /// dokunmak anında siliyor ve dekont nesnesini de Storage'dan düşürüyordu.
    /// Malzeme fişinde onay diyaloğu VARDI, tahsilatta yoktu — aynı ürün
    /// içinde tutarsız ve geri dönüşü olmayan tarafta eksik.
    @State private var pendingPaymentDelete: Payment?
    /// Tahsilat defteri uzunsa ilk altısı gösteriliyor; kalanı bununla açılır.
    @State private var showAllPayments = false
    /// Plan uzunsa ilk altı vade gösteriliyor; kalanı bu bayrakla açılıyor.
    @State private var showAllInstallments = false

    /// Tam ekranda açılan dekont.
    @State private var previewedReceipt: SharePayloadImage?

    private var apartment: Apartment? {
        viewModel.apartments.first { $0.id == apartmentId }
    }

    /// PROJE BAZLI rol — global rol değil.
    ///
    /// `appState.isAdmin` her gerçek oturuma `.admin` veriyor (rol artık
    /// projede yaşıyor, kullanıcıda değil — madde 16j). Burada globale
    /// bakıldığında, davetle katılan ORTAK bu ekranda "Galeriden / Fotoğraf
    /// Çek" karolarını görüyor, fotoğraf ekleyebiliyor ve yükleme hem
    /// `storage.rules` hem `firestore.rules` tarafından 403 ile reddediliyordu:
    /// ekranda duran ama hiçbir yere gitmeyen bir fotoğraf ve "sonra yeniden
    /// denenecek" diyen, asla tutulamayacak bir söz. Aynı soru
    /// `SitePhotosView`de baştan doğru soruluyordu.
    /// Kilitli projede (arşiv, paket sınırı) düzenleme düğmeleri yok;
    /// görünürlük `isAdmin`de kalıyor (`ProjectViewModel.canEdit`).
    private var canEdit: Bool {
        viewModel.canEdit(viewModel.apartments.first { $0.id == apartmentId }?.projectId,
                          for: appState.currentUser)
    }

    private var isAdmin: Bool {
        viewModel.role(forApartment: apartmentId, user: appState.currentUser) == .admin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let apartment {
                SheetHeader(title: "Daire No \(apartment.apartmentNumber)",
                            subtitle: subtitle(apartment)) { dismiss() }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        priceBlock(apartment)
                            .padding(.top, 16)

                        // Görseller şeridi — sayaç gerçek görsel adedini gösterir
                        HStack {
                            Text("Görseller")
                                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                            Spacer()
                            let photos = viewModel.photos(forApartment: apartment.id)
                            if !photos.isEmpty {
                                Text("Tümü (\(photos.count))")
                                    .font(.manrope(12, .bold))
                                    .foregroundColor(Palette.accent)
                            }
                        }
                        .padding(.top, 20)

                        imageStrip(apartment)
                            .padding(.top, 10)

                        // ÖDEME PLANI önce, TAHSİLAT sonra — madde 50.
                        // Sıra bilinçli: plan BEKLENENİ, defter GERÇEKLEŞENİ
                        // gösteriyor ve ikisi arasındaki fark bu ekranın asıl
                        // sorusu. Plan bugüne kadar hiçbir ekranda listelenmiyordu:
                        // yalnızca gecikmiş vadeler, bildirimler ve JSON yedeği
                        // üzerinden görülebiliyordu, yani "bu dairenin ödeme
                        // takvimi ne?" sorusunun cevabı uygulamada YOKTU.
                        if apartment.isCommitted {
                            installmentSection(apartment)
                                .padding(.top, 20)

                            paymentSection(apartment)
                                .padding(.top, 20)
                        }

                        // Detay satırları
                        detailRow("Daire durumu", apartment.status.label)
                            .padding(.top, 14)
                        Divider().overlay(Palette.divider)
                        detailRow("Tip / Alan", "\(apartment.type) · \(apartment.areaText)")
                        Divider().overlay(Palette.divider)
                        if apartment.isCommitted {
                            detailRow("Ödeme durumu", apartment.paymentStatus?.rawValue ?? "—")
                            Divider().overlay(Palette.divider)
                        }
                        detailRow("Teslim durumu", apartment.deliveryNote)

                        if canEdit {
                            adminActions(apartment)
                        }

                        Spacer().frame(height: 24)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .sheetHeight(0.78)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
        .onChange(of: pickedItems) { _ in
            if let apartment { importPickedPhotos(for: apartment.id) }
        }
        .confirmationDialog(apartment?.status == .reserved ? "Rezervi kaldır" : "Satışı iptal et",
                            isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button(apartment?.status == .reserved ? "Rezervi kaldır" : "Satışı iptal et",
                   role: .destructive) {
                guard let apartment else { return }
                viewModel.cancelSale(role: isAdmin ? .admin : .partner,
                                     apartmentId: apartment.id)
                dismiss()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Daire No \(apartment?.apartmentNumber ?? 0) tekrar boş duruma dönecek; alıcı ve tahsilat kayıtları silinecek. İşlem, silinen tutarın anlık görüntüsüyle değişiklik defterine yazılır ve ortakların akışında görünür.")
        }
        .receiptPreview($previewedReceipt)
        .sheet(item: $editingPayment) { payment in
            PaymentSheet(apartmentId: apartmentId, editingPaymentId: payment.id)
        }
        .alert("Tahsilat silinsin mi?", isPresented: Binding(
            get: { pendingPaymentDelete != nil },
            set: { if !$0 { pendingPaymentDelete = nil } }
        ), presenting: pendingPaymentDelete) { payment in
            Button("Vazgeç", role: .cancel) { pendingPaymentDelete = nil }
            Button("Sil", role: .destructive) {
                viewModel.deletePayment(role: isAdmin ? .admin : .partner, id: payment.id)
                pendingPaymentDelete = nil
            }
        } message: { payment in
            // DEKONTUN DA GİDECEĞİ YAZILI: kullanıcı yalnızca bir satır
            // sildiğini sanıyordu, oysa bankadan alınmış görsel de düşüyor.
            Text("\(payment.detailText) · \(Fmt.money(payment.amount))"
                 + (payment.receiptPath != nil || viewModel.receiptImages[payment.id] != nil
                    ? "\n\nDekont da silinecek ve geri alınamaz."
                    : "\n\nBu işlem geri alınamaz."))
        }
        .sheet(isPresented: $showPayment) {
            PaymentSheet(apartmentId: apartmentId)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { image in
                    if let apartment {
                        viewModel.addApartmentPhotos(role: isAdmin ? .admin : .partner,
                                                     apartmentId: apartment.id, images: [image])
                    }
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    private func subtitle(_ apartment: Apartment) -> String {
        var parts = [apartment.floorLabel]
        if let buyer = apartment.buyerName { parts.append(buyer) }
        if let date = apartment.saleDateText { parts.append(date) }
        return parts.joined(separator: " · ")
    }

    /// Bedel bloğu — duruma göre. Sheet artık satılmamış daireler için de
    /// açıldığından koşulsuz yeşil "Satış Bedeli" bloğu, kat karşılığı bir
    /// daireyi onaylanmış satış gibi gösterirdi.
    @ViewBuilder
    private func priceBlock(_ apartment: Apartment) -> some View {
        switch apartment.status {
        case .sold:
            priceCard(label: "Satış Bedeli", value: Fmt.compactMoney(apartment.price),
                      valueColor: Palette.success,
                      labelColor: Palette.successInk.opacity(0.6),
                      background: Palette.successTint, border: Palette.successBorder) {
                StatusChip(text: apartment.paymentStatus == .tamamlandi ? "Tahsil Edildi" : (apartment.paymentStatus?.rawValue ?? ""),
                           background: apartment.paymentStatus == .tamamlandi ? Palette.successChip : Palette.pendingTint,
                           foreground: apartment.paymentStatus == .tamamlandi ? Palette.successInk : Palette.pendingInk)
            }
        case .reserved:
            priceCard(label: "Liste Fiyatı", value: Fmt.compactMoney(apartment.price),
                      valueColor: Palette.accent,
                      labelColor: Palette.accent.opacity(0.65),
                      background: Palette.accentTint, border: Palette.accent.opacity(0.4)) {
                StatusChip(text: apartment.status.badge,
                           background: Palette.accent, foreground: .white)
            }
        case .landOwner:
            priceCard(label: "Arsa Sahibi Payı", value: "Bedelsiz",
                      valueColor: Palette.ink,
                      labelColor: Palette.textTertiary,
                      background: Palette.fillSubtle, border: Palette.border) {
                StatusChip(text: apartment.status.badge,
                           background: Palette.accent, foreground: .white)
            }
        case .available:
            priceCard(label: apartment.price > .zero ? "Liste Fiyatı" : "Durum",
                      value: apartment.price > .zero ? Fmt.compactMoney(apartment.price) : "Satışa hazır",
                      valueColor: Palette.ink,
                      labelColor: Palette.textTertiary,
                      background: Palette.fillSubtle, border: Palette.border) {
                StatusChip(text: apartment.status.badge,
                           background: Palette.fillMuted, foreground: Palette.textFaded)
            }
        }
    }

    private func priceCard<Chip: View>(label: String, value: String,
                                       valueColor: Color, labelColor: Color,
                                       background: Color, border: Color,
                                       @ViewBuilder chip: () -> Chip) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .smallCapsLabel(size: 10, color: labelColor, tracking: 1.1)
                Text(value)
                    .font(.sora(26, .bold))
                    .foregroundColor(valueColor)
            }
            Spacer()
            chip()
        }
        .padding(16)
        .background(background)
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(border, lineWidth: 1))
    }

    /// Yönetici eylemleri duruma göre değişir: satılmış dairede satış kaydı,
    /// rezervede "Satışa Çevir", boş/kat karşılığında yalnızca bilgi düzenleme.
    @ViewBuilder
    private func adminActions(_ apartment: Apartment) -> some View {
        VStack(spacing: 9) {
            switch apartment.status {
            case .sold:
                PrimaryButton(title: "Satış Kaydını Düzenle") {
                    // Üst görünüm sheet kapanınca satış formunu açar;
                    // sabit gecikmeye dayanan zincirleme kaldırıldı.
                    onEdit(apartment.id)
                    dismiss()
                }
                secondaryButton("Daire Bilgisini Düzenle") {
                    onEditInfo(apartment.id); dismiss()
                }
                destructiveButton("Satışı İptal Et") { showCancelConfirm = true }
            case .reserved:
                PrimaryButton(title: "Satışa Çevir") {
                    onEdit(apartment.id)
                    dismiss()
                }
                secondaryButton("Daire Bilgisini Düzenle") {
                    onEditInfo(apartment.id); dismiss()
                }
                destructiveButton("Rezervi Kaldır") { showCancelConfirm = true }
            case .landOwner, .available:
                PrimaryButton(title: "Daire Bilgisini Düzenle") {
                    onEditInfo(apartment.id); dismiss()
                }
            }
        }
        .padding(.top, 16)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Palette.accentTint)
                .cornerRadius(13)
        }
    }

    private func destructiveButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.alertInk)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Palette.alertTint.opacity(0.6))
                .cornerRadius(13)
        }
    }

    /// 3 kolonlu görsel şeridi: dolu kareler (yatay kaydırmalı) + yöneticiye ekleme yuvası.
    private func imageStrip(_ apartment: Apartment) -> some View {
        let photos = viewModel.photos(forApartment: apartment.id)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(photos) { photo in
                    photoTile(photo)
                }

                if canEdit {
                    // Galeriden seç
                    PhotosPicker(selection: $pickedItems, maxSelectionCount: 6, matching: .images) {
                        addTile(icon: "photo.on.rectangle", title: "Galeriden")
                    }
                    // Kameradan çek
                    Button {
                        showCamera = true
                    } label: {
                        addTile(icon: "camera.fill", title: "Fotoğraf Çek")
                    }
                }
            }
        }
        .frame(height: 112)
    }

    /// Dolu görsel karesi; yöneticide uzun basınca silme seçeneği çıkar.
    private func photoTile(_ photo: ApartmentPhoto) -> some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 104, height: 108)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            } else {
                // Tasarımdaki yer tutucu kare (henüz fotoğraf yüklenmemiş yuva)
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .iconFont(20, weight: .light)
                        .foregroundColor(Palette.textTertiary)
                    Text(photo.label)
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(Palette.textMuted)
                }
                .frame(width: 104, height: 108)
                .background(Palette.fillSubtle)
                .cornerRadius(13)
                .dashedBorder(Palette.dashed, radius: 13, lineWidth: 1.2)
            }
        }
        .contextMenu {
            if canEdit {
                Button(role: .destructive) {
                    viewModel.removeApartmentPhoto(role: isAdmin ? .admin : .partner,
                                                   photoId: photo.id)
                } label: {
                    Label("Görseli sil", systemImage: "trash")
                }
            }
        }
        // Piksel EKRANA GELİNCE isteniyor. Açılışta hepsini indirmek, fotoğraf
        // ekranını hiç açmayan kullanıcıya bile projenin tüm görsellerinin
        // faturasını çıkarıyordu.
        .task(id: photo.id) { viewModel.imageNeeded(bucket: .apartmentPhotos, photoId: photo.id) }
    }

    /// Kesikli "ekle" yuvası (galeri / kamera).
    private func addTile(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .iconFont(15, weight: .medium)
                .foregroundColor(Palette.accent)
                .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                        .frame(width: 44, height: 44)
                .background(Palette.accentTint)
                .cornerRadius(10)
            Text(title)
                .font(.manrope(11.5, .bold))
                .foregroundColor(Palette.accent)
        }
        .frame(width: 104, height: 108)
        .background(Palette.surface)
        .cornerRadius(13)
        .dashedBorder(Palette.dashed, radius: 13, lineWidth: 1.2)
    }

    /// Galeriden seçilenleri küçültüp daireye ekler.
    private func importPickedPhotos(for apartmentId: UUID) {
        guard !pickedItems.isEmpty else { return }
        let items = pickedItems
        pickedItems = []
        let role: UserRole = isAdmin ? .admin : .partner

        Task.detached(priority: .userInitiated) {
            var images: [UIImage] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let thumbnail = SitePhoto.downsample(data) else { continue }
                images.append(thumbnail)
            }
            let ready = images
            await MainActor.run {
                viewModel.addApartmentPhotos(role: role, apartmentId: apartmentId, images: ready)
            }
        }
    }

    /// Tahsilat defteri: kalan alacak + ödeme geçmişi + yöneticiye ekleme.
    // MARK: Ödeme planı (madde 50)

    @ViewBuilder
    private func installmentSection(_ apartment: Apartment) -> some View {
        let plan = viewModel.installmentPlan(for: apartment.id)
        let rows = Installment.settle(plan, collected: apartment.paidAmount)
        let taksitSayisi = plan.filter { $0.sequence > 0 }.count
        let acik = rows.filter { !$0.isSettled }
        let gecikmis = rows.filter { $0.isOverdue() }

        if rows.isEmpty {
            // Peşin satışta plan yok; "0 taksit" yazmak plan varmış izlenimi verirdi.
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Ödeme planı")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    Spacer()
                    Text(taksitSayisi > 0 ? "\(taksitSayisi) taksit" : "peşinat")
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(Palette.textSecondary)
                }

                // ÖZET: kapanan / kalan vade sayısı ve gecikme.
                HStack {
                    Text("\(rows.count - acik.count)/\(rows.count) vade kapandı")
                    Spacer()
                    if gecikmis.isEmpty {
                        Text(acik.isEmpty ? "Plan tamamlandı" : "Gecikme yok")
                            .foregroundColor(acik.isEmpty ? Palette.success : Palette.textMuted)
                    } else {
                        let tutar = gecikmis.reduce(Kurus.zero) { $0 + $1.unpaid }
                        Text("\(gecikmis.count) vade gecikti · \(Fmt.exactMoney(tutar))")
                            .foregroundColor(Palette.alertInk)
                    }
                }
                .font(.manrope(11.5, .semiBold))
                .foregroundColor(Palette.textMuted)
                .padding(.top, 10)

                let gorunen = showAllInstallments ? rows : Array(rows.prefix(6))
                VStack(spacing: 0) {
                    ForEach(Array(gorunen.enumerated()), id: \.element.id) { index, row in
                        installmentRow(row)
                        if index < gorunen.count - 1 {
                            Divider().overlay(Palette.divider)
                        }
                    }
                }
                .padding(.top, 6)

                // KIRPMA SESSİZ OLAMAZ: kaç vadenin gizlendiği YAZILI ve
                // dokunulduğunda açılıyor — bir daha kapanmayan bir "+n daha"
                // etiketi, planı görmek isteyen kullanıcıyı yine yedek dosyasına
                // gönderirdi.
                if rows.count > 6 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAllInstallments.toggle() }
                    } label: {
                        Text(showAllInstallments
                             ? "İlk 6 vadeyi göster"
                             : "+ \(rows.count - 6) vade daha")
                            .font(.manrope(11.5, .semiBold))
                            .foregroundColor(Palette.accent)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    private func installmentRow(_ row: Installment.Settlement) -> some View {
        let item = row.installment
        let gecikti = row.isOverdue()
        let baslik = item.sequence == 0 ? "Peşinat" : "\(item.sequence). taksit"

        // Durum metni ve rengi TEK YERDE türetiliyor; ikon, alt satır ve
        // VoiceOver etiketi aynı kaynaktan besleniyor ki üçü ayrışmasın.
        let durum: (metin: String, renk: Color, ikon: String)
        if row.isSettled {
            durum = ("Ödendi", Palette.success, "checkmark.circle.fill")
        } else if gecikti {
            let gun = Fmt.calendar.dateComponents(
                [.day], from: Fmt.calendar.startOfDay(for: item.dueDate),
                to: Fmt.calendar.startOfDay(for: Date())).day ?? 0
            durum = (row.isPartial
                     ? "Gecikti · \(gun) gün · kalan \(Fmt.exactMoney(row.unpaid))"
                     : "Gecikti · \(gun) gün", Palette.alertInk, "exclamationmark.circle.fill")
        } else if row.isPartial {
            durum = ("Kısmi · kalan \(Fmt.exactMoney(row.unpaid))", Palette.textMuted, "circle.lefthalf.filled")
        } else {
            durum = ("Bekliyor", Palette.textMuted, "circle")
        }

        return HStack(spacing: 11) {
            Image(systemName: durum.ikon)
                .iconFont(11, weight: .medium)
                .foregroundColor(durum.renk)
                .frame(width: 28, height: 28)
                .background(row.isSettled ? Palette.successTint
                            : (gecikti ? Palette.alertTint : Palette.fillMuted))
                .cornerRadius(9)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(baslik) · \(Fmt.shortDate(item.dueDate))")
                    .font(.manrope(12.5, .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                Text(durum.metin)
                    .font(.manrope(11, .medium))
                    .foregroundColor(durum.renk)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(Fmt.exactMoney(item.amount))
                .font(.sora(13, .bold))
                .foregroundColor(row.isSettled ? Palette.textMuted : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 11)
        // TEK CÜMLE olarak okunuyor (madde 31): parça parça okunduğunda
        // hangi tutarın hangi vadeye ait olduğu kayboluyordu. Durum ayrıca
        // RENKLE de taşındığı için etikette geçmesi şart.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(baslik), vade \(Fmt.shortDate(item.dueDate)), "
                            + "\(Fmt.exactMoney(item.amount)), \(durum.metin)")
    }

    private func paymentSection(_ apartment: Apartment) -> some View {
        let payments = viewModel.payments(forApartment: apartment.id)
        let remaining = max(.zero, apartment.price - apartment.paidAmount)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tahsilat")
                    .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                Spacer()
                Text("\(payments.count) ödeme")
                    .font(.manrope(12, .semiBold))
                    .foregroundColor(Palette.textSecondary)
            }

            // Tahsil edilen / kalan
            HStack {
                Text("Tahsil edilen \(Fmt.compactMoney(apartment.paidAmount))")
                Spacer()
                Text(remaining > .zero ? "Kalan \(Fmt.compactMoney(remaining))" : "Tamamlandı")
                    .foregroundColor(remaining > .zero ? Palette.textMuted : Palette.success)
            }
            .font(.manrope(11.5, .semiBold))
            .foregroundColor(Palette.textMuted)
            .padding(.top, 10)

            ProgressBarView(fraction: apartment.collectionFraction, fill: Palette.success, height: 5)
                .padding(.top, 7)

            // Ödeme geçmişi
            if payments.isEmpty {
                Text("Henüz tahsilat kaydı yok")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    let gorunen = showAllPayments ? payments : Array(payments.prefix(6))
                    ForEach(Array(gorunen.enumerated()), id: \.element.id) { index, payment in
                        paymentRow(payment)
                        if index < gorunen.count - 1 {
                            Divider().overlay(Palette.divider)
                        }
                    }
                }
                .padding(.top, 6)

                // KIRPMA DOKUNULABİLİR OLMALI (madde 65). Önceden bu düz bir
                // metindi: altıncıdan sonraki ödemeler uygulamada HİÇBİR
                // yerden görülemiyordu. 36 aylık taksitli bir satışta bu,
                // ödemelerin çoğunun erişilemez olması demekti — ve tek yol
                // yedek dosyasını açmaktı.
                if payments.count > 6 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAllPayments.toggle() }
                    } label: {
                        Text(showAllPayments
                             ? "İlk 6 ödemeyi göster"
                             : "+ \(payments.count - 6) ödeme daha")
                            .font(.manrope(11.5, .semiBold))
                            .foregroundColor(Palette.accent)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
            }

            if canEdit {
                Button {
                    showPayment = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .iconFont(12, weight: .bold)
                        Text("Ödeme Ekle")
                            .font(.manrope(13.5, .bold))
                    }
                    .foregroundColor(Palette.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Palette.accentTint)
                    .cornerRadius(13)
                }
                .padding(.top, 10)
            }
        }
    }

    private func paymentRow(_ payment: Payment) -> some View {
        HStack(spacing: 11) {
            Image(systemName: payment.method.icon)
                .iconFont(11, weight: .medium)
                .foregroundColor(Palette.success)
                .frame(width: 28, height: 28)
                .background(Palette.successTint)
                .cornerRadius(9)

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.detailText)
                    .font(.manrope(12.5, .bold))
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                Text(payment.dateText)
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            // Dekont YALNIZCA YÖNETİCİDE. Üstünde gönderenin adı (çoğu kez
            // IBAN'ı da) yazıyor; `storage.rules` de bu yüzden `paymentReceipts`
            // kovasını ortağa kapatıyor. Kapı burada, `imageNeeded`
            // ÇAĞRILMADAN önce: ortak yer tutucuyu bile görmemeli — "göremediğin
            // bir dekont var" demek, gizlenen şeyin varlığını ilan etmektir.
            // Kapı unutulsaydı ortak sonsuza kadar 403 alan bir indirme döngüsüne
            // girerdi (her yeniden çizimde bir istek, üstelik kuralın çapraz
            // servis sorgusu yüzünden fatura da yazardı).
            if isAdmin, payment.receiptPath != nil || viewModel.receiptImages[payment.id] != nil {
                paymentReceiptButton(payment)
            }

            Text(Fmt.compactMoney(payment.amount))
                .font(.sora(13, .bold))
                .foregroundColor(Palette.success)
        }
        .padding(.vertical, 11)
        .contextMenu {
            if canEdit {
                Button {
                    editingPayment = payment
                } label: {
                    Label("Tahsilatı düzenle", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    // Doğrudan SİLMİYOR: onay diyaloğu açılıyor (madde 64).
                    pendingPaymentDelete = payment
                } label: {
                    Label("Tahsilatı sil", systemImage: "trash")
                }
            }
        }
    }

    /// Dekont küçük resmi. Piksel elde yoksa yer tutucu çizilir ve indirme
    /// EKRANDA GÖRÜNDÜĞÜ AN istenir.
    @ViewBuilder
    private func paymentReceiptButton(_ payment: Payment) -> some View {
        if let receipt = viewModel.receiptImages[payment.id] {
            Image(uiImage: receipt)
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipped()
                .cornerRadius(8)
                .onTapGesture { previewedReceipt = SharePayloadImage(image: receipt) }
        } else {
            Image(systemName: "doc.text")
                .iconFont(12, weight: .light)
                .foregroundColor(Palette.textTertiary)
                .frame(width: 30, height: 30)
                .background(Palette.fillMuted)
                .cornerRadius(8)
                .task(id: payment.id) {
                    viewModel.imageNeeded(bucket: .paymentReceipts, photoId: payment.id)
                }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.manrope(13, .medium))
                .foregroundColor(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.manrope(13, .bold))
                .foregroundColor(Palette.ink)
        }
        .padding(.vertical, 13)
    }
}
