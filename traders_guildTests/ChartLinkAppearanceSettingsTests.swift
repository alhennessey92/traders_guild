import Foundation
import Testing
@testable import traders_guild

/// The persisted connector appearance settings.
@MainActor
struct ChartLinkAppearanceSettingsTests {

    private func fresh() -> ChartSettings {
        // Start from no stored values so each test sees the defaults.
        UserDefaults.standard.removeObject(forKey: "chartLinkLineWidth")
        UserDefaults.standard.removeObject(forKey: "chartLinkCurvature")
        return ChartSettings()
    }

    @Test
    func defaultsAreTheTunedGeometry() {
        let settings = fresh()
        #expect(settings.linkLineWidth == 1.5, "matches the stack spine it sits beside")
        #expect(settings.linkCurvature == 1.0, "the geometry as tuned")
        #expect(ChartSettings.linkCurvatureRange == MarkerLinkGeometry.curvatureRange,
                "one range, owned by the geometry")
    }

    @Test
    func valuesPersistAndReload() {
        let settings = fresh()
        settings.linkLineWidth = 2.25
        settings.linkCurvature = 1.3

        let reloaded = ChartSettings()
        #expect(reloaded.linkLineWidth == 2.25)
        #expect(reloaded.linkCurvature == 1.3)
    }

    /// A value outside the range — from a slider bug, a future build with
    /// wider bounds, or a hand-edited plist — must never reach the geometry.
    @Test
    func outOfRangeValuesAreClampedOnSetAndOnLoad() {
        let settings = fresh()
        settings.linkLineWidth = 12
        #expect(settings.linkLineWidth == ChartSettings.linkLineWidthRange.upperBound)
        settings.linkCurvature = 0.01
        #expect(settings.linkCurvature == ChartSettings.linkCurvatureRange.lowerBound)

        UserDefaults.standard.set(-4.0, forKey: "chartLinkLineWidth")
        UserDefaults.standard.set(9.0, forKey: "chartLinkCurvature")
        let reloaded = ChartSettings()
        #expect(reloaded.linkLineWidth == ChartSettings.linkLineWidthRange.lowerBound)
        #expect(reloaded.linkCurvature == ChartSettings.linkCurvatureRange.upperBound)

        settings.linkLineWidth = .nan
        #expect(settings.linkLineWidth.isFinite)
    }

    @Test
    func resetRestoresBothDefaults() {
        let settings = fresh()
        settings.linkLineWidth = 3
        settings.linkCurvature = 0.6
        settings.resetLinkAppearance()
        #expect(settings.linkLineWidth == ChartSettings.defaultLinkLineWidth)
        #expect(settings.linkCurvature == ChartSettings.defaultLinkCurvature)
    }

    /// The render context picks the persisted values up by default, which is
    /// what lets the chart follow the slider without a call-site change.
    @Test
    func renderContextDefaultsToThePersistedValues() {
        let shared = ChartSettings.shared
        let previousWidth = shared.linkLineWidth
        let previousCurvature = shared.linkCurvature
        defer {
            shared.linkLineWidth = previousWidth
            shared.linkCurvature = previousCurvature
        }
        shared.linkLineWidth = 2.5
        shared.linkCurvature = 0.8
        let context = MarkerLinkRenderContext(
            focus: .standalone(selectedId: UUID()), ringStyles: [:], revealProgress: 1,
            plotRect: CGRect(x: 0, y: 0, width: 400, height: 800)
        )
        #expect(context.lineWidth == 2.5)
        #expect(context.curvature == 0.8)
    }
}
