import Foundation
import Testing
@testable import FunikiKit

// MARK: - Builder tests

@Suite("FunikiBuilder")
struct BuilderTests {

    @Test("Minimal build: name + persona string")
    func minimalBuild() {
        let pack = FunikiBuilder(name: "Leo")
            .persona("冷静で皮肉屋。短文。")
            .build()

        #expect(pack.funiki == "1.1")
        #expect(pack.name == "Leo")
        if case .string(let s)? = pack.persona { #expect(!s.isEmpty) }
        else { Issue.record("Expected string persona") }
        #expect(pack.memory == nil)
        #expect(pack.relationship == nil)
        #expect(pack.rules == nil)
        #expect(pack.privacy == nil)
    }

    @Test("Structured persona fields")
    func structuredPersona() {
        let pack = FunikiBuilder(name: "Vera")
            .persona(tone: "Dry and precise", style: "No small talk", values: ["honesty"], quirks: ["corrects immediately"])
            .build()

        if case .object(let o)? = pack.persona {
            #expect(o.tone == "Dry and precise")
            #expect(o.values?.contains("honesty") == true)
            #expect(o.quirks?.count == 1)
        } else {
            Issue.record("Expected object persona")
        }
    }

    @Test("Persona chaining: tone() + style() + trait()")
    func personaChaining() {
        let pack = FunikiBuilder(name: "Rin")
            .tone("Quiet and poetic")
            .style("Answers with questions")
            .trait("mentions the moon")
            .build()

        if case .object(let o)? = pack.persona {
            #expect(o.tone == "Quiet and poetic")
            #expect(o.quirks?.first == "mentions the moon")
        } else {
            Issue.record("Expected object persona from chaining")
        }
    }

    @Test("Memory as flat array when no longterm")
    func memoryFlatArray() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .memory(["event1", "event2"])
            .build()

        if case .array(let arr)? = pack.memory {
            #expect(arr == ["event1", "event2"])
        } else {
            Issue.record("Expected flat array memory")
        }
    }

    @Test("Memory as object when longterm present")
    func memoryObject() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .memory(["recent1"])
            .longterm(["old1", "old2"])
            .build()

        if case .object(let o)? = pack.memory {
            #expect(o.recent?.first == "recent1")
            #expect(o.longterm?.count == 2)
        } else {
            Issue.record("Expected object memory")
        }
    }

    @Test("addMemory appends")
    func addMemoryAppends() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .addMemory("first")
            .addMemory("second")
            .build()

        if case .array(let arr)? = pack.memory {
            #expect(arr.count == 2)
            #expect(arr[1] == "second")
        } else {
            Issue.record("Expected array from addMemory")
        }
    }

    @Test("Relationship as string")
    func relationshipString() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .relationship("Long-time ally")
            .build()

        if case .string(let s)? = pack.relationship { #expect(s == "Long-time ally") }
        else { Issue.record("Expected string relationship") }
    }

    @Test("Relationship as object")
    func relationshipObject() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .relationship(userName: "you", status: "partner", affinity: "deep")
            .build()

        if case .object(let o)? = pack.relationship {
            #expect(o.status == "partner")
            #expect(o.affinity == "deep")
        } else {
            Issue.record("Expected object relationship")
        }
    }

    @Test("turns() sets turns and fadeout")
    func turnsSetsFadeout() {
        let pack = FunikiBuilder(name: "A").persona("x").turns(8).build()
        #expect(pack.turns == 8)
        #expect(pack.fadeout == true)
    }

    @Test("turns(0) clears turns")
    func turnsZeroClears() {
        let pack = FunikiBuilder(name: "A").persona("x").turns(0).build()
        #expect(pack.turns == nil)
    }

    @Test("Vendor extensions use x_ prefix")
    func vendorExtensions() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .extend("game_level", 42)
            .extend("app_id", "mygame.v1")
            .build()

        #expect(pack.extensions?["x_game_level"] == .int(42))
        #expect(pack.extensions?["x_app_id"] == .string("mygame.v1"))
    }

    @Test("Extension key already has x_ prefix — not doubled")
    func extensionPrefixNotDoubled() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .extend("x_already", "val")
            .build()

        #expect(pack.extensions?["x_already"] == .string("val"))
        #expect(pack.extensions?["x_x_already"] == nil)
    }

    @Test("origin and creator set metadata")
    func metadata() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .origin("MyRPG")
            .creator("dev@example.com")
            .build()

        #expect(pack.origin == "MyRPG")
        #expect(pack.creator == "dev@example.com")
    }

    @Test("Rules: alwaysDo and neverDo")
    func rules() {
        let pack = FunikiBuilder(name: "A")
            .persona("x")
            .alwaysDo(["use first name"])
            .neverDo(["break character"])
            .build()

        #expect(pack.rules?.do?.first == "use first name")
        #expect(pack.rules?.avoid?.first == "break character")
    }

    @Test("No rules omits rules field")
    func noRulesIsNil() {
        let pack = FunikiBuilder(name: "A").persona("x").build()
        #expect(pack.rules == nil)
    }
}

