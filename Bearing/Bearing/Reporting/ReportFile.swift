import Foundation

/// The one temporary PDF that the share sheet reads. It holds the person's numbers,
/// so it is locked while the phone is locked and removed when no longer needed.
enum ReportFile {
    static var url: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Bearing-report.pdf")
    }

    static func write(_ data: Data) throws -> URL {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
