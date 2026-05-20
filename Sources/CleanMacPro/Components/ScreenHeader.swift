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
                    Text(kicker.uppercased()).font(.system(size: 11, weight: .semibold))
                        .tracking(1).foregroundColor(.text3(theme.dark))
                }
                Text(title).font(.system(size: 30, weight: .bold))
                    .tracking(-0.5).foregroundColor(.text1(theme.dark))
                if let subtitle {
                    Text(subtitle).font(.system(size: 14))
                        .foregroundColor(.text2(theme.dark))
                        .frame(maxWidth: 560, alignment: .leading)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.bottom, 22)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(kicker: String? = nil, title: String, subtitle: String? = nil) {
        self.init(kicker: kicker, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}
