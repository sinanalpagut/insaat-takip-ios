import SwiftUI

// MARK: - Plan & Proje Dosyaları (Ekran 11)
// Gruplar: Mimari Proje / Statik Proje / Ruhsat & Resmî Evrak (+ Görsel, Sözleşme).
// Satır: 38px dosya türü rozeti (PDF kiremit, DWG bakır, JPG yeşil), ad,
// "v3 · 4,2 MB · 12 Oca 2026" ve indirme butonu. Filtre koyu başlıktaki çiplerden gelir.

struct DocumentsTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    let projectId: String
    /// Filtre çipleri bu görünümün içinde; koyu başlık sekmeye göre yükseklik değiştirmesin diye.
    @Binding var filter: Filter

    enum Filter: String, CaseIterable {
        case tumu = "Tümü"
        case mimari = "Mimari"
        case statik = "Statik"
        case ruhsat = "Ruhsat"

        /// Çipin kapsadığı belge grupları.
        func matches(_ group: ProjectDocument.Group) -> Bool {
            switch self {
            case .tumu:   return true
            case .mimari: return group == .mimari
            case .statik: return group == .statik
            case .ruhsat: return group == .ruhsat || group == .sozlesme
            }
        }
    }

    /// Görünür belgeler (rol + filtre uygulanmış), grup sırasıyla.
    private var groupedDocuments: [(ProjectDocument.Group, [ProjectDocument])] {
        let visible = viewModel.documents(for: projectId, role: appState.currentUser?.role ?? .partner)
            .filter { filter.matches($0.group) }
        return ProjectDocument.Group.allCases.compactMap { group in
            let docs = visible.filter { $0.group == group }
            return docs.isEmpty ? nil : (group, docs)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Tümü / Mimari / Statik / Ruhsat filtresi
                HStack(spacing: 8) {
                    ForEach(Filter.allCases, id: \.self) { option in
                        Button {
                            filter = option
                        } label: {
                            Text(option.rawValue)
                                .font(.manrope(12.5, .bold))
                                .foregroundColor(filter == option ? Palette.accent : Palette.textMuted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(filter == option ? Palette.accentTint : Palette.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(filter == option ? Palette.accent : Palette.border, lineWidth: 1)
                                )
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.top, 16)

                ForEach(groupedDocuments, id: \.0) { group, docs in
                    HStack {
                        Text(group.sectionTitle)
                            .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                        Spacer()
                        Text("\(docs.count) dosya")
                            .font(.manrope(12, .semiBold))
                            .foregroundColor(Palette.textSecondary)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 10)

                    VStack(spacing: 0) {
                        ForEach(Array(docs.enumerated()), id: \.element.id) { index, doc in
                            DocumentRowView(document: doc) {
                                viewModel.flash("\(doc.name) indiriliyor")
                            }
                            if index < docs.count - 1 {
                                Divider().overlay(Palette.divider)
                            }
                        }
                    }
                    .background(Palette.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border, lineWidth: 1))
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Belge satırı

struct DocumentRowView: View {
    let document: ProjectDocument
    var onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Dosya türü rozeti
            Text(document.fileType.rawValue)
                .font(.sora(10, .bold))
                .foregroundColor(badgeForeground)
                .frame(width: 38, height: 38)
                .background(badgeBackground)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(document.name)
                        .font(.manrope(13.5, .bold))
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                    // Yalnızca yöneticinin görebildiği dosyalara kilit işareti
                    if !document.partnerVisible {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Palette.textTertiary)
                    }
                }
                Text(document.metaText)
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Button(action: onDownload) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.textMuted)
                    .frame(width: 40, height: 40)
                    .background(Palette.fillMuted)
                    .cornerRadius(13)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
    }

    private var badgeBackground: Color {
        switch document.fileType {
        case .pdf: return Palette.alertTint
        case .dwg: return Palette.accentTint
        case .jpg: return Palette.successTint
        }
    }

    private var badgeForeground: Color {
        switch document.fileType {
        case .pdf: return Palette.alertInk
        case .dwg: return Palette.accent
        case .jpg: return Palette.success
        }
    }
}
