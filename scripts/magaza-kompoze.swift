#!/usr/bin/env swift
//
//  Mağaza görsellerini BİRLEŞTİRİR.
//
//      swift scripts/magaza-kompoze.swift kontak  <kaynak-dizin> <çıktı.png>
//      swift scripts/magaza-kompoze.swift header  <ekran.png> <çıktı.png> "Başlık" "Alt satır"
//      swift scripts/magaza-kompoze.swift arama   <ekran.png> <çıktı.png> "Başlık" "Alt satır"
//
//  NEDEN SWIFT: makinede ImageMagick ve PIL yok; CoreGraphics her macOS'ta
//  var ve `make-icon.swift` ile aynı yol. Araç kurmak, altı ay sonra bu
//  betiği koşturacak kişiye de aynı kurulumu yaptırırdı.
//
//  NEDEN KONTAK SAYFASI: 42 ekran görüntüsünün tek tek açılması pratik
//  değil; bir sheet'in açılmadığı ancak hepsi yan yana görülünce fark
//  edilir. Dosyanın var olması doğru ekranı gösterdiği anlamına gelmiyor.
//
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreText
import AppKit

// UYGULAMANIN KENDİ FONTLARI YÜKLENİYOR.
//
// NEDEN: mağaza görseli sistem fontuyla konuşursa, indiren kişi uygulamayı
// açtığında başka bir tipografiyle karşılaşıyor ve ikisi iki ayrı ürün gibi
// görünüyor. Sora başlık, Manrope gövde — uygulamanın her ekranında olduğu
// gibi.
let fontKok = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("InsaatTakip/Resources/Fonts")

func fontlariKaydet() {
    for ad in ["Sora-Bold", "Sora-SemiBold", "Manrope-Medium", "Manrope-SemiBold"] {
        let url = fontKok.appendingPathComponent("\(ad).ttf") as CFURL
        CTFontManagerRegisterFontsForURL(url, .process, nil)
    }
}

/// Kayıtlı fontu ADIYLA ister; bulunamazsa sistem fontuna düşer.
///
/// SESSİZCE DÜŞMÜYOR: font bulunamadığında uyarı basılıyor. Yoksa çıktı
/// "biraz farklı" görünür ve sebebi hiçbir yerde yazmaz — tam da bu
/// projenin avladığı sessiz sapma.
func uygulamaFontu(_ ad: String, _ punto: CGFloat, yedekAgirlik: NSFont.Weight) -> NSFont {
    if let f = NSFont(name: ad, size: punto) { return f }
    FileHandle.standardError.write(Data("[font] bulunamadı, sisteme düşüldü: \(ad)\n".utf8))
    return NSFont.systemFont(ofSize: punto, weight: yedekAgirlik)
}

func gorselYukle(_ yol: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: yol) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func yaz(_ ctx: CGContext, _ yol: String) {
    guard let hedef = CGImageDestinationCreateWithURL(URL(fileURLWithPath: yol) as CFURL,
                                                      UTType.png.identifier as CFString, 1, nil),
          let img = ctx.makeImage() else { fatalError("PNG yazılamadı: \(yol)") }
    CGImageDestinationAddImage(hedef, img, nil)
    guard CGImageDestinationFinalize(hedef) else { fatalError("PNG kapatılamadı: \(yol)") }
}

func baglam(_ w: Int, _ h: Int) -> CGContext {
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fatalError("bağlam kurulamadı") }
    return ctx
}

/// Metni verilen genişlikte, satır sararak çizer; kullanılan yüksekliği döner.
@discardableResult
func metin(_ ctx: CGContext, _ s: String, x: CGFloat, ustY: CGFloat, genislik: CGFloat,
           punto: CGFloat, agirlik: NSFont.Weight, renk: CGColor, satirAraligi: CGFloat = 1.18,
           fontAdi: String? = nil, ortala: Bool = false) -> CGFloat {
    let font = fontAdi.map { uygulamaFontu($0, punto, yedekAgirlik: agirlik) }
               ?? NSFont.systemFont(ofSize: punto, weight: agirlik)
    let para = NSMutableParagraphStyle()
    para.lineHeightMultiple = satirAraligi
    para.alignment = ortala ? .center : .natural
    let attr: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: renk) ?? .white,
        .paragraphStyle: para,
    ]
    let ns = NSAttributedString(string: s, attributes: attr)
    let fs = CTFramesetterCreateWithAttributedString(ns)
    let sinir = CTFramesetterSuggestFrameSizeWithConstraints(
        fs, CFRange(location: 0, length: 0), nil,
        CGSize(width: genislik, height: .greatestFiniteMagnitude), nil)
    let kutu = CGRect(x: x, y: ustY - sinir.height, width: genislik, height: sinir.height)
    let yol = CGPath(rect: kutu, transform: nil)
    let frame = CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), yol, nil)
    CTFrameDraw(frame, ctx)
    return sinir.height
}

