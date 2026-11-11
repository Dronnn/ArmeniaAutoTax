import SwiftUI

struct RulesView: View {
    let language: AppLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(kicker: t("rules.kicker"),
                              title: t("rules.title"),
                              subtitle: t("rules.subtitle"))
                ratesCard
                ageCard
                conditionsCard
                links
            }
            .padding(16)
        }
        .contentMargins(.bottom, 104, for: .scrollContent)
        .background(Palette.background)
        .navigationTitle(t("rules.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var ratesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 13) {
                Text(t("rules.rates.title")).font(.headline)
                row(t("rules.rates.passenger1"), "200 ֏")
                row(t("rules.rates.passenger2"), "300 ֏")
                row(t("rules.rates.passenger3"), "500 ֏")
                Text(t("rules.rates.extra"))
                    .font(.footnote).foregroundStyle(.secondary)
                Divider()
                row(t("rules.rates.bus1"), "100 ֏")
                row(t("rules.rates.bus2"), "200 ֏")
                row(t("rules.rates.motorcycle"), "40 ֏")
                row(t("rules.rates.other"), "150 ֏")
            }
        }
    }

    private var ageCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("rules.age.title")).font(.headline)
                Text(t("rules.age.body"))
                Text(t("rules.age.cargo"))
                Text(t("rules.age.other"))
            }
            .font(.subheadline)
        }
    }

    private var conditionsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 11) {
                Text(t("rules.extra.title")).font(.headline)
                Text(t("rules.extra.surcharge"))
                Text(t("rules.extra.months"))
                Text(t("rules.extra.power"))
                Text(t("rules.extra.exclusions"))
                Text(t("rules.extra.estimate"))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
        }
    }

    private var links: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("rules.links.title")).font(.headline)
                Link(destination: URL(string: "https://www.arlis.am/en/acts/205620")!) {
                    Label(t("rules.links.taxCode"), systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://www.cba.am/en/exchange-rates-retrieval")!) {
                    Label(t("rules.links.cba"), systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://english.hartak.am/guides/individual-taxes/")!) {
                    Label(t("rules.links.hartak"), systemImage: "arrow.up.right.square")
                }
                Text(t("rules.links.note"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .tint(Palette.accent)
        }
    }

    private func row(_ label: String, _ amount: String) -> some View {
        MetricRow(label: label, value: amount)
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }
}
