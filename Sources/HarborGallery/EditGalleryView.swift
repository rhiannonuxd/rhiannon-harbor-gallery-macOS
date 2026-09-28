import SwiftUI
import UniformTypeIdentifiers

struct EditGalleryView: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.dismiss) private var dismiss

    let album: HarborAlbum

    @State private var name: String
    @State private var stack: String
    @State private var addedImageURLs: [URL] = []
    @State private var deletedNoteIDs: Set<String> = []
    @State private var showingImporter = false
    @State private var confirmingPhotoRemoval = false
    @State private var confirmingGalleryDeletion = false

    let onGalleryDeleted: () -> Void

    init(album: HarborAlbum, onGalleryDeleted: @escaping () -> Void = {}) {
        self.album = album
        self.onGalleryDeleted = onGalleryDeleted
        _name = State(initialValue: album.title)
        _stack = State(initialValue: album.stack)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: GallerySpacing.space4) {
                    Text("Edit Gallery")
                        .font(.title2.weight(.semibold))
                    Text("Changes are saved to the Harbor notebook and its photo notes.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(store.isEditingGallery)
            }
            .padding(GallerySpacing.space24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: GallerySpacing.space24) {
                    VStack(alignment: .leading, spacing: GallerySpacing.space8) {
                        Text("Gallery details")
                            .font(.headline)
                        TextField("Gallery name", text: $name)
                            .textFieldStyle(.roundedBorder)
                        Picker("Stack", selection: $stack) {
                            Text("No stack").tag("")
                            ForEach(stackChoices, id: \.self) { stackName in
                                Text(stackName).tag(stackName)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: GallerySpacing.space8) {
                        HStack {
                            Text("Add photos")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingImporter = true
                            } label: {
                                Label("Choose Photos…", systemImage: "photo.badge.plus")
                            }
                        }

                        if addedImageURLs.isEmpty {
                            Text("No new photos selected.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(addedImageURLs, id: \.self) { url in
                                HStack(spacing: GallerySpacing.space8) {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                    Text(url.lastPathComponent)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        addedImageURLs.removeAll { $0 == url }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .help("Remove from additions")
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: GallerySpacing.space8) {
                        Text("Current photos")
                            .font(.headline)

                        if album.files.isEmpty {
                            Text("This gallery has no photos yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(album.files) { file in
                                photoRow(file)
                            }
                        }

                        if !deletedNoteIDs.isEmpty {
                            Text("Removed photos are moved to Harbor Trash with their notes, where they can be restored.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(GallerySpacing.space24)
            }

            Divider()

            HStack(spacing: GallerySpacing.space16) {
                Button("Delete Gallery…", role: .destructive) {
                    confirmingGalleryDeletion = true
                }
                .disabled(store.isEditingGallery)

                if store.isEditingGallery {
                    ProgressView()
                        .controlSize(.small)
                    Text(store.editProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save Changes") { prepareToSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges || cleanName.isEmpty || store.isEditingGallery)
            }
            .padding(GallerySpacing.space24)
        }
        .frame(width: 680, height: 680)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                for url in urls where !addedImageURLs.contains(url) {
                    addedImageURLs.append(url)
                }
            case let .failure(error):
                store.errorMessage = error.localizedDescription
            }
        }
        .alert("Move photos to Harbor Trash?", isPresented: $confirmingPhotoRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Save and Move to Trash", role: .destructive) { save() }
        } message: {
            Text("This will move \(deletedNoteIDs.count) \(deletedNoteIDs.count == 1 ? "photo note" : "photo notes") to Harbor Trash. You can restore them from Harbor.")
        }
        .alert("Delete “\(album.title)”?", isPresented: $confirmingGalleryDeletion) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Gallery", role: .destructive) { deleteGallery() }
        } message: {
            Text("The Harbor notebook will be deleted and its \(album.files.count) \(album.files.count == 1 ? "photo note" : "photo notes") will be moved to Harbor Trash. The notes can be restored, but the gallery notebook itself cannot.")
        }
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var stackChoices: [String] {
        var choices = store.availableStacks.map(\.name)
        if !stack.isEmpty, !choices.contains(stack) { choices.append(stack) }
        return choices.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var hasChanges: Bool {
        cleanName != album.title
            || stack != album.stack
            || !addedImageURLs.isEmpty
            || !deletedNoteIDs.isEmpty
    }

    private func photoRow(_ file: HarborFile) -> some View {
        let isRemoved = deletedNoteIDs.contains(file.id)
        return HStack(spacing: GallerySpacing.space16) {
            RemoteHarborImage(file: file, token: store.token ?? "")
                .frame(width: 80, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(isRemoved ? 0.35 : 1)

            VStack(alignment: .leading, spacing: GallerySpacing.space4) {
                Text(file.noteTitle)
                    .lineLimit(1)
                Text(file.originalFilename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .opacity(isRemoved ? 0.5 : 1)

            Spacer()

            Button(isRemoved ? "Undo" : "Remove") {
                if isRemoved {
                    deletedNoteIDs.remove(file.id)
                } else {
                    deletedNoteIDs.insert(file.id)
                }
            }
            .foregroundStyle(isRemoved ? Color.secondary : Color.red)
        }
        .padding(.vertical, GallerySpacing.space4)
    }

    private func prepareToSave() {
        if deletedNoteIDs.isEmpty {
            save()
        } else {
            confirmingPhotoRemoval = true
        }
    }

    private func save() {
        Task {
            if await store.updateGallery(
                album,
                name: cleanName,
                stack: stack,
                addedImageURLs: addedImageURLs,
                deletedNoteIDs: deletedNoteIDs
            ) {
                dismiss()
            }
        }
    }

    private func deleteGallery() {
        Task {
            if await store.deleteGallery(album) {
                dismiss()
                DispatchQueue.main.async {
                    onGalleryDeleted()
                }
            }
        }
    }
}
