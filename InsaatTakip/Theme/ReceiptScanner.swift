import Foundation
import UIKit
import Vision

// MARK: - Fiş Okuyucu (cihaz üstü OCR)
// Kamerayla çekilen fiş/irsaliye görselinden toplam tutar, tarih ve firma adını
// ayıklar. Tamamen cihazda çalışır: internet gerekmez, veri dışarı çıkmaz,
// ücret yoktur — şantiyede kapsama alanı dışında da işe yarar.
//
// SINIR: Vision'ın "accurate" modu Türkçeyi her iOS sürümünde desteklemiyor.
// Rakamlar dilden bağımsız okunduğu için tutar/tarih güvenilir çıkar; Türkçe
// kelimeler (TOPLAM, TUTAR…) yanlış okunabilir, bu yüzden anahtar kelime
// eşleşmesi harf yaklaşıklığına toleranslı tutulmuştur.
// Okunan değerler ASLA doğrudan kaydedilmez; kullanıcıya öneri olarak sunulur.

enum ReceiptScanner {

    /// Fişten okunabilen alanlar. Hepsi opsiyoneldir — okunamayan alan nil kalır.
    struct Reading: Equatable {
        var total: Kurus?           // Genel toplam / ödenecek tutar
        var dateText: String?       // "18 Şub 2026" biçimine çevrilmiş tarih
        var supplier: String?       // Firma / satıcı adı (üst satırlardan)
        var lineCount: Int = 0      // Okunan satır sayısı — hiç yazı yoksa 0

        /// Forma önerilecek bir şey var mı?
        var hasAnything: Bool { total != nil || dateText != nil || supplier != nil }
    }

    // MARK: Tarama

    /// Senkron çalışır; çağıran taraf arka plan görevinden çağırmalıdır.
    static func scan(_ image: UIImage) -> Reading {
        guard let cgImage = image.cgImage else { return Reading() }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Fişte sözlükte olmayan kodlar/rakamlar var; dil düzeltmesi zarar veriyor.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = preferredLanguages(for: request)

        let handler = VNImageRequestHandler(cgImage: cgImage,
                                            orientation: cgOrientation(image.imageOrientation),
                                            options: [:])
        try? handler.perform([request])

        let observations = request.results ?? []
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        return parse(lines: lines)
    }

    /// Türkçe destekleniyorsa onu kullan; yoksa İngilizceye düş (rakamlar aynı okunur).
    private static func preferredLanguages(for request: VNRecognizeTextRequest) -> [String] {
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        return supported.contains("tr-TR") ? ["tr-TR", "en-US"] : ["en-US"]
    }

    // MARK: Ayrıştırma

    static func parse(lines: [String]) -> Reading {
        var reading = Reading()
        reading.lineCount = lines.count
        guard !lines.isEmpty else { return reading }

        // Sınır dönüşümü TEK yerde: tarayıcı içeride ₺ cinsinden çalışır
            // (eşikler ve karşılaştırmalar öyle yazılı), dışarıya kuruş verir.
        reading.total = findTotal(in: lines).map { Kurus.kurus(Int64(($0 * 100).rounded())) }
        reading.dateText = findDate(in: lines)
        reading.supplier = findSupplier(in: lines)
        return reading
    }

    /// Toplam tutar: önce "genel toplam", sonra "toplam", sonra "tutar" satırları;
    /// hiçbiri yoksa fişteki en büyük parasal sayı (fişlerde toplam genelde en büyüktür).
    private static func findTotal(in lines: [String]) -> Double? {
        // Öncelik sırası — üstteki bulunursa alttakilere bakılmaz.
        let keywordGroups = [
            ["genel toplam", "odenecek", "ödenecek", "toplam tutar"],
            ["toplam"],
            ["tutar", "yekun", "yekûn"],
        ]

        for group in keywordGroups {
            var candidates: [Double] = []
            for (index, line) in lines.enumerated() {
                let normalized = normalize(line)
                guard group.contains(where: { normalized.contains($0) }) else { continue }
                // KDV satırlarını toplam sanma
                if normalized.contains("kdv") && !normalized.contains("dahil") { continue }

                // Tutar aynı satırda olmayabilir; bir sonraki satıra da bak.
                var pool = amounts(in: line)
                if pool.isEmpty, index + 1 < lines.count {
                    pool = amounts(in: lines[index + 1])
                }
                candidates.append(contentsOf: pool)
            }
            if let best = candidates.max() { return best }
        }

        // Anahtar kelime yakalanamadıysa: kuruşlu (ondalıklı) en büyük sayı
        let decimals = lines.flatMap { amounts(in: $0, requireDecimals: true) }
        if let best = decimals.max() { return best }

        return nil
    }

