import SwiftUI

struct PhotoDetailView: View {
    let files: [HarborFile]
    let token: String
    let viewerSize: CGSize

    @EnvironmentObject private var store: GalleryStore
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var isRenaming = false
    @State private var draftTitle: String
    @State private var confirmingDelete = false

    init(
        files: [HarborFile],
        initialFile: HarborFile,
        token: String,
        availableSize: CGSize
    ) {
        self.files = files
        self.token = token
        viewerSize = CGSize(
            width: min(1_040, max(680, availableSize.width)),
            height: min(720, max(520, availableSize.height))
        )
        _index = State(initialValue: files.firstIndex(of: initialFile) ?? 0)
        _draftTitle = State(initialValue: initialFile.noteTitle)
    }

    private var file: HarborFile {
        store.files.first { $0.id == files[index].id } ?? files[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black.opacity(0.96)
                RemoteHarborImage(file: file, token: token, fullSize: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(GallerySpacing.space24)

                HStack {
                    navigationButton(systemName: "chevron.left", action: previous)
                        .disabled(index == 0)
                    Spacer()
                    navigationButton(systemName: "chevron.right", action: next)
                        .disabled(index >= files.count - 1)
                }
                .padding(GallerySpacing.space16)
            }

            HStack(alignment: .top, spacing: GallerySpacing.space16) {
                VStack(alignment: .leading, spacing: GallerySpacing.space4) {
                    if isRenaming {
                        TextField("Note name", text: $draftTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)
                            .onSubmit { renameNote() }
                    } else {
                        Text(file.noteTitle)
                            .font(.headline)
                    }
                    Text(file.originalFilename)
                        .foregroundStyle(.secondary)
                    Text(file.createdDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("\(index + 1) of \(files.count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                if store.isEditingPhoto {
                    ProgressView()
                        .controlSize(.small)
                } else if isRenaming {
                    Button("Cancel") {
                        draftTitle = file.noteTitle
                        isRenaming = false
                    }
                    Button("Save") { renameNote() }
                        .buttonStyle(.borderedProminent)
                        .disabled(cleanDraftTitle.isEmpty)
                } else {
                    Button {
                        draftTitle = file.noteTitle
                        isRenaming = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(store.isEditingPhoto)
            }
            .padding(GallerySpacing.space16)
        }
        .frame(width: viewerSize.width, height: viewerSize.height)
        .onMoveCommand { direction in
            guard !isRenaming, !store.isEditingPhoto else { return }
            if direction == .left { previous() }
            if direction == .right { next() }
        }
        .alert("Move Photo Note to Trash?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) { deleteNote() }
        } message: {
            Text("“\(file.noteTitle)” will be removed from this gallery and moved to Harbor Trash, where it can be restored.")
        }
    }

    private var cleanDraftTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func navigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .frame(width: 44, height: 60)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func previous() {
        guard index > 0 else { return }
        index -= 1
        draftTitle = file.noteTitle
        isRenaming = false
    }

    private func next() {
        guard index < files.count - 1 else { return }
        index += 1
        draftTitle = file.noteTitle
        isRenaming = false
    }

    private func renameNote() {
        guard !cleanDraftTitle.isEmpty else { return }
        let selectedFile = file
        Task {
            if await store.renamePhotoNote(selectedFile, title: cleanDraftTitle) {
                draftTitle = cleanDraftTitle
                isRenaming = false
            }
        }
    }

    private func deleteNote() {
        let selectedFile = file
        Task {
            if await store.deletePhotoNote(selectedFile) {
                dismiss()
            }
        }
    }
}
