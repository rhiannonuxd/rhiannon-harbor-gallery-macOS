import SwiftUI
import UniformTypeIdentifiers

struct NewGalleryView: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var stack = ""
    @State private var selectedURLs: [URL] = []
    @State private var showingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: GallerySpacing.space24) {
            HStack {
                VStack(alignment: .leading, spacing: GallerySpacing.space4) {
                    Text("New Gallery")
                        .font(.title2.weight(.semibold))
                    Text("Harbor will create one notebook and one note per photo.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: GallerySpacing.space8) {
                Text("Gallery name").font(.headline)
                TextField("e.g. Chile 2012 Trip", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: GallerySpacing.space8) {
                Text("Stack (optional)").font(.headline)
                Picker("Stack", selection: $stack) {
                    Text("No stack").tag("")
                    ForEach(store.availableStacks) { item in
                        Text(item.name).tag(item.name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button {
                    showingImporter = true
                } label: {
                    Label("Choose Photos…", systemImage: "photo.badge.plus")
                }
                Text(selectionLabel)
                    .foregroundStyle(.secondary)
            }

            if !selectedURLs.isEmpty {
                List(selectedURLs, id: \.self) { url in
                    HStack {
                        Image(systemName: "photo")
                        Text(url.lastPathComponent).lineLimit(1)
                    }
                }
                .frame(minHeight: 180)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .overlay {
                        Text("Choose the images that belong in this gallery.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 150)
            }

            if store.isCreatingGallery {
                VStack(alignment: .leading, spacing: GallerySpacing.space8) {
                    ProgressView()
                    Text(store.creationProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let creationError = store.creationErrorMessage {
                Label {
                    Text(creationError)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Gallery creation failed: \(creationError)")
            }

            HStack {
                Text("Requires Files, Notes, and Notebooks permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Create Gallery") {
                    Task {
                        if await store.createGallery(
                            named: name,
                            stack: stack.isEmpty ? nil : stack,
                            imageURLs: selectedURLs
                        ) {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || selectedURLs.isEmpty
                        || store.isCreatingGallery
                )
            }
        }
        .padding(GallerySpacing.space24)
        .frame(width: 610, height: 570)
        .onAppear {
            store.clearGalleryCreationError()
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                selectedURLs = urls
            case let .failure(error):
                store.errorMessage = error.localizedDescription
            }
        }
    }

    private var selectionLabel: String {
        selectedURLs.isEmpty
            ? "No photos selected"
            : "\(selectedURLs.count) \(selectedURLs.count == 1 ? "photo" : "photos") selected"
    }
}
