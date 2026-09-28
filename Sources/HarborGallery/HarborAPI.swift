import AppKit
import Foundation
import UniformTypeIdentifiers

struct HarborAPI: Sendable {
    static let baseURL = URL(string: "https://app.harbor.my/api/v1")!

    let token: String

    func listImages(limit: Int = 500, offset: Int = 0) async throws -> HarborFilePage {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("files"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "mime", value: "image/"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "order", value: "-created_at")
        ]
        return try await request(components.url!)
    }

    func listImages(linkedTo noteID: String) async throws -> [HarborFile] {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("files"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "note_id", value: noteID),
            URLQueryItem(name: "mime", value: "image/"),
            URLQueryItem(name: "limit", value: "100")
        ]
        let page: HarborFilePage = try await request(components.url!)
        return page.data
    }

    func downloadInfo(for hash: String, variant: String? = nil) async throws -> HarborDownload {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("files").appendingPathComponent(hash),
            resolvingAgainstBaseURL: false
        )!
        if let variant {
            components.queryItems = [URLQueryItem(name: "variant", value: variant)]
        }
        return try await request(components.url!)
    }

    func validateNotesAccess() async throws {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("notes"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "fields", value: "meta")
        ]
        let _: HarborNotesProbe = try await request(components.url!)
    }

    func validateNotebookAccess() async throws {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("notebooks"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "limit", value: "1")]
        let _: HarborNotebookPage = try await request(components.url!)
    }

    func listNotebooks() async throws -> [HarborNotebook] {
        var all: [HarborNotebook] = []
        var offset = 0
        while true {
            var components = URLComponents(
                url: Self.baseURL.appendingPathComponent("notebooks"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "limit", value: "500"),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            let page: HarborNotebookPage = try await request(components.url!)
            all.append(contentsOf: page.data)
            guard page.paging.hasMore, !page.data.isEmpty else { break }
            offset += page.data.count
        }
        return all
    }

    func listGalleryNotes() async throws -> [HarborNoteMeta] {
        var all: [HarborNoteMeta] = []
        var offset = 0
        while true {
            var components = URLComponents(
                url: Self.baseURL.appendingPathComponent("notes"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "fields", value: "meta"),
                URLQueryItem(name: "order", value: "created_at"),
                URLQueryItem(name: "limit", value: "500"),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            let page: HarborNoteMetaPage = try await request(components.url!)
            all.append(contentsOf: page.data.filter { $0.source == "harbor.gallery.photo" })
            guard page.paging.hasMore, !page.data.isEmpty else { break }
            offset += page.data.count
        }
        return all
    }

    func listPhotoNotes(in notebookID: String) async throws -> [HarborNoteMeta] {
        var all: [HarborNoteMeta] = []
        var offset = 0
        while true {
            var components = URLComponents(
                url: Self.baseURL.appendingPathComponent("notes"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "notebook_id", value: notebookID),
                URLQueryItem(name: "order", value: "created_at"),
                URLQueryItem(name: "limit", value: "500"),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            let page: HarborNoteMetaPage = try await request(components.url!)
            all.append(contentsOf: page.data.filter { $0.cover?.mime.hasPrefix("image/") == true })
            guard page.paging.hasMore, !page.data.isEmpty else { break }
            offset += page.data.count
        }
        return all
    }

    func listStacks() async throws -> [HarborStack] {
        let page: HarborStackPage = try await request(Self.baseURL.appendingPathComponent("stacks"))
        return page.data
    }

    func createGalleryNotebook(named name: String, stack: String?) async throws -> HarborNotebook {
        let payload = CreateNotebookPayload(
            name: name,
            stack: stack ?? "",
            defaultEncrypt: false
        )
        return try await sendJSON(
            to: Self.baseURL.appendingPathComponent("notebooks"),
            method: "POST",
            payload: payload,
            response: HarborNotebook.self
        )
    }

    func updateNotebook(id: String, name: String, stack: String) async throws -> HarborNotebook {
        let payload = UpdateNotebookPayload(name: name, stack: stack)
        return try await sendJSON(
            to: Self.baseURL.appendingPathComponent("notebooks").appendingPathComponent(id),
            method: "PATCH",
            payload: payload,
            response: HarborNotebook.self
        )
    }

    func deleteNotebookAndTrashNotes(id: String) async throws {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent("notebooks").appendingPathComponent(id),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "notes", value: "trash")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func uploadImage(at fileURL: URL) async throws -> HarborUploadedFile {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { fileURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: fileURL)
        let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey])
        let mime = resourceValues?.contentType?.preferredMIMEType ?? "application/octet-stream"
        guard mime.hasPrefix("image/") else { throw HarborAPIError.unsupportedImage }

        let boundary = "HarborGallery-\(UUID().uuidString)"
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent.multipartEscaped)\"\r\n")
        body.appendUTF8("Content-Type: \(mime)\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: Self.baseURL.appendingPathComponent("files/upload"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (responseData, response) = try await URLSession.shared.upload(for: request, from: body)
        try validate(response: response, data: responseData)
        return try decode(HarborUploadedFile.self, from: responseData)
    }

    func createPhotoNote(
        title: String,
        notebookID: String,
        file: HarborUploadedFile
    ) async throws -> HarborCreatedNote {
        let name = (file.filename ?? "Photo").htmlEscaped
        let embed = "<harbor-embed type=\"image\" resource=\"sha256:\(file.hash)\" title=\"\(name)\"></harbor-embed>"
        let payload = CreatePhotoNotePayload(
            title: title,
            content: embed,
            contentFormat: "html",
            notebookID: notebookID,
            thumbnail: "sha256:\(file.hash)",
            source: "harbor.gallery.photo"
        )
        let mutation: HarborNoteMutation = try await sendJSON(
            to: Self.baseURL.appendingPathComponent("notes"),
            method: "POST",
            payload: payload,
            response: HarborNoteMutation.self
        )
        return mutation.note
    }

    func moveNoteToTrash(id: String) async throws {
        var request = URLRequest(
            url: Self.baseURL.appendingPathComponent("notes").appendingPathComponent(id)
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    func updateNoteTitle(id: String, title: String) async throws -> HarborCreatedNote {
        let payload = UpdateNoteTitlePayload(title: title)
        let mutation: HarborNoteMutation = try await sendJSON(
            to: Self.baseURL.appendingPathComponent("notes").appendingPathComponent(id),
            method: "PATCH",
            payload: payload,
            response: HarborNoteMutation.self
        )
        return mutation.note
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw HarborAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(HarborErrorEnvelope.self, from: data)
            let code = envelope?.code ?? envelope?.error?.code
            let resource = envelope?.error?.details?.resource
            let message = envelope?.message
                ?? envelope?.error?.message
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw HarborAPIError.server(
                status: http.statusCode,
                code: code,
                resource: resource,
                message: message
            )
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw HarborAPIError.decoding(error.localizedDescription)
        }
    }

    private func sendJSON<Payload: Encodable, Response: Decodable>(
        to url: URL,
        method: String,
        payload: Payload,
        response: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = try JSONEncoder().encode(payload)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        try validate(response: urlResponse, data: data)
        return try decode(response, from: data)
    }
}

