import Charts
import SwiftUI
import UIKit

struct GarageView: View {
    @ObservedObject var store: AppStore
    let onSelect: (Vehicle) -> Void
    @State private var shareURL: URL?
    @State private var showingShare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(kicker: t("garage.kicker"),
                              title: t("garage.title"),
                              subtitle: t("garage.subtitle"))
                if store.garage.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "car.side.rear.open")
                                .font(.largeTitle).foregroundStyle(Palette.accent)
                            Text(t("garage.empty.title")).font(.headline)
                                .accessibilityIdentifier("garage.empty")
                            Text(t("garage.empty.body"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(store.garage) { car in carCard(car) }
                    if store.garage.count > 1 { comparisonChart }
                }

                SectionHeader(kicker: t("garage.history.kicker"),
                              title: f("garage.history.title", store.history.count))
                if store.history.isEmpty {
                    SurfaceCard {
                        InlineMessage(symbol: "clock.arrow.circlepath", message: t("garage.history.empty"))
                    }
                } else {
                    ForEach(store.history) { entry in historyCard(entry) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .contentMargins(.bottom, 104, for: .scrollContent)
        .background(Palette.background)
        .navigationTitle(t("garage.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareURL = store.exportArchive()
                    showingShare = shareURL != nil
                } label: { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel(t("garage.export.a11y"))
                .disabled(store.garage.isEmpty && store.history.isEmpty)
            }
        }
        .sheet(isPresented: $showingShare) {
            if let shareURL { NativeShareSheet(url: shareURL) }
        }
    }

    private func carCard(_ car: Vehicle) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: car.category.symbol)
                        .font(.title2)
                        .foregroundStyle(Palette.accent)
                        .frame(width: 36, height: 36)
                        .background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(car.localizedDisplayName(language: store.language)).font(.headline)
                        Text(f("garage.car.subtitle",
                               car.manufactureYear,
                               car.horsepower,
                               t("common.hp"),
                               car.category.localizedShortTitle(language: store.language)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) { store.removeVehicle(car.id) } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(f("garage.delete.a11y", car.localizedDisplayName(language: store.language)))
                    .accessibilityIdentifier("garage.delete")
                }
                HStack {
                    Text(MoneyText.amount(TaxCalculator.calculate(car).periodTotal))
                        .font(.title3.bold()).monospacedDigit()
                    Spacer()
                    Button(t("garage.open")) { onSelect(car) }
                        .buttonStyle(.bordered).tint(Palette.accent)
                        .font(.caption)
                        .accessibilityIdentifier("garage.open")
                }
            }
        }
    }

    private var comparisonChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(kicker: t("garage.compare.kicker"), title: t("garage.compare.title"))
            SurfaceCard {
                Chart(store.garage) { car in
                    BarMark(
                        x: .value(t("charts.y.tax"), TaxCalculator.calculate(car).periodTotal),
                        y: .value(t("garage.title"), car.localizedDisplayName(language: store.language))
                    )
                    .foregroundStyle(Palette.accent)
                    .annotation(position: .trailing) {
                        Text(MoneyText.number(TaxCalculator.calculate(car).periodTotal, digits: 0))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(max(170, min(560, store.garage.count * 55))))
            }
        }
    }

    private func historyCard(_ entry: TaxHistoryEntry) -> some View {
        SurfaceCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.vehicle.localizedDisplayName(language: store.language)).font(.subheadline.bold())
                    Text(entry.timestamp.formatted(
                        .dateTime.year().month(.abbreviated).day()
                            .hour().minute()
                            .locale(store.language.locale)
                    ))
                    .font(.caption2).foregroundStyle(.secondary)
                    Text(MoneyText.amount(entry.tax.periodTotal))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                }
                Spacer()
                Button { onSelect(entry.vehicle) } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .accessibilityLabel(t("garage.history.repeat.a11y"))
                .tint(Palette.accent)
                Button(role: .destructive) { store.removeHistory(entry.id) } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(t("garage.history.delete.a11y"))
            }
        }
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: store.language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: store.language.locale, arguments: arguments)
    }
}

private struct NativeShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
