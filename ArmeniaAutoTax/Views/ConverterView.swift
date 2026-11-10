import SwiftUI

struct ConverterView: View {
    @ObservedObject var rates: ExchangeRatesStore
    let language: AppLanguage
    var initialAMD: Double

    @State private var amdAmount: Double = 0
    @State private var rawEditingText = ""
    @FocusState private var editing: CurrencyCode?
    @State private var manualEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(kicker: t("converter.kicker"),
                          title: t("converter.title"),
                          subtitle: t("converter.subtitle"))
            SurfaceCard {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        amdAmount = initialAMD
                        editing = nil
                    } label: {
                        Label(t("converter.fillTax"), systemImage: "arrow.down.left")
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Palette.accent)
                    ForEach(CurrencyCode.allCases) { currency in
                        currencyRow(currency)
                        if currency != .rub { Divider() }
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t("converter.bank"))
                                .font(.caption.weight(.semibold))
                            Text(f("converter.rateDate", rates.current.asOf, rateOriginTitle))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if rates.isLoading { ProgressView().controlSize(.small) }
                    }
                    if let error = rates.errorMessage {
                        Text(error).font(.caption2).foregroundStyle(.orange)
                    }
                    HStack(spacing: 12) {
                        Button { Task { await rates.refresh() } } label: {
                            Label(t("converter.refresh"), systemImage: "arrow.clockwise")
                        }
                        .disabled(rates.isLoading)
                        Button(t("converter.manual")) { manualEditor = true }
                    }
                    .font(.caption.weight(.semibold))
                    .tint(Palette.accent)
                }
            }
        }
        .onAppear { amdAmount = initialAMD }
        .onChange(of: initialAMD) { _, newValue in
            if editing == nil { amdAmount = newValue }
        }
        .onChange(of: editing) { _, newValue in
            if let newValue {
                let calculated = rates.current.convert(amdAmount, from: .amd, to: newValue)
                rawEditingText = MoneyText.editable(calculated, locale: language.locale)
            }
        }
        .sheet(isPresented: $manualEditor) {
            ManualRatesView(rates: rates, language: language)
        }
    }

    private var rateOriginTitle: String {
        switch rates.current.origin {
        case .fallback: t("converter.origin.fallback")
        case .centralBank: t("converter.origin.centralBank")
        case .manual: t("converter.origin.manual")
        }
    }

    private func currencyRow(_ code: CurrencyCode) -> some View {
        HStack(spacing: 12) {
            Text(code.symbol)
                .font(.title3.bold())
                .frame(width: 30)
                .foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(code.rawValue).font(.caption.bold())
                Text(code.title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            TextField("0", text: Binding(
                get: {
                    editing == code
                        ? rawEditingText
                        : MoneyText.number(
                            rates.current.convert(amdAmount, from: .amd, to: code),
                            locale: language.locale
                        )
                },
                set: { newValue in
                    rawEditingText = newValue
                    if let number = DecimalInput.parse(newValue, locale: language.locale) {
                        amdAmount = number * rates.current.amdPerUnit(code)
                    } else if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        amdAmount = 0
                    }
                }
            ))
            .focused($editing, equals: code)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .frame(maxWidth: 140)
            .accessibilityLabel(f("converter.amountA11y", code.rawValue))
        }
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: arguments)
    }
}

struct ManualRatesView: View {
    @ObservedObject var rates: ExchangeRatesStore
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var usd = ""
    @State private var eur = ""
    @State private var rub = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(t("manualRates.section")) {
                    TextField("USD", text: $usd).keyboardType(.decimalPad)
                    TextField("EUR", text: $eur).keyboardType(.decimalPad)
                    TextField("RUB", text: $rub).keyboardType(.decimalPad)
                }
                Section {
                    Text(t("manualRates.note"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(t("manualRates.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("manualRates.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("manualRates.save")) {
                        guard let u = read(usd), let e = read(eur), let r = read(rub) else { return }
                        rates.setManual(usd: u, eur: e, rub: r)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            usd = MoneyText.editable(rates.current.usd, locale: language.locale)
            eur = MoneyText.editable(rates.current.eur, locale: language.locale)
            rub = MoneyText.editable(rates.current.rub, locale: language.locale)
        }
    }

    private func read(_ value: String) -> Double? {
        guard let n = DecimalInput.parse(value, locale: language.locale), n > 0 else { return nil }
        return n
    }

    private var isValid: Bool { read(usd) != nil && read(eur) != nil && read(rub) != nil }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }
}
