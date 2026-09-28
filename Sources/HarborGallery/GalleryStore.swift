import Foundation

@MainActor
final class GalleryStore: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var files: [HarborFile] = []
    @Published private(set) var albums: [HarborAlbum] = []
    @Published private(set) var availableStacks: [HarborStack] = []
    @Published private(set) var availableNotebooks: [HarborNotebook] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isCreatingGallery = false
    @Published private(set) var isEditingGallery = false
    @Published private(set) var isEditingPhoto = false
    @Published private(set) var isRecovering = false
    @Published private(set) var creationProgress = ""
    @Published private(set) var creationErrorMessage: String?
    @Published private(set) var editProgress = ""
    @Published private(set) var loadedCount = 0
    @Published private(set) var totalCount = 0
    @Published var errorMessage: String?
    @Published var searchText = ""

    init() {
        token = KeychainStore.readToken()
        if token != nil {
            Task { await reload() }
        }
    }

    var filteredFiles: [HarborFile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return files }
        return files.filter { file in
            file.noteTitle.localizedCaseInsensitiveContains(query)
                || file.originalFilename.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredAlbums: [HarborAlbum] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return albums }
        return albums.filter { album in
            album.title.localizedCaseInsensitiveContains(query)
                || album.files.contains {
                    $0.noteTitle.localizedCaseInsensitiveContains(query)
                        || $0.originalFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    func connect(using candidate: String) async -> Bool {
        let cleanToken = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            errorMessage = "Paste a Harbor personal access token first."
            return false
        }

        isLoading = true
        errorMessage = nil
        do {
            let api = HarborAPI(token: cleanToken)
            _ = try await api.listImages(limit: 1)
            try await api.validateNotesAccess()
            try await api.validateNotebookAccess()
            try KeychainStore.saveToken(cleanToken)
            token = cleanToken
            isLoading = false
            await reload()
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }
    }

    func reload() async {
        guard let token else { return }
        isLoading = true
        errorMessage = nil
        files = []
        loadedCount = 0
        totalCount = 0

        do {
            let api = HarborAPI(token: token)
            async let notebooksRequest = api.listNotebooks()
            async let stacksRequest = api.listStacks()
            let (notebooks, stacks) = try await (notebooksRequest, stacksRequest)

            availableNotebooks = notebooks.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            availableStacks = stacks.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            let existingNotebookIDs = Set(notebooks.map(\.id))
            LocalGalleryCatalog.retainOnly(existingNotebookIDs)
            let galleryIDs = LocalGalleryCatalog.notebookIDs
            let galleryNotebooks = notebooks
                .filter { galleryIDs.contains($0.id) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            var builtAlbums: [HarborAlbum] = []
            for notebook in galleryNotebooks {
                let notes = try await api.listPhotoNotes(in: notebook.id)
                let albumFiles = await makeGalleryFiles(from: notes, using: api)
                builtAlbums.append(
                    HarborAlbum(
                        id: notebook.id,
                        title: notebook.name,
                        stack: notebook.stack,
                        files: albumFiles,
                        notebookID: notebook.id
                    )
                )
                loadedCount += albumFiles.count
            }

            albums = builtAlbums
            files = builtAlbums.flatMap(\.files)
            totalCount = files.count
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createGallery(named name: String, stack: String?, imageURLs: [URL]) async -> Bool {
        guard let token else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !imageURLs.isEmpty else {
            creationErrorMessage = "Give the gallery a name and choose at least one image."
            return false
        }

        isCreatingGallery = true
        errorMessage = nil
        creationErrorMessage = nil
        creationProgress = "Checking Harbor permissions…"

        do {
            let api = HarborAPI(token: token)
            try await api.validateNotesAccess()
            try await api.validateNotebookAccess()

            creationProgress = "Creating the \(cleanName) notebook…"
            let notebook = try await api.createGalleryNotebook(named: cleanName, stack: stack)
            LocalGalleryCatalog.add(notebook.id)

            for (index, url) in imageURLs.enumerated() {
                creationProgress = "Uploading \(index + 1) of \(imageURLs.count): \(url.lastPathComponent)"
                let uploaded = try await api.uploadImage(at: url)
                let photoTitle = url.deletingPathExtension().lastPathComponent
                _ = try await api.createPhotoNote(
                    title: photoTitle,
                    notebookID: notebook.id,
                    file: uploaded
                )
            }

            creationProgress = "Refreshing galleries…"
            isCreatingGallery = false
            await reload()
            creationErrorMessage = nil
            return true
        } catch {
            isCreatingGallery = false
            creationProgress = ""
            if case let HarborAPIError.server(
                status: _,
                code: "plan_limit_reached",
                resource: resource,
                message: _
            ) = error {
                creationErrorMessage = planLimitMessage(for: resource)
            } else if case HarborAPIError.server(
                status: 403,
                code: _,
                resource: _,
                message: _
            ) = error {
                creationErrorMessage = "Creating galleries requires a Harbor token with Files, Notes, and Notebooks permissions. Replace the token in Harbor Gallery Settings, then try again."
            } else {
                creationErrorMessage = "The gallery could not be completed. Anything already uploaded remains safely in Harbor. \(error.localizedDescription)"
            }
            return false
        }
    }

    func clearGalleryCreationError() {
        creationErrorMessage = nil
    }

    private func planLimitMessage(for resource: String?) -> String {
        switch resource {
        case "notebooks":
            return "Your Harbor plan has reached its notebook limit. Upgrade your plan or free a notebook slot in Harbor, then try again."
        case "notes":
            return "Your Harbor plan has reached its note limit, so the gallery’s photo notes cannot be created. Upgrade your plan or free note space in Harbor, then try again."
        case "files":
            return "Your Harbor plan has reached its file limit, so the selected photos cannot be uploaded. Upgrade your plan or free file space in Harbor, then try again."
        default:
            return "Your Harbor plan has reached an account limit. Upgrade your plan or free space in Harbor, then try again."
        }
    }

    func recoverGalleries() async {
        guard let token else { return }
        isRecovering = true
        errorMessage = nil
        do {
            let notes = try await HarborAPI(token: token).listGalleryNotes()
            let recoveredIDs = Set(notes.map(\.notebookID))
            guard !recoveredIDs.isEmpty else {
                isRecovering = false
                errorMessage = "No Harbor Gallery photo markers were found in this account."
                return
            }
            LocalGalleryCatalog.add(contentsOf: recoveredIDs)
            isRecovering = false
            await reload()
        } catch {
            isRecovering = false
            errorMessage = error.localizedDescription
        }
    }

    func adoptNotebook(_ notebookID: String) async {
        LocalGalleryCatalog.add(notebookID)
        await reload()
    }

    func updateGallery(
        _ album: HarborAlbum,
        name: String,
        stack: String,
        addedImageURLs: [URL],
        deletedNoteIDs: Set<String>
    ) async -> Bool {
        guard let token, let notebookID = album.notebookID else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Give the gallery a name."
            return false
        }

        isEditingGallery = true
        errorMessage = nil

        do {
            let api = HarborAPI(token: token)

            if cleanName != album.title || stack != album.stack {
                editProgress = "Updating gallery details…"
                _ = try await api.updateNotebook(id: notebookID, name: cleanName, stack: stack)
            }

            for (index, url) in addedImageURLs.enumerated() {
                editProgress = "Adding photo \(index + 1) of \(addedImageURLs.count)…"
                let uploaded = try await api.uploadImage(at: url)
                _ = try await api.createPhotoNote(
                    title: url.deletingPathExtension().lastPathComponent,
                    notebookID: notebookID,
                    file: uploaded
                )
            }

            for (index, noteID) in deletedNoteIDs.enumerated() {
                editProgress = "Moving photo \(index + 1) of \(deletedNoteIDs.count) to Trash…"
                try await api.moveNoteToTrash(id: noteID)
            }

            editProgress = "Refreshing gallery…"
            isEditingGallery = false
            await reload()
            editProgress = ""
            return true
        } catch {
            isEditingGallery = false
            editProgress = ""
            errorMessage = "The gallery could not be fully updated. Any completed changes remain safely in Harbor. \(error.localizedDescription)"
            return false
        }
    }

    func renamePhotoNote(_ file: HarborFile, title: String) async -> Bool {
        guard let token else { return false }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            errorMessage = "Give the photo note a name."
            return false
        }

        isEditingPhoto = true
        errorMessage = nil
        do {
            _ = try await HarborAPI(token: token).updateNoteTitle(id: file.id, title: cleanTitle)
            isEditingPhoto = false
            await reload()
            return true
        } catch {
            isEditingPhoto = false
            errorMessage = "The photo note could not be renamed. \(error.localizedDescription)"
            return false
        }
    }

    func deletePhotoNote(_ file: HarborFile) async -> Bool {
        guard let token else { return false }
        isEditingPhoto = true
        errorMessage = nil
        do {
            try await HarborAPI(token: token).moveNoteToTrash(id: file.id)
            isEditingPhoto = false
            await reload()
            return true
        } catch {
            isEditingPhoto = false
            errorMessage = "The photo note could not be moved to Trash. \(error.localizedDescription)"
            return false
        }
    }

    func deleteGallery(_ album: HarborAlbum) async -> Bool {
        guard let token, let notebookID = album.notebookID else { return false }
        isEditingGallery = true
        errorMessage = nil
        editProgress = "Deleting gallery and moving its photo notes to Trash…"

        do {
            try await HarborAPI(token: token).deleteNotebookAndTrashNotes(id: notebookID)
            LocalGalleryCatalog.remove(notebookID)
            albums.removeAll { $0.id == album.id }
            files = albums.flatMap(\.files)
            availableNotebooks.removeAll { $0.id == notebookID }
            isEditingGallery = false
            editProgress = ""
            await reload()
            return true
        } catch {
            isEditingGallery = false
            editProgress = ""
            errorMessage = "The gallery could not be deleted. \(error.localizedDescription)"
            return false
        }
    }

    private func makeGalleryFiles(
        from notes: [HarborNoteMeta],
        using api: HarborAPI
    ) async -> [HarborFile] {
        var resourcesByNoteID: [String: [HarborFile]] = [:]

        for batchStart in stride(from: 0, to: notes.count, by: 8) {
            let batchEnd = min(batchStart + 8, notes.count)
            let batch = Array(notes[batchStart..<batchEnd])

            await withTaskGroup(of: (String, [HarborFile]?).self) { group in
                for note in batch {
                    group.addTask {
                        do {
                            return (note.id, try await api.listImages(linkedTo: note.id))
                        } catch {
                            return (note.id, nil)
                        }
                    }
                }

                for await (noteID, resources) in group {
                    if let resources {
                        resourcesByNoteID[noteID] = resources
                    }
                }
            }
        }

        return notes.compactMap { note in
            let resources = resourcesByNoteID[note.id]
            let resource = resources?.first { $0.hash == note.cover?.hash }
            return makeGalleryFile(from: note, resource: resource, linkedImages: resources)
        }
    }

    private func makeGalleryFile(
        from note: HarborNoteMeta,
        resource: HarborFile?,
        linkedImages: [HarborFile]?
    ) -> HarborFile? {
        guard let cover = note.cover, cover.mime.hasPrefix("image/") else { return nil }
        return HarborFile(
            id: note.id,
            hash: cover.hash,
            size: resource?.size ?? 0,
            mime: cover.mime,
            filename: resource?.filename,
            isEncrypted: cover.isEncrypted,
            thumbStatus: cover.thumbStatus,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            notes: [
                LinkedNote(
                    noteId: note.id,
                    title: note.title,
                    role: "inline",
                    isEncrypted: note.isEncrypted
                )
            ],
            galleryValidationIssue: galleryValidationIssue(
                for: note,
                coverHash: cover.hash,
                linkedImages: linkedImages
            )
        )
    }

    private func galleryValidationIssue(
        for note: HarborNoteMeta,
        coverHash: String,
        linkedImages: [HarborFile]?
    ) -> GalleryPhotoValidationIssue? {
        if note.isEncrypted { return .noteChanged }

        if let linkedImages {
            guard linkedImages.count == 1, linkedImages[0].hash == coverHash else {
                return .noteChanged
            }
        }

        guard let content = note.content, !content.isEmpty else { return .noteChanged }

        let embedPattern = #"(?is)<harbor-embed\b[^>]*\bresource\s*=\s*[\"']sha256:([0-9a-f]{64})[\"'][^>]*(?:>\s*</harbor-embed\s*>|/>)"#
        guard let embedExpression = try? NSRegularExpression(pattern: embedPattern) else {
            return .noteChanged
        }

        let fullRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = embedExpression.matches(in: content, range: fullRange)
        guard matches.count == 1,
              let hashRange = Range(matches[0].range(at: 1), in: content),
              content[hashRange].lowercased() == coverHash.lowercased() else {
            return .noteChanged
        }

        var remainder = embedExpression.stringByReplacingMatches(
            in: content,
            range: fullRange,
            withTemplate: ""
        )
        remainder = remainder.replacingOccurrences(
            of: #"(?is)<!--.*?-->|<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        remainder = remainder
            .replacingOccurrences(of: "&nbsp;", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "&#160;", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return remainder.isEmpty ? nil : .noteChanged
    }

    func disconnect() {
        KeychainStore.deleteToken()
        token = nil
        files = []
        albums = []
        availableStacks = []
        availableNotebooks = []
        searchText = ""
        errorMessage = nil
        Task { await ImageRepository.shared.clear() }
    }
}
