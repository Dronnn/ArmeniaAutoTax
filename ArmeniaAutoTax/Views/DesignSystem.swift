import SwiftUI

// Semantic, native colors adapt automatically to system light/dark mode.
enum Palette {
    static let ink = Color.primary
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color(red: 0.15, green: 0.53, blue: 0.47)
    static let darkCard = Color(red: 0.075, green: 0.14, blue: 0.17)
    static let muted = Color.secondary
}

enum MoneyText {
    static func number(_ value: Double, digits: Int = 2, locale: Locale = L10n.locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func amount(
        _ value: Double,
        currency: CurrencyCode = .amd,
        digits: Int = 2,
        locale: Locale = L10n.locale
    ) -> String {
        "\(number(value, digits: digits, locale: locale)) \(currency.symbol)"
    }

    /// Editable text without grouping so typing over a value stays valid.
    static func editable(_ value: Double, digits: Int = 2, locale: Locale = L10n.locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// Keeps readable line lengths and control widths on iPad while the
/// surrounding scroll view still fills the window.
struct AppContentWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func appContentWidth() -> some View { modifier(AppContentWidth()) }
}

struct SectionHeader: View {
    let kicker: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(kicker.uppercased())
                .font(.caption2.weight(.bold)).tracking(1.6).foregroundStyle(Palette.accent)
            Text(title).font(.title2.bold()).foregroundStyle(Palette.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SurfaceCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct MetricRow: View {
    var label: String
    var value: String
    var emphasized: Bool = false
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).foregroundStyle(emphasized ? .primary : .secondary)
            Spacer(minLength: 8)
            Text(value).fontWeight(emphasized ? .bold : .medium)
                .monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(emphasized ? .subheadline : .footnote)
    }
}

struct InlineMessage: View {
    let symbol: String
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol).foregroundStyle(Palette.accent)
            Text(message).foregroundStyle(.secondary)
        }
        .font(.footnote)
    }
}
