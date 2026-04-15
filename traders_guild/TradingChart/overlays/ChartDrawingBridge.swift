import Foundation

enum ChartDrawingBridge {
    static func normalizedAnnotationDrawing(
        from drawing: ChartDrawing,
        fallbackAnchorTime: Date,
        fallbackAnchorPrice: Double
    ) -> ChartDrawing {
        switch drawing.type {
        case .textNote, .emoji:
            guard drawing.points.isEmpty else { return drawing }
            var normalized = drawing
            normalized.points = [
                ChartDrawingPoint(time: fallbackAnchorTime, price: fallbackAnchorPrice),
            ]
            return normalized
        default:
            return drawing
        }
    }

    static func markerDraft(
        from drawing: ChartDrawing,
        anchorTime: Date,
        anchorPrice: Double
    ) -> MarkerComponentDraft {
        switch drawing.type {
        case .trendline:
            let first = drawing.points.first ?? ChartDrawingPoint(time: anchorTime, price: anchorPrice)
            let second = drawing.points.dropFirst().first ?? ChartDrawingPoint(
                time: first.time.addingTimeInterval(30 * 60),
                price: first.price
            )
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .drawingTrendline,
                payload: .drawingTrendline(
                    TrendlinePayload(
                        startTime: first.time,
                        startPrice: first.price,
                        endTime: second.time,
                        endPrice: second.price,
                        colorHex: drawing.colorHex,
                        lineStyle: drawing.lineStyle,
                        lineWidth: drawing.lineWidth
                    )
                )
            )

        case .horizontalLine:
            let price = drawing.points.first?.price ?? anchorPrice
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .drawingHorizontalLine,
                payload: .drawingHorizontalLine(
                    HorizontalLinePayload(
                        price: price,
                        label: drawing.note,
                        colorHex: drawing.colorHex,
                        lineStyle: drawing.lineStyle,
                        lineWidth: drawing.lineWidth
                    )
                )
            )

        case .zone:
            let topPrice = drawing.points.first?.price ?? anchorPrice
            let bottomPrice = drawing.points.dropFirst().first?.price ?? anchorPrice
            let startTime = drawing.points.first?.time ?? anchorTime
            let endTime = drawing.points.dropFirst().first?.time ?? anchorTime
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .drawingZone,
                payload: .drawingZone(
                    ZonePayload(
                        topPrice: max(topPrice, bottomPrice),
                        bottomPrice: min(topPrice, bottomPrice),
                        startTime: startTime,
                        endTime: endTime,
                        colorHex: drawing.colorHex,
                        lineStyle: drawing.lineStyle,
                        lineWidth: drawing.lineWidth
                    )
                )
            )

        case .supportLevel:
            let price = drawing.points.first?.price ?? anchorPrice
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .levelSupport,
                payload: .levelSupport(
                    LevelPayload(
                        price: price,
                        label: drawing.note,
                        colorHex: drawing.colorHex,
                        lineStyle: drawing.lineStyle,
                        lineWidth: drawing.lineWidth
                    )
                )
            )

        case .resistanceLevel:
            let price = drawing.points.first?.price ?? anchorPrice
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .levelResistance,
                payload: .levelResistance(
                    LevelPayload(
                        price: price,
                        label: drawing.note,
                        colorHex: drawing.colorHex,
                        lineStyle: drawing.lineStyle,
                        lineWidth: drawing.lineWidth
                    )
                )
            )

        case .textNote:
            let noteAnchor = drawing.points.first ?? ChartDrawingPoint(time: anchorTime, price: anchorPrice)
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .textNote,
                payload: .note(
                    NotePayload(
                        text: drawing.note ?? "Add your context",
                        offsetX: drawing.offsetX,
                        offsetY: drawing.offsetY,
                        anchorTime: noteAnchor.time,
                        anchorPrice: noteAnchor.price,
                        fontSize: drawing.fontSize
                    )
                )
            )

        case .emoji:
            let emojiAnchor = drawing.points.first ?? ChartDrawingPoint(time: anchorTime, price: anchorPrice)
            return MarkerComponentDraft(
                id: drawing.id,
                componentType: .reactionEmoji,
                payload: .reactionEmoji(
                    EmojiPayload(
                        emoji: drawing.emoji ?? "🎯",
                        offsetX: drawing.offsetX,
                        offsetY: drawing.offsetY,
                        anchorTime: emojiAnchor.time,
                        anchorPrice: emojiAnchor.price,
                        scale: drawing.scale
                    )
                )
            )
        }
    }

    static func chartDrawing(
        from draft: MarkerComponentDraft,
        anchorTime: Date,
        anchorPrice: Double
    ) -> ChartDrawing? {
        switch draft.payload {
        case let .drawingTrendline(payload):
            return ChartDrawing(
                id: draft.id,
                type: .trendline,
                points: [
                    ChartDrawingPoint(time: payload.startTime, price: payload.startPrice),
                    ChartDrawingPoint(time: payload.endTime, price: payload.endPrice),
                ],
                colorHex: payload.colorHex ?? ChartDrawingType.trendline.defaultColorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth
            )

        case let .drawingHorizontalLine(payload):
            return ChartDrawing(
                id: draft.id,
                type: .horizontalLine,
                points: [ChartDrawingPoint(time: anchorTime, price: payload.price)],
                colorHex: payload.colorHex ?? ChartDrawingType.horizontalLine.defaultColorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth,
                note: payload.label
            )

        case let .drawingZone(payload):
            let start = payload.startTime ?? anchorTime
            let end = payload.endTime ?? anchorTime
            return ChartDrawing(
                id: draft.id,
                type: .zone,
                points: [
                    ChartDrawingPoint(time: start, price: payload.topPrice),
                    ChartDrawingPoint(time: end, price: payload.bottomPrice),
                ],
                colorHex: payload.colorHex ?? ChartDrawingType.zone.defaultColorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth
            )

        case let .levelSupport(payload):
            return ChartDrawing(
                id: draft.id,
                type: .supportLevel,
                points: [ChartDrawingPoint(time: anchorTime, price: payload.price)],
                colorHex: payload.colorHex ?? ChartDrawingType.supportLevel.defaultColorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth,
                note: payload.label
            )

        case let .levelResistance(payload):
            return ChartDrawing(
                id: draft.id,
                type: .resistanceLevel,
                points: [ChartDrawingPoint(time: anchorTime, price: payload.price)],
                colorHex: payload.colorHex ?? ChartDrawingType.resistanceLevel.defaultColorHex,
                lineStyle: payload.lineStyle,
                lineWidth: payload.lineWidth,
                note: payload.label
            )

        case let .note(payload):
            return ChartDrawing(
                id: draft.id,
                type: .textNote,
                points: [
                    ChartDrawingPoint(
                        time: payload.anchorTime ?? anchorTime,
                        price: payload.anchorPrice ?? anchorPrice
                    ),
                ],
                colorHex: ChartDrawingType.textNote.defaultColorHex,
                note: payload.text,
                offsetX: payload.offsetX,
                offsetY: payload.offsetY,
                fontSize: payload.fontSize
            )

        case let .reactionEmoji(payload):
            return ChartDrawing(
                id: draft.id,
                type: .emoji,
                points: [
                    ChartDrawingPoint(
                        time: payload.anchorTime ?? anchorTime,
                        price: payload.anchorPrice ?? anchorPrice
                    ),
                ],
                colorHex: ChartDrawingType.emoji.defaultColorHex,
                emoji: payload.emoji,
                offsetX: payload.offsetX,
                offsetY: payload.offsetY,
                scale: payload.scale
            )

        default:
            return nil
        }
    }
}
