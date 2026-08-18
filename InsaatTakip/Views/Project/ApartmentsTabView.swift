import SwiftUI

// MARK: - Daireler & Satış Durumu (Ekran 04)
// Üstte özet kart (TOPLAM DAİRE / SATILAN / KALAN + satış oranı barı),
// altında 2 kolonlu ızgara: satılan = yeşil kart, boş = kesikli kenarlık.

struct ApartmentsTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    let projectId: UUID
    /// Daireye dokununca: satıldıysa detay, boşsa satış formu (yalnızca yönetici).
    var onSelect: (Apartment) -> Void
    /// Basılı tutunca "Daire Bilgisini Düzenle". Boş daire dokununca satış formunu
    /// açtığı için düzenleme ekranına ULAŞILAMIYORDU: yeni kurulan projede tüm
    /// daireler boş olduğundan tip/alan/kat düzeltmek ve kat karşılığı işaretlemek
    /// imkânsızdı — yani düzenleme formu tam olarak var olma sebebine erişemiyordu.
    var onEditInfo: (Apartment) -> Void

    /// Proje bazlı rol (bkz. Project.role(for:)).
    private var isAdmin: Bool {
        viewModel.projects.first { $0.id == projectId }?
            .role(for: appState.currentUser) == .admin
    }

    @State private var searchText = ""
    /// nil = tümü.
    @State private var statusFilter: Apartment.Status?

    private var apartments: [Apartment] {
        viewModel.apartments(for: projectId)
    }

    /// Arama + durum süzgeci.
    ///
    /// ALICI ADIYLA ARAMA YALNIZCA YÖNETİCİDE. Ortakta `buyerName` zaten nil
    /// geliyor (madde 18: alıcı kimliği ayrı belgede ve yalnızca yöneticiye
    /// açık), ama koşul burada AÇIKÇA duruyor: alan bir gün ortağa da inse,
    /// arama kutusu "bu isim bu projede var mı" sorusuna cevap veren bir
    /// kâhin hâline gelirdi — eşleşen tek bir daire, gizlenen kimliği ele
    /// verirdi.
    private var visibleApartments: [Apartment] {
        let query = searchText
            .trimmingCharacters(in: .whitespaces)
            .lowercased(with: Fmt.locale)
        return apartments.filter { apartment in
            if let statusFilter, apartment.status != statusFilter { return false }
            guard !query.isEmpty else { return true }

            var haystack = [
                "\(apartment.apartmentNumber)",
                apartment.type,
                apartment.area,
                Apartment.floorLabel(for: apartment.floor),
                apartment.status.label,
            ]
            if isAdmin, let buyer = apartment.buyerName { haystack.append(buyer) }
            return haystack.contains { $0.lowercased(with: Fmt.locale).contains(query) }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                summaryCard
                    .padding(.top, 16)

                if isAdmin {
                    HStack {
                        Spacer()
                        Text("Tip, m² ve durum için karta basılı tut")
                            .font(.manrope(10.5, .medium))
                            .foregroundColor(Palette.textTertiary)
                    }
                }

                searchBar
                statusChips

                if visibleApartments.isEmpty {
                    noMatchState
                }

                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(visibleApartments) { apartment in
                        Button {
                            onSelect(apartment)
                        } label: {
                            ApartmentCellView(apartment: apartment)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if isAdmin {
                                Button {
                                    onEditInfo(apartment)
                                } label: {
                                    Label("Daire Bilgisini Düzenle", systemImage: "pencil")
                                }
                            }
                        }
                    }
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Özet kart

    // MARK: Arama ve süzgeç (madde 22)

    /// 22 daire gözle taranıyordu. Arama daire numarası, tip, alan, kat ve
    /// durum metninde geçiyor; alıcı adı YALNIZCA yöneticide (bkz.
    /// `visibleApartments`).
    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Palette.textTertiary)

            TextField(isAdmin ? "Daire no, tip, kat veya alıcı" : "Daire no, tip veya kat",
                      text: $searchText)
                .font(.manrope(13, .medium))
                .foregroundColor(Palette.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Palette.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Palette.surface)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
    }

    /// Durum çipleri. Sayılar SÜZÜLMEMİŞ listeden: çipe basmadan önce kaç
    /// daire olduğunu görmek, süzgecin ne yapacağını önceden söyler.
    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Tümü", count: apartments.count, value: nil)
                ForEach(Apartment.Status.allCases) { status in
                    let count = apartments.filter { $0.status == status }.count
                    if count > 0 {
                        chip(title: status.badge, count: count, value: status)
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func chip(title: String, count: Int, value: Apartment.Status?) -> some View {
        let selected = statusFilter == value
        return Button {
            // Aynı çipe ikinci dokunuş süzgeci kaldırır — çıkış yolu
            // "Tümü"ne gitmeyi gerektirmesin.
            statusFilter = selected ? nil : value
        } label: {
            Text("\(title) \(count)")
                .font(.manrope(11.5, .bold))
                .foregroundColor(selected ? .white : Palette.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Palette.accent : Palette.surface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.clear : Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var noMatchState: some View {
        VStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(Palette.textTertiary)
            Text("Eşleşen daire yok")
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.ink)
            Text(searchText.isEmpty ? "Bu durumda daire bulunmuyor."
                                    : "\"\(searchText)\" için sonuç yok.")
                .font(.manrope(11.5, .medium))
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Palette.fillSubtle)
        .cornerRadius(15)
        .dashedBorder(Palette.dashed, radius: 15, lineWidth: 1.2)
    }

    private var summaryCard: some View {
        let total = apartments.count
        let sold = viewModel.soldCount(for: projectId)
        let reserved = viewModel.reservedCount(for: projectId)
        let landOwner = viewModel.landOwnerCount(for: projectId)
        // "Kalan" artık gerçekten satılabilir boş daire. Önceden "toplam − satılan"
        // deniyordu ve kat karşılığı + rezerve daireleri stok gibi gösteriyordu.
        let available = viewModel.availableCount(for: projectId)
        let rate = Int((viewModel.salesRate(for: projectId) * 100).rounded())
        let deposit = viewModel.depositAmount(for: projectId)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Toplam Daire")
                        .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.1)
                    Text("\(total)")
                        .font(.sora(26, .bold))
                        .foregroundColor(Palette.ink)
                }
                Spacer()
                HStack(spacing: 18) {
                    countColumn("Satılan", "\(sold)", Palette.success)
                    if reserved > 0 {
                        countColumn("Rezerve", "\(reserved)", Palette.accent)
                    }
                    countColumn("Kalan", "\(available)", Palette.textMuted)
                }
            }

            ProgressBarView(fraction: viewModel.salesRate(for: projectId),
                            fill: Palette.success)
                .padding(.top, 14)

            HStack {
                Text("Satış oranı %\(rate)")
                Spacer()
                Text("Ciro \(Fmt.compactMoney(viewModel.totalSales(for: projectId)))")
            }
            .font(.manrope(12, .medium))
            .foregroundColor(Palette.textMuted)
            .padding(.top, 10)

            // Paydanın neden toplamdan küçük olduğunu gizlemeyelim: kat karşılığı
            // daireler satılamaz, o yüzden orana girmez ama toplamda durur.
            if landOwner > 0 || deposit > .zero {
                Text([landOwner > 0 ? "Kat karşılığı \(landOwner) daire · satılabilir \(total - landOwner)" : nil,
                      deposit > .zero ? "Bekleyen kapora \(Fmt.compactMoney(deposit))" : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }

    private func countColumn(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textTertiary, tracking: 1.1)
            Text(value)
                .font(.sora(18, .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Daire hücresi

struct ApartmentCellView: View {
    let apartment: Apartment

    var body: some View {
        Group {
            switch apartment.status {
            case .sold:      soldCell
            case .reserved:  reservedCell
            case .landOwner: landOwnerCell
            case .available: emptyCell
            }
        }
        .frame(minHeight: 142)
    }

    /// Satılan daire: yeşil zemin, alıcı + bedel + tahsilat barı + ödeme çipi.
    private var soldCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellHeader

            Text(apartment.buyerName ?? "")
                .font(.manrope(11.5, .semiBold))
                .foregroundColor(Palette.textMuted)
                .lineLimit(1)
                .padding(.top, 7)

            Text(Fmt.compactMoney(apartment.price))
                .font(.sora(15, .bold))
                .foregroundColor(Palette.success)
                .padding(.top, 3)

            Text(apartment.saleDateText ?? "")
                .font(.manrope(10, .medium))
                .foregroundColor(Palette.textTertiary)
                .padding(.top, 3)

            Spacer(minLength: 8)

            // Tahsilat oranı (ödenen ÷ bedel)
            ProgressBarView(fraction: apartment.collectionFraction,
                            fill: Palette.success,
                            track: Palette.successBorder.opacity(0.55),
                            height: 4)

            HStack {
                StatusChip(text: apartment.paymentStatus?.rawValue ?? "",
                           background: apartment.paymentStatus == .tamamlandi ? Palette.successChip : Palette.pendingTint,
                           foreground: apartment.paymentStatus == .tamamlandi ? Palette.successInk : Palette.pendingInk,
                           fontSize: 9)
                Spacer()
                Text(apartment.collectionText)
                    .font(.manrope(10, .semiBold))
                    .foregroundColor(apartment.paymentStatus == .tamamlandi ? Palette.successInk : Palette.textMuted)
            }
            .padding(.top, 8)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.successTint)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.successBorder, lineWidth: 1))
    }

    /// Rezerve daire: kapora aşamasında — sahibi henüz kesin değil, o yüzden
    /// kesikli kenarlık dili korunur ama bakır tonuyla ve alıcı adayı görünür.
    private var reservedCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellHeader

            Text(apartment.buyerName ?? "")
                .font(.manrope(11.5, .semiBold))
                .foregroundColor(Palette.textMuted)
                .lineLimit(1)
                .padding(.top, 7)

            Text(Fmt.compactMoney(apartment.price))
                .font(.sora(15, .bold))
                .foregroundColor(Palette.accent)
                .padding(.top, 3)

            Text(apartment.saleDateText ?? "")
                .font(.manrope(10, .medium))
                .foregroundColor(Palette.textTertiary)
                .padding(.top, 3)

            Spacer(minLength: 8)

            HStack {
                StatusChip(text: apartment.status.badge,
                           background: Palette.accentTint,
                           foreground: Palette.accent,
                           fontSize: 9)
                Spacer()
                Text(apartment.collectionText)
                    .font(.manrope(10, .semiBold))
                    .foregroundColor(Palette.accent)
            }
            .padding(.top, 8)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .cornerRadius(14)
        .dashedBorder(Palette.accent, radius: 14)
    }

    /// Kat karşılığı payı: sahibi bellidir (arsa sahibi), o yüzden DÜZ kenarlık
    /// ve dolgun rozet — "boş" diliyle karıştırılmamalı. Bedeli yoktur.
    private var landOwnerCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellHeader

            Text("Arsa sahibi payı")
                .font(.manrope(11.5, .semiBold))
                .foregroundColor(Palette.textMuted)
                .lineLimit(1)
                .padding(.top, 7)

            Spacer(minLength: 8)

            HStack {
                StatusChip(text: apartment.status.badge,
                           background: Palette.accent,
                           foreground: .white,
                           fontSize: 9)
                Spacer()
                Text(apartment.collectionText)
                    .font(.manrope(10, .semiBold))
                    .foregroundColor(Palette.textTertiary)
            }
            .padding(.top, 8)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentTint)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.accent.opacity(0.45), lineWidth: 1))
    }

    /// Boş daire: beyaz zemin, 1.5px kesikli kenarlık, sol altta "BOŞ" çipi.
    private var emptyCell: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellHeader

            // Tip/alan girilmişse görünsün: yeni projede "—" gelir ve
            // düzenlenmesi gerektiği kartın üstünde belli olur.
            if apartment.type != "—" || apartment.area != "—" {
                Text("\(apartment.type) · \(apartment.area)")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .lineLimit(1)
                    .padding(.top, 7)
            }

            Spacer(minLength: 8)

            StatusChip(text: apartment.status.badge,
                       background: Palette.fillMuted,
                       foreground: Palette.textFaded,
                       fontSize: 9)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .cornerRadius(14)
        .dashedBorder(Palette.dashedSoft, radius: 14)
    }

    /// Tüm kart varyantlarının ortak başlığı: "No 7" + kat etiketi.
    private var cellHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("No \(apartment.apartmentNumber)")
                .font(.sora(15, .bold))
                .foregroundColor(Palette.ink)
            Spacer()
            Text(apartment.floorLabel)
                .font(.manrope(10.5, .semiBold))
                .foregroundColor(Palette.textSecondary)
        }
    }
}
