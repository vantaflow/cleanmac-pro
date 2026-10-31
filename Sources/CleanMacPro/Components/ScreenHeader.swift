import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    @Environment(\.theme) private var theme
    var kicker: String? = nil
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
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
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.bottom, 20)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(kicker: String? = nil, title: String, subtitle: String? = nil) {
        self.init(kicker: kicker, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}
