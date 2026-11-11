import Charts
import SwiftUI

struct TaxChartsView: View {
    let vehicle: Vehicle
    let language: AppLanguage

    private var points: [HorsepowerTaxPoint] {
        TaxChartData.horsepowerPoints(for: vehicle)
    }

    private var years: [YearTaxPoint] {
        TaxChartData.yearPoints(for: vehicle)
    }

    private var thresholdPair: (low: Int, high: Int)? {
        TaxChartData.thresholdPair(for: vehicle.category)
    }

    private var thresholdDifference: Double? {
        TaxChartData.thresholdDifference(for: vehicle)
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
                                x: .value(t("charts.x.hp"), String(item.horsepower)),
                                y: .value(t("charts.y.tax"), item.annualTax)
                            )
                            .foregroundStyle(item.horsepower == vehicle.horsepower
                                             ? Palette.accent
                                             : Palette.accent.opacity(0.43))
                            .cornerRadius(4)
                        }
                        .frame(width: max(550, CGFloat(points.count) * 60), height: 230)
                    }
                    .scrollIndicators(.hidden)
                    if let thresholdPair, let thresholdDifference {
                        InlineMessage(
                            symbol: "chart.bar.xaxis",
                            message: t("charts.power.note",
                                       thresholdPair.low,
                                       thresholdPair.high,
                                       MoneyText.amount(thresholdDifference, digits: 0))
                        )
                    } else {
                        InlineMessage(symbol: "chart.bar.xaxis", message: t("charts.power.linear"))
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
                            .foregroundStyle(Palette.accent)
                            .symbolSize(56)
                    }
                    .chartXScale(domain: 2026...2030)
                    .chartXAxis {
                        AxisMarks(values: [2026, 2027, 2028, 2029, 2030]) { value in
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
                        MetricRow(label: String(item.year), value: MoneyText.amount(item.annualTax, digits: 0))
                    }
                }
            }
        }
        .id("charts.age")
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    private func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: arguments)
    }
}
