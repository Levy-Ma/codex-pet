import AppKit
import Foundation

let statePath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "runtime/pet-state.json"
let petImagePath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
let petBlinkImagePath = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : ""

struct PetState {
    var state: String = "idle"
    var message: String = "Ready"
}

final class PetStateStore {
    private let url: URL
    private var lastModified: Date = .distantPast
    private(set) var current = PetState()

    init(path: String) {
        self.url = URL(fileURLWithPath: path)
        ensureStateFile()
        load(force: true)
    }

    private func ensureStateFile() {
        let manager = FileManager.default
        let dir = url.deletingLastPathComponent()
        try? manager.createDirectory(at: dir, withIntermediateDirectories: true)
        if !manager.fileExists(atPath: url.path) {
            let payload: [String: Any] = ["state": "idle", "message": "Ready", "updatedAt": ISO8601DateFormatter().string(from: Date())]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
                try? data.write(to: url)
            }
        }
    }

    func load(force: Bool = false) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modified = attrs?[.modificationDate] as? Date ?? .distantPast
        if !force && modified == lastModified { return }
        lastModified = modified
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else { return }
        let allowed: Set<String> = ["idle", "thinking", "success", "error", "sleeping"]
        let rawState = (dict["state"] as? String ?? "idle").lowercased()
        current.state = allowed.contains(rawState) ? rawState : "idle"
        current.message = dict["message"] as? String ?? "Ready"
    }
}

final class PetView: NSView {
    let store: PetStateStore
    let petImage: NSImage?
    let petBlinkImage: NSImage?
    var tick: Double = 0

    init(frame: NSRect, store: PetStateStore) {
        self.store = store
        self.petImage = petImagePath.isEmpty ? nil : NSImage(contentsOfFile: petImagePath)
        self.petBlinkImage = petBlinkImagePath.isEmpty ? nil : NSImage(contentsOfFile: petBlinkImagePath)
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        store.load()
        let state = store.current.state
        let phase = tick / 10.0
        let bob = sin(phase) * (state == "sleeping" ? 1.0 : 3.0)
        let breathe = sin(phase * 0.8) * 2.0
        let tail = sin(phase * 1.4) * 8.0
        if let petImage = petImage {
            let blinkFrame = Int(tick) % 126 < 5
            let image = blinkFrame ? (petBlinkImage ?? petImage) : petImage
            drawPetImage(image, phase: phase, bob: bob)
            drawStatus(state: state, phase: phase, bob: bob)
            tick += 1
            return
        }
        drawShadow()
        drawTail(tail: tail, bob: bob, state: state)
        drawBody(breathe: breathe, bob: bob, state: state)
        drawHead(bob: bob, state: state)
        drawFace(bob: bob, state: state)
        drawStatus(state: state, phase: phase, bob: bob)
        drawCaption(state: state)
        tick += 1
    }


    func drawPetImage(_ image: NSImage, phase: Double, bob: Double) {
        let padding: CGFloat = 8
        let breathe = 1.0 + CGFloat(sin(phase * 0.8)) * 0.012
        let available = NSRect(x: padding, y: padding - CGFloat(bob), width: bounds.width - padding * 2, height: bounds.height - padding * 2)
        let imageSize = image.size
        guard imageSize.width > 0 && imageSize.height > 0 else { return }
        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        let drawSize = NSSize(width: imageSize.width * scale * breathe, height: imageSize.height * scale * breathe)
        let rect = NSRect(
            x: available.midX - drawSize.width / 2,
            y: available.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: rect, from: NSRect(origin: .zero, size: imageSize), operation: .sourceOver, fraction: 1.0)
    }

