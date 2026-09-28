import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: GalleryStore

    var body: some View {
        Group {
            if store.token == nil {
                WelcomeView()
            } else {
                AlbumsView()
            }
        }
        .alert(
            "Harbor Gallery",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "An unknown error occurred.")
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var token = ""

    var body: some View {
        VStack(spacing: GallerySpacing.space24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 58, weight: .light))
                .foregroundStyle(.tint)

            VStack(spacing: GallerySpacing.space8) {
                Text("Turn Harbor into a photo gallery")
                    .font(.largeTitle.weight(.semibold))
                Text("Create photo galleries in Harbor or use notebooks you already have.\nYour access token is stored securely in Mac Keychain.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: GallerySpacing.space8) {
                Text("Harbor personal access token")
                    .font(.headline)
                SecureField("hbp_…", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 420)
                Text("Create one in Harbor’s web app under Settings → Developer with Files, Notes, and Notebooks permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 420, alignment: .leading)
            }

            Button {
                Task { _ = await store.connect(using: token) }
            } label: {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Connect to Harbor")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)
        }
        .padding(GallerySpacing.space48)
    }
}

struct AlbumsView: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var selectedAlbum: HarborAlbum?
    @State private var showingNewGallery = false
    @State private var showingAdoptNotebook = false

    var body: some View {
        GeometryReader { geometry in
            galleryBrowser
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailView(album: album, parentSize: geometry.size)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingNewGallery) {
                NewGalleryView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingAdoptNotebook) {
                AdoptNotebookView()
                    .environmentObject(store)
            }
        }
    }

    private var galleryBrowser: some View {
        VStack(spacing: 0) {
            if store.isLoading {
                ProgressView(
                    store.totalCount > 0
                        ? "Loading \(store.loadedCount) of \(store.totalCount) images…"
                        : "Loading images…"
                )
                .controlSize(.small)
                .padding(.vertical, GallerySpacing.space8)
            }

            if store.filteredAlbums.isEmpty && !store.isLoading {
                VStack(spacing: GallerySpacing.space16) {
                    Image(systemName: store.searchText.isEmpty ? "rectangle.stack.badge.plus" : "magnifyingglass")
                        .font(.system(size: 42, weight: .light))
                    Text(store.searchText.isEmpty ? "No Harbor galleries yet" : "No matching galleries")
                        .font(.title2.weight(.medium))
                    Text(store.searchText.isEmpty
                         ? "Create one to upload photos as individual Harbor notes in a dedicated notebook."
                         : "Try a gallery name or photo filename.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if store.searchText.isEmpty {
                        HStack(spacing: GallerySpacing.space8) {
                            Button("New Gallery") { showingNewGallery = true }
                                .buttonStyle(.borderedProminent)
                            Button("Use Existing Notebook") { showingAdoptNotebook = true }
                            Button("Recover Galleries") {
                                Task { await store.recoverGalleries() }
                            }
                            .disabled(store.isRecovering)
                        }
                        if store.isRecovering {
                            ProgressView("Looking for Harbor Gallery photo markers…")
                                .controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { viewport in
                    let contentWidth = max(0, viewport.size.width - GallerySpacing.space64)
                    let contentHeight = max(0, viewport.size.height - GallerySpacing.space64)
                    let columnCount = max(
                        1,
                        Int(
                            (contentWidth + GallerySpacing.space16)
                                / (300 + GallerySpacing.space16)
                        )
                    )
                    let fixedColumns = Array(
                        repeating: GridItem(
                            .fixed(300),
                            spacing: GallerySpacing.space16,
                            alignment: .topLeading
                        ),
                        count: columnCount
                    )

                    ScrollView {
                        LazyVGrid(
                            columns: fixedColumns,
                            alignment: .leading,
                            spacing: GallerySpacing.space16
                        ) {
                            ForEach(store.filteredAlbums) { album in
                                AlbumCard(album: album)
                                    .onTapGesture { selectedAlbum = album }
                            }
                        }
                        .frame(width: contentWidth, alignment: .topLeading)
                    }
                    .frame(
                        width: contentWidth,
                        height: contentHeight,
                        alignment: .topLeading
                    )
                    .padding(GallerySpacing.space32)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                HStack(spacing: 0) {
                    Text(albumCountLabel)
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    Spacer().frame(width: GallerySpacing.space16)

                    Button {
                        Task { await store.reload() }
                    } label: {
                        ToolbarActionLabel(title: "Sync", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isLoading)

                    Spacer().frame(width: GallerySpacing.space8)

                    Button {
                        showingNewGallery = true
                    } label: {
                        ToolbarActionLabel(title: "Create", systemImage: "plus")
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(width: GallerySpacing.space8)

                    ToolbarButtonSurface {
                        Menu {
                            Button("Use Existing Notebook as Gallery…") {
                                showingAdoptNotebook = true
                            }
                            Button("Recover Galleries…") {
                                Task { await store.recoverGalleries() }
                            }
                            .disabled(store.isRecovering)
                        } label: {
                            ToolbarMoreLabel()
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }

                    Spacer().frame(width: GallerySpacing.space16)

                    ToolbarSearchField(
                        text: $store.searchText,
                        placeholder: "Gallery or photo name"
                    )
                    .frame(width: 240)
                }
            }
        }
    }

    private var albumCountLabel: String {
        let count = store.filteredAlbums.count
        return "\(count) \(count == 1 ? "gallery" : "galleries")"
    }
}

private struct ToolbarActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        ToolbarButtonSurface {
            HStack(spacing: GallerySpacing.space4) {
                Text(title)
                Image(systemName: systemImage)
            }
        }
    }
}

private struct ToolbarMoreLabel: View {
    var body: some View {
        Text("More  \(Image(systemName: "chevron.down"))")
            .fixedSize()
    }
}

private struct ToolbarButtonSurface<Content: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, GallerySpacing.space8)
            .frame(height: 26)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        Color(nsColor: isHovering
                              ? .selectedControlColor
                              : .controlBackgroundColor)
                            .opacity(isHovering ? 0.16 : 0.8)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.separator.opacity(0.7), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.5)
            .fixedSize()
            .onHover { isHovering = $0 }
    }
}

