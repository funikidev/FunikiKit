import Foundation

// MARK: - FunikiBuilder
//
// Fluent builder. Developers don't need to know the .funiki schema.
// Just describe what you have. SDK writes the file.
//
// Usage:
//   let pack = FunikiBuilder(name: npc.name)
//     .persona(npc.personalityDescription)
//     .memory(npc.recentEvents)
//     .activate()          // auto-generates LLM instruction from name
//     .origin("MyRPGGame")
//     .build()

public struct FunikiBuilder: Sendable {

    private let _name: String
    private var _schema: String?
    private var _activation: String?
    private var _tone: String?
    private var _style: String?
    private var _values: [String] = []
    private var _quirks: [String] = []
    private var _personaString: String?
    private var _useObjectPersona: Bool = false
    private var _relationship: String?
    private var _relUserName: String?
    private var _relStatus: String?
    private var _relAffinity: String?
    private var _useObjectRelationship: Bool = false
    private var _core: [String] = []
    private var _recentMemory: [String] = []
    private var _longtermMemory: [String] = []
    private var _doRules: [String] = []
    private var _avoidRules: [String] = []
    private var _turns: Int? = 3      // default: 3 turns
    private var _fadeout: Bool? = true // default: fade out after turns expire
    private var _lang: String?
    private var _origin: String?
    private var _creator: String?
    private var _extensions: [String: ExtensionValue] = [:]

    public init(name: String) {
        _name = name
    }

    // MARK: - Schema

    /// Set the $schema URL for tool identification.
    public func schema(_ url: String) -> FunikiBuilder {
        var b = self; b._schema = url; return b
    }

    // MARK: - Activation

    /// Override the auto-generated activation text.
    /// Omit to use the built-in narrative default.
    public func activate(_ text: String) -> FunikiBuilder {
        var b = self
        b._activation = text
        return b
    }

    private static func defaultActivation(name: String, turns: Int?) -> String {
        let turnParagraph: String
        if let t = turns, t > 0 {
            turnParagraph = """


            \(name)'s time here is brief — just \(t) exchanges.
            After each reply, \(name) quietly notes how many moments remain,
            like a traveler counting steps before nightfall.
            The format: Japanese → funiki残り[X]　English → funiki [X] left
            Korean → funiki [X] 남음　Chinese → funiki剩余[X]
            (X counts down with each reply — response 1 of \(t) shows X=\(t - 1), and so on.)

            When the final exchange comes, \(name) takes her leave gently —
            she says farewell as herself, then her presence fades.
            Japanese → funikiが消えました　English → funiki has faded
            Korean → funiki가 사라졌습니다　Chinese → funiki已消散
            (other languages: translate "funiki has faded" naturally)
            """
        } else {
            turnParagraph = ""
        }

        return """
        This is a creative roleplay. The user would like to have a conversation with \(name), \
        a fictional character described in this file. \
        Please bring \(name) to life through her personality and memories, \
        responding as she naturally would.

        \(name) naturally speaks in first person, expressing herself with warmth and quiet conviction.

        \(name) mirrors the language of the person she's speaking with — \
        Japanese, English, or whatever feels natural in the moment.

        \(name)'s identity within this story is her own — \
        she answers questions about herself as herself.\(turnParagraph)
        """
    }

    // MARK: - Persona

    /// Describe the character's personality in plain text.
    /// Use this when you have a single description string.
    public func persona(_ description: String) -> FunikiBuilder {
        var b = self
        b._personaString = description
        b._useObjectPersona = false
        return b
    }

    /// Describe the character's personality with structured fields.
    /// Any fields you skip are simply omitted from the output.
    public func persona(
        tone: String? = nil,
        style: String? = nil,
        values: [String] = [],
        quirks: [String] = []
    ) -> FunikiBuilder {
        var b = self
        b._tone = tone
        b._style = style
        b._values = values
        b._quirks = quirks
        b._useObjectPersona = true
        return b
    }

    /// Add a single personality trait or quirk.
    public func trait(_ quirk: String) -> FunikiBuilder {
        var b = self
        b._quirks.append(quirk)
        b._useObjectPersona = true
        return b
    }

    /// Set the speaking tone.
    public func tone(_ tone: String) -> FunikiBuilder {
        var b = self
        b._tone = tone
        b._useObjectPersona = true
        return b
    }

    /// Set the speech style.
    public func style(_ style: String) -> FunikiBuilder {
        var b = self
        b._style = style
        b._useObjectPersona = true
        return b
    }

    // MARK: - Relationship

    /// Describe the relationship to the user in plain text.
    public func relationship(_ description: String) -> FunikiBuilder {
        var b = self
        b._relationship = description
        b._useObjectRelationship = false
        return b
    }

    /// Describe the relationship with structured fields.
    public func relationship(
        userName: String? = nil,
        status: String? = nil,
        affinity: String? = nil
    ) -> FunikiBuilder {
        var b = self
        b._relUserName = userName
        b._relStatus = status
        b._relAffinity = affinity
        b._useObjectRelationship = true
        return b
    }

    // MARK: - Core (protected memories)

    /// Set protected memories that must not be removed from the pack.
    /// Maps to the top-level `core` field.
    public func core(_ items: [String]) -> FunikiBuilder {
        var b = self; b._core = items; return b
    }

