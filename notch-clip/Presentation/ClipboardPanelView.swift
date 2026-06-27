import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        ZStack(alignment: .top) {
            NotchPanelBackground()

            VStack(alignment: .leading, spacing: 22) {
                header
                content
            }
            .padding(.top, 30)
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 820, minHeight: 310)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 18) {
                SearchField(text: $store.query)
                    .frame(width: 440)

                FilterTabs(selection: $store.filter)
            }

            Spacer()

            HStack(spacing: 10) {
                PanelIconButton(symbolName: "doc.on.doc", title: "Copy") {
                    store.copySelected()
                }
                PanelIconButton(symbolName: store.selectedItem?.isPinned == true ? "pin.slash" : "pin", title: "Pin") {
                    store.togglePinSelected()
                }
                PanelIconButton(symbolName: "trash", title: "Delete") {
                    store.deleteSelected()
                }
            }
            .padding(.top, 58)
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
                                store.select(item)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct NotchPanelBackground: View {
    var body: some View {
        NotchPanelShape(cornerRadius: 22, notchWidth: 132, notchDepth: 18)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.98),
                        Color(red: 0.03, green: 0.03, blue: 0.03).opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                NotchPanelShape(cornerRadius: 22, notchWidth: 132, notchDepth: 18)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 18)
    }
}

private struct NotchPanelShape: Shape {
    let cornerRadius: CGFloat
    let notchWidth: CGFloat
    let notchDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        let notchStart = rect.midX - notchWidth / 2
        let notchEnd = rect.midX + notchWidth / 2
        let radius = min(cornerRadius, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: notchStart, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + notchDepth),
            control1: CGPoint(x: notchStart + notchWidth * 0.22, y: rect.minY),
            control2: CGPoint(x: rect.midX - notchWidth * 0.18, y: rect.minY + notchDepth)
        )
        path.addCurve(
            to: CGPoint(x: notchEnd, y: rect.minY),
            control1: CGPoint(x: rect.midX + notchWidth * 0.18, y: rect.minY + notchDepth),
            control2: CGPoint(x: notchEnd - notchWidth * 0.22, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
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
        .frame(height: 44)
        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
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
                        .frame(height: 34)
                        .padding(.horizontal, 14)
                        .foregroundStyle(selection == filter ? .white : .white.opacity(0.55))
                        .background(
                            Group {
                                if selection == filter {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct PanelIconButton: View {
    let symbolName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(item.kind.title, systemImage: item.kind.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))

            preview

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: item.isPinned ? "pin.fill" : "square")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(item.isPinned ? .white.opacity(0.82) : .white.opacity(0.35))

                Text(item.sourceApp ?? item.kind.title)
                    .lineLimit(1)

                Spacer()

                Text(item.metadata)
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(14)
        .frame(width: 220, height: 165)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.68) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.8 : 1)
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
            .frame(height: 94)

        case .image(let data):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 94)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Text(item.previewText)
                    .previewTextStyle()
            }

        case .url(let url, _):
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 28, weight: .regular))
                Text(item.displayTitle)
                    .font(.system(size: 16, weight: .bold))
                Text(url.absoluteString)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.76))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(height: 94)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

        default:
            Text(item.previewText)
                .previewTextStyle(monospaced: item.kind == .code)
        }
    }
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
            .lineLimit(5)
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
            .padding(12)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
