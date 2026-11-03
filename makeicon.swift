import Cocoa

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let rect = NSRect(x: 0, y: 0, width: size, height: size).insetBy(dx: 50, dy: 50)
let path = NSBezierPath(roundedRect: rect, xRadius: 225, yRadius: 225)
let gradient = NSGradient(
    starting: NSColor(srgbRed: 0.40, green: 0.66, blue: 0.99, alpha: 1.0),
    ending: NSColor(srgbRed: 0.12, green: 0.30, blue: 0.78, alpha: 1.0)
)!
gradient.draw(in: path, angle: -90)

let text = "BD" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 400, weight: .heavy),
    .foregroundColor: NSColor.white
]
let textSize = text.size(withAttributes: attributes)
text.draw(
    at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 + 20),
    withAttributes: attributes
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("icon: failed\n", stderr)
    exit(1)
}

try! png.write(to: URL(fileURLWithPath: "icon1024.png"))
print("icon1024.png created")
