import AppKit
import Combine
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
        .clipShape(NotchRevealShape(progress: transition.progress))
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.items) { item in
                            ClipboardCard(
                                item: item,
                                isSelected: store.selectedID == item.id
                            )
                            .onTapGesture {
                                store.selectAndCopy(item)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                .frame(maxWidth: .infinity, maxHeight: 166)
                .clipped()
            }
        }
    }
}

private struct NotchRevealShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clampedProgress = min(max(progress, 0), 1)
        let widthProgress = 0.18 + clampedProgress * 0.82
        let heightProgress = 0.05 + clampedProgress * 0.95
        let width = rect.width * widthProgress
        let height = rect.height * heightProgress
        let revealRect = CGRect(
            x: rect.midX - width / 2,
            y: rect.minY,
            width: width,
            height: height
        )

        return Path(
            bottomRoundedRect: revealRect,
            cornerRadius: 22
        )
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
            Image(systemName: item?.kind.symbolName ?? "clipboard")
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

private struct ClipboardCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)

                Text(item.kind.title)
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

                Text(item.sourceApp ?? item.kind.title)
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
            if let image = NSImage(data: data) {
                ImagePreview(image: image)
            } else {
                Text(item.previewText)
                    .previewTextStyle()
            }

        case .fileURL(let url):
            if url.isFileURL, let image = NSImage(contentsOf: url) {
                ImagePreview(image: image)
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
    let image: NSImage

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(height: ClipboardCardMetrics.previewHeight)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .clipped()
    }
}

private enum ClipboardCardMetrics {
    static let width: CGFloat = 220
    static let height: CGFloat = 156
    static let padding: CGFloat = 11
    static let previewHeight: CGFloat = 84
    static let footerHeight: CGFloat = 15
    static let footerIconWidth: CGFloat = 10
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
