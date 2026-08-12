import SwiftUI

// MARK: - İnşaat İlerlemesi (yalnızca yönetici)
// Proje detayındaki ⋯ menüsünden açılır. İlerleme yüzdesi ve yapım aşaması
// dashboard kartının en görünür öğesi; buradan güncellenir.

struct ProgressSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    let projectId: String

    @State private var progress: Double = 0
    @State private var phase: ProjectPhase = .temel
    @State private var didLoad = false

    private var project: Project? {
        viewModel.projects.first { $0.id == projectId }
    }

    /// %90 ve üzeri yeşile döner — dashboard kartıyla aynı kural.
    private var barColor: Color {
        Int(progress) >= 90 ? Palette.success : Palette.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(title: "İnşaat İlerlemesi",
                        subtitle: project?.title) { dismiss() }

            // Canlı önizleme — dashboard kartındaki satırın aynısı
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("İnşaat ilerlemesi")
                        .font(.manrope(12, .medium))
                        .foregroundColor(Palette.textMuted)
                    Spacer()
                    Text("%\(Int(progress))")
                        .font(.sora(15, .bold))
                        .foregroundColor(barColor)
                }
                ProgressBarView(fraction: progress / 100, fill: barColor)
                    .padding(.top, 8)
            }
            .padding(16)
            .background(Palette.fillSubtle)
            .cornerRadius(15)
            .padding(.top, 18)

            // %5'lik adımlarla kaydırıcı
            Slider(value: $progress, in: 0...100, step: 5)
                .tint(Palette.accent)
                .padding(.top, 14)

            HStack {
                Text("%0")
                Spacer()
                Text("%100")
            }
            .font(.manrope(10.5, .medium))
            .foregroundColor(Palette.textTertiary)

            Text("Yapım Aşaması")
                .smallCapsLabel(size: 10, color: Palette.textControl, tracking: 0.9)
                .padding(.top, 20)

            FlowLayout(spacing: 9) {
                ForEach(ProjectPhase.allCases, id: \.self) { option in
                    phaseChip(option)
                }
            }
            .padding(.top, 10)

            PrimaryButton(title: "Kaydet") {
                viewModel.updateProgress(role: appState.currentUser?.role ?? .partner,
                                         projectId: projectId,
                                         progress: Int(progress), phase: phase)
                dismiss()
            }
            .padding(.top, 22)

            Text("Bu bilgi ortakların gördüğü proje kartında görünür.")
                .font(.manrope(11, .medium))
                .foregroundColor(Palette.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Palette.surface)
        .sheetHeight(0.62)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius24()
        .onAppear {
            guard !didLoad, let project else { return }
            didLoad = true
            progress = Double(project.progress)
            phase = project.phase
        }
    }

    private func phaseChip(_ option: ProjectPhase) -> some View {
        let selected = phase == option
        return Button {
            phase = option
            // Aşama seçimi ilerlemeyi önerir; kullanıcı kaydırıcıyla ince ayar yapar.
            switch option {
            case .temel      where progress < 10:  progress = 15
            case .kabaInsaat where progress < 30:  progress = 50
            case .inceIsler  where progress < 60:  progress = 80
            case .teslim     where progress < 90:  progress = 100
            default: break
            }
        } label: {
            Text(option.rawValue)
                .font(.manrope(12.5, .bold))
                .foregroundColor(selected ? Palette.accent : Palette.textMuted)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(selected ? Palette.accentTint : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(selected ? Palette.accent : Palette.border, lineWidth: 1)
                )
                .cornerRadius(9)
        }
    }
}
