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
        let body = NSBezierPath(roundedRect: NSRect(x: 82, y: 18 - bob, width: 76, height: 76 + breathe), xRadius: 36, yRadius: 34)
        strokePath(body, fill: fur, stroke: outline, line: 5)

        let leftHand = NSBezierPath(roundedRect: NSRect(x: 88, y: 18 - bob, width: 28, height: 58), xRadius: 13, yRadius: 14)
        strokePath(leftHand, fill: fur, stroke: outline, line: 4)
        let rightHand = NSBezierPath(roundedRect: NSRect(x: 122, y: 18 - bob, width: 28, height: 58), xRadius: 13, yRadius: 14)
        strokePath(rightHand, fill: fur, stroke: outline, line: 4)

        for x in [99.0, 112.0, 133.0, 146.0] {
            let toe = NSBezierPath()
            toe.move(to: NSPoint(x: x, y: 21 - bob))
            toe.curve(to: NSPoint(x: x + 2, y: 54 - bob), controlPoint1: NSPoint(x: x - 3, y: 32 - bob), controlPoint2: NSPoint(x: x - 1, y: 45 - bob))
            outline.setStroke()
            toe.lineWidth = 3.2
            toe.lineCapStyle = .round
            toe.stroke()
        }
    }

    func drawHead(bob: Double, state: String) {
        let outline = color(0x3a241f)
        let fur = color(0x050505)
        let innerEar = color(0xb7d2a8)
        let y = 42 - bob

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 45, y: y + 83))
        leftEar.curve(to: NSPoint(x: 72, y: y + 147), controlPoint1: NSPoint(x: 41, y: y + 122), controlPoint2: NSPoint(x: 47, y: y + 149))
        leftEar.curve(to: NSPoint(x: 112, y: y + 95), controlPoint1: NSPoint(x: 94, y: y + 143), controlPoint2: NSPoint(x: 107, y: y + 120))
        leftEar.close()
        strokePath(leftEar, fill: fur, stroke: outline, line: 5)

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 128, y: y + 95))
        rightEar.curve(to: NSPoint(x: 168, y: y + 147), controlPoint1: NSPoint(x: 134, y: y + 121), controlPoint2: NSPoint(x: 148, y: y + 143))
        rightEar.curve(to: NSPoint(x: 195, y: y + 83), controlPoint1: NSPoint(x: 194, y: y + 149), controlPoint2: NSPoint(x: 199, y: y + 122))
        rightEar.close()
        strokePath(rightEar, fill: fur, stroke: outline, line: 5)

        let leftInner = NSBezierPath()
        leftInner.move(to: NSPoint(x: 59, y: y + 92))
        leftInner.curve(to: NSPoint(x: 76, y: y + 128), controlPoint1: NSPoint(x: 58, y: y + 113), controlPoint2: NSPoint(x: 63, y: y + 129))
        leftInner.curve(to: NSPoint(x: 97, y: y + 95), controlPoint1: NSPoint(x: 88, y: y + 126), controlPoint2: NSPoint(x: 95, y: y + 111))
        leftInner.close()
        innerEar.setFill(); leftInner.fill()

        let rightInner = NSBezierPath()
        rightInner.move(to: NSPoint(x: 143, y: y + 95))
        rightInner.curve(to: NSPoint(x: 164, y: y + 128), controlPoint1: NSPoint(x: 146, y: y + 111), controlPoint2: NSPoint(x: 153, y: y + 126))
        rightInner.curve(to: NSPoint(x: 181, y: y + 92), controlPoint1: NSPoint(x: 178, y: y + 129), controlPoint2: NSPoint(x: 183, y: y + 113))
        rightInner.close()
        innerEar.setFill(); rightInner.fill()

        let head = NSBezierPath(ovalIn: NSRect(x: 55, y: y + 11, width: 130, height: 130))
        strokePath(head, fill: fur, stroke: outline, line: 5)
        if state == "error" {
            color(0xff6b6b, alpha: 0.65).setStroke()
            let alert = NSBezierPath(ovalIn: NSRect(x: 62, y: y + 18, width: 116, height: 116))
            alert.lineWidth = 3
            alert.stroke()
        }
    }

    func drawFace(bob: Double, state: String) {
        let outline = color(0x3a241f)
        let eyeCream = color(0xf2efdc)
        let pupil = color(0x030303)
        let y = 42 - bob
        let blink = Int(tick) % 92 < 3 && state != "error" && state != "sleeping"

        let leftEyeRect = NSRect(x: 67, y: y + 51, width: 51, height: 70)
        let rightEyeRect = NSRect(x: 122, y: y + 51, width: 51, height: 70)
        oval(leftEyeRect, fill: eyeCream, stroke: outline, line: 4)
        oval(rightEyeRect, fill: eyeCream, stroke: outline, line: 4)

        if state == "sleeping" || blink {
            color(0x050505).setStroke()
            let l = NSBezierPath()
            l.move(to: NSPoint(x: 79, y: y + 87))
            l.curve(to: NSPoint(x: 107, y: y + 87), controlPoint1: NSPoint(x: 86, y: y + 78), controlPoint2: NSPoint(x: 100, y: y + 78))
            l.lineWidth = 5
            l.lineCapStyle = .round
            l.stroke()
            let r = NSBezierPath()
            r.move(to: NSPoint(x: 134, y: y + 87))
            r.curve(to: NSPoint(x: 162, y: y + 87), controlPoint1: NSPoint(x: 141, y: y + 78), controlPoint2: NSPoint(x: 155, y: y + 78))
            r.lineWidth = 5
            r.lineCapStyle = .round
            r.stroke()
        } else {
            oval(NSRect(x: 82, y: y + 61, width: 22, height: 48), fill: pupil)
            oval(NSRect(x: 137, y: y + 61, width: 22, height: 48), fill: pupil)
        }
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
