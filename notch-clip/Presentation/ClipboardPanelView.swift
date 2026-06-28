import AppKit
import Combine
import ImageIO
import SwiftUI

@MainActor
final class PanelTransitionState: ObservableObject {
    @Published var progress: CGFloat = 0
}

struct ClipboardPanelView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var transition: PanelTransitionState

    var body: some View {
        ZStack(alignment: .top) {
            NotchPanelBackground()

            VStack(alignment: .leading, spacing: 22) {
                header
                content
            }
            .padding(.top, 24)
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
            .opacity(contentProgress)
            .offset(y: (1 - contentProgress) * -12)
            .scaleEffect(0.985 + contentProgress * 0.015, anchor: .top)
        }
        .frame(minWidth: 820, minHeight: 310)
        .preferredColorScheme(.dark)
    }

    private var contentProgress: CGFloat {
        min(max((transition.progress - 0.22) / 0.78, 0), 1)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                SearchField(text: $store.query)
                    .frame(width: 440)

                FilterTabs(selection: $store.filter)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 12) {
                CurrentClipboardValueView(item: store.currentClipboardItem)

                HStack(spacing: 10) {
                    PanelIconButton(
                        symbolName: store.selectedItem?.isPinned == true ? "pin.slash" : "pin",
                        title: "Pin",
                        isEnabled: store.selectedItem != nil
                    ) {
                        store.togglePinSelected()
                    }
                    PanelIconButton(symbolName: "trash", title: "Delete", isEnabled: store.selectedItem != nil) {
                        store.deleteSelected()
                    }
                }
            }
        }
    }

    private var content: some View {
        Group {
            if store.items.isEmpty {
                EmptyClipboardView()
            } else {
                GeometryReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(store.visibleItems) { item in
                                ClipboardCard(
                                    item: item,
                                    isSelected: store.selectedID == item.id,
                                    scrollViewportWidth: proxy.size.width
                                )
                                .equatable()
                                .onTapGesture {
                                    store.selectAndCopy(item)
                                }
                                .onAppear {
                                    store.loadMoreItemsIfNeeded(currentItem: item)
                                }
                            }

                            if store.hasMoreVisibleItems {
                                Color.clear
                                    .frame(width: 1, height: ClipboardCardMetrics.height)
                                    .onAppear {
                                        store.loadNextVirtualPage()
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .coordinateSpace(name: ClipboardHistoryLayout.coordinateSpaceName)
                }
                .frame(maxWidth: .infinity, maxHeight: 166)
                .clipped()
            }
        }
    }
}

private struct NotchPanelBackground: View {
    var body: some View {
        let shape = BottomRoundedPanelShape(cornerRadius: 22)

        PanelVisualEffect(material: .hudWindow, blendingMode: .behindWindow)
            .clipShape(shape)
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.10, blue: 0.11).opacity(0.72),
                            Color(red: 0.01, green: 0.012, blue: 0.015).opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.11),
                            .white.opacity(0.025),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                shape.stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.62), radius: 34, y: 20)
            .shadow(color: .black.opacity(0.32), radius: 8, y: 2)
    }
}

private struct PanelVisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

private struct BottomRoundedPanelShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(bottomRoundedRect: rect, cornerRadius: cornerRadius)
    }
}

private struct CurrentClipboardValueView: View {
    let item: ClipboardItem?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item?.displaySymbolName ?? "clipboard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("Current clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))

                Text(item?.previewText ?? "Clipboard is empty")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: 280, height: 42)
        .background(GlassSurface(cornerRadius: 10, fillOpacity: 0.08, strokeOpacity: 0.12))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))

            TextField("Search clipboard history", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(GlassSurface(cornerRadius: 10, fillOpacity: 0.08, strokeOpacity: 0.14))
        .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
    }
}

