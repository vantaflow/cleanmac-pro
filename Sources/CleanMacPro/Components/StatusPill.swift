import SwiftUI

enum PillStatus { case good, warn, bad, info
    var colors: (bg: Color, fg: Color, dot: Color) {
        switch self {
        case .good: return (Color.cmpGood.opacity(0.14), Color(red: 15/255, green: 138/255, blue: 55/255), .cmpGood)
        case .warn: return (Color.cmpWarn.opacity(0.16), Color(red: 166/255, green: 104/255, blue: 10/255), .cmpWarn)
        case .bad:  return (Color.cmpBad.opacity(0.14),  Color(red: 197/255, green: 37/255,  blue: 29/255), .cmpBad)
        case .info: return (Color.cmpInfo.opacity(0.12), Color(red: 6/255,   green: 86/255,  blue: 181/255), .cmpInfo)
        }
    }
}

struct StatusPill: View {
    var status: PillStatus = .good
    var text: String

    var body: some View {
        let c = status.colors
        HStack(spacing: 6) {
            Circle().fill(c.dot).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11.5, weight: .semibold))
        }
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(c.bg)
        .foregroundColor(c.fg)
        .clipShape(Capsule())
    }
}
