import Foundation

// MARK: - Bellek içi veri kaynağı (Faz 1)
//
// Uygulamanın demo verisi ve kalıcılık aynası. Bu blok daha önce
// ProjectViewModel'in içindeydi ve dosyanın %28'ini kaplıyordu; iş mantığıyla
// veri kaynağını aynı dosyada tutmak, Faz 2'de Firestore gelince tam olarak
// hangi kısmın değişeceğini görünmez kılıyordu. Artık ayrım net: ViewModel
// kuralları bilir, burası veriyi.
//
// `apply` ile gelen yazmalar kendi kopyasına da işlenir. Bugün bu kopyanın tek
// okuyucusu `cachedSnapshot()` (açılış) ve `load()`; ama asıl işlevi, Faz 2'de
// Firestore'un devralacağı yazma yolunun bugünden çalışır durumda olmasıdır.
// Diziler ViewModel'le AYNI sırayla tutulur (yeni kayıt başa) — böylece
// `load()` ekranın gördüğü sırayı birebir döndürür.

// MARK: - Demo kimlikleri
// Mock veri okunabilir kalsın diye sabit UUID'ler; gerçek projeler UUID() alır.

enum DemoID {
    static let cayirova = UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!
    static let nilufer  = UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!
    static let kepez    = UUID(uuidString: "A1000000-0000-4000-8000-000000000003")!
    static let kars309  = UUID(uuidString: "A1000000-0000-4000-8000-000000000004")!
    static let kars327  = UUID(uuidString: "A1000000-0000-4000-8000-000000000005")!
}

// MARK: - Demo verisi

extension InMemoryProjectRepository {

