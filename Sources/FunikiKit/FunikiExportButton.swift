import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - FunikiShareLink
//
// Works exactly like SwiftUI's ShareLink, but outputs a .funiki file.
// The closest to "native" feel for iOS developers.
//
// Usage:
//   FunikiShareLink("Share Character", pack: myPack)
//   FunikiShareLink(pack: myPack) { Label("Export", systemImage: "square.and.arrow.up") }

public struct FunikiShareLink<Label: View>: View {

    private let pack: FunikiPack
    private let label: Label

    public init(
        _ title: String = "Share",
        systemImage: String = "square.and.arrow.up",
        pack: FunikiPack
    ) where Label == SwiftUI.Label<Text, Image> {
        self.pack = pack
        self.label = SwiftUI.Label(title, systemImage: systemImage)
    }

    public init(pack: FunikiPack, @ViewBuilder label: () -> Label) {
        self.pack = pack
        self.label = label()
    }

    public var body: some View {
        if let fileURL = try? FunikiExporter.temporaryFileURL(pack) {
            ShareLink(item: fileURL, preview: SharePreview(pack.name, icon: Image(systemName: "person.crop.circle"))) {
                label
            }
        } else {
            Button(action: {}) { label }.disabled(true)
        }
    }
}

// MARK: - FunikiExportButton
//
// Wraps a Button with share sheet presentation.
// Use when you need more control than FunikiShareLink.
//
// Usage:
//   FunikiExportButton("Share Leo") {
//     FunikiBuilder(name: npc.name).persona(npc.bio).build()
//   }

public struct FunikiExportButton: View {

    private let title: LocalizedStringKey
    private let systemImage: String
    private let buildPack: @Sendable () -> FunikiPack

    @State private var isPresenting = false
    @State private var exportError: String?

    public init(
        _ title: LocalizedStringKey = "Share",
        systemImage: String = "square.and.arrow.up",
        build buildPack: @escaping @Sendable () -> FunikiPack
    ) {
        self.title = title
        self.systemImage = systemImage
        self.buildPack = buildPack
    }

    public var body: some View {
        Button {
            let pack = buildPack()
            let errors = FunikiExporter.validate(pack)
            guard errors.isEmpty else {
                exportError = errors.joined(separator: "\n")
                return
            }
            isPresenting = true
        } label: {
            Label(title, systemImage: systemImage)
        }
        .sheet(isPresented: $isPresenting) {
            FunikiShareSheet(pack: buildPack())
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }
}

// MARK: - View Modifier
//
// Attach .funikiExport to ANY button in your UI.
//
// Usage:
//   Button("Share NPC") { }
//     .funikiExport {
//       FunikiBuilder(name: npc.name).persona(npc.bio).build()
//     }

extension View {
    public func funikiExport(
        @ViewBuilder label: @escaping () -> some View = { EmptyView() },
        build: @escaping @Sendable () -> FunikiPack
    ) -> some View {
        self.modifier(FunikiExportModifier(buildPack: build))
    }
}

public struct FunikiExportModifier: ViewModifier {
    let buildPack: @Sendable () -> FunikiPack
    @State private var pack: FunikiPack?
    @State private var showSheet = false

    public func body(content: Content) -> some View {
        content
            .onTapGesture {
                pack = buildPack()
                showSheet = true
            }
            .sheet(isPresented: $showSheet) {
                if let p = pack { FunikiShareSheet(pack: p) }
            }
    }
}

// MARK: - FunikiShareSheet
//
// Bottom sheet preview before sharing.
// Shows the pack name, persona summary, and export options.

public struct FunikiShareSheet: View {

    let pack: FunikiPack
    @Environment(\.dismiss) private var dismiss
    @State private var didCopyURL = false

    public var body: some View {
        NavigationStack {
            List {
                // Preview
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pack.name)
                            .font(.title2).bold()
                        Text(personaSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let origin = pack.origin {
                            Label(origin, systemImage: "app.badge")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Export
                Section("Export") {
                    if let url = try? FunikiExporter.temporaryFileURL(pack) {
                        ShareLink(
                            item: url,
                            preview: SharePreview("\(pack.name).funiki.json", icon: Image(systemName: "doc"))
                        ) {
                            Label("Share .funiki.json", systemImage: "square.and.arrow.up")
                        }
                    }

                    if let shareURL = FunikiExporter.shareURL(pack) {
                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = shareURL.absoluteString
                            #elseif canImport(AppKit)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(shareURL.absoluteString, forType: .string)
                            #endif
                            withAnimation { didCopyURL = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { didCopyURL = false }
                            }
                        } label: {
                            Label(didCopyURL ? "Copied!" : "Copy URL", systemImage: didCopyURL ? "checkmark" : "link")
                        }
                    }
                }

            }
            .navigationTitle("Export Pack")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var personaSummary: String {
        switch pack.persona {
        case .string(let s): return String(s.prefix(120))
        case .object(let o):
            return [o.tone, o.style].compactMap { $0 }.joined(separator: " · ")
        }
    }
}