    /// "12.03.2026" / "12/03/26" → "12 Mar 2026"
    private static func findDate(in lines: [String]) -> String? {
        let pattern = #"(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let dayRange = Range(match.range(at: 1), in: line),
                  let monthRange = Range(match.range(at: 2), in: line),
                  let yearRange = Range(match.range(at: 3), in: line),
                  let day = Int(line[dayRange]),
                  let month = Int(line[monthRange]),
                  var year = Int(line[yearRange]) else { continue }

            guard (1...31).contains(day), (1...12).contains(month) else { continue }
            if year < 100 { year += 2000 }
            guard (2000...2100).contains(year) else { continue }

            return "\(day < 10 ? "0" : "")\(day) \(monthNames[month - 1]) \(year)"
        }
        return nil
    }

    /// Firma adı: üst satırlarda, rakam içermeyen, yeterince uzun ilk satır.
    private static func findSupplier(in lines: [String]) -> String? {
        for line in lines.prefix(6) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 4, trimmed.count <= 40 else { continue }
            guard !trimmed.contains(where: \.isNumber) else { continue }
            let letters = trimmed.filter { $0.isLetter }.count
            guard letters >= 4 else { continue }
            // "FİŞ", "FATURA" gibi başlıkları firma sanma
            let normalized = normalize(trimmed)
            if ["fis", "fiş", "fatura", "irsaliye", "adisyon"].contains(where: { normalized.contains($0) }) { continue }
            return trimmed
        }
        return nil
    }

    // MARK: Yardımcılar

    /// Ay kısaltmaları. ProjectViewModel @MainActor izole olduğu için buradan
    /// kopyalanır — tarayıcı arka plan görevinden çağrılıyor.
    private static let monthNames = ["Oca", "Şub", "Mar", "Nis", "May", "Haz",
                                     "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"]

    /// UIImage yönünü Vision'ın beklediği CGImagePropertyOrientation'a çevirir.
    /// Kameradan gelen kare döndürülmüş olabilir; bu yapılmazsa yazı yan okunur.
    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }

    /// Türkçe karakterleri sadeleştirip küçük harfe indirir (anahtar kelime eşleşmesi için).
    private static func normalize(_ text: String) -> String {
        text.lowercased(with: Fmt.locale)
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")
    }

    /// Bir satırdaki parasal sayı adaylarını çıkarır.
    /// - Parameter requireDecimals: yalnızca kuruşlu (",99" / ".99") sayıları al.
    static func amounts(in line: String, requireDecimals: Bool = false) -> [Double] {
        let pattern = requireDecimals
            ? #"\d{1,3}(?:[.\s]\d{3})*[,.]\d{2}(?!\d)"#
            : #"\d{1,3}(?:[.\s]\d{3})*(?:[,.]\d{1,2})?(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let r = Range(match.range, in: line) else { return nil }
            return money(from: String(line[r]))
        }
        // Tarih parçaları (12, 03, 2026) tutar sanılmasın diye çok küçükleri ele
        .filter { $0 >= 1 }
    }

    /// "1.234,56" · "1,234.56" · "1234,5" → Double.
    /// Son ayırıcı ondalık kabul edilir; öncekiler binlik ayracıdır.
    static func money(from raw: String) -> Double? {
        let cleaned = raw.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !cleaned.isEmpty else { return nil }

        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")

        var decimalSeparator: Character?
        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            decimalSeparator = comma > dot ? "," : "."
        case (let comma?, nil):
            // Tek virgül: ondalık mı binlik mi? Sağında 3 hane varsa binliktir (1,234)
            decimalSeparator = cleaned.distance(from: comma, to: cleaned.endIndex) - 1 == 3 ? nil : ","
        case (nil, let dot?):
            decimalSeparator = cleaned.distance(from: dot, to: cleaned.endIndex) - 1 == 3 ? nil : "."
        case (nil, nil):
            decimalSeparator = nil
        }

        var integerPart = cleaned
        var fractionPart = ""
        if let separator = decimalSeparator,
           let index = cleaned.lastIndex(of: separator) {
            integerPart = String(cleaned[cleaned.startIndex..<index])
            fractionPart = String(cleaned[cleaned.index(after: index)...])
        }

        let digitsOnly = integerPart.filter(\.isNumber)
        guard !digitsOnly.isEmpty || !fractionPart.isEmpty else { return nil }

        let normalized = fractionPart.isEmpty ? digitsOnly : "\(digitsOnly).\(fractionPart)"
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
