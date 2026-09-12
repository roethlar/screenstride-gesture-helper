import AppKit
import ApplicationServices

/// Only ARDP-marked gesture records are translated. No keyboard/mouse capture,
/// desktop recording, network listener, credentials or background daemon.
final class GestureEventTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var watchdog: Timer?
    private var translator = GestureTranslator()
    var running: Bool { tap != nil }

    static let marker: Int64 = 0x41524450
    private static func field(_ raw: UInt32) -> CGEventField { CGEventField(rawValue: raw)! }

    func start() -> Bool {
        guard tap == nil else { return true }
        guard AXIsProcessTrusted() else { return false }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<GestureEventTap>.fromOpaque(context).takeUnretainedValue().receive(type: type, event: event)
        }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: 1 << 29, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()),
            let source = CFMachPortCreateRunLoopSource(nil, created, 0) else { return false }
        tap = created; self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.post(self.translator.expire(now: ProcessInfo.processInfo.systemUptime))
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
        return true
    }

    func stop() {
        post(translator.cancel())
        watchdog?.invalidate(); watchdog = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    private func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            post(translator.cancel())
            if let tap, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 29, event.getIntegerValueField(Self.field(110)) == 16,
              event.getIntegerValueField(Self.field(138)) == Self.marker else {
            return Unmanaged.passUnretained(event)
        }
        let packet = GesturePacket(axis: event.getIntegerValueField(Self.field(123)),
            phase: event.getIntegerValueField(Self.field(134)),
            progress: event.getDoubleValueField(Self.field(124)))
        post(translator.receive(packet, now: ProcessInfo.processInfo.systemUptime))
        return nil
    }

    private func post(_ gestures: [DockGesture]) {
        for gesture in gestures {
            guard let event = CGEvent(source: nil), let marker = CGEvent(source: nil) else { continue }
            event.type = CGEventType(rawValue: 30)!
            event.setIntegerValueField(Self.field(110), value: 23)
            event.setIntegerValueField(Self.field(123), value: gesture.axis)
            event.setIntegerValueField(Self.field(132), value: gesture.phase)
            event.setIntegerValueField(Self.field(134), value: gesture.phase)
            event.setDoubleValueField(Self.field(124), value: gesture.progress)
            event.setIntegerValueField(Self.field(136), value: gesture.directionFlags)
            event.setIntegerValueField(Self.field(138), value: gesture.flavor)
            event.post(tap: .cgSessionEventTap)
            marker.type = CGEventType(rawValue: 29)!
            marker.post(tap: .cgSessionEventTap)
        }
    }
    deinit { stop() }
}
