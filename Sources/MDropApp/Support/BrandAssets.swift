import AppKit

enum BrandAssets {
    static func menuBarImage(
        bundle: Bundle = .main
    ) -> NSImage? {
        guard let url = bundle.url(
            forResource: "MDropMenuBarTemplate",
            withExtension: "pdf"
        ),
        let image = NSImage(contentsOf: url)
        else { return nil }

        return asMenuBarTemplate(image)
    }

    static func applicationIcon(
        bundle: Bundle = .main
    ) -> NSImage? {
        guard let url = bundle.url(
            forResource: "AppIcon",
            withExtension: "icns"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }

    static func asMenuBarTemplate(
        _ image: NSImage
    ) -> NSImage {
        image.isTemplate = true
        return image
    }
}
