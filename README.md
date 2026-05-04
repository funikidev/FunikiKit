# FunikiKit

> Export any in-app character, persona, or state as a `.funiki` file — with one tap.

iOS 17+ · macOS 14+ · Swift 6 · SwiftUI · Zero dependencies

---

## What it does

Your app has characters. States. Personalities. FunikiKit exports them as portable `.funiki` files that work in ChatGPT, Claude, Gemini, and any LLM — without your users needing to know what funiki is.

**Input**: any data in your app — RPG character, pet companion, user profile, diary entry, playlist mood, coach persona.  
**Output**: a `.funiki` file. Share sheet opens. Done.

---

## Install

```swift
// Package.swift
.package(url: "https://github.com/funikidev/FunikiKit", from: "1.0.0")

// Target dependency
.product(name: "FunikiKit", package: "FunikiKit")
```

---

## The one-minute version

```swift
import FunikiKit

// 1. Describe what you have
let pack = FunikiBuilder(name: npc.name)
    .persona(npc.personalityDescription)
    .memory(npc.recentEvents)
    .origin("MyApp")
    .build()

// 2. Add a button. User taps. Share sheet opens.
FunikiShareLink("Share Character", pack: pack)
```

That's it. The user gets a `.funiki` file they can drop into any AI chat.

---

## Works for any kind of app

### RPG / Game NPC

```swift
let pack = FunikiBuilder(name: character.name)
    .persona(
        tone: character.personalityTone,
        style: character.speechStyle,
        values: character.coreValues,
        quirks: character.habits
    )
    .memory(character.recentEventLog.map(\.description))
    .longterm(character.backstory)
    .alwaysDo(["address you by battle name"])
    .neverDo(["show fear"])
    .turns(10)
    .origin("EpicQuestRPG")
    .extend("character_class", character.classType)
    .extend("level", character.level)
    .build()
```

### 育成ゲーム / Pet companion

```swift
let pack = FunikiBuilder(name: companion.name)
    .tone(companion.currentMoodDescription)
    .trait(companion.specialSkill)
    .memory(companion.recentMilestones)
    .relationship(status: "一緒に育ったパートナー", affinity: "\(companion.affectionLevel)%")
    .origin("PetApp")
    .extend("affection", companion.affectionLevel)
    .extend("age_days", companion.ageDays)
    .build()
```

### SNS / User profile

```swift
let pack = FunikiBuilder(name: user.displayName)
    .persona(user.bio)
    .relationship("Mutual follower with shared interests")
    .origin("SocialApp")
    .build()
```

### 日記アプリ / Diary → weekly persona

```swift
let pack = FunikiBuilder(name: "今週の私")
    .persona(diary.extractedMoodDescription)
    .memory(diary.topMomentsThisWeek)
    .turns(5)
    .origin("DiaryApp")
    .build()
```

### 勉強アプリ / Study coach

```swift
let pack = FunikiBuilder(name: settings.coachName)
    .persona(tone: settings.coachingStyle, style: settings.communicationPreference)
    .alwaysDo(settings.encouragementRules)
    .neverDo(settings.avoidPatterns)
    .origin("StudyApp")
    .build()
```

### 音楽アプリ / Playlist persona

```swift
let pack = FunikiBuilder(name: playlist.name)
    .persona("このプレイリストの雰囲気: \(playlist.moodDescription)")
    .memory(playlist.recentTracks.prefix(5).map { "「\($0.title)」を最近よく聴いた" })
    .extend("top_genre", playlist.topGenre)
    .extend("track_count", playlist.tracks.count)
    .build()
```

---

## SwiftUI components

### FunikiShareLink — works like native ShareLink

```swift
// Simple
FunikiShareLink("Share Character", pack: pack)

// Custom label
FunikiShareLink(pack: pack) {
    Label("Export as .funiki", systemImage: "square.and.arrow.up")
}
```

### FunikiExportButton — with built-in preview sheet

```swift
FunikiExportButton("Share \(npc.name)") {
    FunikiBuilder(name: npc.name)
        .persona(npc.personality)
        .build()
}
```

### .funikiExport modifier — attach to any button

```swift
Button("Share") { }
    .funikiExport {
        FunikiBuilder(name: character.name)
            .persona(character.description)
            .build()
    }
```

---

## Export formats

All formats are handled by `FunikiExporter`. You rarely need to call it directly — the SwiftUI components handle it — but it's available for custom flows.

```swift
// File URL (for custom share flows)
let url = try FunikiExporter.temporaryFileURL(pack)

// JSON string (for copy/paste, logging)
let json = try FunikiExporter.jsonString(pack)

// Share URL (opens in browser, no app needed)
let url = FunikiExporter.shareURL(pack)  // → https://funikidev.github.io/pack.html?pack=...

// System share sheet (UIKit)
await FunikiExporter.presentShareSheet(for: pack, from: button)
```

---

## FunikiBuilder API

| Method | Description |
|---|---|
| `init(name:)` | Start a builder. Name is required. |
| `.persona(_ string)` | Describe personality as plain text |
| `.persona(tone:style:values:quirks:)` | Structured personality fields |
| `.tone(_ string)` | Set speaking tone |
| `.style(_ string)` | Set speech style |
| `.trait(_ string)` | Add one personality quirk |
| `.relationship(_ string)` | Describe user relationship as plain text |
| `.relationship(userName:status:affinity:)` | Structured relationship |
| `.memory(_ items)` | Recent memories (array of strings) |
| `.addMemory(_ item)` | Append one recent memory |
| `.longterm(_ items)` | Background / historical memories |
| `.alwaysDo(_ rules)` | Behaviors the character should perform |
| `.neverDo(_ rules)` | Behaviors to avoid |
| `.turns(_ count)` | Session length (0 = unlimited) |
| `.fadeout(_ bool)` | Override fadeout behavior |
| `.origin(_ appName)` | Tag the source app |
| `.creator(_ id)` | Tag the creator |
| `.extend(_ key, _ value)` | Add vendor extension field (x_ prefix auto-added) |
| `.build()` | Assemble and return `FunikiPack` |

---

## Validate before export

```swift
let errors = FunikiExporter.validate(pack)
if errors.isEmpty {
    FunikiShareLink("Share", pack: pack)
} else {
    // Handle errors: ["name is empty", ...]
}
```

---

## License

MIT — [funikidev](https://github.com/funikidev)
