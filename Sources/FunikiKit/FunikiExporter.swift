import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - FunikiExporter
//
// Handles all output formats for a FunikiPack.
// Developers call one function; the SDK handles file creation, encoding, and sharing.

public enum FunikiExporter {

    // MARK: - Encode

    /// Encode pack to a formatted JSON string.
    public static func jsonString(_ pack: FunikiPack) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(pack)
        guard let string = String(data: data, encoding: .utf8) else {
            throw FunikiExportError.encodingFailed
        }
        return string
    }

    /// Encode pack to Data.
    public static func jsonData(_ pack: FunikiPack) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(pack)
    }

    // MARK: - File

    /// Write pack to a temporary .funiki file and return the URL.
    /// The file is valid for the current process lifetime — use immediately for sharing.
    public static func temporaryFileURL(_ pack: FunikiPack) throws -> URL {
        let data = try jsonData(pack)
        let filename = sanitizeFilename(pack.name) + ".funiki.json"
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("funiki", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    /// Write pack to a specified URL.
    public static func write(_ pack: FunikiPack, to url: URL) throws {
        let data = try jsonData(pack)
        try data.write(to: url)
    }

    // MARK: - Share URL

    /// Encode the pack as a base64 share URL pointing to the funiki web generator.
    /// Recipients can open this URL to view and use the pack without any app.
    public static func shareURL(_ pack: FunikiPack, base: String = "https://funikidev.github.io/pack.html") -> URL? {
        guard let data = try? jsonData(pack) else { return nil }
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "\(base)?pack=\(b64)")
    }

    // MARK: - System Share Sheet (iOS / iPadOS)

#if canImport(UIKit) && !os(watchOS)
    /// Present the system share sheet for a .funiki file.
    /// Call from a button action — pass the button's UIView for iPad popover anchor.
    @MainActor
    public static func presentShareSheet(
        for pack: FunikiPack,
        from sourceView: UIView? = nil,
        in viewController: UIViewController? = nil
    ) {
        guard let fileURL = try? temporaryFileURL(pack) else { return }

        var items: [Any] = [fileURL]

        // Also include the share URL as a fallback for recipients without the app
        if let shareURL = shareURL(pack) {
            items.append(shareURL)
        }

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = [.assignToContact, .saveToCameraRoll]

        let presenter = viewController ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first(where: \.isKeyWindow)?.rootViewController

        if let popover = vc.popoverPresentationController, let source = sourceView {
            popover.sourceView = source
            popover.sourceRect = source.bounds
        }

        presenter?.present(vc, animated: true)
    }
#endif

    // MARK: - Validation

    /// Quick validation before export. Returns error strings if invalid.
    public static func validate(_ pack: FunikiPack) -> [String] {
        var errors: [String] = []
        if pack.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("name is empty")
        }
        if pack.privacy == "mask" {
            if pack.payload == nil || pack.payload?.isEmpty == true {
                errors.append("payload is empty (required when privacy=mask)")
            }
        } else {
            if pack.persona == nil {
                errors.append("persona is missing")
            } else if case .some(.string(let s)) = pack.persona,
                      s.trimmingCharacters(in: .whitespaces).isEmpty {
                errors.append("persona is empty")
            }
        }
        if let turns = pack.turns, turns < 0 {
            errors.append("turns must be >= 0")
        }
        let major = pack.funiki.split(separator: ".").first.map(String.init) ?? ""
        if major != "1" { errors.append("unsupported major version: \(pack.funiki)") }
        return errors
    }

    // MARK: - Private

    private static func sanitizeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        return name
            .lowercased()
            .components(separatedBy: allowed.inverted)
            .joined(separator: "-")
            .trimmingCharacters(in: .init(charactersIn: "-"))
            .prefix(50)
            .description
    }
}

// MARK: - Error

public enum FunikiExportError: Error, LocalizedError {
    case encodingFailed
    case validationFailed([String])

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode pack as JSON"
        case .validationFailed(let errors): return "Validation failed: \(errors.joined(separator: ", "))"
        }
    }
}
