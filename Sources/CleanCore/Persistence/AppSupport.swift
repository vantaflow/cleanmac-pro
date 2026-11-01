import Foundation

/// Where CleanMac Pro keeps its small JSON files (exclusions, history, schedule).
public enum AppSupport {
    public static var defaultDirectory: URL {
        // UI test mode (`--ui-test`): keep history/exclusions inside the run's
        // output folder so a local run never writes into the user's real data.
        let args = CommandLine.arguments
        if args.contains("--ui-test") {
            let out = args.first(where: { $0.hasPrefix("--ui-test-out=") })
                .map { URL(fileURLWithPath: String($0.dropFirst("--ui-test-out=".count))) }
                ?? FileManager.default.temporaryDirectory.appendingPathComponent("cleanmac-ui")
            return out.appendingPathComponent("support", isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FS.home.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("CleanMac Pro", isDirectory: true)
    }

    static func load<T: Decodable>(_ type: T.Type, from file: URL) -> T? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(value).write(to: file, options: .atomic)
    }
}
