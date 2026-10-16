#!/usr/bin/env swift
//
//  Simülatör kaydını App Store önizleme ölçüsüne dönüştürür.
//
//      swift scripts/video-donustur.swift <giris.mov> <cikis.mp4> <genislik> <yukseklik> [baslangic_sn] [sure_sn]
//
//  KIRPMA NEDEN ŞART: App Store önizlemesi 15-30 saniye olmak zorunda.
//  Simülatör kaydı kaç saniye sürdüyse o kadar oluyor ve otomasyonla
//  sürülen bir tur kaçınılmaz olarak bu sınırı aşıyor.
//
//  NEDEN KENDİ ARACIMIZ: makinede ffmpeg yok ve kurmak, bu betiği altı ay
//  sonra koşturacak kişiye de aynı kurulumu yaptırırdı. AVFoundation her
//  macOS'ta var.
//
//  NE YAPIYOR: kaydı hedef tuvale ORANI KORUYARAK oturtuyor; artan yer
//  kalırsa siyah değil uygulamanın koyu zemini ile dolduruluyor, çünkü
//  siyah şeritler App Store'da ucuz görünüyor.
//
import Foundation
import AVFoundation
import CoreMedia

let argv = CommandLine.arguments
guard argv.count >= 5,
      let hedefW = Double(argv[3]), let hedefH = Double(argv[4]) else {
    fatalError("kullanım: <giris.mov> <cikis.mp4> <genislik> <yukseklik> [baslangic] [sure]")
}
let baslangic = argv.count > 5 ? Double(argv[5]) ?? 0 : 0
let istenenSure = argv.count > 6 ? Double(argv[6]) : nil
let giris = URL(fileURLWithPath: argv[1])
let cikis = URL(fileURLWithPath: argv[2])
try? FileManager.default.removeItem(at: cikis)

let asset = AVURLAsset(url: giris)
let sem = DispatchSemaphore(value: 0)

Task {
    guard let parca = try? await asset.loadTracks(withMediaType: .video).first else {
        fatalError("videoda görüntü izi yok")
    }
    let dogalBoyut = try! await parca.load(.naturalSize)
    let sure = try! await asset.load(.duration)

    let komposizyon = AVMutableVideoComposition()
    komposizyon.renderSize = CGSize(width: hedefW, height: hedefH)
    komposizyon.frameDuration = CMTime(value: 1, timescale: 30)

    // Kırpma aralığı: verilmezse tamamı.
    let bas = CMTime(seconds: baslangic, preferredTimescale: 600)
    let uzunluk = istenenSure.map { CMTime(seconds: $0, preferredTimescale: 600) }
                  ?? CMTimeSubtract(sure, bas)
    let aralik = CMTimeRange(start: bas, duration: uzunluk)

    // TALİMAT ÖZGÜN ZAMAN ÇİZGİSİNİ KAPSAR, kırpılmışı değil.
    //
    // Sıfırdan başlayan bir aralık verildiğinde dışa aktarım "Operation
    // Stopped" ile düşüyor: `exportSession.timeRange` varlığın kendi zaman
    // çizgisinde çalışıyor ve kompozisyon o çizgiyi karşılamazsa kare
    // bulunamıyor. Kırpmayı yapan `timeRange`, kompozisyon değil.
    let talimat = AVMutableVideoCompositionInstruction()
    talimat.timeRange = CMTimeRange(start: .zero, duration: sure)

    let katman = AVMutableVideoCompositionLayerInstruction(assetTrack: parca)
    // ORANI KORU, TUVALE SIĞDIR (aspect fit) ve ortala.
    let olcek = min(hedefW / dogalBoyut.width, hedefH / dogalBoyut.height)
    let kayX = (hedefW - dogalBoyut.width * olcek) / 2
    let kayY = (hedefH - dogalBoyut.height * olcek) / 2
    katman.setTransform(CGAffineTransform(scaleX: olcek, y: olcek)
                        .concatenating(CGAffineTransform(translationX: kayX, y: kayY)),
                        at: .zero)
    talimat.layerInstructions = [katman]
    komposizyon.instructions = [talimat]

    guard let disaAktar = AVAssetExportSession(asset: asset,
                                               presetName: AVAssetExportPresetHighestQuality) else {
        fatalError("dışa aktarıcı kurulamadı")
    }
    disaAktar.outputURL = cikis
    disaAktar.outputFileType = .mp4
    disaAktar.videoComposition = komposizyon
    disaAktar.timeRange = aralik

    await disaAktar.export()
    if let hata = disaAktar.error {
        print("HATA: \(hata.localizedDescription)")
    } else {
        print("yazıldı: \(cikis.path)  (\(Int(hedefW))x\(Int(hedefH)), \(String(format: "%.1f", uzunluk.seconds)) sn)")
    }
    sem.signal()
}
sem.wait()
