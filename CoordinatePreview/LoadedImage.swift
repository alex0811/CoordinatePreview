import AppKit
import ImageIO

struct LoadedImage {
    let image: NSImage
    let pixelSize: CGSize

    init(contentsOf url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoadingError.unreadableFile
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let sourceWidth = properties?[kCGImagePropertyPixelWidth] as? NSNumber
        let sourceHeight = properties?[kCGImagePropertyPixelHeight] as? NSNumber
        let maximumDimension = max(sourceWidth?.intValue ?? 0, sourceHeight?.intValue ?? 0)

        guard maximumDimension > 0 else {
            throw ImageLoadingError.missingDimensions
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let decodedImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw ImageLoadingError.decodingFailed
        }

        pixelSize = CGSize(width: decodedImage.width, height: decodedImage.height)
        image = NSImage(cgImage: decodedImage, size: pixelSize)
    }
}

enum ImageLoadingError: LocalizedError {
    case unreadableFile
    case missingDimensions
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "文件不是受支持的图片，或当前进程没有读取权限。"
        case .missingDimensions:
            "无法读取图片尺寸。"
        case .decodingFailed:
            "图片数据解码失败。"
        }
    }
}