private struct HarborNotesProbe: Decodable {
    let data: [ProbeNote]
}

private struct ProbeNote: Decodable {
    let id: String
}

private struct CreateNotebookPayload: Encodable {
    let name: String
    let stack: String
    let defaultEncrypt: Bool

    enum CodingKeys: String, CodingKey {
        case name, stack
        case defaultEncrypt = "default_encrypt"
    }
}

private struct CreatePhotoNotePayload: Encodable {
    let title: String
    let content: String
    let contentFormat: String
    let notebookID: String
    let thumbnail: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case title, content, thumbnail, source
        case contentFormat = "content_format"
        case notebookID = "notebook_id"
    }
}

private struct UpdateNotebookPayload: Encodable {
    let name: String
    let stack: String
}

private struct UpdateNoteTitlePayload: Encodable {
    let title: String
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension String {
    var multipartEscaped: String {
        replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
    }

    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

enum HarborAPIError: LocalizedError {
    case invalidResponse
    case server(status: Int, code: String?, resource: String?, message: String)
    case decoding(String)
    case invalidImage
    case unsupportedImage

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Harbor returned an invalid response."
        case let .server(status, code, _, message):
            if status == 401 { return "That token was not accepted by Harbor." }
            if code == "plan_limit_reached" { return message }
            if status == 403 { return "This token needs Harbor’s Files, Notes, and Notebooks permissions." }
            return "Harbor returned error \(status): \(message)"
        case let .decoding(message):
            return "Harbor’s response could not be read: \(message)"
        case .invalidImage:
            return "The downloaded file is not a readable image."
        case .unsupportedImage:
            return "One of the selected files is not a supported image."
        }
    }
}

actor ImageRepository {
    static let shared = ImageRepository()

    private let cache = NSCache<NSString, NSImage>()

    func image(for file: HarborFile, token: String, fullSize: Bool = false) async throws -> NSImage {
        let variant = fullSize ? "original" : "medium"
        let cacheKey = "\(file.hash)-\(variant)" as NSString
        if let image = cache.object(forKey: cacheKey) { return image }

        let api = HarborAPI(token: token)
        let info: HarborDownload
        if fullSize {
            info = try await api.downloadInfo(for: file.hash)
        } else {
            do {
                info = try await api.downloadInfo(for: file.hash, variant: "medium")
            } catch {
                info = try await api.downloadInfo(for: file.hash)
            }
        }

        let (data, response) = try await URLSession.shared.data(from: info.downloadURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HarborAPIError.server(
                status: http.statusCode,
                code: nil,
                resource: nil,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
        guard let image = NSImage(data: data) else { throw HarborAPIError.invalidImage }
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    func clear() {
        cache.removeAllObjects()
    }
}