private struct FilterTabs: View {
    @Binding var selection: ClipboardFilter

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ClipboardFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Label(filter.title, systemImage: filter.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(height: 32)
                        .padding(.horizontal, 14)
                        .foregroundStyle(selection == filter ? .white : .white.opacity(0.55))
                        .background(
                            Group {
                                if selection == filter {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.white.opacity(0.15))
                                        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(GlassSurface(cornerRadius: 10, fillOpacity: 0.075, strokeOpacity: 0.08))
    }
}

private struct PanelIconButton: View {
    let symbolName: String
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Label(title, systemImage: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isEnabled ? .white.opacity(isHovered ? 0.94 : 0.74) : .white.opacity(0.28))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(
                    GlassSurface(
                        cornerRadius: 8,
                        fillOpacity: isEnabled ? (isHovered ? 0.15 : 0.09) : 0.045,
                        strokeOpacity: isEnabled ? (isHovered ? 0.20 : 0.10) : 0.04
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .scaleEffect(isHovered && isEnabled ? 1.025 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.86), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct ClipboardCard: View, Equatable {
    let item: ClipboardItem
    let isSelected: Bool
    let scrollViewportWidth: CGFloat
    @State private var isHovered = false
    @State private var isPreviewInVisibleArea = false

    nonisolated static func == (lhs: ClipboardCard, rhs: ClipboardCard) -> Bool {
        lhs.item.id == rhs.item.id
            && lhs.item.isPinned == rhs.item.isPinned
            && lhs.isSelected == rhs.isSelected
            && lhs.scrollViewportWidth == rhs.scrollViewportWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: item.displaySymbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)

                Text(item.displayKindTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(isSelected ? .white.opacity(0.86) : .white.opacity(0.60))
            .frame(height: 17, alignment: .leading)

            preview

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .opacity(item.isPinned ? 1 : 0)
                    .frame(width: ClipboardCardMetrics.footerIconWidth)
                    .accessibilityHidden(!item.isPinned)

                Text(item.sourceApp ?? item.displayKindTitle)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(item.metadata)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.46))
            .frame(height: ClipboardCardMetrics.footerHeight)
        }
        .padding(ClipboardCardMetrics.padding)
        .frame(width: ClipboardCardMetrics.width, height: ClipboardCardMetrics.height)
        .background(
            GlassSurface(
                cornerRadius: 10,
                fillOpacity: isSelected ? 0.16 : (isHovered ? 0.115 : 0.082),
                strokeOpacity: isSelected ? 0.28 : (isHovered ? 0.16 : 0.075)
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color(red: 0.54, green: 0.72, blue: 1).opacity(0.72) : .clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(isSelected ? 0.34 : 0.20), radius: isSelected ? 16 : 10, y: isSelected ? 10 : 6)
        .scaleEffect(isHovered ? 1.015 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: isHovered)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: isSelected)
        .onHover { isHovered = $0 }
        .background(
            ScrollAreaVisibilityReader(
                viewportWidth: scrollViewportWidth,
                isVisible: $isPreviewInVisibleArea
            )
        )
    }

    @ViewBuilder
    private var preview: some View {
        switch item.content {
        case .color(let color):
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: color) ?? Color.white.opacity(0.08))
                Text(color)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(height: ClipboardCardMetrics.previewHeight)
            .frame(maxWidth: .infinity)
            .clipped()

        case .image(let data):
            LazyImagePreview(
                request: .data(data, kind: .image, cacheKey: item.contentHash),
                placeholder: .text(item.previewText),
                isVisible: isPreviewInVisibleArea
            )

        case .pdf(let data):
            LazyImagePreview(
                request: .data(data, kind: .pdf, cacheKey: item.contentHash),
                placeholder: .pdf(title: item.displayTitle),
                isVisible: isPreviewInVisibleArea
            )

        case .fileURL(let url):
            if let request = ClipboardImagePreviewRequest(
                fileURL: url,
                cacheKey: item.contentHash,
                embeddedData: item.embeddedPreviewData(for: url)
            ) {
                LazyImagePreview(
                    request: request,
                    placeholder: request.placeholder(title: item.displayTitle, fallbackText: item.previewText),
                    isVisible: isPreviewInVisibleArea
                )
            } else {
                Text(item.previewText)
                    .previewTextStyle()
            }

        case .url(let url, _):
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    Image(systemName: "globe")
                        .font(.system(size: 22, weight: .regular))
                        .frame(width: 26)

                    Text(item.displayTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(url.absoluteString)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundStyle(.white.opacity(0.76))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .frame(height: ClipboardCardMetrics.previewHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GlassSurface(cornerRadius: 9, fillOpacity: 0.10, strokeOpacity: 0.06))
            .clipped()

        default:
            Text(item.previewText)
                .previewTextStyle(monospaced: item.kind == .code)
        }
    }
}

private struct ImagePreview: View {
    let image: CachedClipboardPreviewImage
    let kind: PreviewableFileKind

    private var cornerRadius: CGFloat {
        kind == .pdf ? 7 : 9
    }

