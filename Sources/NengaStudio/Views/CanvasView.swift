import AppKit
import NengaCore
import SwiftUI

/// 文面の編集キャンバス。はがき実寸の割合で要素をドラッグできる。
struct CanvasView: View {
    @ObservedObject var document: NengaProjectDocument
    @Binding var selectedElementID: UUID?
    var previewContact: Contact?

    @Environment(\.undoManager) private var undoManager
    @State private var zoom: Double = 1
    @State private var draggingID: UUID?
    @State private var dragStartFrame: ElementFrame?
    @State private var resizingID: UUID?
    @State private var resizeStartFrame: ElementFrame?

    private var cardWidth: Double { document.model.paper.widthMM }
    private var cardHeight: Double { document.model.paper.heightMM }

    var body: some View {
        GeometryReader { geo in
            let fit = min(
                (geo.size.width - 40) / cardWidth,
                (geo.size.height - 40) / cardHeight
            ) * zoom
            let width = cardWidth * fit
            let height = cardHeight * fit

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("はがき \(Int(cardWidth)) × \(Int(cardHeight)) mm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $zoom, in: 0.5...2.0)
                        .frame(width: 140)
                    Text("\(Int(zoom * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        if let id = selectedElementID {
                            document.update(undoManager: undoManager, actionName: "中央にそろえる") { model in
                                guard var frame = model.design[id]?.frame else { return }
                                frame.x = (cardWidth - frame.width) / 2
                                frame.y = (cardHeight - frame.height) / 2
                                model.design[id]?.frame = frame
                            }
                        }
                    } label: {
                        Label("中央にそろえる", systemImage: "align.horizontal.center")
                    }
                    .disabled(selectedElementID == nil)
                }
                .padding(.horizontal, 4)

                ZStack(alignment: .topLeading) {
                    PostcardPreviewImage(
                        document: document.model,
                        page: .design(contact: previewContact),
                        assetLoader: document.imageLoader(),
                        dpi: 130
                    )
                    .frame(width: width, height: height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedElementID = nil
                    }

                    ForEach(document.model.design.elements) { element in
                        elementOverlay(element, fit: fit)
                    }
                }
                .frame(width: width, height: height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func elementOverlay(_ element: DesignElement, fit: Double) -> some View {
        let frame = element.frame
        let isSelected = element.id == selectedElementID
        let rect = CGRect(
            x: frame.x * fit,
            y: frame.y * fit,
            width: max(frame.width * fit, 8),
            height: max(frame.height * fit, 8)
        )

        ZStack(alignment: .topLeading) {
            Rectangle()
                .stroke(isSelected ? Color.accentColor : Color.accentColor.opacity(0.25), lineWidth: isSelected ? 1.5 : 0.8)
                .background(Color.clear)
            if isSelected {
                cornerHandles(element: element, fit: fit, rect: rect)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedElementID = element.id
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard !element.isLocked, resizingID == nil else { return }
                    if draggingID != element.id {
                        draggingID = element.id
                        dragStartFrame = element.frame
                    }
                    guard let start = dragStartFrame else { return }
                    var updated = start
                    updated.x = start.x + value.translation.width / fit
                    updated.y = start.y + value.translation.height / fit
                    updated = snapped(updated)
                    document.model.design[element.id]?.frame = updated
                }
                .onEnded { _ in
                    finishDrag(elementID: element.id, actionName: "要素を移動")
                }
        )
    }

    @ViewBuilder
    private func cornerHandles(element: DesignElement, fit: Double, rect: CGRect) -> some View {
        ForEach(HandleCorner.allCases, id: \.self) { corner in
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                .frame(width: 9, height: 9)
                .position(x: corner.x(in: rect), y: corner.y(in: rect))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !element.isLocked else { return }
                            if resizingID != element.id {
                                resizingID = element.id
                                resizeStartFrame = element.frame
                            }
                            guard let start = resizeStartFrame else { return }
                            var updated = start
                            let dx = value.translation.width / fit
                            let dy = value.translation.height / fit
                            switch corner {
                            case .topLeft:
                                updated.x = start.x + dx
                                updated.y = start.y + dy
                                updated.width = max(start.width - dx, 4)
                                updated.height = max(start.height - dy, 4)
                            case .topRight:
                                updated.y = start.y + dy
                                updated.width = max(start.width + dx, 4)
                                updated.height = max(start.height - dy, 4)
                            case .bottomLeft:
                                updated.x = start.x + dx
                                updated.width = max(start.width - dx, 4)
                                updated.height = max(start.height + dy, 4)
                            case .bottomRight:
                                updated.width = max(start.width + dx, 4)
                                updated.height = max(start.height + dy, 4)
                            }
                            document.model.design[element.id]?.frame = updated
                        }
                        .onEnded { _ in
                            finishResize(elementID: element.id)
                        }
                )
        }
    }

    private func finishDrag(elementID: UUID, actionName: String) {
        if let start = dragStartFrame {
            document.registerFrameUndo(
                elementID: elementID,
                frame: start,
                actionName: actionName,
                undoManager: undoManager
            )
        }
        draggingID = nil
        dragStartFrame = nil
    }

    private func finishResize(elementID: UUID) {
        if let start = resizeStartFrame {
            document.registerFrameUndo(
                elementID: elementID,
                frame: start,
                actionName: "要素の大きさを変更",
                undoManager: undoManager
            )
        }
        resizingID = nil
        resizeStartFrame = nil
    }

    /// はがきの中央と 5mm の格子に吸着させる。
    private func snapped(_ frame: ElementFrame) -> ElementFrame {
        var updated = frame
        let threshold = 1.2
        let centerX = (cardWidth - updated.width) / 2
        let centerY = (cardHeight - updated.height) / 2
        if abs(updated.x - centerX) < threshold { updated.x = centerX }
        if abs(updated.y - centerY) < threshold { updated.y = centerY }
        let grid = 1.0
        updated.x = (updated.x / grid).rounded() * grid
        updated.y = (updated.y / grid).rounded() * grid
        return updated
    }
}

private enum HandleCorner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    func x(in rect: CGRect) -> CGFloat {
        switch self {
        case .topLeft, .bottomLeft: rect.minX
        case .topRight, .bottomRight: rect.maxX
        }
    }

    func y(in rect: CGRect) -> CGFloat {
        switch self {
        case .topLeft, .topRight: rect.minY
        case .bottomLeft, .bottomRight: rect.maxY
        }
    }
}
