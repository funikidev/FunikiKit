import Foundation

#if canImport(UIKit)
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

#if canImport(AppKit)
import AppKit
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
    public static func shareURL(_ pack: FunikiPack, base: String = "https://funikidev.github.io/generator.html") -> URL? {
        guard let data = try? jsonData(pack) else { return nil }
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "\(base)?pack=\(b64)")
    }

    // MARK: - QR Code

#if canImport(CoreImage)
    /// Generate a QR code image from the pack's share URL.
    /// Returns nil if the pack is too large to encode in a QR code.
    public static func qrImage(_ pack: FunikiPack, size: CGFloat = 300) -> PlatformImage? {
        guard let url = shareURL(pack) else { return nil }
        let string = url.absoluteString
        guard let inputData = string.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = inputData
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

#if canImport(UIKit)
        return UIImage(cgImage: cgImage)
#elseif canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
#endif
    }
#endif

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
        if case .string(let s) = pack.persona, s.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("persona is empty")
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
    case packTooLargeForQR
    case validationFailed([String])

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode pack as JSON"
        case .packTooLargeForQR: return "Pack is too large to encode as a QR code"
        case .validationFailed(let errors): return "Validation failed: \(errors.joined(separator: ", "))"
        }
    }
}

// MARK: - Cross-platform image type alias

#if canImport(UIKit)
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
public typealias PlatformImage = NSImage
#endif
