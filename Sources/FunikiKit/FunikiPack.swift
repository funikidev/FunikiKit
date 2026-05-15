import Foundation

// MARK: - FunikiPack

/// The output format. Developers don't construct this directly — use FunikiBuilder.
///
/// A FunikiPack can be in one of two privacy modes:
/// - `open` (default): persona/relationship/core/memory/rules are visible at the top level
/// - `mask`: those fields live inside `payload` (base64-encoded JSON). See spec §17.
public struct FunikiPack: Codable, Sendable, Hashable {

    public let funiki: String
    public let name: String
    public let schema: String?
    /// Privacy mode. `nil` is treated as `open`.
    public let privacy: String?
    /// Base64-encoded payload, present when `privacy == "mask"`.
    public let payload: String?
    /// Natural-language instruction for LLMs: "adopt this persona, don't just describe the file."
    public let activation: String?
    public let persona: PersonaValue?
    public let relationship: RelationshipValue?
    /// Protected memories — MUST NOT be removed from the pack.
    public let core: [String]?
    public let memory: MemoryValue?
    public let rules: Rules?
    public let turns: Int?
    public let fadeout: Bool?
    public let lang: String?
    public let origin: String?
    public let creator: String?

    // x_ vendor extensions captured as raw JSON-compatible values
    public let extensions: [String: ExtensionValue]?

    // Internal init used by FunikiBuilder and FunikiMask
    init(
        funiki: String = "1.1",
        name: String,
        schema: String? = nil,
        privacy: String? = nil,
        payload: String? = nil,
        activation: String? = nil,
        persona: PersonaValue? = nil,
        relationship: RelationshipValue? = nil,
        core: [String]? = nil,
        memory: MemoryValue? = nil,
        rules: Rules? = nil,
        turns: Int? = nil,
        fadeout: Bool? = nil,
        lang: String? = nil,
        origin: String? = nil,
        creator: String? = nil,
        extensions: [String: ExtensionValue]? = nil
    ) {
        self.funiki = funiki
        self.name = name
        self.schema = schema
        self.privacy = privacy
        self.payload = payload
        self.activation = activation
        self.persona = persona
        self.relationship = relationship
        self.core = core
        self.memory = memory
        self.rules = rules
        self.turns = turns
        self.fadeout = fadeout
        self.lang = lang
        self.origin = origin
        self.creator = creator
        self.extensions = extensions
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case funiki, name
        case schema = "$schema"
        case privacy, payload
        case activation, persona, relationship, core, memory, rules, turns, fadeout, lang, origin, creator
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        funiki       = try c.decode(String.self,           forKey: .funiki)
        name         = try c.decode(String.self,           forKey: .name)
        schema       = try c.decodeIfPresent(String.self,  forKey: .schema)
        privacy      = try c.decodeIfPresent(String.self,  forKey: .privacy)
        payload      = try c.decodeIfPresent(String.self,  forKey: .payload)
        activation   = try c.decodeIfPresent(String.self,  forKey: .activation)
        persona      = try c.decodeIfPresent(PersonaValue.self,      forKey: .persona)
        relationship = try c.decodeIfPresent(RelationshipValue.self, forKey: .relationship)
        core         = try c.decodeIfPresent([String].self,          forKey: .core)
        memory       = try c.decodeIfPresent(MemoryValue.self,       forKey: .memory)
        rules        = try c.decodeIfPresent(Rules.self,             forKey: .rules)
        turns        = try c.decodeIfPresent(Int.self,               forKey: .turns)
        fadeout      = try c.decodeIfPresent(Bool.self,              forKey: .fadeout)
        lang         = try c.decodeIfPresent(String.self,            forKey: .lang)
        origin       = try c.decodeIfPresent(String.self,            forKey: .origin)
        creator      = try c.decodeIfPresent(String.self,            forKey: .creator)

        let dyn = try decoder.container(keyedBy: _DynKey.self)
        var exts: [String: ExtensionValue] = [:]
        for key in dyn.allKeys where key.stringValue.hasPrefix("x_") {
            if let val = try? dyn.decode(ExtensionValue.self, forKey: key) {
                exts[key.stringValue] = val
            }
        }
        extensions = exts.isEmpty ? nil : exts
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(funiki,                forKey: .funiki)
        try c.encode(name,                  forKey: .name)
        try c.encodeIfPresent(schema,       forKey: .schema)
        try c.encodeIfPresent(privacy,      forKey: .privacy)
        try c.encodeIfPresent(activation,   forKey: .activation)
        try c.encodeIfPresent(payload,      forKey: .payload)
        try c.encodeIfPresent(persona,      forKey: .persona)
        try c.encodeIfPresent(relationship, forKey: .relationship)
        try c.encodeIfPresent(core,         forKey: .core)
        try c.encodeIfPresent(memory,       forKey: .memory)
        try c.encodeIfPresent(rules,        forKey: .rules)
        try c.encodeIfPresent(turns,        forKey: .turns)
        try c.encodeIfPresent(fadeout,      forKey: .fadeout)
        try c.encodeIfPresent(lang,         forKey: .lang)
        try c.encodeIfPresent(origin,       forKey: .origin)
        try c.encodeIfPresent(creator,      forKey: .creator)
        if let exts = extensions, !exts.isEmpty {
            var dyn = encoder.container(keyedBy: _DynKey.self)
            for (k, v) in exts {
                if let key = _DynKey(stringValue: k) {
                    try dyn.encode(v, forKey: key)
                }
            }
        }
    }
}

// MARK: - Field types

/// Persona: either a plain description string or a structured object.
public enum PersonaValue: Codable, Sendable, Hashable {
    case string(String)
    case object(PersonaObject)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .object(try c.decode(PersonaObject.self))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .string(let s): try c.encode(s)
                      case .object(let o): try c.encode(o) }
    }
}

public struct PersonaObject: Codable, Sendable, Hashable {
    public let tone: String?
    public let style: String?
    public let values: [String]?
    public let quirks: [String]?
}

/// Relationship: either a plain description or a structured object.
public enum RelationshipValue: Codable, Sendable, Hashable {
    case string(String)
    case object(RelationshipObject)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { self = .string(s); return }
        self = .object(try c.decode(RelationshipObject.self))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .string(let s): try c.encode(s)
                      case .object(let o): try c.encode(o) }
    }
}

public struct RelationshipObject: Codable, Sendable, Hashable {
    public let userName: String?
    public let status: String?
    public let affinity: String?
    enum CodingKeys: String, CodingKey {
        case userName = "user_name", status, affinity
    }
}

/// Memory: either a flat array (all treated as recent) or split recent/longterm.
public enum MemoryValue: Codable, Sendable, Hashable {
    case array([String])
    case object(MemoryObject)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let a = try? c.decode([String].self) { self = .array(a); return }
        self = .object(try c.decode(MemoryObject.self))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .array(let a): try c.encode(a)
                      case .object(let o): try c.encode(o) }
    }
}

public struct MemoryObject: Codable, Sendable, Hashable {
    public let recent: [String]?
    public let longterm: [String]?
}

public struct Rules: Codable, Sendable, Hashable {
    public let `do`: [String]?
    public let avoid: [String]?
    enum CodingKeys: String, CodingKey { case `do` = "do", avoid }
}

/// Type-safe wrapper for x_ extension values (string, int, double, bool).
public enum ExtensionValue: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self)   { self = .bool(b);   return }
        if let i = try? c.decode(Int.self)    { self = .int(i);    return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        self = .string(try c.decode(String.self))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i):    try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b):   try c.encode(b)
        }
    }
}

// MARK: - Internal helpers

private struct _DynKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
