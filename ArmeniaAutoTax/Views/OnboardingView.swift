import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    brand
                    languageSection
                    introduction
                    Text(L10n.string("onboarding.footer"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    continueButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 30)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
                .transaction { $0.animation = nil }
                .animation(nil, value: store.language)
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 9) {
            Text("֏")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.accent)
            Text(L10n.string("app.brand"))
                .font(.caption.bold())
                .tracking(2)
                .foregroundStyle(Palette.accent)
        }
        .accessibilityHidden(true)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 40))
                .foregroundStyle(Palette.accent)
                .frame(width: 62, height: 62)
                .background(Palette.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
            Text(L10n.string("onboarding.title"))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.string("onboarding.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("onboarding.language"))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            ForEach(AppLanguage.allCases) { language in
                Button {
                    withTransaction(Transaction(animation: nil)) {
                        store.language = language
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(language.nativeName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.accent)
                            .opacity(store.language == language ? 1 : 0)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(store.language == language ? Palette.accent.opacity(0.1) : Palette.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(store.language == language ? Palette.accent : Color.secondary.opacity(0.2),
                                            lineWidth: store.language == language ? 1.5 : 1)
                            }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.language.\(language.rawValue)")
                .accessibilityAddTraits(store.language == language ? .isSelected : [])
            }
        }
    }

    private var continueButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.28)) {
                store.completeOnboarding()
            }
        } label: {
            Text(L10n.string("onboarding.continue"))
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Palette.accent)
        .accessibilityIdentifier("onboarding.continue")
    }
}
