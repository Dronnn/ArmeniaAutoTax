import StoreKitTest
import XCTest
@testable import ArmeniaAutoTax

@MainActor
final class DonationTests: XCTestCase {
    func testTierCatalogIsStable() {
        XCTAssertEqual(DonationTier.all.count, 6)
        XCTAssertEqual(DonationStore.productIDs.count, 6)
        for tier in DonationTier.all {
            XCTAssertTrue(tier.id.hasPrefix("com.mrmaier.armeniaautotax.tip."))
            XCTAssertFalse(tier.fallbackPrice.isEmpty)
            for language in AppLanguage.allCases {
                XCTAssertFalse(L10n.string(tier.nameKey, language: language).isEmpty)
            }
        }
    }

    func testFallbackPricesAndNamesBeforeLoading() {
        let store = DonationStore()
        XCTAssertEqual(store.displayPrice(for: DonationTier.all[0]), "$2.99")
        XCTAssertEqual(store.displayName(for: DonationTier.all[0], language: .russian), "Небольшой")
        XCTAssertEqual(store.displayName(for: DonationTier.all[0], language: .armenian), "Փոքր")
    }

    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(
            Bundle(for: DonationTests.self).url(forResource: "ArmeniaAutoTax", withExtension: "storekit")
        )
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.storefront = "USA"
        session.locale = Locale(identifier: "en_US")
        return session
    }

    private func loadProductsWithRetry(_ store: DonationStore) async throws {
        await store.loadProducts(force: true)
        if store.products.isEmpty {
            try await Task.sleep(nanoseconds: 300_000_000)
            await store.loadProducts(force: true)
        }
    }

    func testCatalogLoadsAllProducts() async throws {
        let session = try makeSession()
        session.clearTransactions()
        defer { session.clearTransactions() }

        let store = DonationStore()
        try await loadProductsWithRetry(store)
        XCTAssertEqual(store.products.count, 6)
        XCTAssertEqual(store.products.first?.displayPrice, "$2.99")
        XCTAssertEqual(Set(store.products.map(\.id)), Set(DonationStore.productIDs))
        XCTAssertNil(store.errorMessage)
    }

    func testPurchaseCompletesAsThankYou() async throws {
        let session = try makeSession()
        session.clearTransactions()
        defer { session.clearTransactions() }

        let store = DonationStore()
        try await loadProductsWithRetry(store)
        let product = try XCTUnwrap(store.product(for: DonationTier.all[1]))
        await store.purchase(product)
        XCTAssertEqual(store.feedback, .thankYou)
        XCTAssertNil(store.purchasingProductID)
    }

    func testUnknownProductIsRejected() async throws {
        let store = DonationStore()
        await store.loadProducts(force: true)
        XCTAssertNil(store.product(for: DonationTier(
            id: "com.mrmaier.armeniaautotax.tip.unknown",
            nameKey: "donations.tier.small",
            fallbackPrice: "$0.00"
        )))
    }
}
