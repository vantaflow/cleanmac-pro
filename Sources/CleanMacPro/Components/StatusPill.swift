import SwiftUI

enum PillStatus { case good, warn, bad, info, neutral
    var colors: (bg: Color, fg: Color, dot: Color) {
        switch self {
        case .good:    return (Color.cmpGood.opacity(0.16), Color(hex: 0x7BE29A), .cmpGood)
        case .warn:    return (Color.cmpWarn.opacity(0.16), Color(hex: 0xFFCF7A), .cmpWarn)
        case .bad:     return (Color.cmpBad.opacity(0.16),  Color(hex: 0xFF9A94), .cmpBad)
        case .info:    return (Color(hex: 0x16294A), Color(hex: 0x9EC0FF), .cmpInfo)
        case .neutral: return (Color(hex: 0x262B36), Color(hex: 0xC4CAD6), Color(hex: 0x8A91A1))
        }
    }
}

struct StatusPill: View {
    var status: PillStatus = .good
    var text: String
    var dot: Bool = true

    var body: some View {
        let c = status.colors
        HStack(spacing: 6) {
            if dot { Circle().fill(c.dot).frame(width: 6, height: 6) }
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(c.bg))
        .foregroundColor(c.fg)
    }
}
