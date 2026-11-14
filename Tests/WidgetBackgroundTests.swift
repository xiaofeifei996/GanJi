import Foundation
import UIKit
import ImageIO

// From the repository root, with a booted simulator (use x86_64 on Intel):
// xcrun swiftc -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios15.0-simulator Shared/LunarCalendar.swift Shared/WidgetFeed.swift Shared/WidgetBackground.swift Tests/WidgetBackgroundTests.swift -o /tmp/widget-background-tests
// xcrun simctl spawn booted /tmp/widget-background-tests
// All I/O uses a UUID temporary directory; never call the production static storage APIs.
@main struct WidgetBackgroundTests {
    typealias Storage = WidgetBackgroundStore.Storage
    typealias StoreError = WidgetBackgroundStore.StoreError

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    final class Checks {
        var count = 0
        func expect(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure(description: message) }
            count += 1
        }
        func rejects(_ message: String, matching: (StoreError) -> Bool,
                     _ body: () throws -> Void) throws {
            do { try body() }
            catch let error as StoreError {
                try expect(matching(error), "\(message): unexpected error \(error)")
                return
            }
            throw Failure(description: "\(message): expected StoreError")
        }
    }

    // Independent representation of the on-disk contract, deliberately not the private Record.
    struct Envelope: Codable {
        var schema = 1
        var size = "small"
        var revision = UUID()
        var updatedAt = 900.0
        var deleted = false
        var darkness = 0.2
        var jpeg: Data?
        var sourceJPEG: Data?
        var focalX: Double?
        var focalY: Double?
    }

    static func fixture(width: Int = 900, height: Int = 300,
                        orientation: Int = 1, transparent: Bool = false) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: CGSize(width: CGFloat(width), height: CGFloat(height)), format: format).image { ctx in
            if !transparent {
                for (i, color) in [UIColor.red, UIColor.green, UIColor.blue].enumerated() {
                    color.setFill()
                    ctx.fill(CGRect(x: CGFloat(i * width) / 3, y: 0,
                                    width: CGFloat(width) / 3, height: CGFloat(height)))
                }
            }
        }
        let output = NSMutableData()
        let type = transparent ? "public.png" : "public.jpeg"
        guard let cg = image.cgImage,
              let destination = CGImageDestinationCreateWithData(output, type as CFString, 1, nil) else {
            throw Failure(description: "Cannot create image fixture")
        }
        CGImageDestinationAddImage(destination, cg,
                                  [kCGImagePropertyOrientation: orientation,
                                   kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure(description: "Fixture encode failed") }
        return output as Data
    }

    // Sample the central pixel without relying on UIKit's device scale or CGImage row ordering.
    static func centerRGB(_ image: UIImage?) throws -> [UInt8] {
        guard let cg = image?.cgImage,
              let pixel = cg.cropping(to: CGRect(x: CGFloat(cg.width / 2), y: CGFloat(cg.height / 2), width: 1, height: 1)) else {
            throw Failure(description: "Missing output image")
        }
        var bytes = [UInt8](repeating: 0, count: 4)
        let succeeded = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: 1, height: 1,
                                      bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard succeeded else { throw Failure(description: "Cannot sample output pixel") }
        return Array(bytes.prefix(3))
    }

    static func expectColor(_ image: UIImage?, channel: Int, _ label: String, _ c: Checks) throws {
        let rgb = try centerRGB(image)
        try c.expect(rgb[channel] > 220 && rgb.enumerated().allSatisfy { $0.offset == channel || $0.element < 35 },
                     "\(label): unexpected center RGB \(rgb)")
    }

    static func write(_ envelope: Envelope, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(envelope).write(to: url, options: .atomic)
    }

    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WidgetBackgroundTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let c = Checks()
        let photo = try fixture()
        let primary = root.appendingPathComponent("primary", isDirectory: true)
        let fallback = root.appendingPathComponent("fallback", isDirectory: true)
        let store = Storage(directories: [primary, fallback], now: { 1000 })
        try c.expect(store.appearance(for: .small).image == nil, "Missing store must have no photo")
        try c.expect(store.appearance(for: .small).darkness == 0.35, "Missing store default darkness")
        try c.expect(Storage(directories: [primary, primary]).targets(for: .small).count == 1,
                     "Duplicate standardized targets must be removed")

        // Exact pixel sizes and opaque normalized JPEG output for all three widget shapes.
        let heights: [WidgetPhotoSize: Int] = [.small: 1200, .medium: 566, .large: 1143]
        for size in WidgetPhotoSize.allCases {
            try autoreleasepool {
                try store.save(imageData: photo, for: size, darkness: 0.61)
                let result = store.appearance(for: size)
                try c.expect(result.image?.cgImage?.width == 1200 && result.image?.cgImage?.height == heights[size],
                             "Wrong output dimensions for \(size)")
                try c.expect(result.image?.imageOrientation == .up && result.image?.scale == 1,
                             "Output must use normalized orientation and pixel scale")
                try c.expect(result.darkness == 0.61, "Darkness must round trip")
                try expectColor(result.image, channel: 1, "Centered crop for \(size)", c)
                let urls = store.targets(for: size)
                let bytes = try Data(contentsOf: urls[0])
                try c.expect(bytes == Data(contentsOf: urls[1]), "Published channels must match byte-for-byte")
                let record = try JSONDecoder().decode(Envelope.self, from: bytes)
                guard let jpeg = record.jpeg,
                      let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
                    throw Failure(description: "Saved JPEG not readable")
                }
                try c.expect(CGImageSourceGetType(source) as String? == "public.jpeg" && jpeg.count <= 2 * 1024 * 1024,
                             "Saved payload must be a bounded JPEG")
                try c.expect(((props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1) == 1,
                             "Stored EXIF orientation must be normalized")
            }
        }

        try invalidInputs(store, photo: photo, checks: c)
        try cropAndOrientation(store, photo: photo, checks: c)
        try selectionAndWrites(store, root: root, photo: photo, checks: c)
        try editingRoundTrip(root: root, checks: c)
        print("WidgetBackgroundTests: \(c.count) checks passed")
    }

    static func editingRoundTrip(root: URL, checks c: Checks) throws {
        let directories = [root.appendingPathComponent("editor-primary"), root.appendingPathComponent("editor-fallback")]
        let store = Storage(directories: directories, now: { 2000 })
        // Landscape and EXIF-rotated portrait both need to recover pixels outside the saved crop.
        for (size, orientation) in [(WidgetPhotoSize.large, 1), (.medium, 6), (.small, 1)] {
            try autoreleasepool {
                try store.save(imageData: fixture(width: 3000, height: 1000, orientation: orientation),
                               for: size, darkness: 0.63, focalX: 0, focalY: 0)
                let reopened = Storage(directories: directories, now: { 2000 })
                let state = reopened.editorState(for: size)
                guard let source = state.sourceData, let image = state.sourceImage else {
                    throw Failure(description: "Saved background lost its editable original")
                }
                try c.expect(state.focalX == 0 && state.focalY == 0 && state.darkness == 0.63,
                             "Fresh reader must restore exact focus and darkness")
                try c.expect(max(image.size.width, image.size.height) == 2400 && min(image.size.width, image.size.height) == 800,
                             "Retained source must preserve the full photo, normalized and bounded to 2400px")
                try c.expect(image.imageOrientation == .up && source.count <= 2 * 1024 * 1024,
                             "Retained source orientation and byte budget")
                try expectColor(state.image, channel: 0, "Initial saved crop is red", c)
                try reopened.save(imageData: source, for: size, darkness: 0.17, focalX: 1, focalY: 1)
                let edited = Storage(directories: directories, now: { 2000 }).editorState(for: size)
                try c.expect(edited.sourceData == source, "Repeated edits must not recompress or crop the source")
                try c.expect(edited.focalX == 1 && edited.focalY == 1 && edited.darkness == 0.17,
                             "Re-edited parameters must persist")
                try expectColor(edited.image, channel: 2, "Reopened edit recovers blue pixels outside old red crop", c)
                let urls = store.targets(for: size)
                let bytes = try Data(contentsOf: urls[0])
                try c.expect(bytes.count <= 6 * 1024 * 1024 && bytes == Data(contentsOf: urls[1]),
                             "Source, preview and parameters publish together within the record budget")
            }
        }
        let urls = store.targets(for: .large)
        let original = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: urls[0]))
        var legacy = original
        legacy.sourceJPEG = nil
        legacy.focalX = nil
        legacy.focalY = nil
        for url in urls { try write(legacy, to: url) }
        let state = store.editorState(for: .large)
        try c.expect(state.image != nil && state.sourceData == nil && state.sourceImage == nil,
                     "Legacy crop remains visible without claiming an editable original")
        try store.updateDarkness(for: .large, darkness: 0.81)
        let updated = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: urls[0]))
        try c.expect(updated.jpeg == legacy.jpeg && updated.sourceJPEG == nil && updated.focalX == nil && updated.focalY == nil,
                     "Legacy darkness update must preserve crop bytes and absent source")
        try c.expect(store.editorState(for: .large).darkness == 0.81, "Legacy darkness persists after reopen")
        try store.save(imageData: fixture(), for: .large, darkness: 0.2, focalX: 0.25, focalY: 0.75)
        try c.expect(store.editorState(for: .large).sourceData != nil, "Reselect upgrades a legacy photo to editable storage")
        let before = try Data(contentsOf: urls[0])
        try c.rejects("Failed replacement keeps the original and parameters", matching: {
            if case .invalidImage = $0 { return true }; return false
        }) { try store.save(imageData: Data(), for: .large, darkness: 0) }
        try c.expect(before == Data(contentsOf: urls[0]), "Failed replacement leaves the complete record unchanged")
        try store.reset(for: .large)
        let reset = store.editorState(for: .large)
        try c.expect(reset.image == nil && reset.sourceData == nil && reset.sourceImage == nil,
                     "Reset removes source and crop from fresh editor state")
        let tombstone = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: urls[0]))
        try c.expect(tombstone.sourceJPEG == nil && tombstone.focalX == nil && tombstone.focalY == nil,
                     "Reset does not leave retained source bytes or focus on disk")
        try c.expect(store.editorState(for: .medium).sourceData != nil, "Reset must preserve other sizes' editable originals")
    }

    static func invalidInputs(_ store: Storage, photo: Data, checks c: Checks) throws {
        let invalid: (StoreError) -> Bool = { if case .invalidImage = $0 { return true }; return false }
        let oversized: (StoreError) -> Bool = { if case .imageTooLarge = $0 { return true }; return false }
        let before = try Data(contentsOf: store.targets(for: .small)[0])
        for bytes in [Data(), Data("not an image".utf8), Data(photo.prefix(photo.count / 2))] {
            try c.rejects("Empty, arbitrary or truncated input", matching: invalid) {
                try store.save(imageData: bytes, for: .small, darkness: 0.2)
            }
        }
        try autoreleasepool {
            try c.rejects("Input byte limit", matching: oversized) {
                try store.save(imageData: Data(repeating: 0, count: 50 * 1024 * 1024 + 1),
                               for: .small, darkness: 0.2)
            }
        }
        try c.expect(before == Data(contentsOf: store.targets(for: .small)[0]),
                     "Rejected input must not replace the existing photo")
        for (width, height) in [(32769.0, 1.0), (1.0, 32769.0), (10001.0, 10000.0)] {
            try c.rejects("Dimension/pixel count limit", matching: oversized) {
                try WidgetBackgroundStore.validateInputDimensions(width: width, height: height)
            }
        }
        for (width, height) in [(0.0, 1.0), (-1.0, 1.0), (1.5, 1.0), (Double.nan, 1.0), (1.0, Double.infinity)] {
            try c.rejects("Malformed dimensions", matching: invalid) {
                try WidgetBackgroundStore.validateInputDimensions(width: width, height: height)
            }
        }
        try WidgetBackgroundStore.validateInputDimensions(width: 10000, height: 10000)
        try WidgetBackgroundStore.validateInputDimensions(width: 32768, height: 1)
        try c.expect(true, "Inclusive dimension limits must be accepted")

        for (input, expected) in [(-1.0, 0.0), (2.0, 1.0), (0.0, 0.0), (1.0, 1.0),
                                  (Double.nan, 0.35), (Double.infinity, 0.35), (-Double.infinity, 0.35)] {
            try autoreleasepool {
                try store.save(imageData: photo, for: .small, darkness: input)
                let result = store.appearance(for: .small)
                try c.expect(result.darkness == expected, "Darkness clamp/fallback for \(input)")
                try expectColor(result.image, channel: 1, "Darkness must not be baked into JPEG", c)
            }
        }
    }

    static func cropAndOrientation(_ store: Storage, photo: Data, checks c: Checks) throws {
        for (x, channel) in [(-10.0, 0), (0.5, 1), (10.0, 2), (Double.nan, 1), (Double.infinity, 1)] {
            try autoreleasepool {
                try store.save(imageData: photo, for: .small, darkness: 0.3, focalX: x)
                try expectColor(store.appearance(for: .small).image, channel: channel, "Horizontal focus \(x)", c)
            }
        }
        // EXIF 6 rotates stored red/green/blue columns clockwise into top/middle/bottom rows.
        // EXIF 8 rotates counterclockwise; EXIF 3 reverses horizontal order.
        for (orientation, axis, channels) in [(6, "y", [0, 1, 2]), (8, "y", [2, 1, 0]), (3, "x", [2, 1, 0])] {
            let rotated = try fixture(orientation: orientation)
            for (index, focus) in [-4.0, 0.5, 4.0].enumerated() {
                try autoreleasepool {
                    try store.save(imageData: rotated, for: .small, darkness: 0.3,
                                   focalX: axis == "x" ? focus : 0.5,
                                   focalY: axis == "y" ? focus : 0.5)
                    try expectColor(store.appearance(for: .small).image, channel: channels[index],
                                    "EXIF \(orientation) focus \(focus)", c)
                }
            }
        }
        let rotated = try fixture(orientation: 6)
        for focus in [Double.nan, Double.infinity] {
            try store.save(imageData: rotated, for: .small, darkness: 0.3, focalY: focus)
            try expectColor(store.appearance(for: .small).image, channel: 1, "Nonfinite vertical focus", c)
        }
        try store.save(imageData: fixture(width: 30, height: 10, transparent: true), for: .small, darkness: 0)
        try c.expect(centerRGB(store.appearance(for: .small).image).allSatisfy { $0 < 10 },
                     "Transparent input must be composited over black")
        // Thin inputs must upscale safely while retaining the required output shape.
        try store.save(imageData: fixture(width: 3000, height: 3), for: .large, darkness: 0)
        let thin = store.appearance(for: .large).image
        try c.expect(thin?.cgImage?.width == 1200 && thin?.cgImage?.height == 1143,
                     "Extreme aspect ratio output dimensions")
        try expectColor(thin, channel: 1, "Extreme aspect ratio centered crop", c)
    }

    static func selectionAndWrites(_ store: Storage, root: URL, photo: Data, checks c: Checks) throws {
        try store.save(imageData: photo, for: .small, darkness: 0.2)
        let urls = store.targets(for: .small)
        let base = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: urls[0]))
        var old = base
        old.updatedAt = 800
        old.darkness = 0.2
        var recent = base
        recent.updatedAt = 900
        recent.darkness = 0.8
        recent.revision = UUID()
        try write(old, to: urls[0])
        try write(recent, to: urls[1])
        try c.expect(store.appearance(for: .small).darkness == 0.8, "Newer fallback supersedes stale primary")
        try write(recent, to: urls[0])
        try write(old, to: urls[1])
        try c.expect(store.appearance(for: .small).darkness == 0.8, "Newer primary supersedes stale fallback")
        old.updatedAt = recent.updatedAt
        try write(old, to: urls[0])
        try write(recent, to: urls[1])
        try c.expect(store.appearance(for: .small).darkness == 0.2, "Equal timestamps retain target priority")

        var tombstone = recent
        tombstone.jpeg = nil
        tombstone.sourceJPEG = nil
        tombstone.focalX = nil
        tombstone.focalY = nil
        tombstone.deleted = true
        tombstone.updatedAt = 950
        for tombstoneIndex in [0, 1] {
            try write(tombstone, to: urls[tombstoneIndex])
            try write(recent, to: urls[1 - tombstoneIndex])
            let result = store.appearance(for: .small)
            try c.expect(result.image == nil && result.darkness == 0.35,
                         "Latest tombstone in channel \(tombstoneIndex) suppresses all older photos")
        }
        tombstone.updatedAt = 850
        try write(tombstone, to: urls[0])
        try write(recent, to: urls[1])
        try c.expect(store.appearance(for: .small).image != nil && store.appearance(for: .small).darkness == 0.8,
                     "Stale tombstone must not suppress a newer photo")
        tombstone.updatedAt = recent.updatedAt
        try write(tombstone, to: urls[0])
        try c.expect(store.appearance(for: .small).image == nil, "Timestamp tie honors primary tombstone")
        try write(recent, to: urls[0])
        try write(tombstone, to: urls[1])
        try c.expect(store.appearance(for: .small).image != nil, "Timestamp tie honors primary photo")

        // Invalid newer records must never hide a fully valid older fallback.
        try write(recent, to: urls[1])
        var invalidRecords = [Envelope]()
        func bad(_ mutate: (inout Envelope) -> Void) {
            var record = recent
            record.updatedAt = 990
            mutate(&record)
            invalidRecords.append(record)
        }
        bad { $0.schema = 2 }
        bad { $0.sourceJPEG = Data("broken source".utf8) }
        bad { $0.sourceJPEG = Data(repeating: 0, count: 2 * 1024 * 1024 + 1) }
        bad { $0.focalX = nil }
        bad { $0.focalY = 1.1 }
        bad { $0.sourceJPEG = nil }
        bad { $0.size = "medium" }
        bad { $0.updatedAt = -1 }
        bad { $0.updatedAt = 1301 }
        bad { $0.darkness = -0.1 }
        bad { $0.darkness = 1.1 }
        bad { $0.jpeg = nil }
        bad { $0.jpeg = Data() }
        bad { $0.jpeg = Data("broken JPEG".utf8) }
        bad { $0.jpeg = Data(repeating: 0, count: 2 * 1024 * 1024 + 1) }
        bad { $0.deleted = true } // Tombstones cannot carry JPEG bytes.
        bad { $0.jpeg = photo } // Genuine JPEG, but not the required output dimensions.
        let rotatedSquare = try fixture(width: 1200, height: 1200, orientation: 6)
        bad { $0.jpeg = rotatedSquare } // Correct dimensions, non-normalized EXIF.
        let pngSquare = try fixture(width: 1200, height: 1200, transparent: true)
        bad { $0.jpeg = pngSquare } // Correct dimensions, wrong image type.
        for (index, record) in invalidRecords.enumerated() {
            try autoreleasepool {
                try write(record, to: urls[0])
                let result = store.appearance(for: .small)
                try c.expect(result.image != nil && result.darkness == 0.8,
                             "Corrupt/invalid record \(index) must fall back")
            }
        }
        for bytes in [Data(), Data("{truncated".utf8), Data("{}".utf8),
                      Data(repeating: 32, count: 6 * 1024 * 1024 + 1)] {
            try bytes.write(to: urls[0], options: .atomic)
            try c.expect(store.appearance(for: .small).darkness == 0.8,
                         "Empty, malformed, missing-field and oversized records must fall back")
        }
        try FileManager.default.removeItem(at: urls[0])
        try FileManager.default.createDirectory(at: urls[0], withIntermediateDirectories: true)
        try c.expect(store.appearance(for: .small).darkness == 0.8, "Directory is not a record")
        try FileManager.default.removeItem(at: urls[0])

        // Same injected clock on consecutive operations must still produce strict ordering.
        try store.save(imageData: photo, for: .small, darkness: 0.4)
        let saved = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: urls[0]))
        try store.reset(for: .small)
        let resetBytes = try Data(contentsOf: urls[0])
        let reset = try JSONDecoder().decode(Envelope.self, from: resetBytes)
        try c.expect(reset.deleted && reset.jpeg == nil && reset.updatedAt > saved.updatedAt && reset.revision != saved.revision,
                     "Reset persists a strictly newer tombstone")
        try c.expect(resetBytes == Data(contentsOf: urls[1]), "Reset must publish identical tombstones")
        let reloaded = Storage(directories: store.directories, now: { 1000 })
        try c.expect(reloaded.appearance(for: .small).image == nil, "New reader sees persisted reset")
        try c.expect(reloaded.appearance(for: .medium).image != nil, "Reset must not affect another widget size")
        try store.save(imageData: photo, for: .small, darkness: 0.7)
        let restored = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: urls[0]))
        try c.expect(!restored.deleted && restored.updatedAt > reset.updatedAt,
                     "Save after reset must supersede the tombstone")
        try c.expect(reloaded.appearance(for: .small).darkness == 0.7, "Independent reader sees latest write")
        let rollback = Storage(directories: store.directories, now: { 999 })
        try rollback.reset(for: .small)
        let rolled = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: urls[0]))
        try c.expect(rolled.updatedAt > restored.updatedAt, "Small clock rollback preserves ordering")

        // Deterministically unwritable path: its parent is a regular file, not permissions/root dependent.
        let blocker = root.appendingPathComponent("not-a-directory")
        try Data([1]).write(to: blocker)
        let blocked = blocker.appendingPathComponent("child", isDirectory: true)
        let partial = Storage(directories: [blocked, root.appendingPathComponent("writable")], now: { 1000 })
        try partial.save(imageData: photo, for: .small, darkness: 0.6)
        try c.expect(partial.appearance(for: .small).darkness == 0.6, "One writable channel suffices")
        try partial.reset(for: .small)
        try c.expect(partial.appearance(for: .small).image == nil, "Partial-write reset must persist")
        for directories in [[blocked], []] {
            let unwritable = Storage(directories: directories, now: { 1000 })
            try c.rejects("No writable target must report failure", matching: {
                if case .sharedWriteFailed = $0 { return true }; return false
            }) { try unwritable.reset(for: .small) }
        }
        for now in [Double.nan, Double.infinity, -1.0] {
            let brokenClock = Storage(directories: store.directories, now: { now })
            let before = try Data(contentsOf: urls[0])
            try c.rejects("Invalid clock", matching: {
                if case .invalidClock = $0 { return true }; return false
            }) { try brokenClock.reset(for: .small) }
            try c.expect(before == Data(contentsOf: urls[0]), "Invalid clock must not alter disk")
        }
        var boundary = recent
        boundary.updatedAt = 1300
        try write(boundary, to: urls[0])
        try c.expect(store.appearance(for: .small).darkness == 0.8, "Future tolerance includes its boundary")
        try c.rejects("Cannot advance past future tolerance", matching: {
            if case .invalidClock = $0 { return true }; return false
        }) { try store.reset(for: .small) }
    }
}
