import SwiftUI

// MARK: - Ortaklar Sekmesi (Ekran 05)
// Ortak satırları: 40px baş harf avatarı (yönetici = ink, ortak = bakır tint),
// ad + rol, katılım tarihi, sağda bakır hisse yüzdesi.
// Ortak rolündeyken salt-okunur açıklaması gösterilir; davet FAB'ı yalnızca yöneticide.

struct PartnersTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel

    let projectId: UUID

    /// Hissesi düzenlenen ortak (yalnızca yönetici).
    @State private var pendingRemoval: Partner?
    @State private var editingPartner: Partner?
    /// Cari hareket sayfası (madde 82). Ortak kimliği taşıyor: bir ortağın
    /// kartından açıldığında o ortak seçili gelsin.
    @State private var ledgerFor: LedgerTarget?
    @State private var pendingLedgerDelete: PartnerLedgerEntry?

    /// `sheet(item:)` için sarmalayıcı — nil ortak kimliği de geçerli bir
    /// hedef (üstteki "+ Hareket" düğmesi).
    struct LedgerTarget: Identifiable {
        let partnerId: UUID?
        var id: String { partnerId?.uuidString ?? "yeni" }
    }

    /// PROJE BAZLI rol — global rol DEĞİL. `appState.isAdmin` her gerçek
    /// oturuma `.admin` veriyor (rol artık projede yaşıyor, kullanıcıda değil —
    /// madde 16j); global bakılınca davetle katılan ORTAK burada yönetici
    /// muamelesi görür.
    /// Kilitli projede (arşiv, paket sınırı) düzenleme düğmeleri yok;
    /// görünürlük `isAdmin`de kalıyor (`ProjectViewModel.canEdit`).
    /// ORTAĞI ÇIKARMAK BUNA BAĞLI DEĞİL: erişimi kesmek kilitli projede de
    /// açık (`removePartner` kapıdan geçmiyor).
    private var canEdit: Bool { viewModel.canEdit(projectId, for: appState.currentUser) }

    private var isAdmin: Bool {
        viewModel.role(inProject: projectId, for: appState.currentUser) == .admin
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            // TEMBEL LİSTE: hücreler göründükçe çiziliyor. Düz `VStack` bütün
            // listeyi baştan kuruyor — ortak kartları her yeni kayıtla uzuyor ve ilk
            // çizimin maliyeti listeyle birlikte büyüyor.
            LazyVStack(spacing: 10) {
                let partners = viewModel.partners(for: projectId)
                let shareTotal = partners.reduce(0) { $0 + $1.sharePercent }

                HStack {
                    Text("Hisse Dağılımı")
                        .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                    Spacer()
                    // Gerçek toplam; %100'ü tutmuyorsa uyarı rengiyle belirtilir.
                    Text("%\(shareTotal) tanımlı")
                        .font(.manrope(12, .semiBold))
                        .foregroundColor(shareTotal == 100 ? Palette.textSecondary : Palette.alertInk)
                }
                .padding(.top, 16)

                // "Payın" kartı — oturumu açan kişinin KENDİ ortak kaydı için.
                // Yöneticinin de bir Partner kaydı var (kurucu), o yüzden kart
                // role göre değil KAYDA göre çıkıyor.
                if let mine = viewModel.partnerRecord(in: projectId, for: appState.currentUser) {
                    shareCard(mine)
                        .padding(.top, 4)
                }

                ForEach(partners) { partner in
                    PartnerRowView(partner: partner)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Hisse düzenleme YALNIZCA yöneticide. Bu yol açılana
                            // kadar sharePercent hiç girilemiyordu: kurucu sabit
                            // %100, davetle katılan %0.
                            if canEdit { editingPartner = partner }
                        }
                        .contextMenu {
                            // KURUCU listelenmiyor: kendini çıkarırsa projeyi
                            // okuyamaz hale gelir ve kural zaten reddeder.
                            if isAdmin, !partner.isFounder {
                                Button(role: .destructive) {
                                    pendingRemoval = partner
                                } label: {
                                    Label("Projeden Çıkar", systemImage: "person.badge.minus")
                                }
                            }
                        }
                }

                ledgerCard

                // Ortak görünümü: davet yetkisinin kimde olduğunu açıklayan not.
                if !isAdmin {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .iconFont(13, weight: .medium)
                            .foregroundColor(Palette.accent)
                            .padding(.top, 1)
                        Text("Bu projeyi salt okunur takip ediyorsun. Yeni ortak daveti yalnızca yönetici tarafından yapılabilir.")
                            .font(.manrope(12, .medium))
                            .foregroundColor(Palette.textMuted)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.accentTint.opacity(0.55))
                    .cornerRadius(14)
                    .padding(.top, 6)
                }

                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .sheet(item: $editingPartner) { partner in
            PartnerShareSheet(partner: partner)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $ledgerFor) { hedef in
            PartnerLedgerSheet(projectId: projectId, partnerId: hedef.partnerId)
        }
        .alert("Cari hareket silinsin mi?", isPresented: Binding(
            get: { pendingLedgerDelete != nil },
            set: { if !$0 { pendingLedgerDelete = nil } }
        ), presenting: pendingLedgerDelete) { entry in
            Button("Vazgeç", role: .cancel) { pendingLedgerDelete = nil }
            Button("Sil", role: .destructive) {
                viewModel.deleteLedgerEntry(role: isAdmin ? .admin : .partner, entryId: entry.id)
                pendingLedgerDelete = nil
            }
        } message: { entry in
            // SİLMENİN İZ BIRAKTIĞI SÖYLENİYOR: bu kayıtlar ortaklar arasındaki
            // hesabın dayanağı, sessizce kaybolmaları tam olarak uygulamanın
            // önlemek için var olduğu tartışmayı üretirdi.
            Text("\(entry.kind.rawValue) · \(Fmt.money(entry.amount)) kaydı silinecek. "
                 + "Silme işlemi Kayıt İzi'ne yazılır.")
        }
        .alert("Ortak projeden çıkarılsın mı?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        ), presenting: pendingRemoval) { partner in
            Button("Vazgeç", role: .cancel) { pendingRemoval = nil }
            Button("Çıkar", role: .destructive) {
                viewModel.removePartner(role: isAdmin ? .admin : .partner, partnerId: partner.id)
                pendingRemoval = nil
            }
        } message: { partner in
            // NE OLACAĞI YAZILI: bu bir liste temizliği değil, erişim iptali.
            // Hissesinin de kaybolacağı söyleniyor çünkü geri alındığında
            // yönetici onu yeniden tanımlamak zorunda.
            Text("\(partner.name) bu projeyi artık göremeyecek: finansal veriler, "
                 + "daireler ve belgeler dahil.\n\n"
                 + "%\(partner.sharePercent) hissesi de kaydından düşer. Geri almak için "
                 + "yeni bir davet kodu göndermen gerekir.")
        }
    }

    // MARK: Ortak cari hesabı (madde 82)

    /// Kim ne koydu, kim ne çekti.
    ///
    /// BU KART "DAĞITILABİLİR KÂR" DEMİYOR ve demeyecek: o soru madde 86'nın
    /// kalan inşaat maliyetini, satılmamış stoğun gerçekleşme oranını ve
    /// vergi yükünü ister. Buradaki rakam çok daha dar ve kesin: ortak bu
    /// projeye ne koydu, ne çekti, arada ne kaldı.
    ///
    /// ORTAK DA GÖRÜYOR ve karar kuralda alındı (firestore.rules ·
    /// partnerLedger): ortak hesabın TARAFI, alıcı gibi üçüncü kişi değil.
    /// Kimin ne koyduğunu gizlemek, uygulamanın önlemek için var olduğu
    /// tartışmayı WhatsApp'a geri gönderirdi.
    @ViewBuilder
    private var ledgerCard: some View {
        let hareketler = viewModel.ledger(for: projectId)
        let ortaklar = viewModel.partners(for: projectId)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ortak Cari Hesabı")
                    .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                Spacer()
                if canEdit {
                    Button {
                        ledgerFor = LedgerTarget(partnerId: nil)
                    } label: {
                        Text("+ Hareket")
                            .font(.manrope(12, .bold))
                            .foregroundColor(Palette.accent)
                    }
                }
            }

            if hareketler.isEmpty {
                // BOŞ DURUM NE İŞE YARADIĞINI ANLATIYOR: bu defter bugüne
                // kadar hiç olmadığı için kullanıcı ne yazacağını bilmiyor.
                Text(isAdmin
                     ? "Ortakların koyduğu sermaye, çektiği avans ve kâr dağıtımları burada tutulur. Gider defterinden ayrıdır: bu kayıtlar inşaat maliyetine girmez."
                     : "Henüz cari hareket girilmemiş. Sermaye ve çekimler girildiğinde burada görünür.")
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .lineSpacing(3)
                    .padding(.top, 10)
            } else {
                // ORTAK BAZINDA BAKİYE — hareket listesinden ÖNCE: "bende ne
                // kaldı" sorusu, "ne zaman ne oldu"dan önce geliyor.
                ForEach(ortaklar) { ortak in
                    let bakiye = viewModel.balance(forPartner: ortak.id)
                    if !bakiye.isEmpty {
                        Divider().overlay(Palette.divider)
                        balanceRow(ortak, bakiye)
                    }
                }

                Divider().overlay(Palette.divider)
                Text("HAREKETLER")
                    .smallCapsLabel(size: 9.5, color: Palette.textFaded, tracking: 1.1)
                    .padding(.top, 12)

                ForEach(hareketler) { hareket in
                    ledgerRow(hareket, partnerName: ortaklar.first { $0.id == hareket.partnerId }?.name ?? "—")
                }
            }
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border, lineWidth: 1))
        .padding(.top, 6)
    }

    private func balanceRow(_ partner: Partner, _ balance: PartnerBalance) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(partner.name)
                    .font(.manrope(13, .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                // EKSİ BAKİYE GİZLENMİYOR: koyduğundan fazlasını çekmiş
                // ortak ortaklığa borçludur ve rakam bunu söylemeli.
                Text(Fmt.money(balance.net))
                    .font(.sora(14.5, .bold))
                    .foregroundColor(balance.net >= .zero ? Palette.ink : Palette.alertInk)
            }
            Text(balanceDetail(balance))
                .font(.manrope(11, .medium))
                .foregroundColor(Palette.textTertiary)
        }
        .padding(.vertical, 11)
    }

    private func balanceDetail(_ balance: PartnerBalance) -> String {
        var parts: [String] = []
        if balance.capital > .zero { parts.append("sermaye \(Fmt.compactMoney(balance.capital))") }
        if balance.withdrawn > .zero { parts.append("çekilen \(Fmt.compactMoney(balance.withdrawn))") }
        if balance.distributed > .zero { parts.append("dağıtım \(Fmt.compactMoney(balance.distributed))") }
        return parts.joined(separator: " · ")
    }

    private func ledgerRow(_ entry: PartnerLedgerEntry, partnerName: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.kind.icon)
                .iconFont(13, weight: .medium)
                .foregroundColor(entry.kind.increasesBalance ? Palette.success : Palette.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(partnerName) · \(entry.kind.rawValue)")
                    .font(.manrope(12.5, .semiBold))
                    .foregroundColor(Palette.ink)
                Text(entry.note.isEmpty ? entry.dateText : "\(entry.dateText) · \(entry.note)")
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
            }
            Spacer()
            Text((entry.kind.increasesBalance ? "+ " : "− ") + Fmt.money(entry.amount))
                .font(.sora(13, .bold))
                .foregroundColor(entry.kind.increasesBalance ? Palette.success : Palette.ink)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            if canEdit {
                Button(role: .destructive) {
                    pendingLedgerDelete = entry
                } label: {
                    Label("Hareketi Sil", systemImage: "trash")
                }
            }
        }
    }

    // MARK: Payın kartı

    /// Ortağın kendi payı — projenin ZATEN gösterdiği rakamların paya bölünmüş
    /// hâli. Tek satırlık bir "payın şu kadar" YOK; gerekçesi
    /// `ProjectViewModel.share(of:)` yorumunda.
    @ViewBuilder
    private func shareCard(_ partner: Partner) -> some View {
        let project = viewModel.projects.first { $0.id == projectId }
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Payın")
                    .smallCapsLabel(size: 10.5, color: Palette.textFaded, tracking: 1.2)
                Spacer()
                Text("%\(partner.sharePercent)")
                    .font(.sora(15, .bold))
                    .foregroundColor(Palette.accent)
            }

            if let share = viewModel.share(of: partner) {
                shareRow("Satıştan", share.sales, Palette.ink)
                shareRow("Girilen giderden", -share.cost, Palette.alertInk)
                Divider().padding(.vertical, 8)
                shareRow("Aradaki fark", share.difference, Palette.ink, bold: true)

                Text("KASA")
                    .smallCapsLabel(size: 9.5, color: Palette.textFaded, tracking: 1.1)
                    .padding(.top, 14)
                shareRow("Tahsil edilenden", share.collected, Palette.success)
                shareRow("Kalan alacaktan", share.outstanding, Palette.textSecondary)

                // Kapsam kutusu. "Aradaki fark" kâr DEĞİL: gelir tarafı satılan
                // dairenin tam bedelini bugün yazıyor, gider tarafı yalnızca
                // bugüne kadar girileni. Kalan inşaat maliyeti henüz düşülmedi.
                Text(scopeText(progress: project?.progress ?? 0,
                               deposits: viewModel.depositAmount(for: projectId),
                               remainingCost: project?.remainingCostEstimate))
                    .font(.manrope(11, .medium))
                    .foregroundColor(Palette.textTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            } else {
                // Sıfırlarla dolu bir kart, tanımsız hisseyi "payın yok" diye
                // gösterirdi. Davetle katılan ortak %0 ile geliyor.
                Text("Hissen henüz tanımlanmadı. Yönetici hisse dağılımını girdiğinde payına düşen tutarlar burada görünecek.")
                    .font(.manrope(12, .medium))
                    .foregroundColor(Palette.textMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .background(Palette.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.border, lineWidth: 1))
    }

    private func shareRow(_ label: String, _ value: Kurus,
                          _ color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.manrope(bold ? 13 : 12.5, bold ? .bold : .medium))
                .foregroundColor(bold ? Palette.ink : Palette.textSecondary)
            Spacer()
            Text(Fmt.money(value))
                .font(.sora(bold ? 15 : 13.5, .bold))
                .foregroundColor(color)
        }
        .padding(.top, 8)
    }

    /// Neyin dahil OLMADIĞI. Madde 1'in dersi: eksik kapsamlı bir rakam,
    /// kapsamı yazılmadığında yanıltıcıdır.
    private func scopeText(progress: Int, deposits: Kurus,
                           remainingCost: Kurus?) -> String {
        var parts = ["Bu tutarlar uygulamaya girilen kayıtlardan hesaplanır."]
        if progress < 100 {
            // Kalan maliyet GİRİLDİYSE bile bu paylardan DÜŞÜLMÜYOR — cümle
            // bunu söylemeye devam ediyor, yalnızca rakamı da veriyor.
            // Düşseydik payı bugün dağıtılabilir bir tutar olmaktan çıkarır,
            // üstelik elle girilmiş bir tahmini ortağın hissesine karıştırırdık.
            if let remainingCost {
                parts.append("Yöneticinin girdiği kalan inşaat maliyeti \(Fmt.money(remainingCost)) (%\(progress) tamamlandı) bu paylardan DÜŞÜLMEDİ — \"aradaki fark\" kâr değildir.")
            } else {
                parts.append("İnşaatın kalan maliyeti (%\(progress) tamamlandı) HENÜZ DÜŞÜLMEDİ — \"aradaki fark\" kâr değildir.")
            }
        }
        // Kapora kasadadır ama DAĞITILABİLİR DEĞİLDİR: satış bozulursa geri
        // gider. Rakama girmiyor; girmediğini söylemek de kapsamın parçası.
        if deposits > .zero {
            parts.append("Rezerve dairelerin \(Fmt.money(deposits)) kaporası kasadadır ama iade edilebilir olduğu için paya girmez.")
        }
        parts.append("Finansman gideri ve tedarikçi vadesi dahil değildir.")
        // KDV TABANI KARIŞIMI PAYA DA GEÇİYOR (madde 80): pay, net rakamın
        // yüzdeyle dilimlenmiş hâli; net karışımsa pay da karışım. Rapor
        // kartında yazıp burada susmak, sapmayı tam da paranın konuşulduğu
        // ekranda gizlemek olurdu.
        let proje = viewModel.projects.first { $0.id == projectId }
        if let proje, proje.expenseTaxBasis != nil || proje.salesTaxBasis != nil {
            parts.append("Beyan: gider \(proje.expenseTaxBasis.label), "
                         + "satış \(proje.salesTaxBasis.label); "
                         + "uygulama vergi hesaplamaz ve iki taban arasındaki farkı düzeltmez.")
        }
        // MADDE 82 SONRASI: sermaye ve çekimler ARTIK tutuluyor, ama bu kart
        // onları PAYA KATMIYOR ve katmamalı. Pay, proje toplamlarının
        // yüzdeyle dilimlenmiş hâli; cari hesap ise ortağın kasayla arasındaki
        // ayrı bir hesap. İkisini tek rakama katlamak, "payına düşen" ile
        // "sana kalan" arasındaki farkı silerdi — üstelik kart bir mutabakat
        // belgesi gibi görünmeye başladığı için burada daha da tehlikeli.
        parts.append("Ortakların koyduğu sermaye ve çektiği para AYRI tutuluyor "
                     + "(Ortak Cari Hesabı); bu paylara eklenmez, buradan düşülmez.")
        return parts.joined(separator: " ")
    }
}

// MARK: - Ortak satırı

struct PartnerRowView: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: 12) {
            Text(partner.initials)
                .font(.manrope(13, .extraBold))
                .foregroundColor(partner.isFounder ? .white : Palette.accent)
                .frame(width: 40, height: 40)
                .background(partner.isFounder ? Palette.ink : Palette.accentTint)
                .cornerRadius(13)

            VStack(alignment: .leading, spacing: 3) {
                Text(partner.name)
                    .font(.manrope(13.5, .bold))
                    .foregroundColor(Palette.ink)
                Text(partner.joinedText)
                    .font(.manrope(11.5, .medium))
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            Text("%\(partner.sharePercent)")
                .font(.sora(15, .bold))
                .foregroundColor(Palette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Palette.surface)
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.border, lineWidth: 1))
    }
}
