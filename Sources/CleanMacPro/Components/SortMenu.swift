import SwiftUI
import CleanCore

struct SortMenu: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject var appState: AppState
    let module: ModuleID

    var body: some View {
        let state = appState.state(for: module)
        Menu {
            ForEach(SortKey.allCases) { key in
                Button {
                    appState.update(module) { s in
                        if s.sortKey == key { s.sortDescending.toggle() }
                        else { s.sortKey = key; s.sortDescending = (key != .name) }
                    }
                } label: {
                    HStack {
                        Text(key.label)
                        if state.sortKey == key {
                            Image(systemName: state.sortDescending ? "arrow.down" : "arrow.up")
                        }
                    }
                }
            }
            Divider()
            Button {
                appState.update(module) { $0.sortDescending.toggle() }
            } label: {
                Label(state.sortDescending ? "Ordre décroissant ✓" : "Ordre croissant ✓",
                      systemImage: "arrow.up.arrow.down")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: state.sortDescending ? "arrow.down" : "arrow.up")
                    .font(.system(size: 11, weight: .semibold))
                Text("Trier · \(state.sortKey.label)")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(Color.black.opacity(theme.dark ? 0.25 : 0.06))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.hairline(theme.dark), lineWidth: 0.5))
            .foregroundColor(.text1(theme.dark))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
