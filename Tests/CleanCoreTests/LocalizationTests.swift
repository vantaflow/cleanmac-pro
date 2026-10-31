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

    // MARK: - Plurals (Localizable.stringsdict)

    private func plural(_ lang: String, _ value: String.LocalizationValue) throws -> String {
        let b = try XCTUnwrap(L10n.bundle(for: lang))
        return String(localized: value, bundle: b, locale: Locale(identifier: lang))
    }

    func testStringsdictIsShippedInEveryLanguage() throws {
        for lang in L10n.supportedLanguages {
            let b = try XCTUnwrap(L10n.bundle(for: lang))
            XCTAssertNotNil(b.url(forResource: "Localizable", withExtension: "stringsdict"), "\(lang): stringsdict missing from the bundle")
        }
    }

    func testPluralsResolveOneAndOtherInEveryLanguage() throws {
        let one = 1, three = 3
        XCTAssertEqual(try plural("fr", "\(one) supprimé(s) définitivement"), "1 supprimé définitivement")
        XCTAssertEqual(try plural("fr", "\(three) supprimé(s) définitivement"), "3 supprimés définitivement")
        XCTAssertEqual(try plural("fr", "\(one) élément(s) supprimé(s) définitivement : rien à restaurer"), "1 élément supprimé définitivement : rien à restaurer")
        XCTAssertEqual(try plural("fr", "\(three) élément(s) supprimé(s) définitivement : rien à restaurer"), "3 éléments supprimés définitivement : rien à restaurer")
        XCTAssertEqual(try plural("en", "\(one) élément(s) restauré(s)"), "1 item restored")
        XCTAssertEqual(try plural("en", "\(three) élément(s) restauré(s)"), "3 items restored")
        XCTAssertEqual(try plural("es", "\(one) élément(s) restauré(s)"), "1 elemento restaurado")
        XCTAssertEqual(try plural("es", "\(three) élément(s) restauré(s)"), "3 elementos restaurados")
        XCTAssertEqual(try plural("de", "\(one) mise(s) à jour"), "1 Update")
        XCTAssertEqual(try plural("de", "\(three) mise(s) à jour"), "3 Updates")
        XCTAssertEqual(try plural("fr", "\(one) mise(s) à jour"), "1 mise à jour")
        XCTAssertEqual(try plural("fr", "\(three) mise(s) à jour"), "3 mises à jour")
    }

    func testPluralsWithSeveralArguments() throws {
        let size = "5 Mo"
        XCTAssertEqual(try plural("fr", "\(size) · \(1) élément(s) · \(size)"), "5 Mo · 1 élément · 5 Mo")
        XCTAssertEqual(try plural("en", "\(size) · \(3) élément(s) · \(size)"), "5 Mo · 3 items · 5 Mo")
        XCTAssertEqual(try plural("fr", "Mises à jour : \(1) installée(s), \(2) à faire à la main, \(3) en échec."),
                       "Mises à jour : 1 installée, 2 à faire à la main, 3 en échec.")
        XCTAssertEqual(try plural("fr", "Mises à jour : \(2) installée(s), \(0) à faire à la main, \(1) en échec."),
                       "Mises à jour : 2 installées, 0 à faire à la main, 1 en échec.")
        XCTAssertEqual(try plural("es", "Mises à jour : \(1) installée(s), \(2) à faire à la main, \(3) en échec."),
                       "Actualizaciones: 1 instalada, 2 por hacer a mano, 3 fallidas.")
        XCTAssertEqual(try plural("fr", "\(1) fichier(s) choisis (\(size)) iront à la Corbeille avec « Lancer » : vous pourrez les restaurer."),
                       "1 fichier choisi (5 Mo) ira à la Corbeille avec « Lancer » : vous pourrez le restaurer.")
    }

    func testNoVisibleStringKeepsTheLegacyPluralMarker() throws {
        for lang in L10n.supportedLanguages {
            for n in [0, 1, 2, 5] {
                let values: [String.LocalizationValue] = ["\(n) menace(s)", "\(n) échec(s)", "\(n) mise(s) à jour"]
                for v in values {
                    XCTAssertFalse(try plural(lang, v).contains("(s)"), "\(lang) \(n)")
                    XCTAssertFalse(try plural(lang, v).contains("(e)"), "\(lang) \(n)")
                }
            }
        }
    }
}
