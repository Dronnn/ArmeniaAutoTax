import SwiftUI

enum MainTab: Hashable {
    case calculator, garage, rules, settings, donations
}

@main
struct ArmeniaAutoTaxApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var rates = ExchangeRatesStore()
    @State private var selectedTab: MainTab = .calculator

    var body: some Scene {
        WindowGroup {
            ZStack {
                mainTabs
                    .opacity(store.hasCompletedOnboarding ? 1 : 0)
                    .scaleEffect(store.hasCompletedOnboarding ? 1 : 0.985)
                    .allowsHitTesting(store.hasCompletedOnboarding)
                    .accessibilityHidden(!store.hasCompletedOnboarding)

                if !store.hasCompletedOnboarding {
                    OnboardingView(store: store)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.04)),
                            removal: .opacity.combined(with: .scale(scale: 1.06))
                        ))
                }
            }
            .animation(.easeOut(duration: 0.28), value: store.hasCompletedOnboarding)
            .onChange(of: store.hasCompletedOnboarding) { _, completed in
                if completed { selectedTab = .calculator }
            }
            .tint(Palette.accent)
            .preferredColorScheme(scheme)
            .environment(\.locale, store.language.locale)
            .task { await rates.refresh() }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CalculatorView(store: store, rates: rates)
            }
            .tabItem { Label(L10n.string("tab.calculator"), systemImage: "function") }
            .tag(MainTab.calculator)

            NavigationStack {
                GarageView(store: store) { vehicle in
                    store.loadVehicle(vehicle)
                    selectedTab = .calculator
                }
            }
            .tabItem { Label(L10n.string("tab.garage"), systemImage: "car.2.fill") }
            .badge(store.garage.count)
            .tag(MainTab.garage)

            NavigationStack {
                RulesView(language: store.language)
            }
            .tabItem { Label(L10n.string("tab.rules"), systemImage: "text.book.closed") }
            .tag(MainTab.rules)

            NavigationStack {
                SettingsView(store: store)
            }
            .tabItem { Label(L10n.string("tab.settings"), systemImage: "gearshape.fill") }
            .tag(MainTab.settings)

            NavigationStack {
                DonationView(language: store.language)
            }
            .tabItem { Label(L10n.string("tab.donations"), systemImage: "heart.fill") }
            .tag(MainTab.donations)
        }
        .id(store.hasCompletedOnboarding ? store.language.rawValue : "onboarding")
    }

    private var scheme: ColorScheme? {
        switch store.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
