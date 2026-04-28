import Foundation

// MARK: - FunikiPack

/// The output format. Developers don't construct this directly — use FunikiBuilder.
public struct FunikiPack: Codable, Sendable, Hashable {

    public let funiki: String
    public let name: String
    public let persona: PersonaValue
    public let relationship: RelationshipValue?
    public let memory: MemoryValue?
    public let rules: Rules?
    public let turns: Int?
    public let fadeout: Bool?
    public let origin: String?
    public let creator: String?

    // x_ vendor extensions captured as raw JSON-compatible values
    public let extensions: [String: ExtensionValue]?

    // Internal init used only by FunikiBuilder
    init(
        name: String,
        persona: PersonaValue,
        relationship: RelationshipValue? = nil,
        memory: MemoryValue? = nil,
        rules: Rules? = nil,
        turns: Int? = nil,
        fadeout: Bool? = nil,
        origin: String? = nil,
        creator: String? = nil,
        extensions: [String: ExtensionValue]? = nil
    ) {
        self.funiki = "1.0"
        self.name = name
        self.persona = persona
        self.relationship = relationship
        self.memory = memory
        self.rules = rules
        self.turns = turns
        self.fadeout = fadeout
        self.origin = origin
        self.creator = creator
        self.extensions = extensions
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case funiki, name, persona, relationship, memory, rules, turns, fadeout, origin, creator
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        funiki       = try c.decode(String.self,           forKey: .funiki)
        name         = try c.decode(String.self,           forKey: .name)
        persona      = try c.decode(PersonaValue.self,     forKey: .persona)
        relationship = try c.decodeIfPresent(RelationshipValue.self, forKey: .relationship)
        memory       = try c.decodeIfPresent(MemoryValue.self,       forKey: .memory)
        rules        = try c.decodeIfPresent(Rules.self,             forKey: .rules)
        turns        = try c.decodeIfPresent(Int.self,               forKey: .turns)
        fadeout      = try c.decodeIfPresent(Bool.self,              forKey: .fadeout)
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
        try c.encode(funiki,             forKey: .funiki)
        try c.encode(name,               forKey: .name)
        try c.encode(persona,            forKey: .persona)
        try c.encodeIfPresent(relationship, forKey: .relationship)
        try c.encodeIfPresent(memory,    forKey: .memory)
        try c.encodeIfPresent(rules,     forKey: .rules)
        try c.encodeIfPresent(turns,     forKey: .turns)
        try c.encodeIfPresent(fadeout,   forKey: .fadeout)
        try c.encodeIfPresent(origin,    forKey: .origin)
        try c.encodeIfPresent(creator,   forKey: .creator)
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
