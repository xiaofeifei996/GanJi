#if canImport(UIKit)
import Foundation
import UIKit
import ImageIO

/// 与 WidgetFamily 解耦，让 App 和扩展共用同一套照片接口。
enum WidgetPhotoSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "小号"
        case .medium: return "中号"
        case .large: return "大号"
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .small: return 1
        case .medium: return 2.12
        case .large: return 1.05
        }
    }
}

/// 每个尺寸一份原子 JSON；Data 由 Codable 编码为 base64 JPEG。
/// 暗度是供视图叠加黑色遮罩的参数，不会烧入图片。
/// 不保存 App 私有预览副本：没有任何共享路径写入成功时必须向调用者报错。
struct WidgetBackgroundStore {
    enum StoreError: LocalizedError {
        case invalidImage
        case imageTooLarge
        case encodingFailed
        case invalidClock
        case sharedWriteFailed([String])
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "无法读取这张图片，请选择完整的照片文件。"
            case .imageTooLarge:
                return "图片过大，请选择不超过 50 MB、1 亿像素且单边不超过 32768 像素的图片。"
            case .encodingFailed:
                return "背景图片压缩失败，请尝试其他照片。"
            case .invalidClock:
                return "设备时间异常，无法更新小组件背景。"
            case .sharedWriteFailed(let failures):
                return "无法保存到共享目录，小组件背景未同步。" + failures.joined(separator: "；")
            case .verificationFailed:
                return "背景已尝试写入，但回读的最新版本不一致，请重试。"
            }
        }
    }

    private struct Record: Codable {
        let schema: Int
        let size: String
        let revision: UUID
        let updatedAt: Double
        let deleted: Bool
        let darkness: Double
        let jpeg: Data?
    }

    private struct Candidate {
        let record: Record
        let bytes: Data
        let image: UIImage?
    }

    private static let lock = NSLock()
    private static let defaultDarkness = 0.35
    private static let maxInputBytes = 50 * 1024 * 1024
    private static let maxJPEGBytes = 2 * 1024 * 1024
    private static let maxRecordBytes = 3 * 1024 * 1024
    private static let outputEdge = 1200
    private static let futureTolerance: Double = 300

    /// 图片与遮罩取自同一份快照，避免调用 image / darkness 时重复解码。
    static func appearance(for size: WidgetPhotoSize) -> (image: UIImage?, darkness: Double) {
        shared.appearance(for: size)
    }

    static func image(for size: WidgetPhotoSize) -> UIImage? {
        appearance(for: size).image
    }

    static func darkness(for size: WidgetPhotoSize) -> Double {
        appearance(for: size).darkness
    }

    /// 不可变依赖；测试仅传临时目录，不覆盖任何进程全局路径或时钟。
    struct Storage {
        let directories: [URL]
        let now: () -> Double

        init(directories: [URL], now: @escaping () -> Double = { Date().timeIntervalSince1970 }) {
            self.directories = directories
            self.now = now
        }

        func targets(for size: WidgetPhotoSize) -> [URL] {
            let name = "WidgetBackground-v1-\(size.rawValue).json"
            var seen = Set<String>()
            return directories.map { $0.appendingPathComponent(name) }.filter {
                seen.insert($0.standardizedFileURL.path).inserted
            }
        }

        func appearance(for size: WidgetPhotoSize) -> (image: UIImage?, darkness: Double) {
            WidgetBackgroundStore.locked {
                guard let candidate = WidgetBackgroundStore.newest(for: size, targets: targets(for: size), now: now()),
                      !candidate.record.deleted else { return (nil, WidgetBackgroundStore.defaultDarkness) }
                return (candidate.image, candidate.record.darkness)
            }
        }

        func save(imageData: Data, for size: WidgetPhotoSize, darkness: Double,
                  focalX: Double = 0.5, focalY: Double = 0.5) throws {
            let jpeg = try WidgetBackgroundStore.preparedJPEG(imageData, for: size, focalX: focalX, focalY: focalY)
            try WidgetBackgroundStore.locked {
                try WidgetBackgroundStore.publish(jpeg: jpeg, for: size,
                    darkness: WidgetBackgroundStore.unit(darkness, fallback: WidgetBackgroundStore.defaultDarkness),
                    targets: targets(for: size), now: now())
            }
        }

        func reset(for size: WidgetPhotoSize) throws {
            try WidgetBackgroundStore.locked {
                try WidgetBackgroundStore.publish(jpeg: nil, for: size,
                    darkness: WidgetBackgroundStore.defaultDarkness,
                    targets: targets(for: size), now: now())
            }
        }
    }

    /// 焦点坐标相对于按 EXIF 方向旋正后的照片，原点位于左上角。
    /// 焦点及暗度夹在 0...1；非有限值分别退回 0.5 和 0.35。
    static func save(imageData: Data, for size: WidgetPhotoSize,
                     darkness: Double, focalX: Double = 0.5,
                     focalY: Double = 0.5) throws {
        try shared.save(imageData: imageData, for: size, darkness: darkness,
                        focalX: focalX, focalY: focalY)
    }

    /// 不删除文件：保留更新的墓碑，压住暂时不可写通道中的旧照片。
    static func reset(for size: WidgetPhotoSize) throws {
        try shared.reset(for: size)
    }

    private static func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private static func unit(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : fallback
    }

    private static var shared: Storage {
        var directories: [URL] = []
        if let container = WidgetFeedStore.containerURL {
            directories.append(container)
        }
        directories.append(URL(fileURLWithPath: WidgetFeedStore.fallbackDirectory,
                               isDirectory: true))
        return Storage(directories: directories)
    }

    private static func publish(jpeg: Data?, for size: WidgetPhotoSize,
                                darkness: Double, targets: [URL], now: Double) throws {
        let previous = newest(for: size, targets: targets, now: now)?.record.updatedAt ?? 0
        // 严格递增，支持同一时刻连续保存 / 重置及小幅系统时钟回拨。
        let timestamp = max(now, previous.nextUp)
        guard now.isFinite, now >= 0, timestamp.isFinite,
              timestamp <= now + futureTolerance else { throw StoreError.invalidClock }
        let record = Record(schema: 1, size: size.rawValue, revision: UUID(),
                            updatedAt: timestamp, deleted: jpeg == nil,
                            darkness: darkness, jpeg: jpeg)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let bytes = try encoder.encode(record)
        guard bytes.count <= maxRecordBytes else { throw StoreError.encodingFailed }
        var failures = [String]()
        var written = false
        for url in targets {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try bytes.write(to: url, options: .atomic)
                written = true
            } catch {
                failures.append("\(url.deletingLastPathComponent().path)：\(error.localizedDescription)")
            }
        }
        guard written else { throw StoreError.sharedWriteFailed(failures) }
        // 用实际读取路径验证选中的完整对象，不能把旧副本误报为成功。
        guard let selected = newest(for: size, targets: targets, now: now),
              selected.record.revision == record.revision,
              selected.bytes == bytes else { throw StoreError.verificationFailed }
    }

    /// 时间相同时保留 targets 的顺序（App Group 优先）。
    private static func newest(for size: WidgetPhotoSize, targets: [URL], now: Double) -> Candidate? {
        var selected: Candidate?
        for url in targets {
            guard let bytes = boundedRead(url),
                  let candidate = validated(bytes, for: size, now: now) else { continue }
            if let current = selected,
               current.record.updatedAt >= candidate.record.updatedAt { continue }
            selected = candidate
        }
        return selected
    }

    /// 限长读取本身也有上限，避免先把恶意或损坏的大文件全部加载到内存。
    private static func boundedRead(_ url: URL) -> Data? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, let size = values.fileSize,
              size > 0, size <= maxRecordBytes,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            var result = Data()
            while result.count <= maxRecordBytes {
                guard let chunk = try handle.read(upToCount: min(65536, maxRecordBytes + 1 - result.count)),
                      !chunk.isEmpty else { break }
                result.append(chunk)
            }
            guard !result.isEmpty, result.count <= maxRecordBytes else { return nil }
            return result
        } catch {
            return nil
        }
    }

    private static func validated(_ bytes: Data, for size: WidgetPhotoSize,
                                  now: Double) -> Candidate? {
        guard let record = try? JSONDecoder().decode(Record.self, from: bytes),
              record.schema == 1, record.size == size.rawValue,
              now.isFinite, record.updatedAt.isFinite, record.updatedAt >= 0,
              record.updatedAt <= now + futureTolerance,
              record.darkness.isFinite, (0...1).contains(record.darkness) else { return nil }
        if record.deleted {
            guard record.jpeg == nil else { return nil }
            return Candidate(record: record, bytes: bytes, image: nil)
        }
        guard let data = record.jpeg, !data.isEmpty, data.count <= maxJPEGBytes,
              let source = CGImageSourceCreateWithData(data as CFData,
                  [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetType(source) as String? == "public.jpeg",
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let dimensions = dimensions(properties),
              dimensions.width <= Double(outputEdge), dimensions.height <= Double(outputEdge)
        else { return nil }
        let expected = outputSize(for: size)
        guard dimensions.width == Double(expected.width),
              dimensions.height == Double(expected.height),
              ((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1) == 1,
              let decoded = thumbnail(source, maximum: outputEdge),
              decoded.width == Int(expected.width), decoded.height == Int(expected.height)
        else { return nil }
        return Candidate(record: record, bytes: bytes,
                         image: UIImage(cgImage: decoded, scale: 1, orientation: .up))
    }

    private static func dimensions(_ properties: [CFString: Any]) -> (width: Double, height: Double)? {
        guard let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width.isFinite, height.isFinite, width >= 1, height >= 1,
              width.rounded(.down) == width, height.rounded(.down) == height else { return nil }
        return (width, height)
    }

    /// 元数据门禁独立于像素分配，便于验证超大尺寸而无需构造巨型位图。
    static func validateInputDimensions(width: Double, height: Double) throws {
        guard width.isFinite, height.isFinite, width >= 1, height >= 1,
              width.rounded(.down) == width, height.rounded(.down) == height else {
            throw StoreError.invalidImage
        }
        guard width <= 32768, height <= 32768, width * height <= 100_000_000 else {
            throw StoreError.imageTooLarge
        }
    }

    private static func outputSize(for size: WidgetPhotoSize) -> CGSize {
        CGSize(width: CGFloat(outputEdge), height: (CGFloat(outputEdge) / size.aspectRatio).rounded())
    }

    private static func thumbnail(_ source: CGImageSource, maximum: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximum,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func preparedJPEG(_ data: Data, for size: WidgetPhotoSize,
                                     focalX: Double, focalY: Double) throws -> Data {
        guard !data.isEmpty else { throw StoreError.invalidImage }
        guard data.count <= maxInputBytes else { throw StoreError.imageTooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData,
                  [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let dimensions = dimensions(properties) else { throw StoreError.invalidImage }
        // ImageIO can recover a partial JPEG and still report the source as complete.
        // Require the JPEG end marker before allowing it to replace a saved background.
        if CGImageSourceGetType(source) as String? == "public.jpeg",
           data.range(of: Data([0xff, 0xd9]), options: .backwards) == nil {
            throw StoreError.invalidImage
        }
        try validateInputDimensions(width: dimensions.width, height: dimensions.height)
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        guard (1...8).contains(orientation) else { throw StoreError.invalidImage }
        let swapsAxes = (5...8).contains(orientation)
        let width = swapsAxes ? dimensions.height : dimensions.width
        let height = swapsAxes ? dimensions.width : dimensions.height
        let target = outputSize(for: size)
        let fillScale = max(Double(target.width) / width, Double(target.height) / height)
        // 解码器先按 EXIF 旋正并降采样；极端长宽比也最多解码 2400 像素长边。
        // 小图/细长图可能需要放大，但不会为填满裁剪框解码完整原图。
        let maximum = Int(min(2400, max(1, ceil(max(width, height) * min(1, fillScale)))))
        guard let decoded = thumbnail(source, maximum: maximum) else {
            throw StoreError.invalidImage
        }
        let image = UIImage(cgImage: decoded, scale: 1, orientation: .up)
        let scale = max(target.width / image.size.width, target.height / image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let x = max(0, min(drawn.width - target.width,
                           CGFloat(unit(focalX, fallback: 0.5)) * drawn.width - target.width / 2))
        let y = max(0, min(drawn.height - target.height,
                           CGFloat(unit(focalY, fallback: 0.5)) * drawn.height - target.height / 2))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let cropped = UIGraphicsImageRenderer(size: target, format: format).image { context in
            // JPEG 不支持透明度；透明照片固定铺黑底，避免未定义底色。
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(x: -x, y: -y, width: drawn.width, height: drawn.height))
        }
        for quality: CGFloat in [0.88, 0.75, 0.6, 0.45] {
            if let jpeg = cropped.jpegData(compressionQuality: quality), jpeg.count <= maxJPEGBytes {
                return jpeg
            }
        }
        throw StoreError.encodingFailed
    }
}
#endif
