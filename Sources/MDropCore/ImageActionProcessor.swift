import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

struct ImageActionProcessor: Sendable {
    func run(
        _ action: BuiltinActionID,
        request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        switch action {
        case .resizeImages:
            return try resize(request, progress: progress)
        case .convertImages:
            return try convert(request, progress: progress)
        case .compressImages:
            return try compress(request, progress: progress)
        case .removeImageMetadata:
            return try removeMetadata(request, progress: progress)
        case .stitchImages:
            return try stitch(request)
        case .extractText:
            return try extractText(request, progress: progress)
        case .createPDF:
            return try createPDF(request)
        default:
            throw ActionExecutionError.unsupportedAction(action)
        }
    }

    private func resize(
        _ request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        let urls = try imageURLs(request)
        let directory = try outputDirectory(request, sourceURLs: urls)
        let maxWidth = request.parameters.integer("width") ?? 1600
        let maxHeight = request.parameters.integer("height") ?? 1600
        var outputs: [URL] = []

        for (index, url) in urls.enumerated() {
            let image = try loadImage(url)
            let scale = min(
                CGFloat(maxWidth) / CGFloat(image.width),
                CGFloat(maxHeight) / CGFloat(image.height)
            )
            let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
            let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
            let resized = try draw(width: width, height: height) { context in
                context.interpolationQuality = .high
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            let destination = uniqueURL(
                directory.appending(path: "\(url.deletingPathExtension().lastPathComponent)-resized.png")
            )
            try write(resized, to: destination, type: .png)
            outputs.append(destination)
            progress(Double(index + 1) / Double(urls.count))
        }
        return ActionResult(createdFiles: outputs)
    }

    private func convert(
        _ request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        let urls = try imageURLs(request)
        let directory = try outputDirectory(request, sourceURLs: urls)
        let format = (request.parameters.string("format") ?? "png").lowercased()
        let (type, pathExtension) = imageType(for: format)
        var outputs: [URL] = []

        for (index, url) in urls.enumerated() {
            let destination = uniqueURL(
                directory.appending(path: "\(url.deletingPathExtension().lastPathComponent).\(pathExtension)")
            )
            try write(loadImage(url), to: destination, type: type)
            outputs.append(destination)
            progress(Double(index + 1) / Double(urls.count))
        }
        return ActionResult(createdFiles: outputs)
    }

    private func compress(
        _ request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        let urls = try imageURLs(request)
        let directory = try outputDirectory(request, sourceURLs: urls)
        let quality = request.parameters.double("quality") ?? 0.72
        var outputs: [URL] = []

        for (index, url) in urls.enumerated() {
            let destination = uniqueURL(
                directory.appending(path: "\(url.deletingPathExtension().lastPathComponent)-compressed.jpg")
            )
            try write(loadImage(url), to: destination, type: .jpeg, quality: quality)
            outputs.append(destination)
            progress(Double(index + 1) / Double(urls.count))
        }
        return ActionResult(createdFiles: outputs)
    }

    private func removeMetadata(
        _ request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        let urls = try imageURLs(request)
        let directory = try outputDirectory(request, sourceURLs: urls)
        var outputs: [URL] = []

        for (index, url) in urls.enumerated() {
            let destination = uniqueURL(
                directory.appending(path: "\(url.deletingPathExtension().lastPathComponent)-clean.png")
            )
            try write(loadImage(url), to: destination, type: .png)
            outputs.append(destination)
            progress(Double(index + 1) / Double(urls.count))
        }
        return ActionResult(createdFiles: outputs)
    }

    private func stitch(_ request: ActionRequest) throws -> ActionResult {
        let urls = try imageURLs(request)
        guard urls.count >= 2 else {
            throw ActionExecutionError.noCompatibleItems
        }
        let images = try urls.map(loadImage)
        let horizontal = request.parameters.string("direction") == "horizontal"
        let width = horizontal ? images.reduce(0) { $0 + $1.width } : images.map(\.width).max()!
        let height = horizontal ? images.map(\.height).max()! : images.reduce(0) { $0 + $1.height }
        let stitched = try draw(width: width, height: height) { context in
            var offset = 0
            for image in images {
                let rect = horizontal
                    ? CGRect(x: offset, y: 0, width: image.width, height: image.height)
                    : CGRect(x: 0, y: height - offset - image.height, width: image.width, height: image.height)
                context.draw(image, in: rect)
                offset += horizontal ? image.width : image.height
            }
        }
        let directory = try outputDirectory(request, sourceURLs: urls)
        let destination = uniqueURL(directory.appending(path: "Stitched.png"))
        try write(stitched, to: destination, type: .png)
        return ActionResult(createdFiles: [destination])
    }

    private func extractText(
        _ request: ActionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ActionResult {
        let urls = try imageURLs(request)
        var results: [String] = []

        for (index, url) in urls.enumerated() {
            let image = try loadImage(url)
            let recognition = VNRecognizeTextRequest()
            recognition.recognitionLevel = .accurate
            recognition.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: image).perform([recognition])
            let text = (recognition.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            if !text.isEmpty {
                results.append(text)
            }
            progress(Double(index + 1) / Double(urls.count))
        }
        guard !results.isEmpty else {
            throw ActionExecutionError.noCompatibleItems
        }
        return ActionResult(clipboardText: results.joined(separator: "\n\n"))
    }

    private func createPDF(_ request: ActionRequest) throws -> ActionResult {
        let urls = try imageURLs(request)
        let directory = try outputDirectory(request, sourceURLs: urls)
        let document = PDFDocument()
        for (index, url) in urls.enumerated() {
            guard let image = NSImage(contentsOf: url),
                  let page = PDFPage(image: image) else {
                throw ActionExecutionError.noCompatibleItems
            }
            document.insert(page, at: index)
        }
        let destination = uniqueURL(directory.appending(path: "Images.pdf"))
        guard document.write(to: destination) else {
            throw ActionExecutionError.commandFailed("Unable to create PDF.")
        }
        return ActionResult(createdFiles: [destination])
    }

    private func imageURLs(_ request: ActionRequest) throws -> [URL] {
        let urls = request.items.compactMap(\.fileURL)
        guard urls.count == request.items.count, !urls.isEmpty else {
            throw ActionExecutionError.noCompatibleItems
        }
        return urls
    }

    private func outputDirectory(
        _ request: ActionRequest,
        sourceURLs: [URL]
    ) throws -> URL {
        let directory: URL
        if case let .url(value)? = request.parameters["destination"] {
            directory = value
        } else {
            directory = sourceURLs[0]
                .deletingLastPathComponent()
                .appending(path: "MDrop Output", directoryHint: .isDirectory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func loadImage(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ActionExecutionError.noCompatibleItems
        }
        return image
    }

    private func draw(
        width: Int,
        height: Int,
        drawing: (CGContext) -> Void
    ) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ActionExecutionError.commandFailed("Unable to create image context.")
        }
        drawing(context)
        guard let image = context.makeImage() else {
            throw ActionExecutionError.commandFailed("Unable to render image.")
        }
        return image
    }

    private func write(
        _ image: CGImage,
        to url: URL,
        type: UTType,
        quality: Double? = nil
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw ActionExecutionError.commandFailed("Unable to create image destination.")
        }
        var properties: [CFString: Any] = [:]
        if let quality {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ActionExecutionError.commandFailed("Unable to write image.")
        }
    }

    private func imageType(for format: String) -> (UTType, String) {
        switch format {
        case "jpg", "jpeg":
            (.jpeg, "jpg")
        case "heic", "heif":
            (.heic, "heic")
        case "tif", "tiff":
            (.tiff, "tiff")
        default:
            (.png, "png")
        }
    }

    private func uniqueURL(_ preferred: URL) -> URL {
        guard FileManager.default.fileExists(atPath: preferred.path) else {
            return preferred
        }
        let pathExtension = preferred.pathExtension
        let stem = preferred.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidate = preferred.deletingLastPathComponent()
                .appending(path: "\(stem) \(index).\(pathExtension)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}

private extension Dictionary where Key == String, Value == ActionParameterValue {
    func string(_ key: String) -> String? {
        guard case let .string(value)? = self[key] else { return nil }
        return value
    }

    func integer(_ key: String) -> Int? {
        guard case let .integer(value)? = self[key] else { return nil }
        return value
    }

    func double(_ key: String) -> Double? {
        guard case let .double(value)? = self[key] else { return nil }
        return value
    }
}
