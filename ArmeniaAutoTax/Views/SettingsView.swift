import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var taxRates: TaxRatesStore
    @State private var showResetRates = false

    private var rateStatus: TaxRateStatus { taxRates.status(for: store.taxYear) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(kicker: L10n.string("settings.kicker"),
                              title: L10n.string("settings.title"),
                              subtitle: L10n.string("settings.subtitle"))

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string("settings.language.title"))
                            .font(.headline)
                        ForEach([AppLanguage.english, .armenian, .russian]) { language in
                            languageRow(language)
                        }
                        Text(L10n.string("settings.language.note"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string("settings.theme.title"))
                            .font(.headline)
                        Picker(L10n.string("settings.theme.title"), selection: $store.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.label).tag(appearance)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string("settings.rates.title"))
                            .font(.headline)
                        HStack {
                            Text(verbatim: "\(store.taxYear)")
                                .font(.subheadline.weight(.semibold))
                            Text(L10n.string("rates.status.\(rateStatus.rawValue)"))
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Palette.accent.opacity(0.12), in: Capsule())
                                .foregroundStyle(Palette.accent)
                            Spacer()
                        }
                        if taxRates.hasCustomRates {
                            Text(f("settings.rates.customYears",
                                   taxRates.customYears.map(String.init).joined(separator: ", ")))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        NavigationLink(L10n.string("settings.rates.edit")) {
                            TaxRatesEditorView(
                                taxRates: taxRates,
                                language: store.language,
                                initialYear: store.taxYear
                            )
                        }
                        .font(.footnote.weight(.semibold))
                        .tint(Palette.accent)
                        if taxRates.hasCustomRates {
                            Button(L10n.string("settings.rates.reset"), role: .destructive) {
                                showResetRates = true
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        Text(L10n.string("settings.rates.note"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string("settings.about.title"))
                            .font(.headline)
                        Text(L10n.string("settings.about.body"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(versionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(L10n.string("settings.showWelcome")) {
                            store.restartOnboarding()
                        }
                        .font(.footnote.weight(.semibold))
                        .tint(Palette.accent)
                        .accessibilityIdentifier("settings.showWelcome")
                    }
                }

                Text(L10n.string("settings.privacy"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .appContentWidth()
        }
        .contentMargins(.bottom, 104, for: .scrollContent)
        .background(Palette.background)
        .navigationTitle(L10n.string("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(
            L10n.string("settings.rates.reset"),
            isPresented: $showResetRates
        ) {
            Button(L10n.string("settings.rates.reset"), role: .destructive) {
                taxRates.resetAll()
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("settings.rates.reset.confirm"))
        }
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: L10n.string(key, language: store.language),
               locale: store.language.locale,
               arguments: arguments)
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let selected = store.language == language
        return Button {
            store.language = language
        } label: {
            HStack {
                Text(language.nativeName)
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.language.\(language.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return L10n.format("settings.version", version, build)
    }
}
