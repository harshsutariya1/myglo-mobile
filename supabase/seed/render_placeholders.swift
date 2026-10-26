// Renders placeholder JPEGs for the fake salons using only macOS frameworks.
// Reads a JSON array of specs on stdin; used by seed_salon_media.py.
//
// Spec: { path, width, height, title, subtitle?, symbol, from, to, style }
//   style: "avatar" (monogram), "cover" (big title), "card" (icon + caption)
import AppKit

struct Spec: Decodable {
    let path: String
    let width: Int
    let height: Int
    let title: String
    let subtitle: String?
    let symbol: String
    let from: String
    let to: String
    let style: String
}

func color(_ hex: String) -> NSColor {
    var value: UInt64 = 0
    Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
    return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

/// Small deterministic generator so each image's decoration differs but re-renders identically.
struct Seeded {
    var state: UInt64
    init(_ text: String) { state = text.utf8.reduce(1469598103934665603) { ($0 ^ UInt64($1)) &* 1099511628211 } }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
    }
}

func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byWordWrapping
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.04)
    shadow.shadowBlurRadius = size * 0.12
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        .paragraphStyle: style,
        .shadow: shadow,
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let bounds = string.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading])
    let drawRect = NSRect(x: rect.minX, y: rect.midY - bounds.height / 2, width: rect.width, height: bounds.height)
    string.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func drawSymbol(_ name: String, center: NSPoint, size: CGFloat, alpha: CGFloat) {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: .light)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.white.withAlphaComponent(alpha)]))
    guard let image = (NSImage(systemSymbolName: name, accessibilityDescription: nil)
        ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil))?.withSymbolConfiguration(config)
    else { return }
    let s = image.size
    image.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
}

func render(_ spec: Spec) throws {
    let w = CGFloat(spec.width), h = CGFloat(spec.height)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: spec.width, pixelsHigh: spec.height,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { throw NSError(domain: "render", code: 1) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    var random = Seeded(spec.path)
    let canvas = NSRect(x: 0, y: 0, width: w, height: h)
    NSGradient(starting: color(spec.from), ending: color(spec.to))?.draw(in: canvas, angle: -45 + random.next() * 90)

    // Soft bokeh circles for texture.
    for _ in 0..<7 {
        let r = min(w, h) * (0.12 + random.next() * 0.35)
        let circle = NSBezierPath(ovalIn: NSRect(x: random.next() * w - r, y: random.next() * h - r, width: r * 2, height: r * 2))
        NSColor.white.withAlphaComponent(0.05 + random.next() * 0.08).setFill()
        circle.fill()
    }

    let short = min(w, h)
    switch spec.style {
    case "avatar":
        let initials = spec.title.split(separator: " ").filter { $0.first?.isLetter == true }
            .prefix(2).map { String($0.first!) }.joined().uppercased()
        drawText(initials, in: canvas.insetBy(dx: w * 0.08, dy: 0), size: short * 0.36, weight: .semibold)
    case "cover":
        drawSymbol(spec.symbol, center: NSPoint(x: w / 2, y: h * 0.68), size: short * 0.16, alpha: 0.9)
        drawText(spec.title, in: NSRect(x: w * 0.08, y: h * 0.30, width: w * 0.84, height: h * 0.26),
                 size: short * 0.11, weight: .bold)
        if let subtitle = spec.subtitle {
            drawText(subtitle, in: NSRect(x: w * 0.1, y: h * 0.14, width: w * 0.8, height: h * 0.14),
                     size: short * 0.05, weight: .medium, alpha: 0.9)
        }
    default:
        drawSymbol(spec.symbol, center: NSPoint(x: w / 2, y: h * 0.62), size: short * 0.22, alpha: 0.92)
        drawText(spec.title, in: NSRect(x: w * 0.1, y: h * 0.16, width: w * 0.8, height: h * 0.26),
                 size: short * 0.07, weight: .semibold)
        if let subtitle = spec.subtitle {
            drawText(subtitle, in: NSRect(x: w * 0.1, y: h * 0.05, width: w * 0.8, height: h * 0.1),
                     size: short * 0.035, weight: .medium, alpha: 0.85)
        }
    }

    guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    else { throw NSError(domain: "render", code: 2) }
    try data.write(to: URL(fileURLWithPath: spec.path))
}

do {
    let specs = try JSONDecoder().decode([Spec].self, from: FileHandle.standardInput.readDataToEndOfFile())
    for spec in specs { try render(spec) }
} catch {
    FileHandle.standardError.write("render_placeholders: \(error)\n".data(using: .utf8)!)
    exit(1)
}
