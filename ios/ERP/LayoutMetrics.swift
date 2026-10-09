import Foundation

/// Use the available window or content width, never the physical screen size.
struct LayoutMetrics: Equatable {
    let width: CGFloat

    func sidebarWidth(isPad: Bool, accessibility: Bool = false) -> CGFloat {
        guard isPad, !accessibility, width >= 880 else { return 0 }
        return width >= 1100 ? 232 : 208
    }

    var pagePadding: CGFloat { width >= 700 ? 24 : width >= 400 ? 18 : 12 }
    var pageWidth: CGFloat { min(1060, max(0, width)) }
    var contentWidth: CGFloat { max(1, pageWidth - pagePadding * 2) }
    var discoveryPreview: Bool { contentWidth >= 720 }
    func showsDiscoveryPreview(viewportHeight: CGFloat) -> Bool { discoveryPreview && width > viewportHeight }
    var discoveryDeckWidth: CGFloat { discoveryPreview ? min(400, contentWidth * 0.43) : min(572, contentWidth) }
    func singleDiscoveryDeckWidth(viewportHeight: CGFloat) -> CGFloat {
        min(contentWidth, 560, max(260, (viewportHeight - 240) * 0.594))
    }
    var discoveryPreviewWidth: CGFloat { max(0, contentWidth - discoveryDeckWidth - 24) }
    /// The tablet web feed keeps two columns in portrait and landscape.
    var postColumns: Int { contentWidth >= 640 ? 2 : 1 }
    var browseColumns: Int { width >= 850 ? 4 : width >= 600 ? 3 : 2 }
    var postCardWidth: CGFloat { (contentWidth - CGFloat(postColumns - 1) * 16) / CGFloat(postColumns) }
    static func requiresPortrait(isPhone: Bool, width: CGFloat, height: CGFloat) -> Bool { isPhone && width > height }
    var stackedControls: Bool { contentWidth < 620 }

    func gridColumns(minimum: CGFloat, spacing: CGFloat = 16) -> Int {
        max(1, Int((contentWidth + spacing) / (minimum + spacing)))
    }

    /// Leave room for the title and actions in short landscape windows.
    func discoveryCardHeight(viewportHeight: CGFloat) -> CGFloat {
        max(280, min(viewportHeight - 170, contentWidth * 1.25, 680))
    }
}
