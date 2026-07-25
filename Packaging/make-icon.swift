// Renders the Hikari Yaps app icon (warm dark rounded square + golden waveform)
// at every size the .icns format needs.
// Run via: swift Packaging/make-icon.swift <output-dir>
import AppKit

let sizes: [(name: String, points: Int, scale: Int)] = [
    ("icon_16x16", 16, 1), ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1), ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1), ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1), ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1), ("icon_512x512@2x", 512, 2),
]

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> NSImage {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let inset = size * 0.09
    let squircle = NSBezierPath(
        roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
        xRadius: size * 0.2,
        yRadius: size * 0.2
    )

    // Warm dark background gradient
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.18, green: 0.14, blue: 0.09, alpha: 1),
        ending: NSColor(calibratedRed: 0.07, green: 0.06, blue: 0.05, alpha: 1)
    )
    gradient?.draw(in: squircle, angle: -60)

    // Blue glow
    if let glow = NSGradient(
        starting: NSColor(calibratedRed: 0, green: 0.44, blue: 0.89, alpha: 0.28),
        ending: NSColor.clear
    ) {
        squircle.addClip()
        glow.draw(fromCenter: NSPoint(x: size * 0.32, y: size * 0.72), radius: 0,
                  toCenter: NSPoint(x: size * 0.32, y: size * 0.72), radius: size * 0.55,
                  options: [])
    }

    // Waveform bars — blue
    let gold = NSColor(calibratedRed: 0, green: 0.44, blue: 0.89, alpha: 1)
    let heights: [CGFloat] = [0.18, 0.34, 0.52, 0.38, 0.24]
    let barWidth = size * 0.065
    let gap = size * 0.055
    let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    var x = (size - totalWidth) / 2
    for height in heights {
        let barHeight = size * height
        let bar = NSBezierPath(
            roundedRect: NSRect(x: x, y: (size - barHeight) / 2, width: barWidth, height: barHeight),
            xRadius: barWidth / 2,
            yRadius: barWidth / 2
        )
        gold.setFill()
        bar.fill()
        x += barWidth + gap
    }

    image.unlockFocus()
    return image
}

for entry in sizes {
    let pixels = entry.points * entry.scale
    let image = drawIcon(pixels: pixels)
    guard let tiff = image.tiffRepresentation,
          let representation = NSBitmapImageRep(data: tiff) else { continue }
    representation.size = NSSize(width: entry.points, height: entry.points)
    guard let png = representation.representation(using: .png, properties: [:]) else { continue }
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(entry.name).png")
    try? png.write(to: url)
}
print("Icon set written to \(outputDir)")
