import Foundation
import CoreGraphics

enum MarkerDrawingToolGroup {
    case pointSequence
    case horizontalLevel
    case annotation
    case pattern
}

enum MarkerDrawingToolKind: String, CaseIterable, Hashable {
    case trendline
    case horizontalLine
    case support
    case resistance
    case zone
    case note
    case emoji
    case rayLine
    case verticalLine
    case crossLine
    case parallelChannel
    case breakoutRetest
    case rangeReversal
    case risingChannel
    case headAndShoulders
    case longPosition
    case shortPosition
    case takeProfitIdea
    case stopLossIdea

    var title: String {
        switch self {
        case .trendline:
            return "Trendline"
        case .horizontalLine:
            return "Horizontal Line"
        case .support:
            return "Support"
        case .resistance:
            return "Resistance"
        case .zone:
            return "Zone"
        case .note:
            return "Note"
        case .emoji:
            return "Emoji"
        case .rayLine:
            return "Ray Line"
        case .verticalLine:
            return "Vertical Line"
        case .crossLine:
            return "Cross Line"
        case .parallelChannel:
            return "Parallel Channel"
        case .breakoutRetest:
            return "Breakout Retest"
        case .rangeReversal:
            return "Range Reversal"
        case .risingChannel:
            return "Rising Channel"
        case .headAndShoulders:
            return "Head & Shoulders"
        case .longPosition:
            return "Long Position"
        case .shortPosition:
            return "Short Position"
        case .takeProfitIdea:
            return "Take Profit Idea"
        case .stopLossIdea:
            return "Stop Loss Idea"
        }
    }

    var icon: String {
        switch self {
        case .trendline, .rayLine, .parallelChannel:
            return "pencil.and.ruler"
        case .horizontalLine:
            return "line.3.horizontal"
        case .support:
            return "arrow.down.to.line"
        case .resistance:
            return "arrow.up.to.line"
        case .zone:
            return "square.dashed"
        case .note:
            return "text.bubble"
        case .emoji:
            return "face.smiling"
        case .verticalLine:
            return "line.diagonal"
        case .crossLine:
            return "plus"
        case .breakoutRetest:
            return "arrow.up.right.circle"
        case .rangeReversal:
            return "arrow.left.and.right"
        case .risingChannel:
            return "line.diagonal.arrow"
        case .headAndShoulders:
            return "waveform.path.ecg"
        case .longPosition, .takeProfitIdea:
            return "arrow.up.right"
        case .shortPosition, .stopLossIdea:
            return "arrow.down.right"
        }
    }

    var group: MarkerDrawingToolGroup {
        switch self {
        case .horizontalLine, .support, .resistance, .verticalLine, .crossLine:
            return .horizontalLevel
        case .note, .emoji:
            return .annotation
        case .breakoutRetest, .rangeReversal, .risingChannel, .headAndShoulders, .longPosition, .shortPosition, .takeProfitIdea, .stopLossIdea:
            return .pattern
        case .trendline, .zone, .rayLine, .parallelChannel:
            return .pointSequence
        }
    }

    var requiredPointCount: Int {
        switch self {
        case .note, .emoji:
            return 0
        case .horizontalLine, .support, .resistance, .verticalLine, .crossLine:
            return 1
        case .trendline, .zone, .rayLine:
            return 2
        case .parallelChannel, .breakoutRetest, .risingChannel, .longPosition, .shortPosition, .takeProfitIdea, .stopLossIdea:
            return 3
        case .rangeReversal, .headAndShoulders:
            return 4
        }
    }

    var preferredToolGroup: MarkerToolGroup {
        switch self {
        case .support, .resistance:
            return .levels
        default:
            return .draw
        }
    }

    var preferredSubToolRawValue: String? {
        switch self {
        case .trendline:
            return MarkerToolOption.drawTrendline.rawValue
        case .horizontalLine:
            return MarkerToolOption.drawHorizontalLine.rawValue
        case .support:
            return MarkerToolOption.levelSupport.rawValue
        case .resistance:
            return MarkerToolOption.levelResistance.rawValue
        case .zone:
            return MarkerToolOption.drawZone.rawValue
        default:
            return nil
        }
    }

    var componentType: RLComponentType? {
        switch self {
        case .trendline:
            return .drawingTrendline
        case .horizontalLine:
            return .drawingHorizontalLine
        case .support:
            return .levelSupport
        case .resistance:
            return .levelResistance
        case .zone:
            return .drawingZone
        case .note:
            return .textNote
        case .emoji:
            return .reactionEmoji
        case .rayLine, .verticalLine, .crossLine, .parallelChannel, .longPosition, .shortPosition, .takeProfitIdea, .stopLossIdea:
            return nil
        case .breakoutRetest, .rangeReversal, .risingChannel, .headAndShoulders:
            return .drawingPattern
        }
    }

    var defaultLabel: String? {
        switch self {
        case .horizontalLine:
            return "Line"
        case .support:
            return "Support"
        case .resistance:
            return "Resistance"
        case .note:
            return "Add your context"
        case .emoji:
            return "🎯"
        default:
            return nil
        }
    }

    var isPhaseOneEnabled: Bool {
        switch self {
        case .trendline, .horizontalLine, .support, .resistance, .zone, .note, .emoji:
            return true
        case .rayLine, .verticalLine, .crossLine, .parallelChannel, .longPosition, .shortPosition, .takeProfitIdea, .stopLossIdea:
            return false
        case .breakoutRetest, .rangeReversal, .risingChannel, .headAndShoulders:
            return true
        }
    }

