import SwiftUI

// MARK: - Kilit Ekranı ve Gizlilik Örtüsü (madde 78)

/// Kilit açılana kadar İÇERİK HİÇ ÇİZİLMİYOR.
///
/// Şeffaf bir katman ya da bulanıklık yeterli olmazdı: altındaki görünüm
/// bellekte ve ekran görüntüsünde durmaya devam ederdi. Örtü opak.
struct LockScreen: View {
    @EnvironmentObject private var appLock: AppLock
    @State private var denendi = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .iconFont(24, weight: .semibold)
                .foregroundColor(Palette.accent)
                .frame(width: 64, height: 64)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)

            Text("Uygulama kilitli")
                .font(.sora(20, .bold))
                .foregroundColor(.white)

            Text("Proje kayıtlarını görmek için kimliğini doğrula.")
                .font(.manrope(13, .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // DÜĞME HER ZAMAN VAR. Doğrulama otomatik başlıyor ama kullanıcı
            // vazgeçerse ya da yüz okunmazsa ekranda yapacak bir şey kalmalı;
            // yoksa tek çıkış uygulamayı öldürmek olurdu.
            Button {
                Task { await appLock.unlock() }
            } label: {
                Text(denendi ? "Tekrar dene" : "Kilidi aç")
                    .font(.manrope(15, .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Palette.accent)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ink.ignoresSafeArea())
        .task {
            // Açılışta kendiliğinden sor: kullanıcı zaten kilidi açmak için
            // uygulamaya döndü, ayrıca bir düğmeye basmasını istemek gereksiz
            // bir adım olurdu.
            _ = await appLock.unlock()
            denendi = true
        }
    }
}

/// Uygulama değiştirici örtüsü.
///
/// iOS, uygulama `.inactive` olduğunda ekranın anlık görüntüsünü alıyor ve o
/// görüntü uygulama değiştiricide herkese görünüyor. Örtü olmadan ciro, alıcı
/// adları ve dekontlar telefonu eline alan herkese açıktı — kilit açık olsa
/// bile, çünkü kilit yalnızca uygulamaya DÖNÜNCE soruluyor.
struct PrivacyCover: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .iconFont(26, weight: .semibold)
                .foregroundColor(Palette.accent)
            Text("İNŞAAT TAKİP")
                .smallCapsLabel(size: 12, color: .white.opacity(0.75), tracking: 2.0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ink.ignoresSafeArea())
    }
}
