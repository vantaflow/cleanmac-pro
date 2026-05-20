import SwiftUI

/// Bridges the prototype's icon names to SF Symbols.
struct CmpIcon: View {
    let name: String
    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(color)
            .frame(width: size, height: size)
    }

    private var symbol: String {
        switch name {
        case "dashboard": return "gauge.medium"
        case "scan":      return "scanner"
        case "broom":     return "trash.slash"
        case "app":       return "square.grid.2x2"
        case "files":     return "doc.on.doc"
        case "shield":    return "shield.lefthalf.filled"
        case "wrench":    return "wrench.and.screwdriver"
        case "chip":      return "cpu"
        case "sparkle":   return "sparkles"
        case "chevron":   return "chevron.right"
        case "check":     return "checkmark"
        case "trash":     return "trash"
        case "play":      return "play.fill"
        case "pause":     return "pause.fill"
        case "close":     return "xmark"
        case "search":    return "magnifyingglass"
        case "bolt":      return "bolt.fill"
        case "moon":      return "moon"
        case "info":      return "info.circle"
        case "arrow":     return "arrow.up.circle"
        case "ram":       return "memorychip"
        case "disk":      return "internaldrive"
        case "battery":   return "battery.100"
        case "network":   return "wifi"
        case "eye":       return "eye"
        case "cookie":    return "fork.knife"
        case "folder":    return "folder"
        case "lock":      return "lock.shield"
        default:          return "questionmark.circle"
        }
    }
}
