import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    @Environment(\.theme) private var theme
    var kicker: String? = nil
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        // Side by side when the actions leave the text a readable column (≥ 340 pt);
        // otherwise the actions go on their own row below, right-aligned, so the
        // title is never truncated (long languages, narrow windows).
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 24) {
                titleBlock.frame(minWidth: 340, idealWidth: 340, maxWidth: .infinity, alignment: .leading)
                trailing().fixedSize()
            }
            VStack(alignment: .leading, spacing: 14) {
                titleBlock
                HStack { Spacer(minLength: 0); trailing() }
            }
        }
        .padding(.bottom, 20)
    }

    private var titleBlock: some View {
            VStack(alignment: .leading, spacing: 6) {
                if let kicker {
                    Text(kicker)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.accent.soft)
                }
                Text(title)
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundColor(.text1(theme.dark))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14.5))
                        .foregroundColor(.text2(theme.dark))
                        .lineSpacing(2)
                        .frame(maxWidth: 620, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(kicker: String? = nil, title: String, subtitle: String? = nil) {
        self.init(kicker: kicker, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}
