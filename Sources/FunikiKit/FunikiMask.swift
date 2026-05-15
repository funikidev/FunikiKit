import Foundation

// MARK: - FunikiMask
//
// Mask / unmask transforms for FunikiPack.
//
// "mask" wraps sensitive fields (persona, relationship, core, memory, rules, x_*)
// into a base64-encoded `payload` string. This is *obfuscation*, not encryption —
// see spec §17. The mask form is intended for distribution; SDKs and tools operate
// on the open form.

public enum FunikiMask {

    public enum MaskError: Error, LocalizedError {
        case missingPayload
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
            case .missingPayload: return "Cannot unmask: missing payload"
            case .decodeFailed(let s): return "Cannot unmask payload: \(s)"
            }
        }
    }

    private static let schemaURL = "https://funiki.dev/schema/v1.1"
    private static let currentVersion = "1.1"

    // MARK: - mask

    /// Convert an open FunikiPack into a mask FunikiPack.
    /// Sensitive fields are serialized to JSON, base64-encoded, and placed in `payload`.
    /// The activation is regenerated with the decode prelude so the file is self-contained
    /// for hand-paste delivery to an LLM.
    public static func mask(_ pack: FunikiPack) throws -> FunikiPack {
        if pack.privacy == "mask" { return pack }

        var inner: [String: AnyEncodable] = [:]
        if let p = pack.persona       { inner["persona"]      = AnyEncodable(p) }
        if let r = pack.relationship  { inner["relationship"] = AnyEncodable(r) }
        if let c = pack.core, !c.isEmpty { inner["core"]      = AnyEncodable(c) }
        if let m = pack.memory        { inner["memory"]       = AnyEncodable(m) }
        if let r = pack.rules         { inner["rules"]        = AnyEncodable(r) }
        if let exts = pack.extensions {
            for (k, v) in exts { inner[k] = AnyEncodable(v) }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bodyData = try encoder.encode(inner)
        let payload = bodyData.base64EncodedString()

        let act = FunikiActivation.generate(name: pack.name, turns: pack.turns, masked: true)

        return FunikiPack(
            funiki: currentVersion,
            name: pack.name,
            schema: schemaURL,
            privacy: "mask",
            payload: payload,
            activation: act,
            persona: nil,
            relationship: nil,
            core: nil,
            memory: nil,
            rules: nil,
            turns: pack.turns,
            fadeout: pack.fadeout,
            lang: pack.lang,
            origin: pack.origin,
            creator: pack.creator,
            extensions: nil
        )
    }

    // MARK: - unmask

    /// Convert a mask FunikiPack into an open FunikiPack. Idempotent on already-open packs.
    public static func unmask(_ pack: FunikiPack) throws -> FunikiPack {
        if pack.privacy != "mask" { return pack }
        guard let payload = pack.payload, !payload.isEmpty else {
            throw MaskError.missingPayload
        }
        guard let bodyData = Data(base64Encoded: payload) else {
            throw MaskError.decodeFailed("invalid base64")
        }

        // Decode the inner object using FunikiPack's own coding container so that
        // x_ extensions and field unions (persona union, memory union, etc.) round-trip.
        // We wrap the inner object back into a top-level pack shape that the FunikiPack
        // decoder understands: { funiki, name, ...inner }.
        guard var innerJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            throw MaskError.decodeFailed("payload is not a JSON object")
        }
        innerJSON["funiki"] = currentVersion
        innerJSON["name"] = pack.name
        if let t = pack.turns { innerJSON["turns"] = t }
        if let f = pack.fadeout { innerJSON["fadeout"] = f }
        if let l = pack.lang { innerJSON["lang"] = l }
        if let o = pack.origin { innerJSON["origin"] = o }
        if let c = pack.creator { innerJSON["creator"] = c }
        innerJSON["$schema"] = schemaURL
        innerJSON["activation"] = FunikiActivation.generate(
            name: pack.name,
            turns: pack.turns,
            masked: false
        )

        let recombined = try JSONSerialization.data(withJSONObject: innerJSON)
        let decoder = JSONDecoder()
        return try decoder.decode(FunikiPack.self, from: recombined)
    }

    // MARK: - convenience load

    /// Load a Pack from raw JSON data, auto-unmasking if it carries `privacy: "mask"`.
    public static func load(_ data: Data) throws -> FunikiPack {
        let pack = try JSONDecoder().decode(FunikiPack.self, from: data)
        return try unmask(pack)
    }

    /// Load a Pack from a JSON string, auto-unmasking if needed.
    public static func load(jsonString: String) throws -> FunikiPack {
        guard let data = jsonString.data(using: .utf8) else {
            throw MaskError.decodeFailed("input is not valid UTF-8")
        }
        return try load(data)
    }
}

// MARK: - AnyEncodable

/// Type-erased Encodable wrapper used to assemble the inner payload object.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        self._encode = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
