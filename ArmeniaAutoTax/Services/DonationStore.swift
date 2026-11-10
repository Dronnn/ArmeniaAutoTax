import Combine
import Foundation
import StoreKit

enum DonationFeedback: Equatable {
    case thankYou
    case pending
    case failed
}

struct DonationTier: Identifiable, Equatable, Sendable {
    let id: String
    let nameKey: String
    let fallbackPrice: String

    static let all: [DonationTier] = [
        DonationTier(id: "com.mrmaier.armeniaautotax.tip.small",
                     nameKey: "donations.tier.small", fallbackPrice: "$2.99"),
        DonationTier(id: "com.mrmaier.armeniaautotax.tip.medium",
                     nameKey: "donations.tier.medium", fallbackPrice: "$4.99"),
        DonationTier(id: "com.mrmaier.armeniaautotax.tip.large",
                     nameKey: "donations.tier.large", fallbackPrice: "$7.99"),
        DonationTier(id: "com.mrmaier.armeniaautotax.tip.generous",
                     nameKey: "donations.tier.generous", fallbackPrice: "$19.99"),
        DonationTier(id: "com.mrmaier.armeniaautotax.tip.patron",
                     nameKey: "donations.tier.patron", fallbackPrice: "$49.99"),
        DonationTier(id: "com.mrmaier.armeniaautotax.tip.extraordinary",
                     nameKey: "donations.tier.extraordinary", fallbackPrice: "$99.99")
    ]
}

@MainActor
final class DonationStore: ObservableObject {
    static let shared = DonationStore()
    static let productIDs = DonationTier.all.map(\.id)

    @Published private(set) var products: [StoreKit.Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var feedback: DonationFeedback?
    @Published private(set) var purchasingProductID: String?

    private var updatesTask: Task<Void, Never>?
    private var handledTransactionIDs: Set<UInt64> = []

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                await self?.process(result, showFeedback: true)
            }
        }
        Task { [weak self] in
            await self?.processUnfinishedTransactions()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func product(for tier: DonationTier) -> StoreKit.Product? {
        products.first { $0.id == tier.id }
    }

    func displayPrice(for tier: DonationTier) -> String {
        product(for: tier)?.displayPrice ?? tier.fallbackPrice
    }

    func displayName(for tier: DonationTier, language: AppLanguage = .selected) -> String {
        L10n.string(tier.nameKey, language: language)
    }

    func loadProducts(force: Bool = false) async {
        guard force || products.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await StoreKit.Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
            if loaded.isEmpty {
                errorMessage = L10n.string("donations.unavailable")
            }
        } catch {
            products = []
            errorMessage = L10n.string("donations.storeUnavailable")
        }
    }

    func purchase(_ product: StoreKit.Product) async {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }
        feedback = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification,
                      transaction.productID == product.id
                else {
                    feedback = .failed
                    return
                }
                handledTransactionIDs.insert(transaction.id)
                feedback = .thankYou
                await transaction.finish()
            case .pending:
                feedback = .pending
            case .userCancelled:
                break
            @unknown default:
                feedback = .failed
            }
        } catch is CancellationError {
            return
        } catch {
            if let storeKitError = error as? StoreKitError, case .userCancelled = storeKitError {
                return
            }
            feedback = .failed
        }
    }

    func clearFeedback() {
        feedback = nil
    }

    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard !Task.isCancelled else { break }
            await process(result, showFeedback: false)
        }
    }

    private func process(_ result: VerificationResult<Transaction>, showFeedback: Bool) async {
        guard case .verified(let transaction) = result,
              Self.productIDs.contains(transaction.productID),
              transaction.productType == .consumable
        else { return }

        if showFeedback,
           transaction.revocationDate == nil,
           handledTransactionIDs.insert(transaction.id).inserted {
            feedback = .thankYou
        }
        await transaction.finish()
    }
}
