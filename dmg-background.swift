import Cocoa

// DMG background: 660x400 pt, exported as 1x and @2x PNG.
let W: CGFloat = 660
let H: CGFloat = 400

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawBackground(in rect: NSRect) {
    let gradient = NSGradient(starting: color(0xF7F9FE), ending: color(0xE6EDF9))!
    gradient.draw(in: rect, angle: -60)

    if let context = NSGraphicsContext.current?.cgContext {
        context.saveGState()

        func glow(center: CGPoint, radius: CGFloat, color: NSColor) {
            let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            let locations: [CGFloat] = [0, 1]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors,
                                         locations: locations) {
                context.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: radius,
                    options: []
                )
            }
        }

        glow(center: CGPoint(x: 90, y: H - 70), radius: 260,
             color: color(0x2563EB, 0.12))
        glow(center: CGPoint(x: W - 80, y: 40), radius: 280,
             color: color(0x7C3AED, 0.10))

        context.restoreGState()
    }
}

func drawText(_ text: String,
              top: CGFloat,
              font: NSFont,
              textColor: NSColor,
              width: CGFloat = W) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byTruncatingTail

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
        .paragraphStyle: paragraph
    ]

    let height = font.pointSize + 6
    let textRect = NSRect(x: 0, y: H - top - height, width: width, height: height)
    (text as NSString).draw(in: textRect, withAttributes: attributes)
}

func drawArrow() {
    let y = H - 180
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 272, y: y))
    path.line(to: NSPoint(x: 382, y: y))
    path.lineWidth = 3
    path.lineCapStyle = .round
    color(0x2563EB, 0.9).setStroke()
    path.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: 368, y: y + 8))
    head.line(to: NSPoint(x: 382, y: y))
    head.line(to: NSPoint(x: 368, y: y - 8))
    head.lineWidth = 3
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    color(0x2563EB, 0.9).setStroke()
    head.stroke()
}

func render(scale: CGFloat, path: String) -> Bool {
    let pixelWidth = Int(W * scale)
    let pixelHeight = Int(H * scale)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return false }

    rep.size = NSSize(width: W, height: H)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return false }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    drawBackground(in: NSRect(x: 0, y: 0, width: W, height: H))

    drawText("BetterDiscord Installer",
             top: 30,
             font: .systemFont(ofSize: 25, weight: .bold),
             textColor: color(0x0F172A, 0.95))

    drawText("Перетащите приложение в папку Applications",
             top: 64,
             font: .systemFont(ofSize: 13, weight: .medium),
             textColor: color(0x475569, 0.78))

    drawArrow()

    drawText("macOS 12+ · Universal · Intel + Apple Silicon",
             top: 336,
             font: .systemFont(ofSize: 11, weight: .medium),
             textColor: color(0x475569, 0.55))

    drawText("Если macOS не разрешает запуск — правый клик по приложению → Открыть",
             top: 358,
             font: .systemFont(ofSize: 10.5, weight: .regular),
             textColor: color(0x64748B, 0.62))

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { return false }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        return false
    }
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"
let retina = output.replacingOccurrences(of: ".png", with: "@2x.png")

guard render(scale: 1, path: output), render(scale: 2, path: retina) else {
    fputs("failed to render dmg background\n", stderr)
    exit(1)
}

print("background: \(output) and \(retina)")
