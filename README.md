# İnşaat Takip (iOS)

Ada / parsel bazlı inşaat proje yönetimi ve ortak bilgilendirme uygulaması. Sahadaki operasyonu yürüten **Yönetici** malzeme giriş-çıkışlarını, daire satışlarını, belgeleri ve şantiye fotoğraflarını girer; **Ortaklar** davet koduyla katılır ve her şeyi **salt okunur** takip eder. Amaç, projeye birlikte yatırım yapan ortaklar arasında finansal şeffaflık.

Tasarım kaynağı: [sinanalpagut/insaat-takip](https://github.com/sinanalpagut/insaat-takip) (13 ekranlık handoff paketi — Antrasit & Bakır paleti, Sora + Manrope tipografisi). Uygulama bu tasarımlara birebir sadık kodlanmıştır.

## Özellikler

- **Dashboard** — projeler (ada/parsel), ilerleme, satılan/malzeme/ciro özetleri
- **Malzemeler** — 9 kalem stok takibi, kritik stok uyarısı, fiş/irsaliye ile giriş-çıkış; finans şeridi (Satış / Malzeme / Net) canlı hesaplanır
- **Daireler** — satış ızgarası (satıldı/boş), tahsilat oranı, ödeme durumu (Tamamlandı/Kapora/Taksitli), daire detayı + görsel yuvaları, satış ekleme/düzenleme
- **Ortaklar** — hisse dağılımı, tek kullanımlık 48 saatlik davet kodu üretimi (`XXX-XXX`), WhatsApp ile paylaşım
- **Belgeler** — mimari/statik/ruhsat dosya arşivi, sürümleme, belge bazlı "Ortaklar görebilsin" yetkisi, dosya yükleme
- **Hareketler** — tüm giriş-çıkış/satış/katılım olaylarının bildirim akışı
- **Şantiye Fotoğrafları** — haftalık ilerleme kaydı (galeriden ekleme)
- **Dönem Raporu** — ay/çeyrek/tümü özetleri, aylık satış grafiği, tek dokunuşla PDF üretip paylaşma

## Teknik

- SwiftUI, iOS 16+, **MVVM** — tüm iş mantığı `ProjectViewModel`'de, görünümler "dumb"
- Henüz backend yok: tasarımdaki senaryoyu birebir yansıtan gerçekçi mock veri (`ProjectViewModel.loadMockData`)
- `@StateObject` / `@Published` / `EnvironmentObject` ile durum yönetimi
- Xcode 16+ senkronize klasör yapısı (`project.pbxproj` objectVersion 77) — dosya ekleyince proje dosyasına dokunmak gerekmez
- DEBUG launch argümanlarıyla ekran seçimi (screenshot/snapshot akışları): `-role admin|partner -screen project|activity|photos|report|join -tab mat|apt|ptn|doc -sheet log|receipt|invite|apt|sale|upload`

## Çalıştırma

```bash
open InsaatTakip.xcodeproj
```

Xcode'da `InsaatTakip` şemasını seçip ⌘R. Komut satırından derleme:

```bash
xcodebuild -project InsaatTakip.xcodeproj -scheme InsaatTakip \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

## Klasör Yapısı

```
InsaatTakip/
├── App/          # Giriş, kök görünüm, rotalar, launch argümanları
├── Models/       # Codable + Identifiable veri modelleri
├── ViewModels/   # AppState (rol/oturum) + ProjectViewModel (tüm iş mantığı)
├── Views/        # Onboarding, Dashboard, Proje detayı (4 sekme + sheet'ler)
├── Theme/        # Palet, tipografi, tr-TR formatlayıcılar, ortak bileşenler
└── Resources/    # Sora + Manrope fontları
```
