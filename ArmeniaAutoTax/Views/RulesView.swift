import SwiftUI

struct RulesView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var taxRates: TaxRatesStore

    private var language: AppLanguage { store.language }
    private var schedule: TaxRateSchedule { taxRates.schedule(for: store.taxYear) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(kicker: t("rules.kicker"),
                              title: t("rules.title"),
                              subtitle: subtitle)
                yearCard
                ratesCard
                evCard
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
    }

    private var yearCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(t("calculator.taxYear")).font(.headline)
                    Spacer()
                    Picker(t("calculator.taxYear"), selection: $store.taxYear) {
                        ForEach(TaxScheduleStore.availableYears(), id: \.self) { year in
                            Text(verbatim: "\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("rules.taxYear")
                }
                HStack(spacing: 8) {
                    Text(verbatim: "\(store.taxYear)")
                        .font(.subheadline.weight(.semibold))
                    Text(t("rates.status.\(schedule.status.rawValue)"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(statusColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(statusColor)
                }
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if schedule.status == .custom {
                    NavigationLink(t("settings.rates.edit")) {
                        TaxRatesEditorView(taxRates: taxRates, language: language, initialYear: store.taxYear)
                    }
                    .font(.footnote.weight(.semibold))
                    .tint(Palette.accent)
                }
            }
        }
    }

    private var ratesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 13) {
                Text(t("rules.rates.title")).font(.headline)
                ForEach(Array(schedule.passengerBands.enumerated()), id: \.offset) { index, band in
                    row(
                        bandLabel(index: index, band: band, bands: schedule.passengerBands,
                                  prefix: t("rules.rates.passenger")),
                        f("rules.rates.perHP", band.ratePerHorsepower)
                    )
                }
                if let extra = schedule.passengerBands.first(where: { $0.extraAbove != nil }),
                   let above = extra.extraAbove,
                   let rate = extra.extraPerHorsepower {
                    Text(f("rules.rates.extra", MoneyText.number(above), rate))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Divider()
                ForEach(Array(schedule.busCargoBands.enumerated()), id: \.offset) { index, band in
                    row(
                        bandLabel(index: index, band: band, bands: schedule.busCargoBands,
                                  prefix: t("rules.rates.busCargo")),
                        f("rules.rates.perHP", band.ratePerHorsepower)
                    )
                }
                row(t("rules.rates.motorcycle"), f("rules.rates.perHP", schedule.motorcycleRate))
                row(t("rules.rates.other"), f("rules.rates.perHP", schedule.otherRate))
            }
        }
    }

    private var evCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("rules.ev.title")).font(.headline)
                Text(t("rules.ev.body"))
                Text(t("rules.ev.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    private var ageCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("rules.age.title")).font(.headline)
                Text(f("rules.age.body",
                       max(0, schedule.fullTaxYears - 1),
                       schedule.discountStep,
                       schedule.maxDiscount))
                Text(f("rules.age.cargo", schedule.cargoExemptionAge))
                Text(t("rules.age.other"))
            }
            .font(.subheadline)
        }
    }

    private var conditionsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 11) {
                Text(t("rules.extra.title")).font(.headline)
                Text(f("rules.extra.surcharge", schedule.communityMaxPercent))
                Text(t("rules.extra.months"))
                Text(t("rules.extra.power"))
                Text(t("rules.extra.seats"))
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

    private var subtitle: String {
        switch schedule.status {
        case .verified:
            return f("rules.subtitle.verified", String(store.taxYear), schedule.verifiedOn ?? "")
        case .projected:
            return f("rules.subtitle.projected", String(store.taxYear))
        case .custom:
            return f("rules.subtitle.custom", String(store.taxYear))
        }
    }

    private var statusText: String {
        switch schedule.status {
        case .verified:
            return f("rules.status.verified", schedule.verifiedOn ?? "")
        case .projected:
            return t("rules.status.projected")
        case .custom:
            return t("rules.status.custom")
        }
    }

    private var statusColor: Color {
        switch schedule.status {
        case .verified: Palette.accent
        case .projected: .orange
        case .custom: .purple
        }
    }

    private func bandLabel(
        index: Int,
        band: TaxRateBand,
        bands: [TaxRateBand],
        prefix: String
    ) -> String {
        let lower: Double
        if index == 0 {
            lower = 1
        } else {
            lower = (bands.indices.contains(index - 1) ? (bands[index - 1].upperBound ?? 0) : 0) + 1
        }
        if let upper = band.upperBound {
            return f("rules.rates.range", prefix, MoneyText.number(lower), MoneyText.number(upper))
        }
        return f("rules.rates.openRange", prefix, MoneyText.number(lower))
    }

    private func row(_ label: String, _ amount: String) -> some View {
        MetricRow(label: label, value: amount)
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: arguments)
    }
}
