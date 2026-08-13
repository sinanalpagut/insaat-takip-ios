import SwiftUI

// MARK: - Dönem Raporu / PDF (Ekran 10)
// Dönem çipleri (Bu ay / Çeyrek / Tümü), özet kart (son satır "Dönem net" yeşil),
// AYLIK SATIŞ çubuk grafiği (≥7 M ₺ koyu bakır, altı açık) ve PDF paylaşımı.

struct ReportView: View {
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: UUID

    @State private var period: ProjectViewModel.ReportPeriod = .ceyrek
    @State private var sharePayload: SharePayload?

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    private var summary: ProjectViewModel.ReportSummary {
        viewModel.reportSummary(for: projectId, period: period)
    }

    private var bars: [ProjectViewModel.MonthBar] {
        viewModel.monthlySales(for: projectId)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    summaryCard
                        .padding(.top, 16)
                    chartCard

                    PrimaryButton(title: "PDF Olarak İndir", icon: "doc.text") {
                        exportPDF()
                    }
                    .padding(.top, 6)

                    Text("Rapor tüm ortaklara otomatik olarak da gönderilebilir.")
                        .font(.manrope(11.5, .medium))
                        .foregroundColor(Palette.textTertiary)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Palette.page.ignoresSafeArea())
        .navigationBarHidden(true)
        // sheet(item:) kullanılır: isPresented + "if let" kalıbında sheet içeriği
        // sunum anında henüz güncellenmemiş değeri yakalayıp boş (beyaz) açılıyordu.
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
        }
    }

    // MARK: Başlık

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                DarkHeaderButton(systemName: "chevron.left") { dismiss() }
                Spacer()
            }
            .padding(.top, 6)

            Text("Dönem Raporu")
                .font(.sora(26, .bold))
                .foregroundColor(.white)
                .padding(.top, 14)

            Text(project?.title ?? "")
                .font(.manrope(12.5, .medium))
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 5)

            HStack(spacing: 8) {
                ForEach(ProjectViewModel.ReportPeriod.allCases, id: \.self) { option in
                    Button {
                        period = option
                    } label: {
                        Text(option.rawValue)
                            .font(.manrope(12.5, .bold))
                            .foregroundColor(period == option ? Palette.ink : .white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(period == option ? Color.white : Color.white.opacity(0.08))
                            .cornerRadius(11)
                    }
                }
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Palette.ink
                .clipShape(RoundedCorners(radius: 22, corners: [.bottomLeft, .bottomRight]))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Özet kart

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(summary.title)
                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                .padding(.bottom, 6)

            summaryRow("Satılan daire", "\(summary.soldCount) adet")
            Divider().overlay(Palette.divider)
            // Ciroya girmeyen ama ortağın bilmesi gereken kalemler. Kırılım
            // olmadan "Satılan daire N adet" ya kat karşılığını içerip yanlış
            // olur ya da bekleyen kaporayı tamamen gizler.
            if summary.reservedCount > 0 {
                summaryRow("Rezerve",
                           "\(summary.reservedCount) adet · kapora \(Fmt.compactMoney(summary.depositTotal))")
                Divider().overlay(Palette.divider)
            }
            if summary.landOwnerCount > 0 {
                summaryRow("Kat karşılığı (bedelsiz)", "\(summary.landOwnerCount) adet")
                Divider().overlay(Palette.divider)
            }
            summaryRow("Satış geliri", Fmt.compactMoney(summary.salesTotal))
            Divider().overlay(Palette.divider)
            summaryRow("Tahsil edilen", Fmt.compactMoney(summary.collectedTotal))
            Divider().overlay(Palette.divider)
            summaryRow("Malzeme gideri", Fmt.compactMoney(summary.materialCost))
            Divider().overlay(Palette.divider)
            summaryRow("Diğer giderler", Fmt.compactMoney(summary.otherExpenses))
            Divider().overlay(Palette.divider)
            // Gider defteri geldiği için "Dönem net" artık dürüst bir rakam.
            summaryRow("Dönem net", Fmt.compactMoney(summary.net),
                       valueColor: summary.net >= .zero ? Palette.success : Palette.alertInk)

            // Bu kart ortaklara PDF olarak dağıtılıyor; kapsamı yazılı olmalı.
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.top, 1)
                Text("Yalnızca uygulamaya girilen gider kayıtlarını kapsar; vergi ve finansman giderleri dahil değildir.")
                    .font(.manrope(11, .medium))
                    .lineSpacing(2)
            }
            .foregroundColor(Palette.textTertiary)
            .padding(.top, 12)
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }

    private func summaryRow(_ label: String, _ value: String, valueColor: Color = Palette.ink) -> some View {
        HStack {
            Text(label)
                .font(.manrope(13.5, .medium))
                .foregroundColor(Palette.textMuted)
            Spacer()
            Text(value)
                .font(.sora(15, .bold))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 13)
    }

    // MARK: Grafik kartı

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Aylık Satış (M ₺)")
                .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)

            HStack(alignment: .bottom, spacing: 14) {
                // Sıfıra bölmeyi engelleyen taban: 1 kuruş.
                let maxValue = max(bars.map(\.value).max() ?? .zero, Kurus.kurus(1))
                ForEach(bars) { bar in
                    VStack(spacing: 7) {
                        Text(Fmt.millionsShort(bar.value))
                            .font(.sora(11, .bold))
                            .foregroundColor(Palette.textMuted)
                        // ≥7 M ₺ aylar koyu bakır, diğerleri açık ton
                        RoundedCorners(radius: 5, corners: [.topLeft, .topRight])
                            // Eşik LİRA cinsinden yazılır; kuruş sabiti bırakılsaydı
                            // 70.000 ₺ anlamına gelir ve neredeyse her ay koyu görünürdü.
                            .fill(bar.value >= Kurus.lira(7_000_000) ? Palette.accent : Palette.barSoft)
                            .frame(height: max(10, Double(bar.value.raw) / Double(maxValue.raw) * 62))
                        Text(bar.label)
                            .font(.manrope(11, .semiBold))
                            .foregroundColor(Palette.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 16)
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.border, lineWidth: 1))
        .shadow(color: Color(hex: 0x22262E, alpha: 0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: PDF üretimi

    /// Özet ve grafiği tek sayfalık PDF'e çevirip paylaşım sayfası açar.
    private func exportPDF() {
        let content = VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("İNŞAAT TAKİP — DÖNEM RAPORU")
                    .font(.manrope(11, .extraBold))
                    .tracking(1.4)
                    .foregroundColor(Palette.accent)
                Text(project?.title ?? "")
                    .font(.sora(24, .bold))
                    .foregroundColor(Palette.ink)
                Text("\(project?.meta ?? "") · \(Fmt.shortDate())")
                    .font(.manrope(12, .medium))
                    .foregroundColor(Palette.textSecondary)
            }
            summaryCard
            chartCard
            Text("Bu rapor İnşaat Takip uygulamasından oluşturulmuştur. Ortaklar salt okunur erişime sahiptir.")
                .font(.manrope(10.5, .medium))
                .foregroundColor(Palette.textTertiary)
        }
        .padding(28)
        .frame(width: 560)
        .background(Color.white)

        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 560, height: nil)

        // Ada/parsel kullanıcı girdisidir; "/" gibi karakterler var olmayan bir
        // alt dizin yolu üretip PDF'in sessizce yazılamamasına yol açardı.
        let safe: (String?) -> String = { raw in
            (raw ?? "").components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }.joined(separator: "-")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Donem-Raporu-\(safe(project?.blockNumber))-\(safe(project?.parcelNumber)).pdf")

        var didWrite = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard size.width > 0, size.height > 0,
                  let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            didWrite = true
        }

        // Yazma başarısızsa boş bir paylaşım sayfası açmak yerine kullanıcıyı bilgilendir.
        guard didWrite, FileManager.default.fileExists(atPath: url.path) else {
            viewModel.flash("PDF oluşturulamadı")
            return
        }

        sharePayload = SharePayload(url: url)
    }
}

/// Paylaşılacak dosya — sheet(item:) için kimlikli sarmalayıcı.
struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIKit paylaşım sayfası köprüsü (PDF çıktısı için).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
