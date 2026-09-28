import Foundation
import UniformTypeIdentifiers

struct HarborFilePage: Decodable {
    let data: [HarborFile]
    let paging: Paging
}

struct Paging: Decodable {
    let limit: Int
    let offset: Int
    let total: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case limit, offset, total
        case hasMore = "has_more"
    }
}

struct HarborFile: Decodable, Identifiable, Hashable {
    let id: String
    let hash: String
    let size: Int
    let mime: String
    let filename: String?
    let isEncrypted: Bool
    let thumbStatus: String?
    let createdAt: Int64
    let updatedAt: Int64
    let notes: [LinkedNote]
    let galleryValidationIssue: GalleryPhotoValidationIssue?

    enum CodingKeys: String, CodingKey {
        case id, hash, size, mime, filename, notes
        case isEncrypted = "is_encrypted"
        case thumbStatus = "thumb_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case galleryValidationIssue = "_gallery_validation_issue"
    }

    var noteTitle: String {
        if let title = notes.first?.title, !title.isEmpty { return title }
        if let filename, !filename.isEmpty {
            return (filename as NSString).deletingPathExtension
        }
        return "Untitled image"
    }

    var originalFilename: String {
        if let filename, !filename.isEmpty { return filename }

        let preferredExtension = UTType(mimeType: mime)?.preferredFilenameExtension
        guard let preferredExtension, !preferredExtension.isEmpty else { return noteTitle }
        guard (noteTitle as NSString).pathExtension.isEmpty else { return noteTitle }
        return "\(noteTitle).\(preferredExtension)"
    }

    var displayName: String { noteTitle }

    var noteSummary: String { originalFilename }

    var createdDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
    }
}

enum GalleryPhotoValidationIssue: String, Decodable, Hashable {
    case noteChanged
}

struct LinkedNote: Decodable, Hashable {
    let noteId: String
    let title: String
    let role: String
    let isEncrypted: Bool

    enum CodingKeys: String, CodingKey {
        case title, role
        case noteId = "note_id"
        case isEncrypted = "is_encrypted"
    }
}

struct HarborDownload: Decodable {
    let downloadURL: URL
    let expiresAt: Int64
    let mime: String
    let size: Int
    let filename: String?

    enum CodingKeys: String, CodingKey {
        case mime, size, filename
        case downloadURL = "download_url"
        case expiresAt = "expires_at"
    }
}

struct HarborErrorEnvelope: Decodable {
    let code: String?
    let message: String?
    let error: HarborNestedError?
}

struct HarborNestedError: Decodable {
    let code: String?
    let message: String?
    let details: HarborErrorDetails?
}

struct HarborErrorDetails: Decodable {
    let resource: String?
    let used: Int?
    let limit: Int?

    let planCode: String?
    let upgradeURL: URL?

    enum CodingKeys: String, CodingKey {
        case resource, used, limit
        case planCode = "plan_code"
        case upgradeURL = "upgrade_url"
    }
}

struct HarborUploadedFile: Decodable {
    let id: String
    let hash: String
    let size: Int
    let mime: String
    let filename: String?
}

struct HarborNoteMutation: Decodable {
    let note: HarborCreatedNote
    let usn: Int
}

struct HarborCreatedNote: Decodable {
    let id: String
    let title: String
}

struct HarborAlbum: Identifiable, Hashable {
    let id: String
    let title: String
    let stack: String
    let files: [HarborFile]
    let notebookID: String?

    var cover: HarborFile? { files.first }

    var photoCountLabel: String {
        "\(files.count) \(files.count == 1 ? "photo" : "photos")"
    }
}

struct HarborNotebookPage: Decodable {
    let data: [HarborNotebook]
    let paging: Paging
}

struct HarborNotebook: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let stack: String
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, stack
        case isDefault = "is_default"
    }
}

struct HarborStackPage: Decodable {
    let data: [HarborStack]
}

struct HarborStack: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let notebookCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case notebookCount = "notebook_count"
    }
}

struct HarborNoteMetaPage: Decodable {
    let data: [HarborNoteMeta]
    let paging: Paging
}

struct HarborNoteMeta: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let notebookID: String
    let source: String?
    let content: String?
    let isEncrypted: Bool
    let cover: HarborNoteCover?
    let createdAt: Int64
    let updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, source, content, cover
        case notebookID = "notebook_id"
        case isEncrypted = "is_encrypted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HarborNoteCover: Decodable, Hashable {
    let hash: String
    let mime: String
    let isEncrypted: Bool
    let thumbStatus: String?

    enum CodingKeys: String, CodingKey {
        case hash, mime
        case isEncrypted = "is_encrypted"
        case thumbStatus = "thumb_status"
    }
}
