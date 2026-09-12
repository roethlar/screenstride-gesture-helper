import Foundation

/// State for the optional Mac helper. Input is an ARDP-marked PageSwipe event
/// already delivered by the authenticated Screen Sharing session.
public struct GesturePacket: Equatable, Sendable {
    public let axis: Int64
    public let phase: Int64
    public let progress: Double
    public init(axis: Int64, phase: Int64, progress: Double) {
        self.axis = axis; self.phase = phase; self.progress = progress
    }
}

public struct DockGesture: Equatable, Sendable {
    public let axis: Int64
    public let phase: Int64
    public let progress: Double
    public var directionFlags: Int64 { axis == 2 ? 1 : 0 }
    public var flavor: Int64 { axis == 2 ? 3 : 0 }
}

public struct GestureTranslator {
    private var axis: Int64?
    private var progress = 0.0
    private var lastPacket = 0.0
    private var postedBegin = false
    public var active: Bool { axis != nil }
    public init() {}

    private func output(phase: Int64) -> DockGesture? {
        guard let axis else { return nil }
        return DockGesture(axis: axis, phase: phase,
                           progress: axis == 2 ? -progress : progress)
    }

    public mutating func cancel() -> [DockGesture] {
        let result = postedBegin ? output(phase: 8).map { [$0] } ?? [] : []
        self = Self()
        return result
    }

    public mutating func receive(_ packet: GesturePacket, now: TimeInterval) -> [DockGesture] {
        guard (packet.axis == 1 || packet.axis == 2), [1, 2, 4, 8].contains(packet.phase),
              packet.progress.isFinite, abs(packet.progress) <= 2, now.isFinite else {
            return cancel()
        }
        var result: [DockGesture] = []
        if packet.phase == 1 {
            result += cancel()
            axis = packet.axis
        }
        guard axis == packet.axis else { return result }
        let previous = progress
        progress = packet.progress
        lastPacket = now
        if packet.axis == 2 && !postedBegin {
            // The captured native vertical begin has nonzero progress. Dock
            // selects Mission Control/App Exposé from this first direction.
            if (packet.phase == 1 || packet.phase == 2), progress != 0 {
                if let event = output(phase: 1) { result.append(event) }
                postedBegin = true
            }
        } else if packet.phase != 2 || progress != previous {
            // Stationary hold heartbeats renew the timeout without reposting
            // a synthetic movement or beginning another gesture.
            if let event = output(phase: packet.phase) { result.append(event) }
            if packet.phase == 1 { postedBegin = true }
        }
        if packet.phase == 4 || packet.phase == 8 { self = Self() }
        return result
    }

    public mutating func expire(now: TimeInterval, timeout: TimeInterval = 2) -> [DockGesture] {
        guard active, now - lastPacket > timeout else { return [] }
        return cancel()
    }
}
