import StoreKit
import SwiftUI

struct DonationView: View {
    @ObservedObject private var store = DonationStore.shared
    let language: AppLanguage

    @State private var selectedTierID = DonationTier.all[1].id
    @State private var didRequestProducts = false

    init(language: AppLanguage) {
        self.language = language
        #if DEBUG
        if let suffix = LaunchOptions.value(after: "-donation-tier"),
           let tier = DonationTier.all.first(where: {
               $0.id == suffix || $0.id.hasSuffix("." + suffix)
           }) {
            _selectedTierID = State(initialValue: tier.id)
        }
        #endif
    }

    private var selectedTier: DonationTier {
        DonationTier.all.first { $0.id == selectedTierID } ?? DonationTier.all[1]
    }

    private var selectedProduct: StoreKit.Product? {
        store.product(for: selectedTier)
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if store.feedback == .thankYou {
                        thankYouContent
                    } else {
                        donationContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .contentMargins(.bottom, 170, for: .scrollContent)
        }
        .navigationTitle(t("donations.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if store.feedback != .thankYou {
                donateButton
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .task {
            guard !didRequestProducts else { return }
            didRequestProducts = true
            await store.loadProducts()
        }
        .onAppear {
            #if DEBUG
            if LaunchOptions.arguments.contains("-demo-donation-thankyou") {
                store.demoPurchase()
            }
            #endif
        }
        .onDisappear { store.clearFeedback() }
    }

    private var donationContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 56, height: 56)
                    .background(Palette.accent.opacity(0.11), in: Circle())
                    .accessibilityHidden(true)
                Text(t("donations.headline"))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(t("donations.body"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(t("donations.choose"))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(DonationTier.all) { tier in
                        tierCard(tier)
                    }
                }
            }

            if store.isLoading && store.products.isEmpty {
                HStack(spacing: 9) {
                    ProgressView()
                    Text(t("donations.loading"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if !DonationStore.isDemoMode,
                      let errorMessage = store.errorMessage,
                      store.products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(t("donations.retry")) {
                        Task { await store.loadProducts(force: true) }
                    }
                    .font(.footnote.weight(.semibold))
                    .tint(Palette.accent)
                }
            }

            switch store.feedback {
            case .pending:
                InlineMessage(symbol: "clock", message: t("donations.pending"))
            case .failed:
                Text(t("donations.failed"))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            default:
                EmptyView()
            }

            Text(t("donations.finePrint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var thankYouContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(Palette.accent)
                .frame(height: 52)
            Text(t("donations.thankYou.title"))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
            Text(t("donations.thankYou.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(t("donations.done")) {
                store.clearFeedback()
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accent)
            .accessibilityIdentifier("donations.done")
        }
    }

    private var donateButton: some View {
        Button {
            if DonationStore.isDemoMode {
                store.demoPurchase()
                return
            }
            guard let selectedProduct else { return }
            Task { await store.purchase(selectedProduct) }
        } label: {
            HStack(spacing: 8) {
                if store.purchasingProductID != nil {
                    ProgressView().controlSize(.small)
                }
                Text(f("donations.donate", store.displayPrice(for: selectedTier)))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.accent)
        .disabled((!DonationStore.isDemoMode && selectedProduct == nil) ||
                  store.purchasingProductID != nil)
        .accessibilityIdentifier("donations.donate")
    }

    private func tierCard(_ tier: DonationTier) -> some View {
        let selected = selectedTierID == tier.id
        let available = store.isAvailable(tier)
        return Button {
            selectedTierID = tier.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tier.icon)
                    .font(.title3)
                    .foregroundStyle(selected ? Palette.accent : .secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.displayName(for: tier, language: language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(selected ? Palette.accent : .secondary)
                        .lineLimit(1)
                    Text(store.displayPrice(for: tier))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Palette.accent.opacity(0.1) : Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? Palette.accent : Color.secondary.opacity(0.22),
                                    lineWidth: selected ? 1.5 : 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("donations.tier.\(tier.id.split(separator: ".").last ?? "")")
        .accessibilityLabel("\(store.displayName(for: tier, language: language)), \(store.displayPrice(for: tier))")
        .disabled(!available)
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: arguments)
    }
}
