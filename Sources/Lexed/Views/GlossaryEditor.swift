import SwiftUI
import UniformTypeIdentifiers

/// Add, edit, remove, import, and export the keyword glossary.
struct GlossaryEditor: View {
    @EnvironmentObject private var glossary: Glossary
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Keyword.ID?
    @State private var draft = Keyword(term: "", definition: "")
    @State private var isEditing = false
    @State private var importError: String?
    @State private var showImporter = false
    @State private var showExporter = false

    var body: some View {
        NavigationSplitView {
            list
        } detail: {
            if isEditing {
                editor
            } else {
                ContentUnavailableCompat(
                    title: "Select or add a keyword",
                    systemImage: "character.book.closed",
                    message: "Lexed highlights and defines these terms when it hears them."
                )
            }
        }
        .frame(minWidth: 560, minHeight: 460)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                do {
                    let count = try glossary.importJSON(from: url)
                    importError = count == 0 ? "No new keywords found (duplicates skipped)." : nil
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: GlossaryDocument(keywords: glossary.keywords),
            contentType: .json,
            defaultFilename: "lexed-glossary"
        ) { _ in }
        .alert("Import", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: List

    private var list: some View {
        List(selection: $selection) {
            ForEach(glossary.keywords) { keyword in
                VStack(alignment: .leading, spacing: 2) {
                    Text(keyword.term).font(.headline)
                    Text(keyword.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .tag(keyword.id)
            }
            .onDelete { glossary.remove(at: $0) }
        }
        .onChange(of: selection) { id in
            if let id, let kw = glossary.keywords.first(where: { $0.id == id }) {
                draft = kw
                isEditing = true
            }
        }
        .navigationTitle("Glossary")
        .toolbar {
            ToolbarItemGroup {
                Button { beginNew() } label: { Label("Add", systemImage: "plus") }
                Menu {
                    Button("Import JSON…") { showImporter = true }
                    Button("Export JSON…") { showExporter = true }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: Editor

    private var editor: some View {
        Form {
            Section("Term") {
                TextField("e.g. SLA", text: $draft.term)
            }
            Section("Definition") {
                TextEditor(text: $draft.definition)
                    .frame(minHeight: 90)
                    .font(.body)
            }
            Section("Aliases (also-heard forms, comma-separated)") {
                TextField("e.g. service level agreement",
                          text: Binding(
                            get: { draft.aliases.joined(separator: ", ") },
                            set: { draft.aliases = $0
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty } }
                          ))
            }
            Section("Optional") {
                TextField("Category (e.g. DevOps)",
                          text: Binding(get: { draft.category ?? "" },
                                        set: { draft.category = $0.isEmpty ? nil : $0 }))
                TextField("Source URL",
                          text: Binding(get: { draft.source ?? "" },
                                        set: { draft.source = $0.isEmpty ? nil : $0 }))
            }
            Section {
                HStack {
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(draft.term.trimmingCharacters(in: .whitespaces).isEmpty)
                    if glossary.keywords.contains(where: { $0.id == draft.id }) {
                        Button("Delete", role: .destructive) {
                            glossary.remove(draft)
                            reset()
                        }
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(isExisting ? "Edit Keyword" : "New Keyword")
    }

    private var isExisting: Bool {
        glossary.keywords.contains { $0.id == draft.id }
    }

    private func beginNew() {
        draft = Keyword(term: "", definition: "")
        selection = nil
        isEditing = true
    }

    private func save() {
        if isExisting {
            glossary.update(draft)
        } else {
            glossary.add(draft)
        }
        selection = draft.id
    }

    private func reset() {
        draft = Keyword(term: "", definition: "")
        selection = nil
        isEditing = false
    }
}

/// Minimal back-compatible stand-in for `ContentUnavailableView` (macOS 14+).
private struct ContentUnavailableCompat: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Wraps the glossary as a JSON document for `fileExporter`.
struct GlossaryDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var keywords: [Keyword]

    init(keywords: [Keyword]) { self.keywords = keywords }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        keywords = (try? JSONDecoder().decode([Keyword].self, from: data)) ?? []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return FileWrapper(regularFileWithContents: try encoder.encode(keywords))
    }
}
