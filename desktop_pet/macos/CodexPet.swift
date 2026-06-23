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

    func drawShadow() {
        oval(NSRect(x: 62, y: 14, width: 116, height: 16), fill: color(0x1a1a1d, alpha: 0.28))
    }

    func drawTail(tail: Double, bob: Double, state: String) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 150, y: 68 - bob))
        p.curve(to: NSPoint(x: 154, y: 108 - bob), controlPoint1: NSPoint(x: 194, y: 86 - bob + tail), controlPoint2: NSPoint(x: 184, y: 122 - bob + tail / 2))
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        color(state == "success" ? 0x101612 : 0x111218).setStroke(); p.lineWidth = 18; p.stroke()
        color(0x08080a).setStroke(); p.lineWidth = 12; p.stroke()
    }

    func drawBody(breathe: Double, bob: Double, state: String) {
        let y = 24 - bob
        oval(NSRect(x: 74, y: y, width: 90, height: 62 + breathe), fill: color(0x08080a), stroke: color(0x111218), line: 2)
        oval(NSRect(x: 93, y: 19, width: 19, height: 41), fill: color(0x050506))
        oval(NSRect(x: 128, y: 19, width: 19, height: 41), fill: color(0x050506))
    }

    func drawHead(bob: Double, state: String) {
        let y = 40 - bob
        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 75, y: y + 70)); leftEar.line(to: NSPoint(x: 91, y: y + 112)); leftEar.line(to: NSPoint(x: 111, y: y + 71)); leftEar.close()
        color(0x08080a).setFill(); leftEar.fill(); color(0x111218).setStroke(); leftEar.lineWidth = 2; leftEar.stroke()
        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 129, y: y + 71)); rightEar.line(to: NSPoint(x: 151, y: y + 112)); rightEar.line(to: NSPoint(x: 165, y: y + 70)); rightEar.close()
        color(0x08080a).setFill(); rightEar.fill(); color(0x111218).setStroke(); rightEar.lineWidth = 2; rightEar.stroke()
        oval(NSRect(x: 70, y: y, width: 100, height: 82), fill: color(0x08080a), stroke: color(0x111218), line: 2)
    }

    func drawFace(bob: Double, state: String) {
        let y = 40 - bob
        if state == "sleeping" {
            color(0xf7fbff).setStroke()
            let l = NSBezierPath(); l.move(to: NSPoint(x: 92, y: y + 40)); l.curve(to: NSPoint(x: 111, y: y + 40), controlPoint1: NSPoint(x: 97, y: y + 32), controlPoint2: NSPoint(x: 106, y: y + 32)); l.lineWidth = 2; l.stroke()
            let r = NSBezierPath(); r.move(to: NSPoint(x: 130, y: y + 40)); r.curve(to: NSPoint(x: 149, y: y + 40), controlPoint1: NSPoint(x: 135, y: y + 32), controlPoint2: NSPoint(x: 144, y: y + 32)); r.lineWidth = 2; r.stroke()
        } else {
            let blink = Int(tick) % 72 < 3 && state != "error"
            if blink {
                color(0xf7fbff).setStroke()
                let l = NSBezierPath(); l.move(to: NSPoint(x: 91, y: y + 42)); l.line(to: NSPoint(x: 111, y: y + 43)); l.lineWidth = 2; l.stroke()
                let r = NSBezierPath(); r.move(to: NSPoint(x: 130, y: y + 43)); r.line(to: NSPoint(x: 150, y: y + 42)); r.lineWidth = 2; r.stroke()
            } else {
                oval(NSRect(x: 91, y: y + 34, width: 21, height: 23), fill: color(0xf7c948))
                oval(NSRect(x: 130, y: y + 34, width: 21, height: 23), fill: color(0xf7c948))
                oval(NSRect(x: 100, y: y + 37, width: 7, height: 16), fill: color(0x090909))
                oval(NSRect(x: 139, y: y + 37, width: 7, height: 16), fill: color(0x090909))
                oval(NSRect(x: 96, y: y + 50, width: 4, height: 4), fill: color(0xf7fbff))
                oval(NSRect(x: 135, y: y + 50, width: 4, height: 4), fill: color(0xf7fbff))
            }
        }
        let nose = NSBezierPath(); nose.move(to: NSPoint(x: 119, y: y + 30)); nose.line(to: NSPoint(x: 123, y: y + 26)); nose.line(to: NSPoint(x: 115, y: y + 26)); nose.close(); color(0x2c2c34).setFill(); nose.fill()
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