let argv = CommandLine.arguments
guard argv.count >= 4 else { fatalError("kullanım: kontak|header|arama …") }
let komut = argv[1]

let bakir   = CGColor(red: 0.69, green: 0.40, blue: 0.24, alpha: 1)
let ink     = CGColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1)
let inkAlt  = CGColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
let beyaz   = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
let solukB  = CGColor(red: 1, green: 1, blue: 1, alpha: 0.62)

switch komut {

// ─────────────────────────── KONTAK SAYFASI ───────────────────────────
case "kontak":
    let dizin = argv[2], cikti = argv[3]
    let dosyalar = (try! FileManager.default.contentsOfDirectory(atPath: dizin))
        .filter { $0.hasSuffix(".png") }.sorted()
    let kolon = 7
    let satir = Int(ceil(Double(dosyalar.count) / Double(kolon)))
    let kucukW = 300, etiketH = 34
    let kucukH = 300 * 2622 / 1206
    let bosluk = 14
    let W = kolon * (kucukW + bosluk) + bosluk
    let H = satir * (kucukH + etiketH + bosluk) + bosluk

    let ctx = baglam(W, H)
    ctx.setFillColor(inkAlt); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    for (i, dosya) in dosyalar.enumerated() {
        guard let img = gorselYukle("\(dizin)/\(dosya)") else { continue }
        let k = i % kolon, s = i / kolon
        let x = bosluk + k * (kucukW + bosluk)
        let yUst = H - (bosluk + s * (kucukH + etiketH + bosluk))
        ctx.draw(img, in: CGRect(x: CGFloat(x), y: CGFloat(yUst - kucukH - etiketH),
                                 width: CGFloat(kucukW), height: CGFloat(kucukH)))
        metin(ctx, dosya.replacingOccurrences(of: ".png", with: ""),
              x: CGFloat(x), ustY: CGFloat(yUst - kucukH - etiketH) - 6,
              genislik: CGFloat(kucukW), punto: 17, agirlik: .medium, renk: solukB)
    }
    yaz(ctx, cikti)
    print("kontak sayfası: \(cikti)  (\(dosyalar.count) görsel, \(W)x\(H))")

// ──────────────────── HEADER (3840x1646) / ARAMA (3840x2560) ────────────────────
case "header", "arama":
    let ekranYolu = argv[2], cikti = argv[3]
    let baslik = argv.count > 4 ? argv[4] : "İnşaat Takip"
    let altSatir = argv.count > 5 ? argv[5] : ""
    let W = 3840
    let H = komut == "header" ? 1646 : 2560

    let ctx = baglam(W, H)

    // Zemin: koyu, hafif eğimli — uygulamanın karşılama ekranıyla aynı dil.
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [ink, inkAlt] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(H)),
                               end: CGPoint(x: CGFloat(W), y: 0), options: [])
    }

    // METİN SOLDA, TELEFON SAĞDA.
    //
    // ARAMA KARTI ORTADAN KIRPILIYOR (Apple 3:2 kartı küçük gösteriyor), bu
    // yüzden metin blokları kenara DEĞİL, güvenli alana yerleştirildi.
    let kenar = CGFloat(W) * 0.065
    let metinGenislik = CGFloat(W) * 0.42

    let baslikPunto: CGFloat = komut == "header" ? 150 : 190
    let altPunto: CGFloat = komut == "header" ? 62 : 78

    var imlec = CGFloat(H) * (komut == "header" ? 0.68 : 0.62)
    let bH = metin(ctx, baslik, x: kenar, ustY: imlec, genislik: metinGenislik,
                   punto: baslikPunto, agirlik: .bold, renk: beyaz, satirAraligi: 1.05)
    imlec -= bH + (komut == "header" ? 44 : 56)
    if !altSatir.isEmpty {
        metin(ctx, altSatir, x: kenar, ustY: imlec, genislik: metinGenislik,
              punto: altPunto, agirlik: .regular, renk: solukB, satirAraligi: 1.3)
    }

    // Telefon çerçevesi + ekran görüntüsü
    if let ekran = gorselYukle(ekranYolu) {
        let oran = CGFloat(ekran.height) / CGFloat(ekran.width)
        // TELEFON YALNIZCA ALTTAN TAŞIYOR, ÜSTTEN ASLA.
        //
        // İlk denemede üstten de taşıyordu ve ekranın başlığı ("Projelerim")
        // yarıda kesiliyordu: alttan taşmak tasarım, üstten kesilmek kaza
        // gibi görünüyor. Üst kenar sabit bir boşlukla yerleşiyor, boy
        // aşağı doğru serbest.
        let hedefH = CGFloat(H) * (komut == "header" ? 1.30 : 0.92)
        let hedefW = hedefH / oran
        let x = CGFloat(W) - kenar - hedefW
        let ustBosluk = CGFloat(H) * (komut == "header" ? 0.07 : 0.05)
        let y = CGFloat(H) - ustBosluk - hedefH
        let kutu = CGRect(x: x, y: y, width: hedefW, height: hedefH)

        // Bakır halka: ekran görüntüsünün koyu zeminde kaybolmaması için.
        ctx.saveGState()
        let cerceve = CGPath(roundedRect: kutu.insetBy(dx: -18, dy: -18),
                             cornerWidth: 86, cornerHeight: 86, transform: nil)
        ctx.addPath(cerceve); ctx.setFillColor(bakir); ctx.fillPath()

        ctx.addPath(CGPath(roundedRect: kutu, cornerWidth: 72, cornerHeight: 72, transform: nil))
        ctx.clip()
        ctx.draw(ekran, in: kutu)
        ctx.restoreGState()
    }

    yaz(ctx, cikti)
    print("\(komut): \(cikti)  (\(W)x\(H))")

