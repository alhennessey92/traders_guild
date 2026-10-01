import AppKit
let out = CommandLine.arguments[1]
let palette: [(String, NSColor)] = [("A", .systemTeal), ("B", .systemOrange), ("C", .systemPurple), ("D", .systemPink), ("E", .systemGreen)]
for (letter, color) in palette {
    let size = 256
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    color.setFill(); NSRect(x: 0, y: 0, width: size, height: size).fill()
    NSColor.white.withAlphaComponent(0.25).setFill()
    NSBezierPath(ovalIn: NSRect(x: 48, y: 20, width: 160, height: 160)).fill()
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 120), .foregroundColor: NSColor.white]
    let text = NSAttributedString(string: letter, attributes: attrs)
    let t = text.size(); text.draw(at: NSPoint(x: (CGFloat(size) - t.width) / 2, y: (CGFloat(size) - t.height) / 2))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/avatar-\(letter).png"))
}
