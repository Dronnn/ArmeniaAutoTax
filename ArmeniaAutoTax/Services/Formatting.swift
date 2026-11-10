import Foundation

/// Parses decimal input from any supported locale. Handles a decimal comma,
/// a decimal point, and grouping separators that may be pasted with the value.
enum DecimalInput {
    static func parse(_ text: String, locale: Locale = L10n.locale) -> Double? {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: "\u{202f}", with: "")
            .replacingOccurrences(of: " ", with: "")

        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        let hasDot = normalized.contains(".")
        let hasComma = normalized.contains(",")

        if hasDot && hasComma {
            if let lastDot = normalized.lastIndex(of: "."),
               let lastComma = normalized.lastIndex(of: ","),
               lastDot > lastComma {
                normalized = normalized.replacingOccurrences(of: ",", with: "")
            } else {
                normalized = normalized
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            }
        } else if hasDot || hasComma {
            let separator: Character = hasDot ? "." : ","
            let digitsAfter = normalized.split(separator: separator).last?.count ?? 0
            if String(separator) == decimalSeparator {
                if separator == "," {
                    normalized = normalized.replacingOccurrences(of: ",", with: ".")
                }
            } else if String(separator) == groupingSeparator {
                if digitsAfter == 3 {
                    normalized = normalized.replacingOccurrences(of: String(separator), with: "")
                } else {
                    normalized = normalized.replacingOccurrences(of: String(separator), with: ".")
                }
            } else if digitsAfter == 3 {
                normalized = normalized.replacingOccurrences(of: String(separator), with: "")
            } else {
                normalized = normalized.replacingOccurrences(of: String(separator), with: ".")
            }
        }

        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