    func color(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: CGFloat((hex >> 16) & 255) / 255.0,
                green: CGFloat((hex >> 8) & 255) / 255.0,
                blue: CGFloat(hex & 255) / 255.0,
                alpha: alpha)
    }

    func oval(_ rect: NSRect, fill: NSColor, stroke: NSColor? = nil, line: CGFloat = 1) {
        let path = NSBezierPath(ovalIn: rect)
        fill.setFill(); path.fill()
        if let stroke = stroke { stroke.setStroke(); path.lineWidth = line; path.stroke() }
    }

    func strokePath(_ path: NSBezierPath, fill: NSColor, stroke: NSColor, line: CGFloat = 5) {
        fill.setFill()
        path.fill()
        stroke.setStroke()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = line
        path.stroke()
    }

    func drawShadow() {
        oval(NSRect(x: 54, y: 13, width: 226, height: 20), fill: color(0x1a1a1d, alpha: 0.20))
    }

    func drawTail(tail: Double, bob: Double, state: String) {
        let outline = color(0x4a2b22)
        let fur = color(state == "success" ? 0x071008 : 0x050505)
        let y = 46 - bob + tail * 0.06
        let outer = NSBezierPath()
        outer.move(to: NSPoint(x: 202, y: y + 22))
        outer.curve(to: NSPoint(x: 250, y: y + 19), controlPoint1: NSPoint(x: 219, y: y + 26), controlPoint2: NSPoint(x: 236, y: y + 25))
        outer.curve(to: NSPoint(x: 304, y: y + 8), controlPoint1: NSPoint(x: 268, y: y + 11), controlPoint2: NSPoint(x: 286, y: y + 7))
        outer.curve(to: NSPoint(x: 302, y: y - 8), controlPoint1: NSPoint(x: 316, y: y + 9), controlPoint2: NSPoint(x: 315, y: y - 5))
        outer.curve(to: NSPoint(x: 248, y: y - 3), controlPoint1: NSPoint(x: 283, y: y - 13), controlPoint2: NSPoint(x: 267, y: y - 11))
        outer.curve(to: NSPoint(x: 200, y: y + 1), controlPoint1: NSPoint(x: 232, y: y + 3), controlPoint2: NSPoint(x: 217, y: y + 1))
        outer.close()
        strokePath(outer, fill: fur, stroke: outline, line: 7)
    }

    func drawBody(breathe: Double, bob: Double, state: String) {
        let outline = color(0x4a2b22)
        let fur = color(0x050505)
        let y = 22 - bob

        let leftHip = NSBezierPath(ovalIn: NSRect(x: 66, y: y + 16, width: 56, height: 74))
        strokePath(leftHip, fill: fur, stroke: outline, line: 7)
        let rightHip = NSBezierPath(ovalIn: NSRect(x: 174, y: y + 16, width: 56, height: 74))
        strokePath(rightHip, fill: fur, stroke: outline, line: 7)

        let torso = NSBezierPath(roundedRect: NSRect(x: 102, y: y + 18, width: 92, height: 102 + breathe), xRadius: 42, yRadius: 38)
        strokePath(torso, fill: fur, stroke: outline, line: 7)

        let leftLeg = NSBezierPath(roundedRect: NSRect(x: 91, y: y, width: 43, height: 82), xRadius: 20, yRadius: 20)
        strokePath(leftLeg, fill: fur, stroke: outline, line: 7)
        let rightLeg = NSBezierPath(roundedRect: NSRect(x: 151, y: y, width: 43, height: 82), xRadius: 20, yRadius: 20)
        strokePath(rightLeg, fill: fur, stroke: outline, line: 7)

        let leftLine = NSBezierPath()
        leftLine.move(to: NSPoint(x: 111, y: y + 14))
        leftLine.curve(to: NSPoint(x: 121, y: y + 72), controlPoint1: NSPoint(x: 112, y: y + 34), controlPoint2: NSPoint(x: 116, y: y + 54))
        outline.setStroke()
        leftLine.lineWidth = 6
        leftLine.lineCapStyle = .round
        leftLine.stroke()

        let rightLine = NSBezierPath()
        rightLine.move(to: NSPoint(x: 172, y: y + 14))
        rightLine.curve(to: NSPoint(x: 181, y: y + 72), controlPoint1: NSPoint(x: 173, y: y + 34), controlPoint2: NSPoint(x: 177, y: y + 54))
        outline.setStroke()
        rightLine.lineWidth = 6
        rightLine.lineCapStyle = .round
        rightLine.stroke()
    }

    func drawHead(bob: Double, state: String) {
        let outline = color(0x4a2b22)
        let fur = color(0x050505)
        let innerEar = color(0xc6d9bd)
        let y = 96 - bob

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 61, y: y + 52))
        leftEar.curve(to: NSPoint(x: 39, y: y + 147), controlPoint1: NSPoint(x: 37, y: y + 86), controlPoint2: NSPoint(x: 26, y: y + 142))
        leftEar.curve(to: NSPoint(x: 124, y: y + 102), controlPoint1: NSPoint(x: 70, y: y + 160), controlPoint2: NSPoint(x: 99, y: y + 133))
        leftEar.close()
        strokePath(leftEar, fill: fur, stroke: outline, line: 8)

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 196, y: y + 102))
        rightEar.curve(to: NSPoint(x: 281, y: y + 147), controlPoint1: NSPoint(x: 221, y: y + 133), controlPoint2: NSPoint(x: 250, y: y + 160))
        rightEar.curve(to: NSPoint(x: 259, y: y + 52), controlPoint1: NSPoint(x: 294, y: y + 142), controlPoint2: NSPoint(x: 283, y: y + 86))
        rightEar.close()
        strokePath(rightEar, fill: fur, stroke: outline, line: 8)

        let leftInner = NSBezierPath()
        leftInner.move(to: NSPoint(x: 55, y: y + 61))
        leftInner.curve(to: NSPoint(x: 48, y: y + 131), controlPoint1: NSPoint(x: 44, y: y + 89), controlPoint2: NSPoint(x: 38, y: y + 129))
        leftInner.curve(to: NSPoint(x: 105, y: y + 98), controlPoint1: NSPoint(x: 70, y: y + 139), controlPoint2: NSPoint(x: 91, y: y + 120))
        leftInner.close()
        innerEar.setFill(); leftInner.fill()

        let rightInner = NSBezierPath()
        rightInner.move(to: NSPoint(x: 215, y: y + 98))
        rightInner.curve(to: NSPoint(x: 272, y: y + 131), controlPoint1: NSPoint(x: 229, y: y + 120), controlPoint2: NSPoint(x: 250, y: y + 139))
        rightInner.curve(to: NSPoint(x: 265, y: y + 61), controlPoint1: NSPoint(x: 282, y: y + 129), controlPoint2: NSPoint(x: 276, y: y + 89))
        rightInner.close()
        innerEar.setFill(); rightInner.fill()

        let head = NSBezierPath(ovalIn: NSRect(x: 58, y: y + 10, width: 204, height: 166))
        strokePath(head, fill: fur, stroke: outline, line: 8)
        if state == "error" {
            color(0xff6b6b, alpha: 0.65).setStroke()
            let alert = NSBezierPath(ovalIn: NSRect(x: 68, y: y + 20, width: 184, height: 146))
            alert.lineWidth = 4
            alert.stroke()
        }
    }

    func drawFace(bob: Double, state: String) {
        let outline = color(0x4a2b22)
        let eyeCream = color(0xf5f0de)
        let pupil = color(0x030303)
        let y = 96 - bob
        let blink = Int(tick) % 92 < 3 && state != "error" && state != "sleeping"

        let leftEyeRect = NSRect(x: 81, y: y + 52, width: 72, height: 112)
        let rightEyeRect = NSRect(x: 167, y: y + 52, width: 72, height: 112)
        oval(leftEyeRect, fill: eyeCream, stroke: outline, line: 7)
        oval(rightEyeRect, fill: eyeCream, stroke: outline, line: 7)

        if state == "sleeping" || blink {
            color(0x050505).setStroke()
            let l = NSBezierPath()
            l.move(to: NSPoint(x: 98, y: y + 109))
            l.curve(to: NSPoint(x: 136, y: y + 109), controlPoint1: NSPoint(x: 108, y: y + 96), controlPoint2: NSPoint(x: 126, y: y + 96))
            l.lineWidth = 7
            l.lineCapStyle = .round
            l.stroke()
            let r = NSBezierPath()
            r.move(to: NSPoint(x: 184, y: y + 109))
            r.curve(to: NSPoint(x: 222, y: y + 109), controlPoint1: NSPoint(x: 194, y: y + 96), controlPoint2: NSPoint(x: 212, y: y + 96))
            r.lineWidth = 7
            r.lineCapStyle = .round
            r.stroke()
        } else {
            oval(NSRect(x: 103, y: y + 72, width: 38, height: 78), fill: pupil)
            oval(NSRect(x: 189, y: y + 72, width: 38, height: 78), fill: pupil)
        }
    }

    func drawStatus(state: String, phase: Double, bob: Double) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 28)]
        if state == "thinking" {
            for i in 0..<3 { oval(NSRect(x: 258 + i * 14, y: 205 + Int(sin(phase + Double(i)) * 5), width: 8, height: 8), fill: color(0x65a9ff)) }
        } else if state == "success" {
            NSAttributedString(string: "OK", attributes: attrs.merging([.foregroundColor: color(0x54d17a)]) { $1 }).draw(at: NSPoint(x: 252, y: 205 - bob))
        } else if state == "error" {
            NSAttributedString(string: "!", attributes: attrs.merging([.foregroundColor: color(0xff6b6b)]) { $1 }).draw(at: NSPoint(x: 268, y: 205 - bob))
        } else if state == "sleeping" {
            NSAttributedString(string: "Zz", attributes: attrs.merging([.foregroundColor: color(0x65a9ff)]) { $1 }).draw(at: NSPoint(x: 258, y: 208))
        }
    }

    func drawCaption(state: String) {
        let labels = ["idle": "ready", "thinking": "thinking", "success": "done", "error": "attention", "sleeping": "resting"]
        let text = labels[state] ?? "ready"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: color(0xf5f7fa)]
        let s = NSAttributedString(string: text, attributes: attrs)
        s.draw(at: NSPoint(x: 160 - s.size().width / 2, y: 2))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var timer: Timer!
    let store = PetStateStore(path: statePath)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let view = PetView(frame: NSRect(x: 0, y: 0, width: 320, height: 270), store: store)
        window = NSWindow(contentRect: NSRect(x: 80, y: 360, width: 320, height: 270), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in view.needsDisplay = true }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
