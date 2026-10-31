import Foundation

/// Where CleanMac Pro keeps its small JSON files (exclusions, history, schedule).
public enum AppSupport {
    public static var defaultDirectory: URL {
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
