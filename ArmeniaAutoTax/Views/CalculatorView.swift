import SwiftUI

struct CalculatorView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var rates: ExchangeRatesStore
    @ObservedObject var taxRates: TaxRatesStore
    @State private var showAdvanced = false
    @State private var showMonthsSheet = false
    @State private var alert: Confirmation?
    @State private var powerUnit: PowerUnit = .horsepower
    @State private var yearText = "2019"
    @State private var horsepowerText = "243"
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case year
        case horsepower
    }

    private enum Confirmation: Identifiable {
        case saved
        case calculation

        var id: Int {
            switch self {
            case .saved: 0
            case .calculation: 1
            }
        }

        var title: String {
            switch self {
            case .saved: L10n.string("alert.vehicleSaved")
            case .calculation: L10n.string("alert.calculationSaved")
            }
        }
    }

    private var schedule: TaxRateSchedule { taxRates.schedule(for: store.taxYear) }
    private var tax: TaxBreakdown {
        TaxCalculator.calculate(store.draft, year: store.taxYear, schedule: schedule)
    }
    private var rateStatus: TaxRateStatus { schedule.status }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    introduction.id("calculator.top")
                    newYearBanner
                    rateBanner
                    vehicleForm
                    if store.validDraft {
                        resultCard.id("calculator.result")
                        ConverterView(rates: rates, language: store.language, initialAMD: tax.periodTotal)
                            .id("calculator.converter")
                        TaxChartsView(vehicle: store.draft, year: store.taxYear, taxRates: taxRates, language: store.language)
                            .id("calculator.charts")
                    } else {
                        SurfaceCard {
                            InlineMessage(symbol: "exclamationmark.triangle",
                                          message: f("calculator.invalid", String(store.taxYear)))
                        }
                    }
                    footer.id("calculator.footer")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .contentMargins(.bottom, 104, for: .scrollContent)
            .background(Palette.background)
            .onAppear {
                syncTextFields()
                scrollForScreenshot(proxy)
            }
            .onChange(of: store.draft.id) { _, _ in syncTextFields() }
            .onChange(of: store.taxYear) { _, _ in syncTextFields() }
            .onChange(of: powerUnit) { _, _ in syncTextFields() }
        }
        .navigationTitle(t("calculator.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(item: $alert) { value in
            Alert(title: Text(value.title), dismissButton: .default(Text(t("common.ok"))))
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(t("common.ok")) { focusedField = nil }
            }
        }
        .sheet(isPresented: $showMonthsSheet) {
            LiabilityMonthsView(
                taxYear: store.taxYear,
                months: $store.draft.taxableMonths,
                language: store.language
            )
        }
    }

    private func scrollForScreenshot(_ proxy: ScrollViewProxy) {
        #if DEBUG
        guard let section = LaunchOptions.value(after: "-screenshot-scroll") else { return }
        let target: String
        switch section {
        case "result": target = "calculator.result"
        case "converter": target = "calculator.converter"
        case "charts": target = "calculator.charts"
        case "age": target = "charts.age"
        case "footer": target = "calculator.footer"
        default: target = "calculator.top"
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(target, anchor: .top)
            }
        }
        #endif
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("app.brand"))
                .font(.caption.bold()).tracking(2).foregroundStyle(Palette.accent)
            Text(t("calculator.hero"))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(t("calculator.subtitle"))
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(f("calculator.rulesYear", String(store.taxYear)))
                    .font(.caption2.bold()).tracking(1)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Palette.accent.opacity(0.11), in: Capsule())
                Text(t("rates.status.\(rateStatus.rawValue)"))
                    .font(.caption2.bold()).tracking(1)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(statusColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(statusColor)
            }
        }
    }

    @ViewBuilder
    private var newYearBanner: some View {
        if TaxScheduleStore.suggestsCurrentYear(persisted: store.taxYear) {
            let currentYear = TaxScheduleStore.currentTaxYear()
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    InlineMessage(
                        symbol: "calendar.badge.plus",
                        message: f("calculator.newYear", currentYear, store.taxYear)
                    )
                    Button(f("calculator.newYear.action", currentYear)) {
                        store.taxYear = currentYear
                    }
                    .font(.footnote.weight(.semibold))
                    .tint(Palette.accent)
                }
            }
        }
    }

    @ViewBuilder
    private var rateBanner: some View {
        if taxRates.isCustomized(store.taxYear) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    InlineMessage(
                        symbol: "slider.horizontal.3",
                        message: f("calculator.customRates", store.taxYear)
                    )
                    NavigationLink(t("calculator.customRates.action")) {
                        TaxRatesEditorView(taxRates: taxRates, language: store.language, initialYear: store.taxYear)
                    }
                    .font(.footnote.weight(.semibold))
                    .tint(Palette.accent)
                }
            }
        } else if rateStatus == .projected {
            SurfaceCard {
                InlineMessage(
                    symbol: "clock.badge.exclamationmark",
                    message: f("calculator.projectedRates", store.taxYear)
                )
            }
        }
    }

    private var vehicleForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(kicker: t("calculator.section.kicker"),
                              title: t("calculator.section.title"))
                Button(t("calculator.reset")) { store.resetDraft() }
                    .font(.subheadline.weight(.medium))
                    .tint(Palette.accent)
            }
            SurfaceCard {
                VStack(alignment: .leading, spacing: 17) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(t("calculator.name.label")).font(.caption).foregroundStyle(.secondary)
                        TextField(t("calculator.name.placeholder"), text: $store.draft.name)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(t("calculator.year")).font(.caption).foregroundStyle(.secondary)
                            TextField("2019", text: yearBinding)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .year)
                                .accessibilityIdentifier("calculator.year")
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(t("calculator.power"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Picker(t("calculator.power"), selection: $powerUnit) {
                                    Text(t("calculator.unit.hp")).tag(PowerUnit.horsepower)
                                    Text(t("calculator.unit.kw")).tag(PowerUnit.kilowatt)
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .tint(Palette.accent)
                                .frame(width: 72, alignment: .trailing)
                                .accessibilityIdentifier("calculator.powerUnit")
                            }
                            TextField("243", text: horsepowerBinding)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .horsepower)
                                .accessibilityIdentifier("calculator.horsepower")
                            if powerUnit == .kilowatt {
                                Text(f("calculator.power.converted",
                                       MoneyText.number(store.draft.horsepower)))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(t("calculator.category")).font(.caption).foregroundStyle(.secondary)
                        Picker(t("calculator.category"), selection: $store.draft.category) {
                            ForEach(VehicleCategory.allCases) { category in
                                Text(category.localizedTitle(language: store.language)).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(t("calculator.taxYear")).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(t("rates.status.\(rateStatus.rawValue)"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(statusColor)
                        }
                        Picker(t("calculator.taxYear"), selection: $store.taxYear) {
                            ForEach(TaxScheduleStore.availableYears(), id: \.self) { year in
                                Text(verbatim: "\(year)").tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("calculator.taxYear")
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(t("calculator.powerSource")).font(.caption).foregroundStyle(.secondary)
                        Picker(t("calculator.powerSource"), selection: $store.draft.powerSource) {
                            ForEach(VehiclePowerSource.allCases) { source in
                                Text(source.localizedTitle(language: store.language)).tag(source)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("calculator.powerSource")
                        if let note = store.draft.powerSource.localizedNote(language: store.language) {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    InlineMessage(symbol: "info.circle", message: t("calculator.info"))
                    Divider()
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(alignment: .leading, spacing: 16) {
                            Stepper(f("calculator.months", store.draft.taxableMonths),
                                    value: $store.draft.taxableMonths, in: 0...12)
                            Button {
                                showMonthsSheet = true
                            } label: {
                                Label(t("calculator.monthsFromDates"), systemImage: "calendar")
                            }
                            .font(.subheadline.weight(.medium))
                            .tint(Palette.accent)
                            .accessibilityIdentifier("calculator.monthsFromDates")
                            Stepper(f("calculator.surcharge", surchargeBinding.wrappedValue),
                                    value: surchargeBinding,
                                    in: 0...max(0, schedule.communityMaxPercent))
                            Text(t("calculator.advanced.note"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, 10)
                    } label: {
                        Label(t("calculator.advanced"), systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    Button {
                        store.saveVehicle()
                        alert = .saved
                    } label: {
                        Label(t("calculator.saveVehicle"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
                    .disabled(!store.validDraft)
                    .accessibilityIdentifier("calculator.saveVehicle")
                    Text(t("calculator.privacy"))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(t("calculator.result.kicker"), systemImage: "checkmark.seal.fill")
                        .font(.caption2.bold()).tracking(1)
                    Spacer()
                    Text(f("calculator.result.period", String(tax.calculationYear), tax.taxableMonths))
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.78))
                Text(MoneyText.amount(tax.periodTotal, digits: 2))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("calculator.result.amount")
                if tax.isElectricAdjusted {
                    Text(f("calculator.result.taxablePower",
                           MoneyText.number(tax.rawHorsepower),
                           MoneyText.number(tax.taxableHorsepower)))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityIdentifier("calculator.result.taxablePower")
                }
                HStack(spacing: 7) {
                    Text("≈ \(MoneyText.amount(rates.current.convert(tax.periodTotal, from: .amd, to: .usd), currency: .usd))")
                    Text("·")
                    Text("\(MoneyText.amount(rates.current.convert(tax.periodTotal, from: .amd, to: .eur), currency: .eur))")
                    Text("·")
                    Text("\(MoneyText.amount(rates.current.convert(tax.periodTotal, from: .amd, to: .rub), currency: .rub))")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                HStack(spacing: 10) {
                    statPill(label: t("calculator.stat.age"),
                             value: L10n.years(tax.age, language: store.language))
                    statPill(label: t("calculator.stat.discount"), value: "−\(tax.ageDiscountPercent)%")
                    statPill(label: t("calculator.stat.monthly"), value: MoneyText.amount(tax.averagePerMonth))
                }
            }
            .padding(19)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.darkCard, in: RoundedRectangle(cornerRadius: 23))

            SurfaceCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(t("calculator.breakdown.title")).font(.headline)
                    if tax.isElectricAdjusted {
                        MetricRow(
                            label: t("calculator.breakdown.taxablePower"),
                            value: "\(MoneyText.number(tax.taxableHorsepower)) \(t("common.hp"))"
                        )
                    }
                    MetricRow(
                        label: f("calculator.breakdown.base",
                                 MoneyText.number(tax.taxableHorsepower),
                                 tax.baseRatePerHorsepower),
                        value: MoneyText.amount(tax.baseAmount)
                    )
                    if tax.extraHorsepower > 0,
                       let extraAbove = tax.extraAboveHorsepower,
                       let extraRate = tax.extraRatePerHorsepower {
                        MetricRow(
                            label: f("calculator.breakdown.extra",
                                     MoneyText.number(extraAbove),
                                     MoneyText.number(tax.extraHorsepower),
                                     extraRate),
                            value: MoneyText.amount(tax.extraAmount)
                        )
                    }
                    MetricRow(label: t("calculator.breakdown.subtotal"),
                              value: MoneyText.amount(tax.subtotal))
                    if !tax.isExempt {
                        MetricRow(label: f("calculator.breakdown.discount", tax.ageDiscountPercent),
                                  value: "−\(MoneyText.amount(tax.ageDiscountAmount))")
                        MetricRow(label: f("calculator.breakdown.surcharge", tax.surchargePercent),
                                  value: MoneyText.amount(tax.surchargeAmount))
                        if tax.taxableMonths != 12 {
                            MetricRow(label: f("calculator.breakdown.proration", tax.taxableMonths),
                                      value: MoneyText.amount(tax.periodTotal))
                        }
                    }
                    Divider()
                    MetricRow(label: t("calculator.breakdown.total"),
                              value: MoneyText.amount(tax.periodTotal), emphasized: true)
                    if tax.isExempt {
                        InlineMessage(symbol: "checkmark.shield",
                                      message: f("calculator.exempt", schedule.cargoExemptionAge))
                    }
                    Divider()
                    Button {
                        store.recordCalculation(tax)
                        alert = .calculation
                    } label: {
                        Label(t("calculator.saveHistory"), systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.accent)
                }
            }
            InlineMessage(symbol: "text.book.closed", message: t("calculator.disclaimer"))
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.68))
            Text(value).font(.caption2.bold()).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        HStack {
            Text(t("app.brand")).font(.caption.bold()).tracking(1)
            Spacer()
            Text(t("calculator.footer")).font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }

    private var statusColor: Color {
        switch rateStatus {
        case .verified: Palette.accent
        case .projected: .orange
        case .custom: .purple
        }
    }

    private var surchargeBinding: Binding<Int> {
        let maximum = max(0, schedule.communityMaxPercent)
        return Binding(
            get: { min(store.draft.communitySurchargePercent, maximum) },
            set: { store.draft.communitySurchargePercent = min(max(0, $0), maximum) }
        )
    }

    private var yearBinding: Binding<String> {
        Binding(
            get: { yearText },
            set: { newValue in
                yearText = String(newValue.filter(\.isNumber).prefix(4))
                store.draft.manufactureYear = Int(yearText) ?? 0
            }
        )
    }

    private var horsepowerBinding: Binding<String> {
        Binding(
            get: { horsepowerText },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber || $0 == "." || $0 == "," }
                horsepowerText = String(filtered.prefix(8))
                let entered = Double(
                    horsepowerText.replacingOccurrences(of: ",", with: ".")
                ) ?? 0
                store.draft.horsepower = powerUnit.horsepower(from: entered)
            }
        )
    }

    private func syncTextFields() {
        yearText = String(store.draft.manufactureYear)
        horsepowerText = MoneyText.editable(
            powerUnit.value(fromHorsepower: store.draft.horsepower),
            digits: 2,
            locale: store.language.locale
        )
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: store.language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: store.language.locale, arguments: arguments)
    }
}

private struct LiabilityMonthsView: View {
    let taxYear: Int
    @Binding var months: Int
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate: Date

    private var calendar: Calendar { Calendar.current }

    init(taxYear: Int, months: Binding<Int>, language: AppLanguage) {
        self.taxYear = taxYear
        _months = months
        self.language = language
        let calendar = Calendar.current
        // A date before the tax year represents "owned before 1 January".
        let start = calendar.date(from: DateComponents(year: taxYear - 1, month: 12, day: 31)) ?? .now
        let end = calendar.date(from: DateComponents(year: taxYear, month: 12, day: 31)) ?? .now
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    private var computedMonths: Int {
        LiabilityMonths.months(
            in: taxYear,
            acquired: startDate,
            disposed: endDate,
            calendar: calendar
        )
    }

    private var isValidPeriod: Bool { endDate >= startDate }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(t("months.start"), selection: $startDate, displayedComponents: .date)
                    DatePicker(t("months.end"), selection: $endDate, displayedComponents: .date)
                }
                Section {
                    Text(f("months.result", computedMonths))
                        .font(.headline)
                    Text(t("months.note"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !isValidPeriod {
                        Text(t("months.invalid"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(t("months.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("months.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(f("months.apply", computedMonths)) {
                        months = computedMonths
                        dismiss()
                    }
                    .disabled(!isValidPeriod)
                    .accessibilityIdentifier("months.apply")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: arguments)
    }
}
