import SwiftUI
import Testing
@testable import traders_guild

/// Stage 5 accessibility: the selection pop and wiggle honour Reduce Motion
/// under the avatar prototype, and are exactly as shipped without it.
struct MarkerSelectionMotionTests {

    @Test
    func theLegacyChartKeepsItsMotionWhateverTheSetting() {
        for reduceMotion in [false, true] {
            #expect(MarkerSelectionMotion.pop(reduceMotion: reduceMotion, experimentEnabled: false)
                    == .spring(response: 0.5, dampingFraction: 0.7))
            #expect(MarkerSelectionMotion.settle(reduceMotion: reduceMotion, experimentEnabled: false)
                    == .easeOut(duration: 0.3))
            #expect(MarkerSelectionMotion.wiggles(reduceMotion: reduceMotion, experimentEnabled: false))
        }
    }

    @Test
    func thePrototypeHonoursReduceMotion() {
        #expect(MarkerSelectionMotion.pop(reduceMotion: true, experimentEnabled: true) == nil)
        #expect(MarkerSelectionMotion.settle(reduceMotion: true, experimentEnabled: true) == nil)
        #expect(!MarkerSelectionMotion.wiggles(reduceMotion: true, experimentEnabled: true))

        #expect(MarkerSelectionMotion.pop(reduceMotion: false, experimentEnabled: true)
                == .spring(response: 0.5, dampingFraction: 0.7))
        #expect(MarkerSelectionMotion.wiggles(reduceMotion: false, experimentEnabled: true))
    }
}