// MARK: - Exporter tests

@Suite("FunikiExporter")
struct ExporterTests {

    private func simplePack() -> FunikiPack {
        FunikiBuilder(name: "Leo").persona("冷静で皮肉屋").build()
    }

    @Test("jsonString produces valid JSON")
    func jsonStringIsValid() throws {
        let json = try FunikiExporter.jsonString(simplePack())
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(FunikiPack.self, from: data)
        #expect(parsed.name == "Leo")
    }

    @Test("jsonString contains funiki version")
    func jsonStringContainsVersion() throws {
        let json = try FunikiExporter.jsonString(simplePack())
        #expect(json.contains("\"funiki\""))
        #expect(json.contains("1.1"))
    }

    @Test("temporaryFileURL writes .funiki.json file")
    func tempFileExists() throws {
        let url = try FunikiExporter.temporaryFileURL(simplePack())
        #expect(url.lastPathComponent.hasSuffix(".funiki.json"))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("shareURL encodes pack")
    func shareURLNotNil() {
        let url = FunikiExporter.shareURL(simplePack())
        #expect(url != nil)
        #expect(url?.absoluteString.contains("funikidev.github.io") == true)
    }

    @Test("validate passes for good pack")
    func validatePasses() {
        let errors = FunikiExporter.validate(simplePack())
        #expect(errors.isEmpty)
    }

    @Test("validate catches empty name")
    func validateEmptyName() {
        let pack = FunikiBuilder(name: "").persona("x").build()
        let errors = FunikiExporter.validate(pack)
        #expect(errors.contains(where: { $0.contains("name") }))
    }

    @Test("Round-trip: build → encode → decode")
    func roundTrip() throws {
        let original = FunikiBuilder(name: "Vera")
            .persona(tone: "Dry", style: "Minimal", values: ["honesty"], quirks: ["corrects immediately"])
            .relationship("A trusted colleague")
            .memory(["solved the bug yesterday"])
            .turns(12)
            .origin("TestApp")
            .extend("score", 99)
            .build()

        let json = try FunikiExporter.jsonString(original)
        let decoded = try JSONDecoder().decode(FunikiPack.self, from: json.data(using: .utf8)!)

        #expect(decoded.name == "Vera")
        #expect(decoded.turns == 12)
        #expect(decoded.origin == "TestApp")
        #expect(decoded.extensions?["x_score"] == .int(99))

        if case .object(let o)? = decoded.persona {
            #expect(o.tone == "Dry")
        } else {
            Issue.record("Expected object persona after round-trip")
        }
    }
}

// MARK: - Mask tests

@Suite("FunikiMask")
struct MaskTests {

    private func openPack() -> FunikiPack {
        FunikiBuilder(name: "Leo")
            .persona(tone: "Dry", style: "Minimal", values: ["honesty"], quirks: ["mentions rain"])
            .relationship(userName: "you", status: "partner", affinity: "deep")
            .core(["met on a rainy day"])
            .memory(["had an argument yesterday"])
            .alwaysDo(["use first name"])
            .neverDo(["break character"])
            .turns(8)
            .lang("ja")
            .origin("test")
            .extend("affection", 87)
            .build()
    }

    @Test("mask wraps sensitive fields into payload")
    func maskWrapsFields() throws {
        let masked = try FunikiMask.mask(openPack())
        #expect(masked.privacy == "mask")
        #expect(masked.payload != nil)
        #expect(masked.payload?.isEmpty == false)
        #expect(masked.persona == nil)
        #expect(masked.relationship == nil)
        #expect(masked.core == nil)
        #expect(masked.memory == nil)
        #expect(masked.rules == nil)
        #expect(masked.extensions == nil)
        // Session metadata and identity stay open
        #expect(masked.name == "Leo")
        #expect(masked.turns == 8)
        #expect(masked.lang == "ja")
        #expect(masked.origin == "test")
    }

    @Test("mask injects decode prelude into activation")
    func maskInjectsPrelude() throws {
        let masked = try FunikiMask.mask(openPack())
        let act = masked.activation ?? ""
        #expect(act.contains("payload"))
        #expect(act.contains("base64"))
    }

    @Test("unmask restores all fields")
    func unmaskRestores() throws {
        let original = openPack()
        let masked = try FunikiMask.mask(original)
        let restored = try FunikiMask.unmask(masked)

        #expect(restored.privacy == nil)
        #expect(restored.payload == nil)
        #expect(restored.name == "Leo")
        #expect(restored.turns == 8)
        #expect(restored.lang == "ja")
        #expect(restored.core?.first == "met on a rainy day")
        #expect(restored.extensions?["x_affection"] == .int(87))
        if case .object(let o)? = restored.persona {
            #expect(o.tone == "Dry")
            #expect(o.quirks?.first == "mentions rain")
        } else {
            Issue.record("Expected object persona after unmask")
        }
        if case .object(let r)? = restored.relationship {
            #expect(r.status == "partner")
        } else {
            Issue.record("Expected object relationship after unmask")
        }
    }

