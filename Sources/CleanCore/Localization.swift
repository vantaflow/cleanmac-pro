import Foundation

/// Localization entry point shared by CleanCore and the app.
///
/// Keys are the French source text. Interpolations become format specifiers
/// (`%@`, `%lld`) automatically, e.g. `L("Archive vieille de \(days) jours")`
/// looks up `"Archive vieille de %lld jours"` in `Localizable.strings`.
public enum L10n {
    public static let supportedLanguages = ["fr", "en", "es", "de"]

    /// SwiftPM's generated `Bundle.module` accessor only looks next to the
    /// executable (and at an absolute build path), so inside a `.app` we look in
    /// `Contents/Resources` first. `Bundle.module` stays the last resort.
    public static let bundle: Bundle = {
        let name = "CleanMacPro_CleanCore.bundle"
        for base in [Bundle.main.resourceURL, Bundle.main.bundleURL] {
            if let url = base?.appendingPathComponent(name), let b = Bundle(url: url) { return b }
        }
        return Bundle.module
    }()

    /// Language the UI is displayed in (one of `supportedLanguages`).
    public static var languageCode: String {
        bundle.preferredLocalizations.first ?? "fr"
    }

    /// Bundle restricted to one language (used by tests and tooling).
    public static func bundle(for language: String) -> Bundle? {
        guard let path = bundle.path(forResource: language, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}

/// Look up a key without any formatting, for `String(format:)` templates that
/// contain `%` specifiers (`String(format: LK("%.1f Go"), value)`).
public func LK(_ key: String) -> String {
    L10n.bundle.localizedString(forKey: key, value: nil, table: nil)
}

/// Translate a French source string (with optional interpolations).
public func L(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: L10n.bundle)
}
