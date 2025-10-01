//
//  PatternView.swift
//  traders_guild
//
//  Created by Al Hennessey on 30/09/2025.
//
import SwiftUI
// MARK: - Pattern Overlay
/// Subtle pattern overlay for background texture
struct PatternOverlay: View {
    enum PatternType {
        case honeycomb
        case checkered
        case dots
    }
    
    let patternType: PatternType
    var hexSize: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                switch patternType {
                case .honeycomb:
                    drawHoneycomb(context: context, size: size, hexSize: hexSize)
                case .checkered:
                    drawCheckered(context: context, size: size)
                case .dots:
                    drawDots(context: context, size: size)
                }
            }
        }
        .drawingGroup() // Render to offscreen buffer for stability
        .allowsHitTesting(false)
        //.animation(.none) // Explicitly disable animations
    }
    
    // Draw honeycomb pattern
    private func drawHoneycomb(context: GraphicsContext, size: CGSize, hexSize: CGFloat) {
        let hexWidth = hexSize * 2
        let hexHeight = sqrt(3.0) * hexSize
        
        let rows = Int(size.height / hexHeight) + 3
        let cols = Int(size.width / (hexWidth * 0.75)) + 4
        
        for row in 0..<rows {
            for col in 0..<cols {
                let xOffset = CGFloat(col) * hexWidth * 0.75
                let yOffset = CGFloat(row) * hexHeight + (col % 2 == 0 ? 0 : hexHeight / 2)
                
                var path = Path()
                for i in 0..<6 {
                    let angle = CGFloat(i) * .pi / 3
                    let x = xOffset + hexSize * cos(angle)
                    let y = yOffset + hexSize * sin(angle)
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
                
                context.stroke(path, with: .color(.white), lineWidth: 1)
            }
        }
    }
    
    // Draw checkered pattern
    private func drawCheckered(context: GraphicsContext, size: CGSize) {
        let squareSize: CGFloat = 30
        
        let rows = Int(size.height / squareSize) + 1
        let cols = Int(size.width / squareSize) + 1
        
        for row in 0..<rows {
            for col in 0..<cols {
                if (row + col) % 2 == 0 {
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(.white))
                }
            }
        }
    }
    
    // Draw dots pattern
    private func drawDots(context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 20
        let dotSize: CGFloat = 2
        
        let rows = Int(size.height / spacing) + 1
        let cols = Int(size.width / spacing) + 1
        
        for row in 0..<rows {
            for col in 0..<cols {
                let x = CGFloat(col) * spacing
                let y = CGFloat(row) * spacing
                
                let rect = CGRect(
                    x: x - dotSize / 2,
                    y: y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
    }
}
