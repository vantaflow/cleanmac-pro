import SwiftUI

/// Geometry reported to the UI test (`--ui-test` only): where the sidebar sits
/// and whether the active screen is wider than its pane. Lets the test catch
/// any horizontal overflow on every screen and in every language.
@MainActor
final class LayoutProbe {
    static let shared = LayoutProbe()
    var railMinX: CGFloat = 0
    var contentWidth: CGFloat = 0
    var paneWidth: CGFloat = 0

    @ViewBuilder
    static func reporter(_ key: ReferenceWritableKeyPath<LayoutProbe, CGFloat>, minX: Bool = false) -> some View {
        if UITestDriver.isEnabled {
            GeometryReader { g in
                let f = g.frame(in: .global)
                let v = minX ? f.minX : f.width
                Color.clear
                    .onAppear { shared[keyPath: key] = v }
                    .onChange(of: v) { _, n in shared[keyPath: key] = n }
            }
        }
    }
}