    var body: some View {
        Group {
            switch kind {
            case .image:
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .scaledToFill()

            case .pdf:
                Image(decorative: image.cgImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 5)
                    .padding(.horizontal, 24)
                    .background(PDFPreviewBackdrop())
            }
        }
        .frame(height: ClipboardCardMetrics.previewHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
    }
}

private struct LazyImagePreview: View {
    let request: ClipboardImagePreviewRequest
    let placeholder: PreviewPlaceholder
    let isVisible: Bool

    @State private var image: CachedClipboardPreviewImage?
    @State private var isLoading = false
    @State private var failedRequestID: String?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if isVisible, let image {
                ImagePreview(image: image, kind: request.kind)
            } else {
                placeholder
            }
        }
        .onAppear {
            updateLoadingState()
        }
        .onDisappear {
            unload()
        }
        .onChange(of: isVisible) { _, _ in
            updateLoadingState()
        }
        .onChange(of: request.id) { _, _ in
            reset()
            updateLoadingState()
        }
    }

    private func updateLoadingState() {
        if isVisible {
            loadIfNeeded()
        } else {
            unload()
        }
    }

    private func loadIfNeeded() {
        guard image == nil, !isLoading, failedRequestID != request.id else { return }

        if let cachedImage = ClipboardPreviewImageCache.shared.cachedImage(for: request) {
            image = cachedImage
            return
        }

        guard !ClipboardPreviewImageCache.shared.hasCachedFailure(for: request) else {
            failedRequestID = request.id
            return
        }

        isLoading = true
        let currentRequest = request
        loadTask = Task(priority: .utility) {
            let loadedImage = await ClipboardPreviewImageCache.shared.image(
                for: currentRequest,
                maxPixelSize: ClipboardCardMetrics.previewMaxPixelSize
            )

            await MainActor.run {
                guard !Task.isCancelled else { return }
                isLoading = false

                if let loadedImage {
                    image = loadedImage
                } else {
                    failedRequestID = currentRequest.id
                }
            }
        }
    }

    private func unload() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        image = nil
    }

    private func reset() {
        unload()
        failedRequestID = nil
    }
}

private enum PreviewPlaceholder: View {
    case text(String)
    case pdf(title: String)

    var body: some View {
        switch self {
        case .text(let text):
            Text(text)
                .previewTextStyle()
        case .pdf(let title):
            MicroPDFPreview(title: title)
        }
    }
}

private struct MicroPDFPreview: View {
    let title: String

    var body: some View {
        ZStack {
            PDFPreviewBackdrop()

            HStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 48, height: 62)
                        .shadow(color: .black.opacity(0.22), radius: 7, y: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.22))
                            .frame(width: 24, height: 5)
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.black.opacity(index == 0 ? 0.16 : 0.10))
                                .frame(width: index == 3 ? 20 : 30, height: 3)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.leading, 9)
                    .frame(width: 48, height: 62, alignment: .topLeading)

                    Text("PDF")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(red: 0.86, green: 0.18, blue: 0.18))
                        )
                        .offset(x: 5, y: 8)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.22))
                                .frame(height: 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 13)
        }
        .frame(height: ClipboardCardMetrics.previewHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .clipped()
    }
}

private struct PDFPreviewBackdrop: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.28),
                        Color(red: 0.16, green: 0.18, blue: 0.20).opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            )
    }
}

private struct ScrollAreaVisibilityReader: View {
    let viewportWidth: CGFloat
    @Binding var isVisible: Bool

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named(ClipboardHistoryLayout.coordinateSpaceName))
            let visible = frame.maxX > 0 && frame.minX < viewportWidth

            Color.clear
                .onAppear {
                    updateVisibility(visible)
                }
                .onChange(of: visible) { _, newValue in
                    updateVisibility(newValue)
                }
        }
    }

    private func updateVisibility(_ newValue: Bool) {
        guard isVisible != newValue else { return }

        DispatchQueue.main.async {
            guard isVisible != newValue else { return }
            isVisible = newValue
        }
    }
}

private struct CachedClipboardPreviewImage: @unchecked Sendable {
    let cgImage: CGImage
    let cost: Int

    nonisolated init(cgImage: CGImage) {
        self.cgImage = cgImage
        self.cost = max(cgImage.bytesPerRow * cgImage.height, 1)
    }
}

