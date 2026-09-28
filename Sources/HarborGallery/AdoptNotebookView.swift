import SwiftUI

struct AdoptNotebookView: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNotebookID = ""

    private var choices: [HarborNotebook] {
        let existing = Set(store.albums.compactMap(\.notebookID))
        return store.availableNotebooks.filter { !existing.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GallerySpacing.space24) {
            Text("Use Existing Notebook as Gallery")
                .font(.title2.weight(.semibold))
            Text("Image notes in the selected notebook will appear as gallery photos. Moving or renaming the notebook later will not break the gallery.")
                .foregroundStyle(.secondary)

            if choices.isEmpty {
                Text("There are no additional notebooks available.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Notebook", selection: $selectedNotebookID) {
                    Text("Choose a notebook…").tag("")
                    ForEach(choices) { notebook in
                        Text(notebook.stack.isEmpty ? notebook.name : "\(notebook.stack) › \(notebook.name)")
                            .tag(notebook.id)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Use as Gallery") {
                    Task {
                        await store.adoptNotebook(selectedNotebookID)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedNotebookID.isEmpty || store.isLoading)
            }
        }
        .padding(GallerySpacing.space24)
        .frame(width: 520)
    }
}
