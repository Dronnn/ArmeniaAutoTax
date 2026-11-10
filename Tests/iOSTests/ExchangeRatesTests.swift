import XCTest
@testable import ArmeniaAutoTax

@MainActor
final class ExchangeRatesTests: XCTestCase {
    private func soap(
        currentDate: String = "2026-11-10T00:00:00+04:00",
        usd: (amount: String, rate: String) = ("1", "360.43"),
        eur: (amount: String, rate: String) = ("1", "404.55"),
        rub: (amount: String, rate: String) = ("1", "4.3579")
    ) -> Data {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <ExchangeRatesLatestResponse xmlns="http://www.cba.am/">
              <ExchangeRatesLatestResult>
                <CurrentDate>\(currentDate)</CurrentDate>
                <Rates>
                  <ExchangeRate><ISO>USD</ISO><Amount>\(usd.amount)</Amount><Rate>\(usd.rate)</Rate></ExchangeRate>
                  <ExchangeRate><ISO>EUR</ISO><Amount>\(eur.amount)</Amount><Rate>\(eur.rate)</Rate></ExchangeRate>
                  <ExchangeRate><ISO>RUB</ISO><Amount>\(rub.amount)</Amount><Rate>\(rub.rate)</Rate></ExchangeRate>
                </Rates>
              </ExchangeRatesLatestResult>
            </ExchangeRatesLatestResponse>
          </soap:Body>
        </soap:Envelope>
        """
        return Data(xml.utf8)
    }

    func testParsesOfficialCBAResponse() throws {
        let rates = try CBAExchangeRateParser().parse(data: soap())
        XCTAssertEqual(rates.usd, 360.43, accuracy: 0.0001)
        XCTAssertEqual(rates.eur, 404.55, accuracy: 0.0001)
        XCTAssertEqual(rates.rub, 4.3579, accuracy: 0.0001)
        XCTAssertEqual(rates.asOf, "2026-11-10")
        XCTAssertEqual(rates.origin, .centralBank)
    }

    func testNormalizesNonUnitAmount() throws {
        let rates = try CBAExchangeRateParser().parse(data: soap(rub: ("100", "435.79")))
        XCTAssertEqual(rates.rub, 4.3579, accuracy: 0.0001)
    }

    func testRejectsMissingCurrency() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ExchangeRatesLatestResult>
          <CurrentDate>2026-11-10T00:00:00+04:00</CurrentDate>
          <Rates>
            <ExchangeRate><ISO>USD</ISO><Amount>1</Amount><Rate>360.43</Rate></ExchangeRate>
            <ExchangeRate><ISO>EUR</ISO><Amount>1</Amount><Rate>404.55</Rate></ExchangeRate>
          </Rates>
        </ExchangeRatesLatestResult>
        """
        XCTAssertThrowsError(try CBAExchangeRateParser().parse(data: Data(xml.utf8)))
    }

    func testRejectsMissingDate() {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <ExchangeRatesLatestResult>
          <Rates>
            <ExchangeRate><ISO>USD</ISO><Amount>1</Amount><Rate>360.43</Rate></ExchangeRate>
            <ExchangeRate><ISO>EUR</ISO><Amount>1</Amount><Rate>404.55</Rate></ExchangeRate>
            <ExchangeRate><ISO>RUB</ISO><Amount>1</Amount><Rate>4.3579</Rate></ExchangeRate>
          </Rates>
        </ExchangeRatesLatestResult>
        """
        XCTAssertThrowsError(try CBAExchangeRateParser().parse(data: Data(xml.utf8)))
    }

    func testRejectsMalformedXML() {
        XCTAssertThrowsError(try CBAExchangeRateParser().parse(data: Data("<not-xml".utf8)))
    }

    func testInitialFallbackValuesAndOrigin() {
        let rates = ExchangeRates.initial
        XCTAssertEqual(rates.usd, 360.43)
        XCTAssertEqual(rates.eur, 404.55)
        XCTAssertEqual(rates.rub, 4.3579)
        XCTAssertEqual(rates.asOf, "2026-11-10")
        XCTAssertEqual(rates.origin, .fallback)
        XCTAssertEqual(rates.amdPerUnit(.amd), 1)
        XCTAssertEqual(rates.amdPerUnit(.usd), 360.43)
    }

    func testCurrencyConversionRoundTrip() {
        let rates = ExchangeRates.initial
        for currency in [CurrencyCode.usd, .eur, .rub] {
            let converted = rates.convert(82_950, from: .amd, to: currency)
            XCTAssertEqual(rates.convert(converted, from: currency, to: .amd), 82_950, accuracy: 0.00001)
        }
    }

    func testManualRatesArePersistedAndMarkedManual() throws {
        let suite = "ExchangeRatesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ExchangeRatesStore(defaults: defaults)
        store.setManual(usd: 400, eur: 430, rub: 5)
        XCTAssertEqual(store.current.origin, .manual)
        XCTAssertEqual(store.current.usd, 400)
        XCTAssertEqual(store.current.eur, 430)
        XCTAssertEqual(store.current.rub, 5)
        XCTAssertNotNil(store.current.asOf)

        let restored = ExchangeRatesStore(defaults: defaults)
        XCTAssertEqual(restored.current, store.current)
    }

    func testInvalidManualRatesAreIgnored() throws {
        let suite = "ExchangeRatesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ExchangeRatesStore(defaults: defaults)
        let before = store.current
        store.setManual(usd: 0, eur: -1, rub: -5)
        XCTAssertEqual(store.current, before)
    }
}
