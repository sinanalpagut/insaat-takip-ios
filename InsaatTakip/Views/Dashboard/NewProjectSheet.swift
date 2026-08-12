import SwiftUI

// MARK: - Yeni Proje (Yönetici)
// Dashboard'daki "＋ Yeni Proje" FAB'ından açılır. Fiş ekleme sayfasıyla
// aynı form dili: küçük büyük-harf etiketler, beyaz giriş kutuları, bakır CTA.

struct NewProjectSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var block = ""
    @State private var parcel = ""
    @State private var district = ""
    @State private var city = ""
    @State private var floors = 4
    @State private var apartmentCount = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "Yeni Proje",
                        subtitle: "Ada / parsel bilgisiyle takip başlat") { dismiss() }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        field("ADA", text: $block, placeholder: "145", keyboard: .numberPad)
                        field("PARSEL", text: $parcel, placeholder: "2", keyboard: .numberPad)
                    }
                    .padding(.top, 18)

                    HStack(spacing: 10) {
                        field("İLÇE", text: $district, placeholder: "Çayırova")
                        field("İL", text: $city, placeholder: "Kocaeli")
                    }
                    .padding(.top, 14)

                    HStack(spacing: 10) {
                        stepper("KAT", value: $floors, range: 1...30)
                        stepper("DAİRE SAYISI", value: $apartmentCount, range: 1...200)
                    }
                    .padding(.top, 14)

                    PrimaryButton(title: "Projeyi Oluştur") {
                        if viewModel.addProject(role: appState.currentUser?.role ?? .partner,
                                                block: block, parcel: parcel,
                                                district: district, city: city,
                                                floors: floors, apartmentCount: apartmentCount) != nil {
                            dismiss()
                        }
                    }
                    .padding(.top, 24)

                    Text("Daireler boş olarak açılır; satışlar Daireler sekmesinden girilir.")
                        .font(.manrope(11, .medium))
                        .foregroundColor(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .keyboardDoneToolbar()
        .sheetHeight(0.72)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .toastOverlay(viewModel.toast)
    }

    // MARK: Form elemanları

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.manrope(15, .bold))
                .foregroundColor(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(Palette.surface)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
            HStack {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Palette.textMuted)
                        .frame(width: 34, height: 34)
                        .background(Palette.fillMuted)
                        .cornerRadius(10)
                }
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.sora(16, .bold))
                    .foregroundColor(Palette.ink)
                Spacer()
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Palette.accent)
                        .frame(width: 34, height: 34)
                        .background(Palette.accentTint)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 52)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.border, lineWidth: 1))
        }
    }
}

// MARK: - Sheet köşe yardımcısı
// presentationCornerRadius iOS 16.4+ gerektirir; 16.0'da sistem varsayılanı kalır.

extension View {
    @ViewBuilder
    func presentationCornerRadius24() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(24)
        } else {
            self
        }
    }
}
