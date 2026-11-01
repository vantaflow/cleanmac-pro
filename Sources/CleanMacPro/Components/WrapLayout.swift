import SwiftUI

/// Lays children out left to right and wraps to a new line when the proposed
/// width is used up; every line is centered.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    private func lines(_ subviews: Subviews, width: CGFloat) -> [[(Int, CGSize)]] {
        var result: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let size = v.sizeThatFits(.unspecified)
            let needed = result[result.count - 1].isEmpty ? size.width : x + spacing + size.width
            if needed > width, !result[result.count - 1].isEmpty {
                result.append([(i, size)])
                x = size.width
            } else {
                result[result.count - 1].append((i, size))
                x = needed
            }
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let ls = lines(subviews, width: maxWidth)
        var width: CGFloat = 0, height: CGFloat = 0
        for (n, line) in ls.enumerated() {
            let w = line.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, line.count - 1))
            width = max(width, w)
            height += (line.map(\.1.height).max() ?? 0) + (n > 0 ? lineSpacing : 0)
        }
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(subviews, width: bounds.width) {
            let w = line.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, line.count - 1))
            let h = line.map(\.1.height).max() ?? 0
            var x = bounds.minX + max(0, (bounds.width - w) / 2)
            for (i, size) in line {
                subviews[i].place(at: CGPoint(x: x, y: y + (h - size.height) / 2),
                                  anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += h + lineSpacing
        }
    }
}
