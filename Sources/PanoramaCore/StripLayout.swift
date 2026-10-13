import CoreGraphics
import Foundation

/// Geometry is independent of capture, AppKit and input devices, so changes can be tested deterministically.
public struct StripLayout: Sendable {
    public struct Item: Sendable, Equatable {
        public let id: UInt32
        public let aspectRatio: Double
        public init(id: UInt32, aspectRatio: Double) {
            self.id = id
            self.aspectRatio = aspectRatio.isFinite ? max(0.15, min(8, aspectRatio)) : 1
        }
    }
    public let frames: [CGRect]
    public let items: [Item]
    public let viewportWidth: Double
    public let contentWidth: Double
    public var maxOffset: Double { max(0, contentWidth - viewportWidth) }

    public init(items: [Item], viewport: CGSize, gap: Double = 24) {
        self.items = items
        viewportWidth = max(1, viewport.width)
        var x = viewportWidth / 2
        var built: [CGRect] = []
        for item in items {
            let height = min(max(1, viewport.height), viewportWidth * 0.82 / item.aspectRatio)
            let width = height * item.aspectRatio
            if built.isEmpty { x -= width / 2 }
            built.append(CGRect(x: x, y: (viewport.height - height) / 2, width: width, height: height))
            x += width + gap
        }
        frames = built
        if let last = built.last { contentWidth = last.midX + viewportWidth / 2 } else { contentWidth = viewportWidth }
    }
    public func clamped(_ offset: Double) -> Double { min(max(0, offset), maxOffset) }
    public func offset(centering index: Int) -> Double {
        guard frames.indices.contains(index) else { return 0 }
        return clamped(frames[index].midX - viewportWidth / 2)
    }
    public func nearestIndex(to offset: Double) -> Int? {
        let center = offset + viewportWidth / 2
        return frames.indices.min { abs(frames[$0].midX - center) < abs(frames[$1].midX - center) }
    }
    public func visibleIndices(at offset: Double, overscan: Double = 0) -> [Int] {
        frames.indices.filter { frames[$0].maxX > offset - overscan && frames[$0].minX < offset + viewportWidth + overscan }
    }
    /// Preserve the screen coordinate of a surviving window when the catalog changes.
    public func anchoredOffset(from old: StripLayout, offset: Double, anchorID: UInt32) -> Double {
        guard let a = old.items.firstIndex(where: { $0.id == anchorID }),
              let b = items.firstIndex(where: { $0.id == anchorID }) else { return clamped(offset) }
        return clamped(offset + frames[b].midX - old.frames[a].midX)
    }
}