    /// Tasarım dosyasındaki ekranların birebir veri seti.
    func loadMockData() {
        // ---- Projeler --------------------------------------------------------
        // "kars309": GERÇEK proje — TOKİ Kars Karacaören 309 Konut, Ada 1224 / Parsel 1,
        // SF-1 Blok 1 (Zemin+2 kat, 12 daire, tamamı 3+1 · 111,55 m² brüt / 88,5 m² net).
        // Kaynak: TOKİ resmî fiyat listesi (29 Ağu 2024) — DemoAssets/ içinde yerel kopyası var.
        // GERÇEK TAKVİM: Karacaören konutlarının teslimatı 5-30 Mayıs 2025'te başladı
        // (toki.gov.tr haberi) — iki blok da Teslim fazında, ilerleme %100.
        projects = [
            Project(id: DemoID.cayirova, blockNumber: "145", parcelNumber: "2", district: "Çayırova", city: "Kocaeli",
                    floors: 5, totalApartments: 20, phase: .kabaInsaat, progress: 68, ownerId: User.admin.id, invite: nil, photoCount: 48),
            Project(id: DemoID.nilufer, blockNumber: "1287", parcelNumber: "14", district: "Nilüfer", city: "Bursa",
                    floors: 4, totalApartments: 12, phase: .temel, progress: 34, ownerId: User.admin.id, invite: nil, photoCount: 12),
            Project(id: DemoID.kepez, blockNumber: "908", parcelNumber: "7", district: "Kepez", city: "Antalya",
                    floors: 3, totalApartments: 8, phase: .teslim, progress: 96, ownerId: User.admin.id, invite: nil, photoCount: 64),
            Project(id: DemoID.kars309, blockNumber: "1224", parcelNumber: "1", district: "Karacaören", city: "Kars",
                    floors: 3, totalApartments: 12, phase: .teslim, progress: 100, ownerId: User.admin.id, invite: nil, photoCount: 0),
            // "kars327": GERÇEK proje — TOKİ Kars Karacaören 327 Konut, Ada 1139 / Parsel 3,
            // GB Blok 1 (1 bodrum + zemin + 4 normal kat, 22 daire, 3+1 · 103,8 m² brüt / 83,9 m² net).
            Project(id: DemoID.kars327, blockNumber: "1139", parcelNumber: "3", district: "Karacaören", city: "Kars",
                    floors: 6, totalApartments: 22, phase: .teslim, progress: 100, ownerId: User.admin.id, invite: nil, photoCount: 0),
        ]

        // ---- Malzemeler (9 kalem × 3 proje) ---------------------------------
        // (kod, ad, açıklama, birim, birim fiyat, giren, çıkan, adım)
        let baseMaterials: [(String, String, String, String, Double, Double, Double, Double)] = [
            ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 48_000, 41_800, 500),
            ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 1_850, 1_640, 50),
            ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 1_240, 1_060, 50),
            ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 78_000, 68_600, 1_000),
            ("EPS", "Strafor", "5 cm cephe levhası", "m²", 96, 2_400, 1_460, 100),
            ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 186, 144, 10),
            ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 320, 272, 20),
            ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 900, 590, 25),
            ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 640, 420, 25),
        ]
        // p2 ve p3 daha küçük projeler: miktarlar ölçeklenir, fiyatlar aynı kalır.
        let scales: [UUID: Double] = [DemoID.cayirova: 1.0, DemoID.nilufer: 0.52, DemoID.kepez: 0.44]
        for project in projects {
            guard let factor = scales[project.id] else { continue }   // kars309 aşağıda ayrı
            for (code, name, subtitle, unit, price, totalIn, totalOut, step) in baseMaterials {
                let scaledIn = (totalIn * factor).rounded()
                materials.append(Material(id: UUID(), projectId: project.id,
                                          code: code, name: name, subtitle: subtitle, unit: unit,
                                          unitPrice: price,
                                          totalIn: scaledIn,
                                          totalOut: (totalOut * factor).rounded(),
                                          step: step,
                                          accruedCost: scaledIn * price))
            }
        }

        // kars309 malzemeleri — MÜHENDİSLİK TAHMİNİ (proje bazlı malzeme verisi kamuya açık değildir).
        // Taban: 12 daire × 111,55 m² brüt × 1,15 ortak alan payı ≈ 1.540 m² inşaat alanı.
        // Katsayılar (betonarme konut için yaygın değerler): demir 40 kg/m², beton 0,35 m³/m²,
        // çimento 0,7 torba/m², tuğla 45 adet/m², alçı 0,45 torba/m²; cephe ≈ 810 m² (mantolama),
        // doğrama 12 daire × 7 adet. Proje TESLİM EDİLDİ (May 2025) — stoklar kapanış durumunda.
        let karsMaterials: [(String, String, String, String, Double, Double, Double, Double)] = [
            ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 61_500, 61_200, 500),
            ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 540, 540, 50),
            ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 1_080, 1_060, 50),
            ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 69_500, 69_000, 1_000),
            ("EPS", "Strafor", "5 cm mantolama levhası", "m²", 96, 810, 810, 100),
            ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 84, 84, 10),
            ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 340, 335, 20),
            ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 750, 740, 25),
            ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 690, 685, 25),
        ]
        for (code, name, subtitle, unit, price, totalIn, totalOut, step) in karsMaterials {
            materials.append(Material(id: UUID(), projectId: DemoID.kars309,
                                      code: code, name: name, subtitle: subtitle, unit: unit,
                                      unitPrice: price, totalIn: totalIn, totalOut: totalOut,
                                      step: step, accruedCost: totalIn * price))
        }

        // kars327 GB Blok 1 malzemeleri — aynı katsayılarla tahmin:
        // 22 daire × 103,8 m² brüt × 1,15 ≈ 2.626 m² inşaat alanı. TESLİM EDİLDİ — kapanış stokları.
        let kars327Materials: [(String, String, String, String, Double, Double, Double, Double)] = [
            ("Ø12", "Demir", "Nervürlü inşaat demiri", "kg", 28.5, 105_000, 104_500, 500),
            ("C30", "Hazır Beton", "C30/37 pompalı", "m³", 2_450, 920, 920, 50),
            ("ÇMT", "Çimento", "CEM II 42,5 R", "torba", 165, 1_840, 1_815, 50),
            ("TĞL", "Tuğla", "19luk yatay delikli", "adet", 22, 118_000, 117_000, 1_000),
            ("EPS", "Strafor", "5 cm mantolama levhası", "m²", 96, 1_320, 1_320, 100),
            ("PVC", "Pimapen", "PVC doğrama · ısıcam", "adet", 6_800, 154, 154, 10),
            ("KUM", "Kum", "Yıkanmış dere kumu", "ton", 950, 580, 572, 20),
            ("TEL", "Bağ Teli", "1,5 mm galvaniz", "kg", 42, 1_260, 1_245, 25),
            ("ALÇ", "Alçı", "Saten perdah alçısı", "torba", 210, 1_180, 1_170, 25),
        ]
        for (code, name, subtitle, unit, price, totalIn, totalOut, step) in kars327Materials {
            materials.append(Material(id: UUID(), projectId: DemoID.kars327,
                                      code: code, name: name, subtitle: subtitle, unit: unit,
                                      unitPrice: price, totalIn: totalIn, totalOut: totalOut,
                                      step: step, accruedCost: totalIn * price))
        }

        // ---- Malzeme hareket geçmişi ----------------------------------------
        // Demir kayıtları ekran 03'teki değerlerin birebir aynısı; diğer kalemler
        // aynı tarih/irsaliye düzeniyle kendi miktarlarından türetilir.
        let admin = User.admin.name
        for material in materials where material.projectId == DemoID.cayirova {
            if material.code == "Ø12" {
                materialLogs.append(contentsOf: [
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 6_800,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(2, 8, 2026), note: "5. kat perde donatısı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: 12_500,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(28, 7, 2026), note: "İrsaliye #4471 · Yılmaz Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 4_600,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(21, 7, 2026), note: "4. kat döşeme imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: 14_000,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(14, 7, 2026), note: "İrsaliye #4398 · Ege Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: 3_900,
                                unitPrice: material.unitPrice, date: Fmt.makeDate(6, 7, 2026), note: "3. kat kolon donatısı", user: admin),
                ])
            } else {
                let round: (Double) -> Double = { value in
                    let unitStep = max(1, material.step / 5)
                    return max(unitStep, (value / unitStep).rounded() * unitStep)
                }
                materialLogs.append(contentsOf: [
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.16),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(2, 8, 2026), note: "5. kat imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: round(material.totalIn * 0.21),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(28, 7, 2026), note: "İrsaliye #4471 · Yılmaz Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.11),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(21, 7, 2026), note: "4. kat imalatı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .entry, amount: round(material.totalIn * 0.28),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(14, 7, 2026), note: "İrsaliye #4398 · Ege Yapı", user: admin),
                    MaterialLog(id: UUID(), materialId: material.id, type: .exit, amount: round(material.totalOut * 0.09),
                                unitPrice: material.unitPrice, date: Fmt.makeDate(6, 7, 2026), note: "3. kat imalatı", user: admin),
                ])
            }
        }

        // Kars hareketleri — teslim (May 2025) öncesi son imalat kayıtları (temsilî akış).
        // Fiyatlar kayıt anındaki değerlerdir; sonraki zamlar bu kayıtları etkilemez.
        // Kalem UUID'leri okunabilir koddan bulunur.
        let karsLogs: [(UUID, String, MaterialLog.LogType, Double, Double, Date, String)] = [
            (DemoID.kars309, "ALÇ", .exit,  120,   210,  Fmt.makeDate(18, 3, 2025), "Saten perdah tamamlandı"),
            (DemoID.kars309, "EPS", .exit,  90,    96,   Fmt.makeDate(4, 3, 2025),  "Cephe mantolama kapanışı"),
            (DemoID.kars309, "Ø12", .entry, 9_500, 28.5, Fmt.makeDate(11, 2, 2025), "İrsaliye #2087 · Kars Demir Çelik"),
            (DemoID.kars309, "Ø12", .exit,  4_200, 28.5, Fmt.makeDate(27, 2, 2025), "Çevre duvarı donatısı"),
            (DemoID.kars327, "ALÇ", .exit,  150,   210,  Fmt.makeDate(8, 4, 2025),  "Son kat saten perdah"),
            (DemoID.kars327, "PVC", .entry, 30,    6_800, Fmt.makeDate(21, 3, 2025), "İrsaliye #3141 · Serhat PVC"),
            (DemoID.kars327, "EPS", .exit,  160,   96,   Fmt.makeDate(14, 4, 2025), "Güney cephe mantolama kapanışı"),
        ]
        for (projectId, code, type, amount, price, date, note) in karsLogs {
            guard let materialId = material(in: projectId, code: code)?.id else { continue }
            materialLogs.append(MaterialLog(id: UUID(), materialId: materialId, type: type,
                                            amount: amount, unitPrice: price, date: date,
                                            note: note, user: admin))
        }

        // ---- Daireler --------------------------------------------------------
        // 145 Ada / 2 Parsel: 12 satış — alıcı, bedel, ödeme ve tahsilat değerleri
        // ekran 04'teki kartların birebir aynısı. (Tahsilat 28,12 M · Kalan 14,53 M)
        let types = [("2+1", "95 m²"), ("3+1", "128 m²"), ("3+1", "132 m²"), ("2+1", "98 m²")]

        // (daireNo, alıcı, bedel, ödeme, tahsil edilen, tarih)
        let p1Sales: [(Int, String, Double, PaymentStatus, Double, Date)] = [
            (1, "Ahmet Yılmaz", 3_150_000, .tamamlandi, 3_150_000, Fmt.makeDate(18, 2, 2026)),
            (2, "Merve Demir", 3_650_000, .tamamlandi, 3_650_000, Fmt.makeDate(2, 3, 2026)),
            (3, "Selim Kaya", 3_700_000, .kapora, 500_000, Fmt.makeDate(14, 3, 2026)),
            (4, "Emre Şahin", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(27, 3, 2026)),
            (5, "Fatma Çelik", 3_300_000, .taksitli, 1_980_000, Fmt.makeDate(5, 4, 2026)),
            (6, "Hakan Aydın", 3_800_000, .taksitli, 2_280_000, Fmt.makeDate(19, 4, 2026)),
            (7, "Berk Koç", 3_850_000, .tamamlandi, 3_850_000, Fmt.makeDate(28, 4, 2026)),
            (8, "Nazlı Arslan", 3_350_000, .kapora, 500_000, Fmt.makeDate(9, 5, 2026)),
            (9, "Rıza Doğan", 3_450_000, .tamamlandi, 3_450_000, Fmt.makeDate(21, 5, 2026)),
            (11, "Tuğçe Öztürk", 3_900_000, .taksitli, 1_510_000, Fmt.makeDate(6, 6, 2026)),
            (13, "Cem Yıldız", 3_550_000, .tamamlandi, 3_550_000, Fmt.makeDate(17, 6, 2026)),
            (17, "Gizem Polat", 3_750_000, .kapora, 500_000, Fmt.makeDate(2, 7, 2026)),
        ]
        let p2Sales: [(Int, String, Double, PaymentStatus, Double, Date)] = [
            (1, "Ahmet Yılmaz", 3_150_000, .tamamlandi, 3_150_000, Fmt.makeDate(22, 2, 2026)),
            (2, "Merve Demir", 3_650_000, .tamamlandi, 3_650_000, Fmt.makeDate(9, 3, 2026)),
            (4, "Selim Kaya", 3_200_000, .kapora, 500_000, Fmt.makeDate(30, 3, 2026)),
            (7, "Emre Şahin", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(12, 4, 2026)),
        ]
        let p3Sales: [(Int, String, Double, PaymentStatus, Double, Date)] = [
            (1, "Kemal Ünal", 3_400_000, .tamamlandi, 3_400_000, Fmt.makeDate(14, 1, 2026)),
            (2, "Zeynep Kaplan", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(26, 1, 2026)),
            (3, "Murat Şen", 3_300_000, .tamamlandi, 3_300_000, Fmt.makeDate(8, 2, 2026)),
            (4, "Elif Kurt", 3_450_000, .tamamlandi, 3_450_000, Fmt.makeDate(24, 2, 2026)),
            (5, "Okan Güler", 3_150_000, .tamamlandi, 3_150_000, Fmt.makeDate(11, 3, 2026)),
            (6, "Derya Aksoy", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(29, 3, 2026)),
            (7, "Sinan Ateş", 3_500_000, .tamamlandi, 3_500_000, Fmt.makeDate(16, 4, 2026)),
            (8, "Pelin Erden", 3_200_000, .tamamlandi, 3_200_000, Fmt.makeDate(3, 5, 2026)),
        ]
        let salesByProject = [DemoID.cayirova: p1Sales, DemoID.nilufer: p2Sales, DemoID.kepez: p3Sales]

        // 145 Ada KAT KARŞILIĞI yapılıyor: 4 daire arsa sahibinin payı, 1 daire de
        // kapora aşamasında rezerve. Bu beşi önceden "Boş" görünüyor, satış oranı
        // 12/20 (%60) çıkıyor ve "Kalan 8" satılamayacak daireleri stok sayıyordu.
        // Gerçekte satılabilir stok 16 daire (→ %75) ve gerçekten boş yalnızca 3 daire.
        let p1LandOwner: Set<Int> = [15, 16, 19, 20]
        let p1Reserved = (number: 14, buyer: "Serkan Bulut", listPrice: 3_400_000.0,
                          deposit: 150_000.0, date: Fmt.makeDate(28, 7, 2026))

        // Yalnızca kurgu projeler (p1-p3) otomatik üretilir; Kars projeleri aşağıda gerçek veriyle.
        for project in projects where salesByProject[project.id] != nil {
            let sales = salesByProject[project.id] ?? []
            let perFloor = max(1, project.totalApartments / project.floors)
            for n in 1...project.totalApartments {
                let t = types[(n - 1) % types.count]
                let sale = sales.first { $0.0 == n }
                let isCayirova = project.id == DemoID.cayirova
                let isLandOwner = isCayirova && p1LandOwner.contains(n)
                let isReserved = isCayirova && p1Reserved.number == n

                let status: Apartment.Status
                if sale != nil { status = .sold }
                else if isLandOwner { status = .landOwner }
                else if isReserved { status = .reserved }
                else { status = .available }

                apartments.append(Apartment(id: UUID(), projectId: project.id,
                                            apartmentNumber: n,
                                            floor: (n - 1) / perFloor + 1,
                                            type: t.0, area: t.1,
                                            status: status,
                                            buyerName: sale?.1 ?? (isReserved ? p1Reserved.buyer : nil),
                                            // Kat karşılığı daire bedelsizdir: arsa bedeli gider
                                            // defterinde ".arsa" kaleminde duruyor, daireye de
                                            // bedel yazılsaydı aynı maliyet iki kez düşülürdü.
                                            price: sale?.2 ?? (isReserved ? p1Reserved.listPrice : 0),
                                            paidAmount: sale?.4 ?? (isReserved ? p1Reserved.deposit : 0),
                                            paymentStatus: sale?.3 ?? (isReserved ? .kapora : nil),
                                            saleDate: sale?.5 ?? (isReserved ? p1Reserved.date : nil),
                                            deliveryNote: project.phase == .teslim ? "Teslim edildi" : "Anahtar teslim bekliyor"))
            }
        }

        // Daire No 7 (ekran 13): Salon + Mutfak yer tutucu kareleri; No 1: Salon.
        for (number, labels) in [(7, ["Salon", "Mutfak"]), (1, ["Salon"])] {
            guard let apartmentId = apartment(in: DemoID.cayirova, number: number)?.id else { continue }
            for label in labels {
                apartmentPhotos.append(ApartmentPhoto(id: UUID(), apartmentId: apartmentId,
                                                      label: label, image: nil))
            }
        }

        // kars309 daireleri — GERÇEK VERİ (TOKİ fiyat listesi, 29 Ağu 2024):
        // Kat ve daire bazlı satış bedelleri (KDV hariç) listedeki birebir değerlerdir.
        // Zemin: No 1-4 · 1. Kat: No 5-8 · 2. Kat: No 9-12; tamamı 3+1, 111,55 m² brüt.
        // Satış kurgusu: kura 19 Ara 2024 → sözleşmeler Oca 2025'te imzalandı (9 daire);
        // tahsilat = %10 peşinat + Şub 2025–Ağu 2026 arası 19 aylık taksit (TOKİ planı,
        // MMA artışı ihmal edilmiştir). ALICI ADLARI KURGUDUR (gerçek alıcılar gizlidir).
        // No 1, 5, 9 satışta boş; liste fiyatları satış formunda hazır gelir.
        // (daireNo, kat, alıcı?, bedel, tahsil edilen, sözleşme tarihi?)
        let karsUnits: [(Int, Int, String?, Double, Double, Date?)] = [
            (1, 0, nil, 1_805_613, 0, nil),
            (2, 0, "Meryem Karaca", 1_902_563, 371_003, Fmt.makeDate(9, 1, 2025)),
            (3, 0, "Hasan Demirtaş", 1_902_563, 371_003, Fmt.makeDate(14, 1, 2025)),
            (4, 0, "Elif Doğan", 1_805_613, 352_093, Fmt.makeDate(16, 1, 2025)),
            (5, 1, nil, 2_051_221, 0, nil),
            (6, 1, "Yusuf Aslan", 2_193_416, 427_715, Fmt.makeDate(7, 1, 2025)),
            (7, 1, "Zehra Çetin", 2_193_416, 427_715, Fmt.makeDate(21, 1, 2025)),
            (8, 1, "Osman Kaya", 2_051_221, 399_986, Fmt.makeDate(23, 1, 2025)),
            (9, 2, nil, 2_025_368, 0, nil),
            (10, 2, "İbrahim Güneş", 2_167_562, 422_678, Fmt.makeDate(28, 1, 2025)),
            (11, 2, "Hatice Yavuz", 2_167_562, 422_678, Fmt.makeDate(30, 1, 2025)),
            (12, 2, "Ali Yıldırım", 2_025_368, 394_950, Fmt.makeDate(31, 1, 2025)),
        ]
        // Teslimatlar 5-30 Mayıs 2025'te yapıldı (TOKİ resmî haberi).
        for (no, floor, buyer, price, paid, date) in karsUnits {
            apartments.append(Apartment(id: UUID(), projectId: DemoID.kars309,
                                        apartmentNumber: no, floor: floor,
                                        type: "3+1", area: "111,55 m²",
                                        status: buyer == nil ? .available : .sold,
                                        buyerName: buyer,
                                        price: price,
                                        paidAmount: paid,
                                        paymentStatus: buyer == nil ? nil : .taksitli,
                                        saleDate: date,
                                        deliveryNote: buyer == nil ? "Teslime hazır · satışta" : "Teslim edildi · May 2025"))
        }

        // kars327 GB Blok 1 daireleri — GERÇEK VERİ + EMSAL:
        // Kat düzeni: 1. Bodrum (No 1-2), Zemin (3-6), 1-4. Kat (7-22).
        // 12 dairenin bedeli TOKİ listesindeki birebir değerdir (No 1,3,6,9,10,12,13,14,17,19,20,21).
        // İlk kurada satılan 10 dairenin bedeli, kardeş GB bloklarındaki AYNI KONUMLU dairelerin
        // liste fiyatından alınmıştır (emsal). Tahsilat modeli: %10 peşinat + bedel×%0,5 aylık taksit
        // (TOKİ planının birebir oranı) — ilk kura Mar 2024 sözleşme (29 taksit ≈ %24,5),
        // Ara 2024 kurası Oca 2025 sözleşme (19 taksit ≈ %19,5). ALICI ADLARI KURGUDUR.
        // Boş: No 6, 13, 20, 21 (satış formunda gerçek liste fiyatı hazır gelir).
        // (daireNo, kat, alıcı?, bedel, tahsil edilen, sözleşme tarihi?)
        let kars327Units: [(Int, Int, String?, Double, Double, Date?)] = [
            (1, -1, "Ramazan Öz", 1_571_822, 306_505, Fmt.makeDate(3, 1, 2025)),
            (2, -1, "Sevgi Aydemir", 1_539_559, 377_192, Fmt.makeDate(12, 3, 2024)),      // emsal
            (3, 0, "Kadir Bulut", 1_781_526, 347_398, Fmt.makeDate(8, 1, 2025)),
            (4, 0, "Nuray Ekinci", 1_781_526, 436_474, Fmt.makeDate(14, 3, 2024)),        // emsal
            (5, 0, "Veli Şimşek", 1_717_002, 420_665, Fmt.makeDate(15, 3, 2024)),         // emsal
            (6, 0, nil, 1_733_133, 0, nil),
            (7, 1, "Fadime Uçar", 2_028_870, 497_073, Fmt.makeDate(18, 3, 2024)),         // emsal
            (8, 1, "Selçuk Erol", 1_910_575, 468_091, Fmt.makeDate(19, 3, 2024)),         // emsal
            (9, 1, "Melike Sarı", 1_835_297, 357_883, Fmt.makeDate(13, 1, 2025)),
            (10, 1, "Harun Tekin", 1_953_592, 380_950, Fmt.makeDate(16, 1, 2025)),
            (11, 2, "Gülay Erdem", 2_066_510, 506_295, Fmt.makeDate(21, 3, 2024)),        // emsal
            (12, 2, "Ferhat Koçak", 1_948_215, 379_902, Fmt.makeDate(20, 1, 2025)),
            (13, 2, nil, 1_872_936, 0, nil),
            (14, 2, "Şule Aksu", 1_991_231, 388_290, Fmt.makeDate(22, 1, 2025)),
            (15, 3, "Tarık Ünver", 2_012_739, 493_121, Fmt.makeDate(22, 3, 2024)),        // emsal
            (16, 3, "Aysel Turan", 2_088_018, 511_564, Fmt.makeDate(25, 3, 2024)),        // emsal
            (17, 3, "Bülent Işık", 1_894_444, 369_417, Fmt.makeDate(24, 1, 2025)),
            (18, 3, "Nazan Kurt", 1_969_723, 482_582, Fmt.makeDate(26, 3, 2024)),         // emsal
            (19, 4, "Erdal Yaman", 2_050_378, 399_824, Fmt.makeDate(27, 1, 2025)),
            (20, 4, nil, 1_932_083, 0, nil),
            (21, 4, nil, 1_856_805, 0, nil),
            (22, 4, "Songül Ateş", 1_975_100, 483_900, Fmt.makeDate(28, 3, 2024)),        // emsal
        ]
        for (no, floor, buyer, price, paid, date) in kars327Units {
            apartments.append(Apartment(id: UUID(), projectId: DemoID.kars327,
                                        apartmentNumber: no, floor: floor,
                                        type: "3+1", area: "103,8 m²",
                                        status: buyer == nil ? .available : .sold,
                                        buyerName: buyer,
                                        price: price,
                                        paidAmount: paid,
                                        paymentStatus: buyer == nil ? nil : .taksitli,
                                        saleDate: date,
                                        deliveryNote: buyer == nil ? "Teslime hazır · satışta" : "Teslim edildi · May 2025"))
        }

        // ---- Ortaklar (ekran 05) --------------------------------------------
        // Kurucu her projede aynı yöneticidir; diğer ortaklar projeye göre değişir.
        // Uygulamayı kullanan ortak hesabı (User.partner = Serkan Aydın) yalnızca
        // p1 ve kars309'a davetlidir — üyelik filtresinin çalıştığı buradan görülür.
        let partnerSets: [UUID: [(String, Bool, Date, Int, UUID?)]] = [
            DemoID.cayirova: [
                ("Mehmet Kılıç", true, Fmt.makeDate(4, 1, 2026), 40, User.admin.id),
                ("Serkan Aydın", false, Fmt.makeDate(12, 3, 2026), 25, User.partner.id),
                ("Ayşe Tuna", false, Fmt.makeDate(3, 4, 2026), 20, nil),
                ("Burak Erdoğan", false, Fmt.makeDate(21, 4, 2026), 15, nil),
            ],
            DemoID.nilufer: [
                ("Mehmet Kılıç", true, Fmt.makeDate(18, 2, 2026), 60, User.admin.id),
                ("Hakan Yücel", false, Fmt.makeDate(2, 3, 2026), 40, nil),
            ],
            DemoID.kepez: [
                ("Mehmet Kılıç", true, Fmt.makeDate(11, 11, 2025), 50, User.admin.id),
                ("Ayşe Tuna", false, Fmt.makeDate(20, 11, 2025), 50, nil),
            ],
            DemoID.kars309: [
                ("Mehmet Kılıç", true, Fmt.makeDate(12, 8, 2024), 55, User.admin.id),
                ("Serkan Aydın", false, Fmt.makeDate(6, 1, 2025), 45, User.partner.id),
            ],
            DemoID.kars327: [
                ("Mehmet Kılıç", true, Fmt.makeDate(12, 8, 2024), 70, User.admin.id),
                ("Burak Erdoğan", false, Fmt.makeDate(9, 1, 2025), 30, nil),
            ],
        ]
        for project in projects {
            for (name, founder, joined, share, userId) in partnerSets[project.id] ?? [] {
                partners.append(Partner(id: UUID(), projectId: project.id, name: name,
                                        isFounder: founder, joinedAt: joined,
                                        sharePercent: share, userId: userId))
            }
        }

        // ---- Belgeler (ekran 11) --------------------------------------------
        let p1Documents: [(ProjectDocument.Group, ProjectDocument.FileType, String, String, Double, Date, Bool)] = [
            (.mimari, .pdf, "Vaziyet Planı", "v3", 4.2, Fmt.makeDate(12, 1, 2026), true),
            (.mimari, .pdf, "Kat Planları (1–5)", "v5", 11.8, Fmt.makeDate(3, 2, 2026), true),
            (.mimari, .dwg, "Cephe Görünüşleri", "v2", 8.6, Fmt.makeDate(3, 2, 2026), true),
            (.statik, .pdf, "Statik Hesap Raporu", "v2", 22.4, Fmt.makeDate(18, 1, 2026), true),
            (.statik, .pdf, "Zemin Etüdü", "v1", 6.1, Fmt.makeDate(4, 1, 2026), true),
            (.ruhsat, .pdf, "Yapı Ruhsatı", "v1", 1.3, Fmt.makeDate(22, 1, 2026), true),
            (.ruhsat, .pdf, "İskân Başvurusu", "taslak", 0.8, Fmt.makeDate(14, 7, 2026), false),
        ]
        for (group, type, name, version, size, date, visible) in p1Documents {
            documents.append(ProjectDocument(id: UUID(), projectId: DemoID.cayirova, group: group, fileType: type,
                                             name: name, versionText: version, sizeMB: size,
                                             date: date, partnerVisible: visible))
        }
        // Diğer projelerde küçük birer dosya seti.
        for pid in [DemoID.nilufer, DemoID.kepez] {
            documents.append(contentsOf: [
                ProjectDocument(id: UUID(), projectId: pid, group: .mimari, fileType: .pdf,
                                name: "Vaziyet Planı", versionText: "v1", sizeMB: 3.4,
                                date: Fmt.makeDate(22, 1, 2026), partnerVisible: true),
                ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat, fileType: .pdf,
                                name: "Yapı Ruhsatı", versionText: "v1", sizeMB: 1.1,
                                date: Fmt.makeDate(30, 1, 2026), partnerVisible: true),
            ])
        }

        // kars309 + kars327 belgeleri — TOKİ'nin kamuya açık gerçek evrakları (toki.gov.tr/satis).
        // Fiyat listesi ve duyuru her iki Karacaören projesini de kapsar.
        for pid in [DemoID.kars309, DemoID.kars327] {
            documents.append(contentsOf: [
                ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat, fileType: .pdf,
                                name: "TOKİ 83 Konut Fiyat Listesi", versionText: "resmî", sizeMB: 0.2,
                                date: Fmt.makeDate(29, 8, 2024), partnerVisible: true),
                ProjectDocument(id: UUID(), projectId: pid, group: .ruhsat, fileType: .pdf,
                                name: "Satış-Kura Duyurusu", versionText: "resmî", sizeMB: 0.1,
                                date: Fmt.makeDate(16, 12, 2024), partnerVisible: true),
                ProjectDocument(id: UUID(), projectId: pid, group: .sozlesme, fileType: .pdf,
                                name: "Sözleşme Dönemi Bilgilendirmesi", versionText: "resmî", sizeMB: 0.1,
                                date: Fmt.makeDate(2, 1, 2025), partnerVisible: true),
            ])
        }

        // ---- Tahsilat kayıtları ---------------------------------------------
        // Mock verideki tek `paidAmount` toplamı gerçek ödeme kayıtlarına açılır:
        // peşin satışta tek kayıt, taksitlide sözleşme peşinatı + aylık taksitler.
        // Toplam yine aynı tutar; fark, artık her ödemenin tarihi ve yöntemi var.
        // `isCommitted`: rezerve dairenin kaporası da gerçek nakit, defterde durmalı.
        for apartment in apartments where apartment.isCommitted && apartment.paidAmount > 0 {
            let saleDate = apartment.saleDate ?? Date()
            let paid = apartment.paidAmount

            if apartment.paymentStatus == .tamamlandi {
                payments.append(Payment(id: UUID(), apartmentId: apartment.id, amount: paid,
                                        date: saleDate, method: .havale,
                                        note: "Satış bedeli", user: admin))
                continue
            }

            if apartment.paymentStatus == .kapora {
                payments.append(Payment(id: UUID(), apartmentId: apartment.id, amount: paid,
                                        date: saleDate, method: .pesinat,
                                        note: "Kapora", user: admin))
                continue
            }

            // Taksitli: %10 peşinat + kalanı eşit aylık taksitlere bölünür.
            let downPayment = min(paid, (apartment.price * 0.10).rounded())
            payments.append(Payment(id: UUID(), apartmentId: apartment.id, amount: downPayment,
                                    date: saleDate, method: .pesinat,
                                    note: "Sözleşme peşinatı", user: admin))

            let remaining = paid - downPayment
            guard remaining > 0 else { continue }
            let monthsElapsed = max(1, Fmt.calendar.dateComponents([.month], from: saleDate, to: Date()).month ?? 1)
            let installment = (remaining / Double(monthsElapsed)).rounded()

            var written = 0.0
            for month in 1...monthsElapsed {
                guard let date = Fmt.calendar.date(byAdding: .month, value: month, to: saleDate),
                      date <= Date() else { break }
                // Son taksit kuruş farkını kapatır.
                let amount = (month == monthsElapsed) ? (remaining - written) : installment
                guard amount > 0 else { break }
                payments.append(Payment(id: UUID(), apartmentId: apartment.id, amount: amount,
                                        date: date, method: .taksit,
                                        note: "\(month). taksit", user: admin))
                written += amount
            }
        }
        // Toplamları kayıtlardan yeniden türet (tek doğruluk kaynağı).
        for apartment in apartments where apartment.isCommitted {
            recalculateCollected(for: apartment.id)
        }

        // ---- Giderler (malzeme dışı) ----------------------------------------
        // Gerçekçi bir betonarme konut projesinde malzeme toplam maliyetin
        // ancak %35-45'idir; kalanı işçilik, taşeron, arsa ve resmî giderlerdir.
        let expenseSeed: [(UUID, Expense.Category, Double, Int, String, String)] = [
            (DemoID.cayirova, .arsa,       8_500_000, 640, "Arsa sahibi", "Kat karşılığı peşinat"),
            (DemoID.cayirova, .taseron,    2_450_000,  95, "Öz Kalıp İnşaat", "Kaba yapı 3. hakediş"),
            (DemoID.cayirova, .iscilik,    1_180_000,  40, "Şantiye ekibi", "Temmuz puantajı"),
            (DemoID.cayirova, .iscilik,    1_240_000,  10, "Şantiye ekibi", "Ağustos puantajı"),
            (DemoID.cayirova, .ruhsatHarc,   680_000, 520, "Çayırova Belediyesi", "Yapı ruhsat harcı"),
            (DemoID.cayirova, .makine,       420_000,  62, "Kaya Vinç", "Kule vinç kirası"),
            (DemoID.cayirova, .yakit,        135_000,  18, "Petrol Ofisi", "Jeneratör ve nakliye"),
            (DemoID.kars309,  .taseron,    1_620_000, 520, "Serhat Yapı", "İnce işler hakedişi"),
            (DemoID.kars309,  .iscilik,      890_000, 480, "Şantiye ekibi", "Kış dönemi puantajı"),
            (DemoID.kars309,  .ruhsatHarc,   310_000, 700, "Kars Belediyesi", "Ruhsat ve iskân harcı"),
            (DemoID.kars327,  .taseron,    2_980_000, 500, "Serhat Yapı", "GB blok ince işler"),
            (DemoID.kars327,  .iscilik,    1_460_000, 460, "Şantiye ekibi", "Kış dönemi puantajı"),
        ]
        for (projectId, category, amount, daysAgo, payee, note) in expenseSeed {
            expenses.append(Expense(id: UUID(), projectId: projectId, category: category,
                                    amount: amount, date: Fmt.daysAgo(daysAgo),
                                    payee: payee, note: note, user: admin))
        }

        // ---- Hareket akışı (ekran 07) ---------------------------------------
        activities = [
            ActivityItem(id: UUID(), projectId: DemoID.cayirova, kind: .materialIn, title: "Demir · 12.500 kg giriş",
                         meta: "145 Ada / 2 Parsel · İrsaliye #4471", timestamp: Fmt.daysAgo(0, hour: 9, minute: 24)),
            ActivityItem(id: UUID(), projectId: DemoID.cayirova, kind: .sale, title: "Daire No 17 satıldı — 3,75 M ₺",
                         meta: "145 Ada / 2 Parsel · Gizem Polat · Kapora alındı", timestamp: Fmt.daysAgo(0, hour: 8, minute: 10)),
            ActivityItem(id: UUID(), projectId: DemoID.cayirova, kind: .materialOut, title: "Çimento · 180 torba çıkış",
                         meta: "145 Ada / 2 Parsel · 5. kat şap", timestamp: Fmt.daysAgo(1, hour: 16, minute: 40)),
            ActivityItem(id: UUID(), projectId: DemoID.cayirova, kind: .partnerJoined, title: "Burak Erdoğan projeye katıldı",
                         meta: "145 Ada / 2 Parsel · davet kodu ile · salt okunur", timestamp: Fmt.daysAgo(1, hour: 11, minute: 2)),
            ActivityItem(id: UUID(), projectId: DemoID.kepez, kind: .materialIn, title: "Pimapen · 42 adet giriş",
                         meta: "908 Ada / 7 Parsel · İrsaliye #2210", timestamp: Fmt.daysAgo(3, hour: 10, minute: 0)),
            ActivityItem(id: UUID(), projectId: DemoID.cayirova, kind: .materialOut, title: "Kum · 24 ton çıkış",
                         meta: "145 Ada / 2 Parsel · Cephe sıva", timestamp: Fmt.daysAgo(3, hour: 10, minute: 0)),
        ]

        // ---- Şantiye fotoğraf yuvaları (ekran 09) ---------------------------
        // Gün sayısı bugüne göre verilir; "bu hafta / geçen hafta" ayrımını
        // SitePhoto tarihten hesaplar (sabit bayrak yarın yanlış olurdu).
        for days in [0, 0, 1, 2, 3, 3] {
            sitePhotos.append(SitePhoto(id: UUID(), projectId: DemoID.cayirova,
                                        date: Fmt.daysAgo(days), image: nil))
        }
        for days in [8, 9, 10, 11, 12, 13] {
            sitePhotos.append(SitePhoto(id: UUID(), projectId: DemoID.cayirova,
                                        date: Fmt.daysAgo(days), image: nil))
        }

        seedOpeningBalances()
    }

    /// Demo verisinde toplamlar elle yazılı, hareket geçmişi ise yalnızca son
    /// birkaç fişi içeriyor (gerçek hayatta da öyle: uygulama işin ortasında
    /// devralınır). Toplamlar artık hareketlerden türetildiği için, fişlerle
    /// açıklanamayan farkı bir kereye mahsus DEVİR olarak yazıyoruz. Böylece
    /// görünen rakamlar birebir aynı kalır ama bir fiş silindiğinde yalnızca
    /// o fişin etkisi geri alınır.
    func seedOpeningBalances() {
        for index in materials.indices {
            let logs = materialLogs.filter { $0.materialId == materials[index].id }
            let loggedIn = logs.filter { $0.type == .entry }.reduce(0) { $0 + $1.amount }
            let loggedOut = logs.filter { $0.type == .exit }.reduce(0) { $0 + $1.amount }
            let loggedCost = logs.filter { $0.type == .entry }.reduce(0) { $0 + $1.amount * $1.unitPrice }
            materials[index].openingIn = max(0, materials[index].totalIn - loggedIn)
            materials[index].openingOut = max(0, materials[index].totalOut - loggedOut)
            materials[index].openingCost = max(0, materials[index].accruedCost - loggedCost)
            materials[index].recalculate(from: materialLogs)
        }
    }
}
