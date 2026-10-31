import SwiftUI

enum PillStatus { case good, warn, bad, info, neutral
    var colors: (bg: Color, fg: Color, dot: Color) {
        switch self {
        case .good:    return (Color.cmpGood.opacity(0.16), .adaptive(0x7BE29A, 0x1E7A3A), .cmpGood)
        case .warn:    return (Color.cmpWarn.opacity(0.16), .adaptive(0xFFCF7A, 0x8A5A00), .cmpWarn)
        case .bad:     return (Color.cmpBad.opacity(0.16),  .adaptive(0xFF9A94, 0xB8261F), .cmpBad)
        case .info:    return (Accent.blue.tint, Accent.blue.soft, .cmpInfo)
        case .neutral: return (Accent.slate.tint, Accent.slate.soft, .adaptive(0x8A91A1, 0x7C8394))
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
