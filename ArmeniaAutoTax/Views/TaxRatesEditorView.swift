import SwiftUI
import UIKit

struct TaxRatesEditorView: View {
    @ObservedObject var taxRates: TaxRatesStore
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var selectedYear: Int
    @State private var draft: TaxRateEditorDraft
    @State private var originalDraft: TaxRateEditorDraft
    @State private var pendingYear: Int?
    @State private var showDiscard = false
    @State private var showReset = false
    @FocusState private var focusedField: String?

    init(taxRates: TaxRatesStore, language: AppLanguage, initialYear: Int) {
        self.taxRates = taxRates
        self.language = language
        let year = TaxScheduleStore.clampedYear(initialYear)
        let draft = TaxRateEditorDraft(schedule: taxRates.schedule(for: year))
        _selectedYear = State(initialValue: year)
        _draft = State(initialValue: draft)
        _originalDraft = State(initialValue: draft)
    }

    private var isDirty: Bool { draft != originalDraft }
    private var status: TaxRateStatus {
        taxRates.isCustomized(selectedYear) ? .custom : taxRates.defaultSchedule(for: selectedYear).status
    }
    private var issues: [TaxRateValidationIssue] { draft.validationIssues }
    private var canSave: Bool { isDirty && issues.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    kicker: t("rates.editor.kicker"),
                    title: t("rates.editor.title"),
                    subtitle: t("rates.editor.subtitle")
                )
                yearCard
                warningCard
                passengerCard
                busCargoCard
                otherCard
                advancedCard
                if !issues.isEmpty {
                    validationCard
                }
                previewCard
                resetButton
            }
            .padding(16)
            .appContentWidth()
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(Palette.background)
        .navigationTitle(t("rates.editor.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(t("rates.editor.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(t("rates.editor.save")) { save() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("rates.save")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(t("common.ok")) { focusedField = nil }
            }
        }
        .alert(
            t("rates.editor.reset"),
            isPresented: $showReset
        ) {
            Button(t("rates.editor.reset"), role: .destructive) { resetToDefaults() }
            Button(t("common.cancel"), role: .cancel) {}
        } message: {
            Text(f("rates.editor.reset.confirm", String(selectedYear)))
        }
        .alert(
            t("rates.editor.discard"),
            isPresented: $showDiscard
        ) {
            Button(t("rates.editor.discard.action"), role: .destructive) {
                if let pendingYear {
                    selectedYear = pendingYear
                    loadDraft(for: pendingYear)
                }
                pendingYear = nil
            }
            Button(t("rates.editor.keepEditing"), role: .cancel) {
                pendingYear = nil
            }
        } message: {
            Text(t("rates.editor.discard.body"))
        }
    }

    private var yearCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(t("rates.editor.year")).font(.headline)
                    Spacer()
                    Picker(t("rates.editor.year"), selection: yearBinding) {
                        ForEach(TaxScheduleStore.availableYears(), id: \.self) { year in
                            Text(verbatim: "\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.accent)
                    .accessibilityIdentifier("rates.year")
                }
                HStack(spacing: 8) {
                    Text(verbatim: "\(selectedYear)")
                        .font(.subheadline.weight(.semibold))
                    Text(t("rates.status.\(status.rawValue)"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(statusColor.opacity(0.14), in: Capsule())
                        .foregroundStyle(statusColor)
                }
                if status == .verified {
                    Text(f("rules.status.verified",
                           taxRates.defaultSchedule(for: selectedYear).verifiedOn ?? ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var warningCard: some View {
        SurfaceCard {
            InlineMessage(symbol: "exclamationmark.triangle", message: t("rates.editor.warning"))
        }
    }

    private var passengerCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("rates.editor.passenger")).font(.headline)
                bandRow(
                    title: t("rates.editor.upTo"),
                    maxText: $draft.passenger1Max,
                    rateText: $draft.passenger1Rate,
                    maxIdentifier: "rates.passenger1Max",
                    rateIdentifier: "rates.passenger1Rate"
                )
                bandRow(
                    title: t("rates.editor.upTo"),
                    maxText: $draft.passenger2Max,
                    rateText: $draft.passenger2Rate,
                    maxIdentifier: "rates.passenger2Max",
                    rateIdentifier: "rates.passenger2Rate"
                )
                openBandRow(
                    title: t("rates.editor.above"),
                    lowerBound: draft.passenger2Max,
                    rateText: $draft.passenger3Rate,
                    rateIdentifier: "rates.passenger3Rate"
                )
                Divider()
                HStack(spacing: 8) {
                    Text(t("rates.editor.above"))
                    numberField($draft.extraAbove, identifier: "rates.extraAbove", keyboard: .decimalPad)
                    Text(t("common.hp"))
                    Spacer()
                    numberField($draft.extraRate, identifier: "rates.extraRate", keyboard: .numberPad)
                    Text(t("rates.editor.rate"))
                }
                .font(.subheadline)
            }
        }
    }

    private var busCargoCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("rates.editor.busCargo")).font(.headline)
                bandRow(
                    title: t("rates.editor.upTo"),
                    maxText: $draft.busCargo1Max,
                    rateText: $draft.busCargo1Rate,
                    maxIdentifier: "rates.busCargo1Max",
                    rateIdentifier: "rates.busCargo1Rate"
                )
                openBandRow(
                    title: t("rates.editor.above"),
                    lowerBound: draft.busCargo1Max,
                    rateText: $draft.busCargo2Rate,
                    rateIdentifier: "rates.busCargo2Rate"
                )
            }
        }
    }

    private var otherCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("rates.editor.other")).font(.headline)
                HStack {
                    Text(t("rules.rates.motorcycle"))
                    Spacer()
                    numberField($draft.motorcycleRate, identifier: "rates.motorcycleRate", keyboard: .numberPad)
                    Text(t("rates.editor.rate"))
                }
                HStack {
                    Text(t("rules.rates.other"))
                    Spacer()
                    numberField($draft.otherRate, identifier: "rates.otherRate", keyboard: .numberPad)
                    Text(t("rates.editor.rate"))
                }
            }
            .font(.subheadline)
        }
    }

    private var advancedCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 13) {
                numberRow(
                    label: t("rates.editor.fullTaxYears"),
                    text: $draft.fullTaxYears,
                    identifier: "rates.fullTaxYears",
                    keyboard: .numberPad
                )
                numberRow(
                    label: t("rates.editor.discountStep"),
                    text: $draft.discountStep,
                    identifier: "rates.discountStep",
                    keyboard: .numberPad
                )
                numberRow(
                    label: t("rates.editor.maxDiscount"),
                    text: $draft.maxDiscount,
                    identifier: "rates.maxDiscount",
                    keyboard: .numberPad
                )
                numberRow(
                    label: t("rates.editor.cargoExemption"),
                    text: $draft.cargoExemptionAge,
                    identifier: "rates.cargoExemptionAge",
                    keyboard: .numberPad
                )
                numberRow(
                    label: t("rates.editor.communityMax"),
                    text: $draft.communityMax,
                    identifier: "rates.communityMax",
                    keyboard: .numberPad
                )
                Divider()
                Toggle(t("rates.editor.evEnabled"), isOn: $draft.evEnabled)
                    .accessibilityIdentifier("rates.evEnabled")
                if draft.evEnabled {
                    numberRow(
                        label: t("rates.editor.evThreshold"),
                        text: $draft.evThreshold,
                        identifier: "rates.evThreshold",
                        keyboard: .decimalPad
                    )
                    numberRow(
                        label: t("rates.editor.evDivisor"),
                        text: $draft.evDivisor,
                        identifier: "rates.evDivisor",
                        keyboard: .decimalPad
                    )
                    numberRow(
                        label: t("rates.editor.evExcessDivisor"),
                        text: $draft.evExcessDivisor,
                        identifier: "rates.evExcessDivisor",
                        keyboard: .decimalPad
                    )
                }
            }
            .padding(.top, 10)
        } label: {
            Label(t("calculator.advanced"), systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
        }
    }

    private var validationCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("rates.editor.invalid")).font(.headline)
                ForEach(Array(Set(issues).map(\.rawValue).sorted()), id: \.self) { issue in
                    Text(validationText(issue))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var previewCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("rates.editor.preview")).font(.headline)
                Text(f("rates.editor.previewLine",
                       draft.previewAnnualTax.map { MoneyText.amount($0, digits: 0) } ?? "—"))
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            showReset = true
        } label: {
            Text(t("rates.editor.reset"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!isDirty && !taxRates.isCustomized(selectedYear))
        .accessibilityIdentifier("rates.reset")
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { selectedYear },
            set: { newYear in
                guard newYear != selectedYear else { return }
                if isDirty {
                    pendingYear = newYear
                    showDiscard = true
                } else {
                    selectedYear = newYear
                    loadDraft(for: newYear)
                }
            }
        )
    }

    private var statusColor: Color {
        switch status {
        case .verified: Palette.accent
        case .projected: .orange
        case .custom: .purple
        }
    }

    private func save() {
        guard canSave,
              let schedule = draft.makeSchedule(
                  year: selectedYear,
                  status: .custom,
                  source: "Manual override"
              ),
              schedule.isValid
        else { return }
        taxRates.save(schedule)
        dismiss()
    }

    private func resetToDefaults() {
        taxRates.reset(selectedYear)
        loadDraft(for: selectedYear)
    }

    private func loadDraft(for year: Int) {
        let schedule = taxRates.schedule(for: year)
        let loaded = TaxRateEditorDraft(schedule: schedule)
        draft = loaded
        originalDraft = loaded
    }

    private func validationText(_ issue: String) -> String {
        t("rates.editor.invalid.\(issue)")
    }

    private func bandRow(
        title: String,
        maxText: Binding<String>,
        rateText: Binding<String>,
        maxIdentifier: String,
        rateIdentifier: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
            numberField(maxText, identifier: maxIdentifier, keyboard: .decimalPad)
            Text(t("common.hp"))
            Spacer()
            numberField(rateText, identifier: rateIdentifier, keyboard: .numberPad)
            Text(t("rates.editor.rate"))
        }
        .font(.subheadline)
    }

    private func openBandRow(
        title: String,
        lowerBound: String,
        rateText: Binding<String>,
        rateIdentifier: String
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Text(lowerBound)
            Text(t("common.hp"))
            Spacer()
            numberField(rateText, identifier: rateIdentifier, keyboard: .numberPad)
            Text(t("rates.editor.rate"))
        }
        .font(.subheadline)
    }

    private func numberRow(
        label: String,
        text: Binding<String>,
        identifier: String,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            numberField(text, identifier: identifier, keyboard: keyboard)
        }
        .font(.subheadline)
    }

    private func numberField(
        _ text: Binding<String>,
        identifier: String,
        keyboard: UIKeyboardType
    ) -> some View {
        TextField("", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(width: 92)
            .focused($focusedField, equals: identifier)
            .accessibilityIdentifier(identifier)
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: language)
    }

    private func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), locale: language.locale, arguments: arguments)
    }
}