private struct ToolbarSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }
        searchField.placeholderString = placeholder
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            text = searchField.stringValue
        }
    }
}

struct AlbumCard: View {
    @EnvironmentObject private var store: GalleryStore
    let album: HarborAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let cover = album.cover {
                    RemoteHarborImage(file: cover, token: store.token ?? "")
                } else {
                    ZStack {
                        Color(nsColor: .controlBackgroundColor)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 300, height: 170)
            .clipped()

            VStack(alignment: .leading, spacing: GallerySpacing.space4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(album.photoCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(GallerySpacing.space16)
            .frame(width: 300, alignment: .leading)
        }
        .frame(width: 300, alignment: .topLeading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.separator.opacity(0.65), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject private var store: GalleryStore
    @Environment(\.dismiss) private var dismiss
    let album: HarborAlbum
    let parentSize: CGSize

    @State private var selectedFile: HarborFile?
    @State private var tileSize: Double = 190
    @State private var showingEditor = false
    @State private var showsMoreBelow = false

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: tileSize, maximum: tileSize * 1.35), spacing: GallerySpacing.space16)]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: GallerySpacing.space4) {
                    Text(displayedAlbum.title).font(.title2.weight(.semibold))
                    Text(displayedAlbum.photoCountLabel).foregroundStyle(.secondary)
                }
                Spacer()
                Slider(value: $tileSize, in: 120...300)
                    .frame(width: 150)
                Button {
                    showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button("Done") { dismiss() }
            }
            .padding(GallerySpacing.space24)

            Divider()

            if displayedAlbum.files.isEmpty {
                Text("This gallery does not contain any photos yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { viewport in
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: GallerySpacing.space16) {
                            ForEach(displayedAlbum.files) { file in
                                GalleryCard(file: file, tileSize: tileSize)
                                    .onTapGesture { selectedFile = file }
                            }
                        }
                        .padding(GallerySpacing.space24)
                        .background {
                            GeometryReader { content in
                                Color.clear.preference(
                                    key: AlbumGridFramePreferenceKey.self,
                                    value: content.frame(in: .named("album-photo-scroll"))
                                )
                            }
                        }
                    }
                    .coordinateSpace(name: "album-photo-scroll")
                    .onPreferenceChange(AlbumGridFramePreferenceKey.self) { frame in
                        guard frame != .zero else { return }
                        let moreContentIsBelow = gridNeedsScrolling
                            && frame.maxY > viewport.size.height + 1
                        if showsMoreBelow != moreContentIsBelow {
                            showsMoreBelow = moreContentIsBelow
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if showsMoreBelow {
                            MoreContentBelowIndicator()
                                .transition(.opacity)
                        }
                    }
                    .onAppear {
                        showsMoreBelow = gridNeedsScrolling
                    }
                    .onChange(of: tileSize) { _ in
                        showsMoreBelow = gridNeedsScrolling
                    }
                    .onChange(of: displayedAlbum.files.count) { _ in
                        showsMoreBelow = gridNeedsScrolling
                    }
                }
            }
        }
        .frame(width: sheetWidth, height: fittedSheetHeight)
        .sheet(item: $selectedFile) { file in
            PhotoDetailView(
                files: displayedAlbum.files,
                initialFile: file,
                token: store.token ?? "",
                availableSize: CGSize(
                    width: sheetWidth,
                    height: availableSheetHeight
                )
            )
        }
        .sheet(isPresented: $showingEditor) {
            EditGalleryView(album: displayedAlbum) {
                dismiss()
            }
                .environmentObject(store)
        }
    }

    private var sheetWidth: Double {
        max(560, Double(parentSize.width - GallerySpacing.space48))
    }

    private var availableSheetHeight: Double {
        max(220, Double(parentSize.height - GallerySpacing.space32))
    }

    private var displayedAlbum: HarborAlbum {
        store.albums.first { $0.id == album.id } ?? album
    }

    private var fittedSheetHeight: Double {
        guard !displayedAlbum.files.isEmpty else {
            return min(availableSheetHeight, 248)
        }

        return min(availableSheetHeight, 88 + calculatedGridHeight)
    }

    private var gridNeedsScrolling: Bool {
        calculatedGridHeight > fittedSheetHeight - 88
    }

    private var calculatedGridHeight: Double {
        guard !displayedAlbum.files.isEmpty else { return 0 }

        let horizontalPadding = Double(GallerySpacing.space48)
        let spacing = Double(GallerySpacing.space16)
        let availableWidth = sheetWidth - horizontalPadding
        let columnCount = max(1, Int((availableWidth + spacing) / (tileSize + spacing)))
        let rowCount = Int(ceil(Double(displayedAlbum.files.count) / Double(columnCount)))
        let cardHeight = tileSize * 0.78 + 50
        let gridHeight = Double(rowCount) * cardHeight
            + Double(max(0, rowCount - 1)) * spacing
            + Double(GallerySpacing.space48)
        return gridHeight
    }
}

private struct AlbumGridFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct MoreContentBelowIndicator: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    .clear,
                    Color(nsColor: .windowBackgroundColor).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(GallerySpacing.space8)
                .background(.ultraThinMaterial, in: Circle())
                .padding(.bottom, GallerySpacing.space8)
        }
        .frame(height: GallerySpacing.space64)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct GalleryCard: View {
    @EnvironmentObject private var store: GalleryStore
    let file: HarborFile
    let tileSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { geometry in
                RemoteHarborImage(file: file, token: store.token ?? "")
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .frame(height: tileSize * 0.78)

            VStack(alignment: .leading, spacing: GallerySpacing.space4) {
                Text(file.noteTitle)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(file.originalFilename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(GallerySpacing.space8)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.separator.opacity(0.65), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}