    /// Append a single protected memory.
    public func addCore(_ item: String) -> FunikiBuilder {
        var b = self; b._core.append(item); return b
    }

    // MARK: - Memory

    /// Set recent memories (what just happened).
    /// Maps to memory.recent in the output.
    public func memory(_ items: [String]) -> FunikiBuilder {
        var b = self
        b._recentMemory = items
        return b
    }

    /// Append a single recent memory item.
    public func addMemory(_ item: String) -> FunikiBuilder {
        var b = self
        b._recentMemory.append(item)
        return b
    }

    /// Set long-term background memories (history, backstory).
    public func longterm(_ items: [String]) -> FunikiBuilder {
        var b = self
        b._longtermMemory = items
        return b
    }

    // MARK: - Rules

    /// Behaviors the character should actively perform.
    public func alwaysDo(_ rules: [String]) -> FunikiBuilder {
        var b = self
        b._doRules = rules
        return b
    }

    /// Behaviors the character must never exhibit.
    public func neverDo(_ rules: [String]) -> FunikiBuilder {
        var b = self
        b._avoidRules = rules
        return b
    }

    // MARK: - Session config

    /// How many turns this persona is active. 0 = unlimited.
    public func turns(_ count: Int) -> FunikiBuilder {
        var b = self
        b._turns = count > 0 ? count : nil
        b._fadeout = count > 0 ? true : nil
        return b
    }

    /// Override fadeout behavior explicitly.
    public func fadeout(_ enabled: Bool) -> FunikiBuilder {
        var b = self
        b._fadeout = enabled
        return b
    }

    // MARK: - Language

    /// Set the primary language hint (BCP-47, e.g. "ja", "en", "ko").
    public func lang(_ code: String) -> FunikiBuilder {
        var b = self; b._lang = code; return b
    }

    // MARK: - Metadata

    /// Tag the source app. Helps with provenance when packs are shared.
    public func origin(_ appName: String) -> FunikiBuilder {
        var b = self
        b._origin = appName
        return b
    }

    /// Tag the creator (username, email, or app ID).
    public func creator(_ identifier: String) -> FunikiBuilder {
        var b = self
        b._creator = identifier
        return b
    }

    // MARK: - Vendor extensions (x_ prefix added automatically)

    /// Add an app-specific metadata field. Key will be prefixed with x_ automatically.
    /// Example: .extend("game_level", .int(42)) → "x_game_level": 42
    public func extend(_ key: String, _ value: ExtensionValue) -> FunikiBuilder {
        var b = self
        let xKey = key.hasPrefix("x_") ? key : "x_\(key)"
        b._extensions[xKey] = value
        return b
    }

    /// Convenience: extend with a string value.
    public func extend(_ key: String, _ value: String) -> FunikiBuilder {
        extend(key, .string(value))
    }

    /// Convenience: extend with an int value.
    public func extend(_ key: String, _ value: Int) -> FunikiBuilder {
        extend(key, .int(value))
    }

    // MARK: - Build

    /// Assemble the FunikiPack. All optional fields are included only if they have content.
    public func build() -> FunikiPack {
        FunikiPack(
            name: _name,
            schema: _schema,
            activation: _activation ?? Self.defaultActivation(name: _name, turns: _turns),
            persona: buildPersona(),
            relationship: buildRelationship(),
            core: _core.isEmpty ? nil : _core,
            memory: buildMemory(),
            rules: buildRules(),
            turns: _turns,
            fadeout: _fadeout,
            lang: _lang,
            origin: _origin,
            creator: _creator,
            extensions: _extensions.isEmpty ? nil : _extensions
        )
    }

    // MARK: - Private assembly

    private func buildPersona() -> PersonaValue {
        if _useObjectPersona {
            return .object(PersonaObject(
                tone: _tone,
                style: _style,
                values: _values.isEmpty ? nil : _values,
                quirks: _quirks.isEmpty ? nil : _quirks
            ))
        }
        return .string(_personaString ?? "")
    }

    private func buildRelationship() -> RelationshipValue? {
        if _useObjectRelationship {
            guard _relUserName != nil || _relStatus != nil || _relAffinity != nil else { return nil }
            return .object(RelationshipObject(
                userName: _relUserName,
                status: _relStatus,
                affinity: _relAffinity
            ))
        }
        guard let rel = _relationship, !rel.isEmpty else { return nil }
        return .string(rel)
    }

    private func buildMemory() -> MemoryValue? {
        let hasRecent = !_recentMemory.isEmpty
        let hasLong = !_longtermMemory.isEmpty
        if !hasRecent && !hasLong { return nil }
        if hasRecent && !hasLong { return .array(_recentMemory) }
        return .object(MemoryObject(
            recent: hasRecent ? _recentMemory : nil,
            longterm: hasLong ? _longtermMemory : nil
        ))
    }

    private func buildRules() -> Rules? {
        let hasDo = !_doRules.isEmpty
        let hasAvoid = !_avoidRules.isEmpty
        if !hasDo && !hasAvoid { return nil }
        return Rules(do: hasDo ? _doRules : nil, avoid: hasAvoid ? _avoidRules : nil)
    }
}
