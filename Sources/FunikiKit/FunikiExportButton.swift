import SwiftUI

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
    @State private var jsonText: String = ""
    @State private var showCopied = false
    @State private var qrImage: Image?

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

                // Export actions
                Section("Export") {
                    // Native file share
                    if let url = try? FunikiExporter.temporaryFileURL(pack) {
                        ShareLink(
                            item: url,
                            preview: SharePreview("\(pack.name).funiki", icon: Image(systemName: "doc"))
                        ) {
                            Label("Share .funiki file", systemImage: "square.and.arrow.up")
                        }
                    }

                    // Copy JSON
                    Button {
                        if let json = try? FunikiExporter.jsonString(pack) {
                            UIPasteboard.general.string = json
                            showCopied = true
                        }
                    } label: {
                        Label(showCopied ? "Copied!" : "Copy JSON", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    }

                    // Copy share URL
                    if let url = FunikiExporter.shareURL(pack) {
                        ShareLink(item: url) {
                            Label("Share Link", systemImage: "link")
                        }
                    }
                }

                // QR
                Section("QR Code") {
                    Button("Generate QR") {
                        if let img = FunikiExporter.qrImage(pack) {
                            qrImage = Image(uiImage: img)
                        }
                    }
                    if let qr = qrImage {
                        qr
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }

                // JSON preview
                Section("JSON Preview") {
                    ScrollView {
                        Text(jsonText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .navigationTitle("Export Pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                jsonText = (try? FunikiExporter.jsonString(pack)) ?? ""
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
