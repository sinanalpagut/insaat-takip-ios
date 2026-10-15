#!/usr/bin/env swift
//
//  Uygulama simgesini ÜRETİR — açık, koyu ve tonlu üç varyant.
//
//      swift scripts/make-icon.swift
//
//  NEDEN KAYNAK KOD, NEDEN TASARIM DOSYASI DEĞİL: simge üç varyantta ve ileride
//  başka boyutlarda yeniden üretilmesi gereken bir şey. Elle çizilmiş bir PNG,
//  altı ay sonra "saçağın kalınlığı neydi" sorusunu cevaplayamaz; burada her
//  ölçü sayı olarak duruyor ve varyantlar aynı geometriden türüyor — yani koyu
//  varyant açık olandan kayamaz.
//
//  ŞEKİL KARARI (15 Eki 2026): saçaklı apartman bloğu, pencerelerin bir kısmı
//  DOLU. Üçgen çatı denendi ve ELENDİ: "ev" çağrıştırıyor, oysa ürünün konusu
//  çok daireli bloklar — altı pencereli bir müstakil ev kendi içinde çelişir.
//  Saçak apartmanın görsel kısayolu.
//
//  Dolu pencere = satılan daire, boş pencere = satılmamış. Uygulamanın ana
//  ekranındaki ayrımın aynısı; simge böylece "inşaat" değil "inşaat TAKİBİ"
//  diyor.
//
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024

/// Varyantın renkleri. Geometri ortak, yalnızca renk değişiyor.
struct Tema {
    let ustRenk: CGColor
    let altRenk: CGColor
    let cizgi: CGColor
    let dosya: String
}

let bakirUst = CGColor(red: 0.69, green: 0.40, blue: 0.24, alpha: 1)
let bakirAlt = CGColor(red: 0.56, green: 0.31, blue: 0.19, alpha: 1)
// Palette.ink ile aynı aile: koyu varyant uygulamanın başlık rengine oturuyor.
let inkUst = CGColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1)
let inkAlt = CGColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1)
let beyaz = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
let siyah = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

let temalar = [
    Tema(ustRenk: bakirUst, altRenk: bakirAlt, cizgi: beyaz, dosya: "AppIcon1024.png"),
    Tema(ustRenk: inkUst, altRenk: inkAlt, cizgi: beyaz, dosya: "AppIcon1024-Dark.png"),
    // TONLU VARYANT GRİ TONDA olmak zorunda: sistem kullanıcının seçtiği rengi
    // parlaklığa göre uyguluyor. Renkli bir görsel verilirse iOS onu yine gri
    // tona indiriyor ve sonuç kontrolümüzden çıkıyor.
    Tema(ustRenk: siyah, altRenk: siyah, cizgi: beyaz, dosya: "AppIcon1024-Tinted.png"),
]

func yaz(_ ctx: CGContext, _ ad: String) {
    let url = URL(fileURLWithPath: ad) as CFURL
    guard let hedef = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil),
          let img = ctx.makeImage() else { fatalError("PNG yazılamadı: \(ad)") }
    CGImageDestinationAddImage(hedef, img, nil)
    guard CGImageDestinationFinalize(hedef) else { fatalError("PNG kapatılamadı: \(ad)") }
}

for tema in temalar {
    guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { fatalError("bağlam kurulamadı") }

    // Zemin — köşe yuvarlama YOK: iOS maskeyi kendisi uyguluyor, biz
    // yuvarlarsak kenarda ikinci bir hat görünür.
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [tema.ustRenk, tema.altRenk] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
    }

    let cizgiKalinlik: CGFloat = 34
    let x: CGFloat = 296, y: CGFloat = 196, w: CGFloat = 432, h: CGFloat = 556

    // Gövde
    ctx.setStrokeColor(tema.cizgi)
    ctx.setLineWidth(cizgiKalinlik)
    ctx.setLineJoin(.round)
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                       cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.strokePath()

    // Pencereler — 2x3. Üçü DOLU (satılan), üçü boş.
    let kolon = 2, satir = 3
    let dolu: Set<[Int]> = [[0, 0], [1, 0], [0, 1]]
    let padX = w * 0.17, padY = h * 0.13
    let gx = (w - 2 * padX) / CGFloat(kolon), gy = (h - 2 * padY) / CGFloat(satir)
    let pw = gx * 0.62, ph = gy * 0.56
    for r in 0..<satir {
        for k in 0..<kolon {
            let cx = x + padX + gx * CGFloat(k) + gx / 2
            let cy = y + padY + gy * CGFloat(r) + gy / 2
            let kare = CGRect(x: cx - pw / 2, y: cy - ph / 2, width: pw, height: ph)
            ctx.addPath(CGPath(roundedRect: kare, cornerWidth: 10, cornerHeight: 10, transform: nil))
            if dolu.contains([k, r]) {
                ctx.setFillColor(tema.cizgi)
                ctx.fillPath()
            } else {
                ctx.setStrokeColor(tema.cizgi)
                ctx.setLineWidth(cizgiKalinlik * 0.62)
                ctx.strokePath()
            }
        }
    }

    // SAÇAK — gövdeden iki yana taşıyor. Taşma şart: gövdeyle aynı genişlikte
    // olsaydı sadece kalın bir çizgi olurdu, apartman silueti vermezdi.
    ctx.setFillColor(tema.cizgi)
    ctx.addPath(CGPath(roundedRect: CGRect(x: x - 60, y: y + h + 20, width: w + 120, height: 52),
                       cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.fillPath()

    yaz(ctx, tema.dosya)
    print("yazıldı: \(tema.dosya)")
}
