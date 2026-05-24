//
//  ProfileStatDTO.swift
//  traders_guild
//
//  UI model for profile statistics cards.
//

import SwiftUI

/// Statistics card data for profile overview
struct ProfileStatDTO: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let icon: String
    let color: Color
    let trend: StatTrend?

    /// Optional 30-day sparkline. Rendered under the value when non-nil.
    var sparkline: [Double]? = nil

    /// Optional gauge progress in [0, 1]. Rendered in place of the value as a
    /// radial dial when non-nil. Mutually exclusive with `sparkline`.
    var gaugeProgress: Double? = nil

    enum StatTrend {
        case up(String)     // "+12%"
        case down(String)   // "-5%"
        case neutral
        
        var color: Color {
            switch self {
            case .up: return AppColors.statusPositive
            case .down: return AppColors.statusNegative
            case .neutral: return AppColors.secondaryForeground
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
    }
}

