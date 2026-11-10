import Foundation

public enum CurrencyCode: String, CaseIterable, Identifiable {
    case amd = "AMD", usd = "USD", eur = "EUR", rub = "RUB"
    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .amd: "֏"
        case .usd: "$"
        case .eur: "€"
        case .rub: "₽"
        }
    }

    public var title: String {
        switch self {
        case .amd: L10n.string("currency.amd")
        case .usd: L10n.string("currency.usd")
        case .eur: L10n.string("currency.eur")
        case .rub: L10n.string("currency.rub")
        }
    }
}

public enum RateOrigin: String, Codable {
    case fallback, centralBank, manual
}

public struct ExchangeRates: Codable, Equatable {
    public var usd: Double
    public var eur: Double
    public var rub: Double
    public var asOf: String
    public var origin: RateOrigin

    /// Official CBA rates published November 10, 2026 (AMD for 1 unit).
    /// They are a labeled fallback, NOT today's rates.
    public static let initial = ExchangeRates(
        usd: 360.43, eur: 404.55, rub: 4.3579,
        asOf: "2026-11-10", origin: .fallback
    )

    public func amdPerUnit(_ code: CurrencyCode) -> Double {
        switch code {
        case .amd: 1
        case .usd: usd
        case .eur: eur
        case .rub: rub
        }
    }

    public func convert(_ amount: Double, from: CurrencyCode, to: CurrencyCode) -> Double {
        amount * amdPerUnit(from) / amdPerUnit(to)
    }
}

/// Parses the Central Bank of Armenia official SOAP API response.
final class CBAExchangeRateParser: NSObject, XMLParserDelegate {
    private var currentText = ""
    private var iso = ""
    private var amount = 1.0
    private var rate = 0.0
    private var inRate = false
    private var published = ""
    private var values: [String: Double] = [:]

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        if elementName == "ExchangeRate" {
            inRate = true
            iso = ""
            amount = 1
            rate = 0
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if inRate {
            switch elementName {
            case "ISO": iso = value
            case "Amount": amount = Double(value) ?? 1
            case "Rate": rate = Double(value) ?? 0
            case "ExchangeRate":
                if amount > 0 && rate > 0 { values[iso] = rate / amount }
                inRate = false
            default: break
            }
        } else if elementName == "CurrentDate" {
            published = String(value.prefix(10))
        }
        currentText = ""
    }

    func parse(data: Data) throws -> ExchangeRates {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(),
              let usd = values["USD"], let eur = values["EUR"], let rub = values["RUB"],
              usd > 0, eur > 0, rub > 0,
              published.count == 10
        else { throw ExchangeRateError.invalidResponse }
        return ExchangeRates(usd: usd, eur: eur, rub: rub,
                             asOf: published, origin: .centralBank)
    }
}

enum ExchangeRateError: LocalizedError {
    case invalidResponse
    var errorDescription: String? {
        L10n.string("rates.invalid")
    }
}

@MainActor
public final class ExchangeRatesStore: ObservableObject {
    @Published public private(set) var current: ExchangeRates
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let storageKey = "armenianCarTax.exchangeRates.v1"
    private let endpoint = URL(string: "https://api.cba.am/exchangerates.asmx")!
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let rates = try? JSONDecoder().decode(ExchangeRates.self, from: data) {
            current = rates
        } else {
            current = .initial
        }
    }

    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("\"http://www.cba.am/ExchangeRatesLatest\"", forHTTPHeaderField: "SOAPAction")
            request.httpBody = Data("""
            <?xml version="1.0" encoding="utf-8"?>
            <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
              <soap:Body>
                <ExchangeRatesLatest xmlns="http://www.cba.am/" />
              </soap:Body>
            </soap:Envelope>
            """.utf8)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ExchangeRateError.invalidResponse
            }
            let newValue = try CBAExchangeRateParser().parse(data: data)
            save(newValue)
            errorMessage = nil
        } catch {
            errorMessage = L10n.format("rates.error", error.localizedDescription)
        }
    }

    public func setManual(usd: Double, eur: Double, rub: Double) {
        guard usd > 0, eur > 0, rub > 0 else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        save(ExchangeRates(usd: usd, eur: eur, rub: rub,
                           asOf: formatter.string(from: .now), origin: .manual))
        errorMessage = nil
    }

    private func save(_ value: ExchangeRates) {
        current = value
        if let encoded = try? JSONEncoder().encode(value) {
            defaults.set(encoded, forKey: storageKey)
        }
    }
}
