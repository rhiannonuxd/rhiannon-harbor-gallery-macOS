import SwiftUI

struct RemoteHarborImage: View {
    let file: HarborFile
    let token: String
    var fullSize = false

    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if file.galleryValidationIssue != nil {
                GalleryPhotoChangedPlaceholder(showsExplanation: fullSize)
            } else if file.isEncrypted {
                VStack(spacing: GallerySpacing.space8) {
                    Image(systemName: "lock.fill")
                        .font(.title)
                    Text("Encrypted")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            } else if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fullSize ? .fit : .fill)
            } else if failed {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: "\(file.hash)-\(fullSize)-\(file.galleryValidationIssue != nil)") {
            guard !file.isEncrypted, file.galleryValidationIssue == nil else { return }
            failed = false
            do {
                image = try await ImageRepository.shared.image(
                    for: file,
                    token: token,
                    fullSize: fullSize
                )
            } catch {
                failed = true
            }
        }
    }
}

private struct GalleryPhotoChangedPlaceholder: View {
    let showsExplanation: Bool

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)

            VStack(spacing: GallerySpacing.space8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Photo note changed")
                    .font(.callout.weight(.semibold))
                    .multilineTextAlignment(.center)
                if showsExplanation {
                    Text("Gallery photos must contain exactly one image and no extra text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }
            .padding(GallerySpacing.space16)
        }
        .help("Gallery photos must contain exactly one image and no extra text.")
    }
}
