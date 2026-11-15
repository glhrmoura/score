import AppKit
import CoreText

let fontURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func scoreFont(_ size: CGFloat, weight: CGFloat) -> CTFont {
    let base = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: "Score"] as CFDictionary)
    let varied = CTFontDescriptorCreateCopyWithAttributes(base, [kCTFontVariationAttribute: [0x7767_6874: weight, 0x7764_7468: 82]] as CFDictionary)
    return CTFontCreateWithFontDescriptor(varied, size, nil)
}

let size = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3])! : 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.45))
context.addPath(shape)
context.setFillColor(color(0x1F5CFF))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(shape)
context.clip()
let gradient = CGGradient(colorsSpace: space, colors: [color(0x1F5CFF), color(0x1F5CFF)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
context.restoreGState()

context.addPath(shape)
context.setStrokeColor(color(0xFFFFFF, 0.06))
context.setLineWidth(3)
context.strokePath()

let tile = CGRect(x: 512 - 180, y: 512 - 230, width: 360, height: 460)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 60, cornerHeight: 60, transform: nil)
let ink = color(0x0E0F11)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.5))
context.addPath(tilePath)
context.setFillColor(color(0xF5F5F7))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(tilePath)
context.clip()
context.setFillColor(color(0xE4E4E8))
context.fill(CGRect(x: tile.minX, y: tile.minY, width: tile.width, height: tile.height / 2))

let line = CTLineCreateWithAttributedString(NSAttributedString(string: "1", attributes: [.font: scoreFont(360, weight: 850), .foregroundColor: ink]))
context.textPosition = .zero
let bounds = CTLineGetImageBounds(line, context)
context.textPosition = CGPoint(x: tile.midX - bounds.width / 2 - bounds.minX, y: tile.midY - bounds.height / 2 - bounds.minY)
CTLineDraw(line, context)

context.setFillColor(ink)
context.fill(CGRect(x: tile.minX, y: tile.midY - 6, width: tile.width, height: 12))
context.restoreGState()

let dot = CGRect(x: tile.maxX - 52, y: tile.maxY - 52, width: 104, height: 104)
context.saveGState()
context.addEllipse(in: dot.insetBy(dx: -18, dy: -18))
context.clip()
context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
context.restoreGState()
context.setFillColor(color(0xFF3B4A))
context.fillEllipse(in: dot)

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
