import SwiftUI

enum ComponentSubTab: String, CaseIterable, UnifiedTabItem {
    case active = "Active"
    case indicators = "Indicators"
    case drawings = "Drawings"
    case timeframes = "Timeframes"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .indicators:
            return "chart.line.uptrend.xyaxis.circle"
        case .drawings:
            return "pencil.circle"
        case .timeframes:
            return "clock.circle"
        }
    }
}

enum IndicatorSubTab: String, CaseIterable, UnifiedTabItem {
    case trend = "Trend"
    case volatility = "Volatility"
    case momentum = "Momentum"
    case volume = "Volume"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .trend:
            return IndicatorCategory.trend.icon
        case .volatility:
            return IndicatorCategory.volatility.icon
        case .momentum:
            return IndicatorCategory.momentum.icon
        case .volume:
            return IndicatorCategory.volume.icon
        }
    }

    var category: IndicatorCategory {
        switch self {
        case .trend:
            return .trend
        case .volatility:
            return .volatility
        case .momentum:
            return .momentum
        case .volume:
            return .volume
        }
    }
}

enum DrawingSubTab: String, CaseIterable, UnifiedTabItem {
    case lines = "Lines"
    case zones = "Zones"
    case annotations = "Annotations"
    case patterns = "Patterns"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .lines:
            return "line.3.horizontal"
        case .zones:
            return "square.dashed"
        case .annotations:
            return "text.bubble"
        case .patterns:
            return "triangle"
        }
    }
}