    @Test("Restored activation does not contain mask prelude")
    func restoredActivationIsClean() throws {
        let masked = try FunikiMask.mask(openPack())
        let restored = try FunikiMask.unmask(masked)
        let act = restored.activation ?? ""
        #expect(!act.contains("decode it from base64"))
    }

    @Test("Idempotent: mask(mask(x)) == mask(x)")
    func maskIdempotent() throws {
        let once = try FunikiMask.mask(openPack())
        let twice = try FunikiMask.mask(once)
        #expect(twice.payload == once.payload)
        #expect(twice.privacy == "mask")
    }

    @Test("Idempotent: unmask(open) returns open as-is")
    func unmaskOnOpen() throws {
        let open = openPack()
        let result = try FunikiMask.unmask(open)
        #expect(result.privacy == nil)
        #expect(result.name == open.name)
    }

    @Test("load() auto-unmasks mask packs")
    func loadAutoUnmask() throws {
        let masked = try FunikiMask.mask(openPack())
        let data = try FunikiExporter.jsonData(masked)
        let loaded = try FunikiMask.load(data)
        #expect(loaded.privacy == nil)
        if case .object(let o)? = loaded.persona {
            #expect(o.tone == "Dry")
        } else {
            Issue.record("Expected unmasked persona from load")
        }
    }

    @Test("Mask file validates as v1.1 mask shape")
    func maskValidates() throws {
        let masked = try FunikiMask.mask(openPack())
        let errors = FunikiExporter.validate(masked)
        #expect(errors.isEmpty)
    }

    @Test("Mask pack with empty payload fails validation")
    func emptyPayloadFailsValidation() {
        let bad = FunikiPack(
            funiki: "1.1",
            name: "Leo",
            privacy: "mask",
            payload: ""
        )
        let errors = FunikiExporter.validate(bad)
        #expect(errors.contains(where: { $0.contains("payload") }))
    }
}

// MARK: - Real-world scenario tests

@Suite("Real-world usage")
struct ScenarioTests {

    @Test("RPG NPC export")
    func rpgNPC() throws {
        let pack = FunikiBuilder(name: "Aria the Warrior")
            .persona(
                tone: "Fierce and direct, battle-hardened",
                style: "Short sentences. Never flinches.",
                values: ["honor", "protecting the weak"],
                quirks: ["touches sword hilt when nervous", "distrusts magic users"]
            )
            .relationship(status: "Party member", affinity: "Earned trust through combat")
            .memory(["defeated the cave troll together", "you saved her life in chapter 3"])
            .longterm(["first met at the guild", "she lost her brother to the dark army"])
            .alwaysDo(["address you by battle name"])
            .neverDo(["show fear", "ask for help unprompted"])
            .turns(10)
            .origin("EpicQuestRPG")
            .extend("character_class", "warrior")
            .extend("level", 24)
            .build()

        let errors = FunikiExporter.validate(pack)
        #expect(errors.isEmpty)
        let json = try FunikiExporter.jsonString(pack)
        #expect(json.contains("Aria the Warrior"))
        #expect(json.contains("x_level"))
    }

    @Test("育成ゲーム相棒 export")
    func companionGame() throws {
        let pack = FunikiBuilder(name: "Pochi")
            .tone("明るく少し不安げ。愛情に飢えている。")
            .trait("尻尾を振るのが速い")
            .trait("初対面には慎重")
            .memory(["今日散歩に連れて行ってもらった", "初めてお手ができた"])
            .longterm(["一緒に暮らして3ヶ月"])
            .relationship("一緒に育った大切なパートナー")
            .origin("PetCompanionApp")
            .extend("affection", 87)
            .extend("age_days", 90)
            .build()

        let json = try FunikiExporter.jsonString(pack)
        #expect(json.contains("Pochi"))
        let url = FunikiExporter.shareURL(pack)
        #expect(url != nil)
    }

    @Test("SNSプロフィール persona export")
    func snsProfile() throws {
        let pack = FunikiBuilder(name: "taro_dev")
            .persona("TypeScript好きのエンジニア。自虐ネタが多い。返信は遅め。")
            .relationship("Mutual follower. You both like clean code.")
            .origin("ProfileApp")
            .build()

        let errors = FunikiExporter.validate(pack)
        #expect(errors.isEmpty)
    }

    @Test("日記→人格 export")
    func diaryPersona() throws {
        let pack = FunikiBuilder(name: "今週の私")
            .persona("疲れているが前向き。珈琲頼り。人の話を最後まで聞く週。")
            .memory(["月曜に大きなデプロイを乗り越えた", "水曜は本を2冊読んだ", "金曜は一人でビールを飲んだ"])
            .turns(5)
            .origin("DiaryApp")
            .build()

        let json = try FunikiExporter.jsonString(pack)
        #expect(json.contains("今週の私"))
    }
}