private enum ClipboardImagePreviewRequest: Identifiable, Equatable, Sendable {
    case data(Data, kind: PreviewableFileKind, cacheKey: String)
    case fileURL(URL, kind: PreviewableFileKind)

    nonisolated init?(fileURL url: URL, cacheKey: String, embeddedData: Data?) {
        guard let kind = PreviewableFileKind(fileURL: url) else { return nil }

        if let embeddedData {
            self = .data(embeddedData, kind: kind, cacheKey: "file-preview:\(cacheKey)")
        } else {
            self = .fileURL(url, kind: kind)
        }
    }

    nonisolated var id: String {
        cacheKey
    }

    nonisolated var cacheKey: String {
        switch self {
        case .data(_, let kind, let cacheKey):
            "data:\(kind.rawValue):\(cacheKey)"
        case .fileURL(let url, let kind):
            "file:\(kind.rawValue):\(url.standardizedFileURL.path)"
        }
    }

    nonisolated var kind: PreviewableFileKind {
        switch self {
        case .data(_, let kind, _), .fileURL(_, let kind):
            kind
        }
    }

    nonisolated func placeholder(title: String, fallbackText: String) -> PreviewPlaceholder {
        switch kind {
        case .image:
            .text(fallbackText)
        case .pdf:
            .pdf(title: title)
        }
    }

    nonisolated func makeThumbnail(maxPixelSize: Int) -> CachedClipboardPreviewImage? {
        switch self {
        case .data(let data, let kind, _):
            return kind.thumbnail(forData: data, maxPixelSize: maxPixelSize)
        case .fileURL(let url, let kind):
            return kind.thumbnail(forFileURL: url, maxPixelSize: maxPixelSize)
        }
    }
}

private extension PreviewableFileKind {
    nonisolated func thumbnail(forData data: Data, maxPixelSize: Int) -> CachedClipboardPreviewImage? {
        switch self {
        case .image:
            makeImageThumbnail(source: CGImageSourceCreateWithData(data as CFData, imageSourceOptions), maxPixelSize: maxPixelSize)
        case .pdf:
            makePDFThumbnail(document: CGDataProvider(data: data as CFData).flatMap(CGPDFDocument.init), maxPixelSize: maxPixelSize)
        }
    }

    nonisolated func thumbnail(forFileURL url: URL, maxPixelSize: Int) -> CachedClipboardPreviewImage? {
        guard url.isFileURL else { return nil }

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        switch self {
        case .image:
            return makeImageThumbnail(
                source: CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions),
                maxPixelSize: maxPixelSize
            )
        case .pdf:
            return makePDFThumbnail(document: CGPDFDocument(url as CFURL), maxPixelSize: maxPixelSize)
        }
    }

    private nonisolated var imageSourceOptions: CFDictionary {
        [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
    }

    private nonisolated func makeImageThumbnail(
        source: CGImageSource?,
        maxPixelSize: Int
    ) -> CachedClipboardPreviewImage? {
        guard let source else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelSize, 1)
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return CachedClipboardPreviewImage(cgImage: image)
    }

    private nonisolated func makePDFThumbnail(
        document: CGPDFDocument?,
        maxPixelSize: Int
    ) -> CachedClipboardPreviewImage? {
        guard let page = document?.page(at: 1) else { return nil }

        let cropBox = page.getBoxRect(.cropBox)
        let pageRect = cropBox.isEmpty ? page.getBoxRect(.mediaBox) : cropBox
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }

        let scale = CGFloat(max(maxPixelSize, 1)) / max(pageRect.width, pageRect.height)
        let width = max(Int((pageRect.width * scale).rounded(.up)), 1)
        let height = max(Int((pageRect.height * scale).rounded(.up)), 1)
        let targetRect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(targetRect)
        context.saveGState()
        context.translateBy(x: 0, y: targetRect.height)
        context.scaleBy(x: 1, y: -1)
        context.concatenate(
            page.getDrawingTransform(
                .cropBox,
                rect: targetRect,
                rotate: 0,
                preserveAspectRatio: true
            )
        )
        context.drawPDFPage(page)
        context.restoreGState()

        guard let image = context.makeImage() else { return nil }
        return CachedClipboardPreviewImage(cgImage: image)
    }
}

private extension ClipboardItem {
    nonisolated var displayKindTitle: String {
        if case .fileURL(let url) = content,
           let kind = PreviewableFileKind(fileURL: url) {
            return kind.displayTitle
        }

        return kind.title
    }

