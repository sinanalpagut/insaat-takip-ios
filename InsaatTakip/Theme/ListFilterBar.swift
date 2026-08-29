import SwiftUI

// MARK: - Ortak arama çubuğu ve dönem çipleri (madde 79)
//
// Arama yalnızca dairelerde vardı ve o çubuk `ApartmentsTabView`in içinde
// yaşıyordu. Giderler ve malzeme hareketleri için ikinci, üçüncü bir kopya
// yazmak, aynı sorgunun bir sekmede bulup diğerinde bulamadığı bir ürün
// üretirdi — ve fark yalnızca kullanıcı iki sekmede aynı şeyi arayınca
// görünürdü. Bileşen tek yerde.

/// Liste araması çubuğu.
struct ListSearchBar: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .iconFont(13, weight: .medium)
                .foregroundColor(Palette.textTertiary)

            TextField(placeholder, text: $text)
                .font(.manrope(13, .medium))
                .foregroundColor(Palette.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .iconFont(14, weight: .regular)
                        .foregroundColor(Palette.textTertiary)
                        // Glif 14pt (tasarım değişmiyor) ama dokunma hedefi
                        // 44pt: sembolün gerçek kutusu 16×16'ydı, yani
                        // Apple'ın asgarisinin çok altında. Çubuk 46pt yüksek
                        // olduğu için görsel hiçbir şey kaymıyor.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Aramayı temizle")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Palette.surface)
        .cornerRadius(13)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
    }
}

/// Dönem çipleri — "Tümü / Bu ay / Son 3 ay / Bu yıl".
///
/// SAYI GÖSTERİLİYOR ve sayılar SÜZÜLMEMİŞ listeden geliyor: çipe basmadan
/// önce kaç kayıt olduğunu görmek, süzgecin ne yapacağını önceden söylüyor.
/// Daire durum çipleri de aynı kuralı izliyor.
struct ListPeriodChips: View {
    @Binding var selection: ListPeriod
    /// Her dönem için kayıt sayısı.
    let count: (ListPeriod) -> Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ListPeriod.allCases) { period in
                    let selected = selection == period
                    Button {
                        // Aynı çipe ikinci dokunuş "Tümü"ye döner — çıkış
                        // yolu ayrı bir çipe gitmeyi gerektirmesin.
                        selection = selected ? .tumu : period
                    } label: {
                        Text("\(period.rawValue) \(count(period))")
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
            }
            .padding(.horizontal, 1)
        }
    }
}

/// Süzgeç sonucu boşsa gösterilen durum.
///
/// "Kayıt yok" ile "aramanla eşleşen yok" AYRI cümleler: ilki kullanıcıya
/// verisinin silindiğini düşündürebilir.
struct ListNoMatchState: View {
    let query: String
    let singular: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .iconFont(20, weight: .light)
                .foregroundColor(Palette.textTertiary)
            Text("Eşleşen \(singular) yok")
                .font(.manrope(13.5, .bold))
                .foregroundColor(Palette.ink)
            Text(query.isEmpty
                 ? "Seçtiğin dönemde kayıt bulunmuyor."
                 : "\"\(query)\" için sonuç yok.")
                .font(.manrope(12, .medium))
                .foregroundColor(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}
