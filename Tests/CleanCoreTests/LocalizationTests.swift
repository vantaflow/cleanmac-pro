import XCTest
@testable import CleanCore

final class LocalizationTests: XCTestCase {
    private func table(_ lang: String, file: StaticString = #filePath, line: UInt = #line) throws -> [String: String] {
        let bundle = try XCTUnwrap(L10n.bundle(for: lang), "\(lang).lproj is missing from the CleanCore bundle", file: file, line: line)
        let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"),
                                "\(lang).lproj has no Localizable.strings", file: file, line: line)
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String],
                             "\(lang) table is not a string dictionary", file: file, line: line)
    }

    /// `%@`, `%lld`, `%.1f`, `%1$@` … (ignores `%%` and stray percent signs).
    private func specifiers(_ s: String) -> [String] {
        let pattern = "%(?:\\d+\\$)?[-+ 0#]*(?:\\d+)?(?:\\.\\d+)?(?:ll|l|h|z)?[@dDiuUxXoOfeEgGcCsSp]"
        let re = try! NSRegularExpression(pattern: pattern)
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
            .map { $0.replacingOccurrences(of: "\\d+\\$", with: "", options: .regularExpression) }
            .sorted()
    }

    func testAllLanguagesShipTheSameKeysAsFrench() throws {
        let fr = try table("fr")
        XCTAssertGreaterThan(fr.count, 300, "the French table looks truncated")
        for lang in L10n.supportedLanguages where lang != "fr" {
            let t = try table(lang)
            let missing = fr.keys.filter { (t[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
            XCTAssertTrue(missing.isEmpty, "\(lang): \(missing.count) key(s) without translation, e.g. \(missing.prefix(5))")
            let extra = t.keys.filter { fr[$0] == nil }
            XCTAssertTrue(extra.isEmpty, "\(lang): keys unknown to fr: \(extra.prefix(5))")
        }
    }

    func testFrenchValuesAreNeverEmpty() throws {
        let fr = try table("fr")
        for (k, v) in fr {
            XCTAssertFalse(v.trimmingCharacters(in: .whitespaces).isEmpty, "fr: empty value for \(k)")
        }
    }

    func testFormatSpecifiersMatchAcrossLanguages() throws {
        let fr = try table("fr")
        for lang in L10n.supportedLanguages where lang != "fr" {
            let t = try table(lang)
            for (key, frValue) in fr {
                guard let value = t[key] else { continue }
                XCTAssertEqual(specifiers(value), specifiers(frValue),
                               "\(lang): format specifiers differ for \"\(key)\" → \"\(value)\"")
                XCTAssertEqual(specifiers(key), specifiers(frValue),
                               "fr: value specifiers differ from the key for \"\(key)\"")
            }
        }
    }

    func testMostStringsAreActuallyTranslated() throws {
        let fr = try table("fr")
        for lang in ["en", "es", "de"] {
            let t = try table(lang)
            let same = fr.filter { t[$0.key] == $0.value }.count
            // Brand names, units and technical terms stay identical; prose must not.
            XCTAssertLessThan(Double(same) / Double(fr.count), 0.2, "\(lang): too many strings left untranslated")
        }
    }

    func testLookupResolvesPerLanguage() throws {
        let expected: [String: (cancel: String, tasks: String)] = [
            "fr": ("Annuler", "Tâches"),
            "en": ("Cancel", "Tasks"),
            "es": ("Cancelar", "Tareas"),
            "de": ("Abbrechen", "Aufgaben"),
        ]
        for (lang, want) in expected {
            let b = try XCTUnwrap(L10n.bundle(for: lang))
            XCTAssertEqual(b.localizedString(forKey: "Annuler", value: nil, table: nil), want.cancel, lang)
            XCTAssertEqual(b.localizedString(forKey: "Tâches", value: nil, table: nil), want.tasks, lang)
        }
    }

    func testInterpolatedKeysResolveWithFormatSpecifiers() throws {
        let de = try XCTUnwrap(L10n.bundle(for: "de"))
        let days = 3
        let name = "foo"
        XCTAssertEqual(String(localized: "Archive vieille de \(days) jours", bundle: de), "Archiv ist 3 Tage alt")
        XCTAssertEqual(String(localized: "Orphelin — aucun package.json dans \(name)", bundle: de),
                       "Verwaist – keine package.json in foo")
        let en = try XCTUnwrap(L10n.bundle(for: "en"))
        XCTAssertEqual(String(localized: "Empreintes perceptuelles \(1)/\(9)…", bundle: en), "Perceptual hashes 1/9…")
    }

    func testModuleTitlesAndSubtitlesAreLocalizable() {
        for m in ModuleID.allCases {
            XCTAssertFalse(m.title.isEmpty, "module title \(m.rawValue)")
            XCTAssertFalse(m.subtitle.isEmpty, "module subtitle \(m.rawValue)")
            XCTAssertFalse(m.title.contains("%"), "unresolved format in title of \(m.rawValue)")
        }
    }
}
