import XCTest
#if !LAYOUT_CHECK
@testable import ERP
#endif

final class LayoutMetricsTests: XCTestCase {
    func testPostFeedMatchesTabletPortraitAndNarrowWindows() {
        for width in [CGFloat(320), 390, 507] { XCTAssertEqual(LayoutMetrics(width: width).postColumns, 1) }
        for width in [CGFloat(744), 834, 978, 1366] {
            let layout = LayoutMetrics(width: width)
            XCTAssertEqual(layout.postColumns, 2)
            XCTAssertEqual(layout.postCardWidth * 2 + 16, layout.contentWidth, accuracy: 0.001)
        }
    }
    func testTabletSingleDiscoveryCardMatchesWebsiteProportions() {
        XCTAssertEqual(LayoutMetrics(width: 834).singleDiscoveryDeckWidth(viewportHeight: 1000), 451.44, accuracy: 0.001)
        XCTAssertEqual(LayoutMetrics(width: 744).singleDiscoveryDeckWidth(viewportHeight: 500), 260)
        for width in stride(from: CGFloat(280), through: 1600, by: 1) {
            let layout = LayoutMetrics(width: width)
            XCTAssertLessThanOrEqual(layout.singleDiscoveryDeckWidth(viewportHeight: 1000), layout.contentWidth)
            XCTAssertLessThanOrEqual(layout.singleDiscoveryDeckWidth(viewportHeight: 1000), 560)
            XCTAssertLessThanOrEqual(layout.singleDiscoveryDeckWidth(viewportHeight: 1000) * 4.3 / 3 + 200, 1000)
        }
    }
    func testOnlyPhoneLandscapeRequiresPortrait() {
        XCTAssertTrue(LayoutMetrics.requiresPortrait(isPhone: true, width: 844, height: 390))
        XCTAssertFalse(LayoutMetrics.requiresPortrait(isPhone: true, width: 390, height: 844))
        XCTAssertFalse(LayoutMetrics.requiresPortrait(isPhone: false, width: 1194, height: 834))
    }
    func testNavigationLeavesUsableContentSpace() {
        XCTAssertEqual(LayoutMetrics(width: 744).sidebarWidth(isPad: true), 0)
        XCTAssertEqual(LayoutMetrics(width: 879).sidebarWidth(isPad: true), 0)
        XCTAssertEqual(LayoutMetrics(width: 880).sidebarWidth(isPad: true), 208)
        XCTAssertEqual(LayoutMetrics(width: 1366).sidebarWidth(isPad: true), 232)
        XCTAssertEqual(LayoutMetrics(width: 1366).sidebarWidth(isPad: false), 0)
        XCTAssertEqual(LayoutMetrics(width: 1366).sidebarWidth(isPad: true, accessibility: true), 0)
    }

    func testRepresentativeWindows() {
        // iPhone, narrow iPad Split View, half-screen iPad, full landscape iPad.
        let windows: [(CGFloat, Int, Bool)] = [(320, 1, true), (507, 1, true), (744, 2, false), (1366, 3, false)]
        for (width, columns, stacked) in windows {
            let window = LayoutMetrics(width: width)
            let sidebar = window.sidebarWidth(isPad: true)
            let page = LayoutMetrics(width: width - sidebar - (sidebar > 0 ? 1 : 0))
            XCTAssertEqual(page.gridColumns(minimum: 290), columns, "window \(width)")
            XCTAssertEqual(page.stackedControls, stacked, "window \(width)")
        }
    }

    func testContinuousResizingNeverOverflowsColumns() {
        XCTAssertEqual(LayoutMetrics(width: 390).browseColumns, 2)
        XCTAssertEqual(LayoutMetrics(width: 834).browseColumns, 3)
        XCTAssertEqual(LayoutMetrics(width: 962).browseColumns, 4)
        for width in stride(from: CGFloat(280), through: 1600, by: 1) {
            let window = LayoutMetrics(width: width)
            let sidebar = window.sidebarWidth(isPad: true)
            let page = LayoutMetrics(width: width - sidebar - (sidebar > 0 ? 1 : 0))
            XCTAssertTrue((2...4).contains(page.browseColumns))
            XCTAssertGreaterThan((page.contentWidth - CGFloat(page.browseColumns - 1) * 14) / CGFloat(page.browseColumns), 110)
            for minimum in [CGFloat(190), 290, 310] {
                let count = page.gridColumns(minimum: minimum)
                let cardWidth = (page.contentWidth - CGFloat(count - 1) * 16) / CGFloat(count)
                XCTAssertGreaterThan(cardWidth, 0, "window \(width)")
                if count > 1 { XCTAssertGreaterThanOrEqual(cardWidth, minimum, "window \(width)") }
            }
        }
    }

    func testShortLandscapeCardAndWidePageLimits() {
        XCTAssertEqual(LayoutMetrics(width: 1024).discoveryCardHeight(viewportHeight: 500), 330)
        XCTAssertEqual(LayoutMetrics(width: 320).discoveryCardHeight(viewportHeight: 250), 280)
        XCTAssertLessThanOrEqual(LayoutMetrics(width: 1800).discoveryCardHeight(viewportHeight: 1400), 680)
        XCTAssertEqual(LayoutMetrics(width: 1800).pageWidth, 1060)
    }
    func testDiscoveryPreviewFitsDuringContinuousWindowResize() {
        XCTAssertFalse(LayoutMetrics(width: 834).showsDiscoveryPreview(viewportHeight: 1100))
        XCTAssertTrue(LayoutMetrics(width: 978).showsDiscoveryPreview(viewportHeight: 700))
        XCTAssertFalse(LayoutMetrics(width: 507).showsDiscoveryPreview(viewportHeight: 700))
        for width in stride(from: CGFloat(280), through: 1600, by: 1) {
            let page = LayoutMetrics(width: width)
            if page.discoveryPreview {
                XCTAssertGreaterThanOrEqual(page.discoveryDeckWidth, 300)
                XCTAssertGreaterThanOrEqual(page.discoveryPreviewWidth, 380)
                XCTAssertEqual(page.discoveryDeckWidth + 24 + page.discoveryPreviewWidth, page.contentWidth, accuracy: 0.001)
            } else { XCTAssertLessThanOrEqual(page.discoveryDeckWidth, page.contentWidth) }
        }
    }

}
