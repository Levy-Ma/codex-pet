import AppKit
import Foundation

let statePath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "runtime/pet-state.json"

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
    var tick: Double = 0

    init(frame: NSRect, store: PetStateStore) {
        self.store = store
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
        drawShadow()
        drawTail(tail: tail, bob: bob, state: state)
        drawBody(breathe: breathe, bob: bob, state: state)
        drawHead(bob: bob, state: state)
        drawFace(bob: bob, state: state)
        drawStatus(state: state, phase: phase, bob: bob)
        drawCaption(state: state)
        tick += 1
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
        oval(NSRect(x: 44, y: 12, width: 165, height: 18), fill: color(0x1a1a1d, alpha: 0.22))
    }

    func drawTail(tail: Double, bob: Double, state: String) {
        let outline = color(0x3a241f)
        let fur = color(state == "success" ? 0x071008 : 0x050505)
        let y = 41 - bob + tail * 0.08
        let outer = NSBezierPath(roundedRect: NSRect(x: 139, y: y, width: 94, height: 22), xRadius: 12, yRadius: 11)
        strokePath(outer, fill: fur, stroke: outline, line: 5)

        let stripe = NSBezierPath()
        stripe.move(to: NSPoint(x: 158, y: y + 11))
        stripe.curve(to: NSPoint(x: 214, y: y + 12), controlPoint1: NSPoint(x: 176, y: y + 8), controlPoint2: NSPoint(x: 198, y: y + 8))
        outline.setStroke()
        stripe.lineWidth = 4
        stripe.lineCapStyle = .round
        stripe.stroke()
    }

    func drawBody(breathe: Double, bob: Double, state: String) {
        let outline = color(0x3a241f)
        let fur = color(0x050505)
        let body = NSBezierPath(roundedRect: NSRect(x: 83, y: 20 - bob, width: 72, height: 66 + breathe), xRadius: 34, yRadius: 30)
        strokePath(body, fill: fur, stroke: outline, line: 5)

        for x in [91.0, 108.0, 125.0] {
            let toe = NSBezierPath()
            toe.move(to: NSPoint(x: x, y: 22 - bob))
            toe.curve(to: NSPoint(x: x + 7, y: 55 - bob), controlPoint1: NSPoint(x: x - 4, y: 34 - bob), controlPoint2: NSPoint(x: x + 1, y: 47 - bob))
            outline.setStroke()
            toe.lineWidth = 4
            toe.lineCapStyle = .round
            toe.stroke()
        }

        let leftPaw = NSBezierPath(roundedRect: NSRect(x: 60, y: 42 - bob, width: 34, height: 24), xRadius: 13, yRadius: 12)
        strokePath(leftPaw, fill: fur, stroke: outline, line: 5)
    }

    func drawHead(bob: Double, state: String) {
        let outline = color(0x3a241f)
        let fur = color(0x050505)
        let innerEar = color(0xb7d2a8)
        let y = 49 - bob

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 47, y: y + 76))
        leftEar.curve(to: NSPoint(x: 78, y: y + 129), controlPoint1: NSPoint(x: 46, y: y + 113), controlPoint2: NSPoint(x: 53, y: y + 133))
        leftEar.curve(to: NSPoint(x: 113, y: y + 82), controlPoint1: NSPoint(x: 93, y: y + 124), controlPoint2: NSPoint(x: 104, y: y + 107))
        leftEar.close()
        strokePath(leftEar, fill: fur, stroke: outline, line: 5)

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 130, y: y + 82))
        rightEar.curve(to: NSPoint(x: 169, y: y + 129), controlPoint1: NSPoint(x: 139, y: y + 108), controlPoint2: NSPoint(x: 151, y: y + 124))
        rightEar.curve(to: NSPoint(x: 193, y: y + 76), controlPoint1: NSPoint(x: 195, y: y + 133), controlPoint2: NSPoint(x: 198, y: y + 111))
        rightEar.close()
        strokePath(rightEar, fill: fur, stroke: outline, line: 5)

        let leftInner = NSBezierPath()
        leftInner.move(to: NSPoint(x: 62, y: y + 85))
        leftInner.curve(to: NSPoint(x: 82, y: y + 115), controlPoint1: NSPoint(x: 62, y: y + 105), controlPoint2: NSPoint(x: 68, y: y + 116))
        leftInner.curve(to: NSPoint(x: 98, y: y + 85), controlPoint1: NSPoint(x: 91, y: y + 111), controlPoint2: NSPoint(x: 96, y: y + 98))
        leftInner.close()
        innerEar.setFill(); leftInner.fill()

        let rightInner = NSBezierPath()
        rightInner.move(to: NSPoint(x: 144, y: y + 85))
        rightInner.curve(to: NSPoint(x: 166, y: y + 115), controlPoint1: NSPoint(x: 147, y: y + 100), controlPoint2: NSPoint(x: 154, y: y + 111))
        rightInner.curve(to: NSPoint(x: 179, y: y + 86), controlPoint1: NSPoint(x: 181, y: y + 116), controlPoint2: NSPoint(x: 181, y: y + 102))
        rightInner.close()
        innerEar.setFill(); rightInner.fill()

        let head = NSBezierPath(ovalIn: NSRect(x: 42, y: y + 13, width: 156, height: 113))
        strokePath(head, fill: fur, stroke: outline, line: 5)
        if state == "error" {
            color(0xff6b6b, alpha: 0.65).setStroke()
            let alert = NSBezierPath(ovalIn: NSRect(x: 50, y: y + 20, width: 140, height: 102))
            alert.lineWidth = 3
            alert.stroke()
        }
    }

    func drawFace(bob: Double, state: String) {
        let outline = color(0x3a241f)
        let eyeCream = color(0xf2efdc)
        let pupil = color(0x030303)
        let y = 49 - bob
        let blink = Int(tick) % 92 < 3 && state != "error" && state != "sleeping"

        let leftEyeRect = NSRect(x: 64, y: y + 41, width: 54, height: 72)
        let rightEyeRect = NSRect(x: 122, y: y + 41, width: 54, height: 72)
        oval(leftEyeRect, fill: eyeCream, stroke: outline, line: 4)
        oval(rightEyeRect, fill: eyeCream, stroke: outline, line: 4)

        if state == "sleeping" || blink {
            color(0x050505).setStroke()
            let l = NSBezierPath()
            l.move(to: NSPoint(x: 77, y: y + 78))
            l.curve(to: NSPoint(x: 105, y: y + 78), controlPoint1: NSPoint(x: 84, y: y + 69), controlPoint2: NSPoint(x: 98, y: y + 69))
            l.lineWidth = 5
            l.lineCapStyle = .round
            l.stroke()
            let r = NSBezierPath()
            r.move(to: NSPoint(x: 135, y: y + 78))
            r.curve(to: NSPoint(x: 163, y: y + 78), controlPoint1: NSPoint(x: 142, y: y + 69), controlPoint2: NSPoint(x: 156, y: y + 69))
            r.lineWidth = 5
            r.lineCapStyle = .round
            r.stroke()
        } else {
            oval(NSRect(x: 80, y: y + 51, width: 24, height: 50), fill: pupil)
            oval(NSRect(x: 138, y: y + 51, width: 24, height: 50), fill: pupil)
        }

        let cheek = NSBezierPath()
        cheek.move(to: NSPoint(x: 77, y: y + 36))
        cheek.curve(to: NSPoint(x: 164, y: y + 36), controlPoint1: NSPoint(x: 99, y: y + 20), controlPoint2: NSPoint(x: 142, y: y + 20))
        outline.setStroke()
        cheek.lineWidth = 5
        cheek.lineCapStyle = .round
        cheek.stroke()
    }

    func drawStatus(state: String, phase: Double, bob: Double) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 28)]
        if state == "thinking" {
            for i in 0..<3 { oval(NSRect(x: 178 + i * 14, y: 136 + Int(sin(phase + Double(i)) * 5), width: 8, height: 8), fill: color(0x65a9ff)) }
        } else if state == "success" {
            NSAttributedString(string: "OK", attributes: attrs.merging([.foregroundColor: color(0x54d17a)]) { $1 }).draw(at: NSPoint(x: 174, y: 130 - bob))
        } else if state == "error" {
            NSAttributedString(string: "!", attributes: attrs.merging([.foregroundColor: color(0xff6b6b)]) { $1 }).draw(at: NSPoint(x: 184, y: 130 - bob))
        } else if state == "sleeping" {
            NSAttributedString(string: "Zz", attributes: attrs.merging([.foregroundColor: color(0x65a9ff)]) { $1 }).draw(at: NSPoint(x: 176, y: 134))
        }
    }

    func drawCaption(state: String) {
        let labels = ["idle": "ready", "thinking": "thinking", "success": "done", "error": "attention", "sleeping": "resting"]
        let text = labels[state] ?? "ready"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: color(0xf5f7fa)]
        let s = NSAttributedString(string: text, attributes: attrs)
        s.draw(at: NSPoint(x: 120 - s.size().width / 2, y: 2))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var timer: Timer!
    let store = PetStateStore(path: statePath)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let view = PetView(frame: NSRect(x: 0, y: 0, width: 240, height: 190), store: store)
        window = NSWindow(contentRect: NSRect(x: 80, y: 420, width: 240, height: 190), styleMask: [.borderless], backing: .buffered, defer: false)
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