    nonisolated var displaySymbolName: String {
        if case .fileURL(let url) = content,
           let kind = PreviewableFileKind(fileURL: url) {
            return kind.symbolName
        }

        return kind.symbolName
    }

    nonisolated func embeddedPreviewData(for fileURL: URL) -> Data? {
        guard let kind = PreviewableFileKind(fileURL: fileURL) else { return nil }

        if let data = representations.first(where: { $0.type == ClipboardTypeIdentifier.filePreviewData })?.data {
            return data
        }

        let dataTypes = switch kind {
        case .image:
            ClipboardTypeIdentifier.imageDataTypes
        case .pdf:
            ClipboardTypeIdentifier.pdfDataTypes
        }

        return representations.first { dataTypes.contains($0.type) }?.data
    }
}

private extension PreviewableFileKind {
    nonisolated var displayTitle: String {
        switch self {
        case .image:
            "Image"
        case .pdf:
            "PDF"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .image:
            "photo"
        case .pdf:
            "doc.richtext"
        }
    }
}

private final class ClipboardPreviewImageCache {
    static let shared = ClipboardPreviewImageCache()

    private let images = NSCache<NSString, CachedClipboardPreviewImageBox>()
    private let failures = NSCache<NSString, NSNumber>()

    private init() {
        images.countLimit = 80
        images.totalCostLimit = 48 * 1024 * 1024
        failures.countLimit = 200
    }

    func cachedImage(for request: ClipboardImagePreviewRequest) -> CachedClipboardPreviewImage? {
        images.object(forKey: request.cacheKey as NSString)?.image
    }

    func hasCachedFailure(for request: ClipboardImagePreviewRequest) -> Bool {
        failures.object(forKey: request.cacheKey as NSString) != nil
    }

    func image(
        for request: ClipboardImagePreviewRequest,
        maxPixelSize: Int
    ) async -> CachedClipboardPreviewImage? {
        let cacheKey = request.cacheKey as NSString

        if let cachedImage = images.object(forKey: cacheKey)?.image {
            return cachedImage
        }

        if failures.object(forKey: cacheKey) != nil {
            return nil
        }

        let loadedImage = await Task.detached(priority: .utility) {
            request.makeThumbnail(maxPixelSize: maxPixelSize)
        }.value

        if let loadedImage {
            images.setObject(CachedClipboardPreviewImageBox(loadedImage), forKey: cacheKey, cost: loadedImage.cost)
        } else {
            failures.setObject(NSNumber(value: true), forKey: cacheKey)
        }

        return loadedImage
    }
}

private final class CachedClipboardPreviewImageBox {
    let image: CachedClipboardPreviewImage

    init(_ image: CachedClipboardPreviewImage) {
        self.image = image
    }
}

private enum ClipboardHistoryLayout {
    static let coordinateSpaceName = "ClipboardHistoryScroll"
}

private enum ClipboardCardMetrics {
    static let width: CGFloat = 220
    static let height: CGFloat = 156
    static let padding: CGFloat = 11
    static let previewHeight: CGFloat = 84
    static let footerHeight: CGFloat = 15
    static let footerIconWidth: CGFloat = 10
    static let previewMaxPixelSize = Int(max(width - padding * 2, previewHeight) * 2)
}

private struct EmptyClipboardView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28, weight: .regular))
            Text("Clipboard history is empty")
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.52))
        .frame(maxWidth: .infinity, minHeight: 154)
    }
}

private extension Text {
    func previewTextStyle(monospaced: Bool = false) -> some View {
        self
            .font(.system(size: 14, weight: .medium, design: monospaced ? .monospaced : .default))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(3)
            .padding(10)
            .frame(height: ClipboardCardMetrics.previewHeight, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(GlassSurface(cornerRadius: 9, fillOpacity: 0.10, strokeOpacity: 0.06))
            .clipped()
    }
}

private struct GlassSurface: View {
    let cornerRadius: CGFloat
    let fillOpacity: Double
    let strokeOpacity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(fillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
    }
}

private extension Path {
    init(bottomRoundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init()

        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        move(to: CGPoint(x: rect.minX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        closeSubpath()
    }
}

private extension Color {
    init?(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard raw.count == 6 || raw.count == 8,
              let value = UInt64(raw, radix: 16)
        else {
            return nil
        }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if raw.count == 8 {
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        } else {
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
