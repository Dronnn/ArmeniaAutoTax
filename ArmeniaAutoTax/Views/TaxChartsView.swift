import Charts
import SwiftUI

struct TaxChartsView: View {
    let vehicle: Vehicle
    let year: Int
    @ObservedObject var taxRates: TaxRatesStore
    let language: AppLanguage

    private var schedule: TaxRateSchedule { taxRates.schedule(for: year) }

    private var points: [HorsepowerTaxPoint] {
        TaxChartData.horsepowerPoints(for: vehicle, year: year, schedule: schedule)
    }

    private var years: [YearTaxPoint] {
        TaxChartData.yearPoints(for: vehicle) { taxRates.schedule(for: $0) }
    }

    private var thresholdPair: (low: Double, high: Double)? {
        TaxChartData.thresholdPair(for: vehicle.category)
    }

    private var thresholdDifference: Double? {
        TaxChartData.thresholdDifference(for: vehicle, year: year, schedule: schedule)
    }

    private var selectedTaxablePower: Double {
        TaxCalculator.taxablePower(for: vehicle, schedule: schedule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(kicker: t("charts.power.kicker"),
                          title: t("charts.power.title"),
                          subtitle: t("charts.power.subtitle"))
            SurfaceCard {
                VStack(alignment: .leading, spacing: 13) {
                    ScrollView(.horizontal) {
                        Chart(points) { item in
                            BarMark(
                                x: .value(t("charts.x.hp"), horsepowerLabel(item.horsepower)),
                                y: .value(t("charts.y.tax"), item.annualTax)
                            )
                            .foregroundStyle(isSelected(item) ? Palette.accent : Palette.accent.opacity(0.43))
                            .cornerRadius(4)
                        }
                        .frame(width: max(550, CGFloat(points.count) * 66), height: 230)
                    }
                    .scrollIndicators(.hidden)
                    if let thresholdPair, let thresholdDifference {
                        InlineMessage(
                            symbol: "chart.bar.xaxis",
                            message: f("charts.power.note",
                                       MoneyText.number(thresholdPair.low),
                                       MoneyText.number(thresholdPair.high),
                                       MoneyText.amount(thresholdDifference, digits: 0))
                        )
                    } else {
                        InlineMessage(symbol: "chart.bar.xaxis", message: t("charts.power.linear"))
                    }
                    if vehicle.powerSource.appliesEVRule {
                        InlineMessage(symbol: "bolt.car", message: t("charts.power.evNote"))
                    }
                }
            }
        }
        .id("charts.power")
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(kicker: t("charts.years.kicker"),
                          title: t("charts.years.title"),
                          subtitle: t("charts.years.subtitle"))
            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Chart(years) { item in
                        AreaMark(x: .value(t("charts.x.year"), item.year),
                                 y: .value(t("charts.y.tax"), item.annualTax))
                            .foregroundStyle(Palette.accent.opacity(0.10))
                        LineMark(x: .value(t("charts.x.year"), item.year),
                                 y: .value(t("charts.y.tax"), item.annualTax))
                            .foregroundStyle(Palette.accent)
                            .lineStyle(.init(lineWidth: 3))
                        PointMark(x: .value(t("charts.x.year"), item.year),
                                  y: .value(t("charts.y.tax"), item.annualTax))
                            .foregroundStyle(statusColor(item.status))
                            .symbolSize(56)
                    }
                    .chartXScale(domain: TaxChartData.referenceYears.lowerBound...TaxChartData.referenceYears.upperBound)
                    .chartXAxis {
                        AxisMarks(values: Array(TaxChartData.referenceYears)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let year = value.as(Int.self) {
                                    Text(verbatim: String(year))
                                }
                            }
                        }
                    }
                    .frame(height: 210)
                    ForEach(years) { item in
                        yearRow(item)
                    }
                }
            }
        }
        .id("charts.age")
    }

    private func yearRow(_ item: YearTaxPoint) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(item.status))
                .frame(width: 7, height: 7)
            Text(verbatim: "\(item.year)")
            Text(t("rates.status.\(item.status.rawValue)"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(MoneyText.amount(item.annualTax, digits: 0))
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.footnote)
    }

    private func isSelected(_ point: HorsepowerTaxPoint) -> Bool {
        abs(point.horsepower - selectedTaxablePower) < 0.000_1
    }

    private func horsepowerLabel(_ value: Double) -> String {
        MoneyText.number(value, digits: value.rounded() == value ? 0 : 2)
    }

    private func statusColor(_ status: TaxRateStatus) -> Color {
        switch status {
        case .verified: Palette.accent
        case .projected: .orange
        case .custom: .purple
        }
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: arguments)
    }
}
