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
    
    enum StatTrend {
        case up(String)     // "+12%"
        case down(String)   // "-5%"
        case neutral
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
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

