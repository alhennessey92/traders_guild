import Foundation
import Combine

struct ChartDrawingPoint: Codable, Hashable {
    var time: Date
    var price: Double
}

enum ChartDrawingType: String, Codable, CaseIterable, Hashable {
    case trendline
    case horizontalLine
    case zone
    case supportLevel
    case resistanceLevel
    case textNote
    case emoji

    var title: String {
        switch self {
        case .trendline:
            return "Trendline"
        case .horizontalLine:
            return "Horizontal Line"
        case .zone:
            return "Zone"
        case .supportLevel:
            return "Support"
        case .resistanceLevel:
            return "Resistance"
        case .textNote:
            return "Text Note"
        case .emoji:
            return "Emoji"
        }
    }

    var icon: String {
        switch self {
        case .trendline:
            return "pencil.and.ruler"
        case .horizontalLine:
            return "line.3.horizontal"
        case .zone:
            return "square.dashed"
        case .supportLevel:
            return "arrow.down.to.line"
        case .resistanceLevel:
            return "arrow.up.to.line"
        case .textNote:
            return "text.bubble"
        case .emoji:
            return "face.smiling"
        }
    }

    var defaultColorHex: String {
        switch self {
        case .trendline:
            return "#14B8A6"
        case .horizontalLine:
            return "#7C3AED"
        case .zone:
            return "#22C55E"
        case .supportLevel:
            return "#7C3AED"
        case .resistanceLevel:
            return "#DB2777"
        case .textNote:
            return "#6B7280"
        case .emoji:
            return "#F59E0B"
        }
    }
}

struct ChartDrawing: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ChartDrawingType
    var points: [ChartDrawingPoint]
    var colorHex: String
    var isVisible: Bool
    var note: String?
    var emoji: String?

    init(
        id: UUID = UUID(),
        type: ChartDrawingType,
        points: [ChartDrawingPoint] = [],
        colorHex: String,
        isVisible: Bool = true,
        note: String? = nil,
        emoji: String? = nil
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.colorHex = colorHex
        self.isVisible = isVisible
        self.note = note
        self.emoji = emoji
    }
}

@MainActor
final class ChartDrawingManager: ObservableObject {
    @Published private(set) var drawings: [ChartDrawing] = []
    @Published var drawingInteractionPhase: DrawingInteractionPhase = .idle
    @Published var pendingDrawingFirstPoint: ChartDrawingPoint?
    @Published var editingDrawingId: UUID?
    @Published var activeDrawingType: ChartDrawingType?

    var symbolId: UUID? {
        didSet {
            guard oldValue != symbolId else { return }
            load()
        }
    }

    var activeDrawings: [ChartDrawing] {
        drawings.filter { $0.isVisible }
    }

    func load() {
        guard let storageKey else {
            drawings = []
            return
        }

        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            drawings = []
            return
        }

        do {
            drawings = try JSONDecoder().decode([ChartDrawing].self, from: data)
        } catch {
            drawings = []
        }
    }

    func resetInteraction() {
        drawingInteractionPhase = .idle
        pendingDrawingFirstPoint = nil
        editingDrawingId = nil
        activeDrawingType = nil
    }

    func prepareForInteractiveDrawing() {
        // Placeholder hook used by Components UI to signal chart interaction mode.
    }

    func startDrawingWorkflow(type: ChartDrawingType) {
        prepareForInteractiveDrawing()
        activeDrawingType = type
        drawingInteractionPhase = .placingFirstPoint
        pendingDrawingFirstPoint = nil
        editingDrawingId = nil
    }

    func setDrawingFirstPoint(time: Date, price: Double) {
        pendingDrawingFirstPoint = ChartDrawingPoint(time: time, price: price)
        drawingInteractionPhase = .placingSecondPoint
    }

    func beginEditingDrawing(_ drawingId: UUID) {
        prepareForInteractiveDrawing()
        editingDrawingId = drawingId
        activeDrawingType = drawings.first(where: { $0.id == drawingId })?.type
        drawingInteractionPhase = .editing
        pendingDrawingFirstPoint = nil
    }

    func beginDrawingCommit() {
        drawingInteractionPhase = .committing
    }

    func commitDrawingAndExit() {
        drawingInteractionPhase = .idle
        pendingDrawingFirstPoint = nil
        editingDrawingId = nil
        activeDrawingType = nil
    }

    func discardActiveDrawingAndExit() {
        if let editingDrawingId {
            removeDrawing(id: editingDrawingId)
        }
        commitDrawingAndExit()
    }

    @discardableResult
    func addDrawing(
        type: ChartDrawingType,
        colorHex: String? = nil,
        note: String? = nil,
        emoji: String? = nil
    ) -> UUID {
        let drawing = ChartDrawing(
            type: type,
            colorHex: colorHex ?? type.defaultColorHex,
            note: note,
            emoji: emoji
        )
        drawings.append(drawing)
        save()
        return drawing.id
    }

    func updateDrawing(_ drawing: ChartDrawing) {
        guard let index = drawings.firstIndex(where: { $0.id == drawing.id }) else { return }
        drawings[index] = drawing
        save()
    }

    func setDrawings(_ newDrawings: [ChartDrawing]) {
        drawings = newDrawings
        save()
    }

    func removeDrawing(id: UUID) {
        drawings.removeAll { $0.id == id }
        save()
    }

    func toggleVisibility(id: UUID) {
        guard let index = drawings.firstIndex(where: { $0.id == id }) else { return }
        drawings[index].isVisible.toggle()
        save()
    }

    func updateColor(id: UUID, colorHex: String) {
        guard let index = drawings.firstIndex(where: { $0.id == id }) else { return }
        drawings[index].colorHex = colorHex
        save()
    }

    func updateNote(id: UUID, note: String?) {
        guard let index = drawings.firstIndex(where: { $0.id == id }) else { return }
        drawings[index].note = note
        save()
    }

    func updateEmoji(id: UUID, emoji: String?) {
        guard let index = drawings.firstIndex(where: { $0.id == id }) else { return }
        drawings[index].emoji = emoji
        save()
    }

    private var storageKey: String? {
        guard let symbolId else { return nil }
        return "chartDrawings_\(symbolId.uuidString.lowercased())"
    }

    private func save() {
        guard let storageKey else { return }

        do {
            let data = try JSONEncoder().encode(drawings)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Ignore persistence failures and keep in-memory state.
        }
    }
}