// ─────────────────────── MAĞAZA EKRANI (1320x2868) ───────────────────────
//
// TASARIM KARARI, ÖLÇÜLEREK ALINDI: cihaz BÜYÜK ve altı kadraj dışına
// taşıyor. Küçük cihazlı şablonlar denendi ve App Store'un küçük gösterdiği
// boyutta rakamların tamamı okunmaz hâle geliyordu — oysa bu uygulamanın
// sattığı şey tam olarak rakamlar. Alttan taşma bedava: oradaki içerik
// tekrar eden kartlar, kaybı yok; üstteki üçte iki neredeyse tam boyda.
case "ekran":
    fontlariKaydet()
    let ekranYolu = argv[2], cikti = argv[3]
    let yazi = argv.count > 4 ? argv[4] : ""
    let W = 1320, H = 2868

    let ctx = baglam(W, H)
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [ink, inkAlt] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(H)),
                               end: CGPoint(x: CGFloat(W), y: 0), options: [])
    }

    // Bant yazısı — tek cümle, en çok iki satır, ortalı.
    let yanBosluk: CGFloat = 108
    metin(ctx, yazi, x: yanBosluk, ustY: CGFloat(H) - 196,
          genislik: CGFloat(W) - yanBosluk * 2,
          punto: 92, agirlik: .bold, renk: beyaz, satirAraligi: 1.14,
          fontAdi: "Sora-Bold", ortala: true)

    // Cihaz
    if let ekran = gorselYukle(ekranYolu) {
        let oran = CGFloat(ekran.height) / CGFloat(ekran.width)
        let cihazW: CGFloat = 1116
        let cihazH = cihazW * oran
        let x = (CGFloat(W) - cihazW) / 2
        let ustY: CGFloat = 640                      // yazının altı
        let y = CGFloat(H) - ustY - cihazH           // alttan taşar

        ctx.saveGState()
        // Bakır halka: koyu zeminde ekranın kenarı kaybolmasın.
        ctx.addPath(CGPath(roundedRect: CGRect(x: x - 7, y: y - 7,
                                               width: cihazW + 14, height: cihazH + 14),
                           cornerWidth: 78, cornerHeight: 78, transform: nil))
        ctx.setFillColor(bakir); ctx.fillPath()

        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: cihazW, height: cihazH),
                           cornerWidth: 72, cornerHeight: 72, transform: nil))
        ctx.clip()
        ctx.draw(ekran, in: CGRect(x: x, y: y, width: cihazW, height: cihazH))
        ctx.restoreGState()
    }

    yaz(ctx, cikti)
    print("ekran: \(cikti)")

default:
    fatalError("bilinmeyen komut: \(komut)")
}