    static func from(componentType: RLComponentType) -> MarkerDrawingToolKind? {
        switch componentType {
        case .drawingTrendline:
            return .trendline
        case .drawingHorizontalLine:
            return .horizontalLine
        case .levelSupport:
            return .support
        case .levelResistance:
            return .resistance
        case .drawingZone:
            return .zone
        case .drawingPattern:
            return .headAndShoulders
        case .textNote:
            return .note
        case .reactionEmoji:
            return .emoji
        default:
            return nil
        }
    }

    static func from(activeSubTool: String?) -> MarkerDrawingToolKind? {
        switch activeSubTool {
        case MarkerToolOption.drawTrendline.rawValue:
            return .trendline
        case MarkerToolOption.drawHorizontalLine.rawValue:
            return .horizontalLine
        case MarkerToolOption.levelSupport.rawValue:
            return .support
        case MarkerToolOption.levelResistance.rawValue:
            return .resistance
        case MarkerToolOption.drawZone.rawValue:
            return .zone
        default:
            return nil
        }
    }

    static func from(patternKey: String?) -> MarkerDrawingToolKind? {
        guard let patternKey else { return nil }
        return MarkerDrawingToolKind(rawValue: patternKey)
    }
}

typealias MarkerDrawingWorkflowTool = MarkerDrawingToolKind

struct MarkerDrawingGuidePoint: Equatable, Hashable {
    var time: Date
    var price: Double
}

enum MarkerDrawingHandle: Equatable, Hashable {
    case point(Int)
    case center
    case annotation
}

enum MarkerDrawingSessionPhase: Equatable {
    case idle
    case placing(stepIndex: Int)
    case editing
    case committing
}

struct MarkerDrawingSession: Equatable {
    var tool: MarkerDrawingToolKind?
    var phase: MarkerDrawingSessionPhase = .idle
    var committedPoints: [MarkerDrawingGuidePoint] = []
    var guidePoint: MarkerDrawingGuidePoint?
    var editingDraftId: UUID?
    var selectedHandle: MarkerDrawingHandle?
    var isPanLocked: Bool = false

    static let inactive = MarkerDrawingSession()

    var isActive: Bool {
        tool != nil || editingDraftId != nil || phase != .idle
    }

    var isPointPlacementActive: Bool {
        if case .placing = phase {
            return true
        }
        return false
    }

    var stepIndex: Int? {
        if case let .placing(stepIndex) = phase {
            return stepIndex
        }
        return nil
    }

    var drawingInteractionPhase: DrawingInteractionPhase {
        switch phase {
        case .idle:
            return .idle
        case .placing(let stepIndex):
            return stepIndex == 0 ? .placingFirstPoint : .placingSecondPoint
        case .editing:
            return .editing
        case .committing:
            return .committing
        }
    }
}

struct MarkerDrawingToolDefinition: Equatable {
    let kind: MarkerDrawingToolKind
    let title: String
    let icon: String
    let group: MarkerDrawingToolGroup
    let requiredPointCount: Int
    let preferredToolGroup: MarkerToolGroup
    let preferredSubToolRawValue: String?
    let componentType: RLComponentType?
    let defaultLabel: String?
    let isPhaseOneEnabled: Bool

    var requiresGuidePlacement: Bool {
        requiredPointCount > 1
    }
}

enum MarkerDrawingToolRegistry {
    static let phaseOneTools: [MarkerDrawingToolDefinition] = MarkerDrawingToolKind.allCases
        .map(definition(for:))
        .filter(\.isPhaseOneEnabled)

    static let futureTools: [MarkerDrawingToolDefinition] = MarkerDrawingToolKind.allCases
        .map(definition(for:))
        .filter { !$0.isPhaseOneEnabled }

    static func definition(for kind: MarkerDrawingToolKind) -> MarkerDrawingToolDefinition {
        MarkerDrawingToolDefinition(
            kind: kind,
            title: kind.title,
            icon: kind.icon,
            group: kind.group,
            requiredPointCount: kind.requiredPointCount,
            preferredToolGroup: kind.preferredToolGroup,
            preferredSubToolRawValue: kind.preferredSubToolRawValue,
            componentType: kind.componentType,
            defaultLabel: kind.defaultLabel,
            isPhaseOneEnabled: kind.isPhaseOneEnabled
        )
    }
}

extension MarkerDrawingToolDefinition {
    func placementInstruction(for stepIndex: Int) -> String {
        if requiredPointCount <= 0 {
            return "\(title): drag to place, tap chart to save"
        }
        if let label = kind.guidePointLabels[safe: stepIndex] {
            return "Step \(stepIndex + 1)/\(requiredPointCount): place \(label)"
        }
        return "\(title): drag to \(ordinal(stepIndex + 1)) point, tap to set"
    }

    private func ordinal(_ number: Int) -> String {
        switch number {
        case 1:
            return "1st"
        case 2:
            return "2nd"
        case 3:
            return "3rd"
        default:
            return "\(number)th"
        }
    }
}

extension MarkerDrawingToolKind {
    var guidePointLabels: [String] {
        switch self {
        case .breakoutRetest:
            return ["Breakout level start", "Breakout level end", "Retest reaction"]
        case .rangeReversal:
            return ["Range high", "Range low", "Rejection", "Target / mean"]
        case .risingChannel:
            return ["Lower channel start", "Lower channel end", "Upper guide"]
        case .headAndShoulders:
            return ["Left shoulder", "Head", "Right shoulder", "Neckline"]
        default:
            return []
        }
    }

    var guideSequenceText: String? {
        let labels = guidePointLabels
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: " -> ")
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum MarkerDrawingLineStyle: String, Codable, CaseIterable {
    case solid
    case dashed
    case dotted

    var title: String {
        rawValue.capitalized
    }

    var dashPattern: [CGFloat] {
        switch self {
        case .solid:
            return []
        case .dashed:
            return [10, 6]
        case .dotted:
            return [2, 5]
        }
    }
}
