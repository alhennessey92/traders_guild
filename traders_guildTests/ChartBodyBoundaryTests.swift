import SwiftUI
import Testing
@testable import traders_guild

@MainActor
struct ChartBodyBoundaryTests {
    @Test
    func constructingTheParentDoesNotBuildTheChartSubtree() {
        var evaluations = 0
        let boundary = ChartBodyBoundary {
            evaluations += 1
            return Text("Chart")
        }

        #expect(evaluations == 0)
        _ = boundary.body
        #expect(evaluations == 1)
    }

    @Test
    func bodyReevaluationDoesNotReuseAnOldSubtree() {
        var version = 1
        var renderedVersions: [Int] = []
        let boundary = ChartBodyBoundary {
            renderedVersions.append(version)
            return Text("Chart \(version)")
        }

        _ = boundary.body
        version = 2
        _ = boundary.body
        #expect(renderedVersions == [1, 2])
    }

    @Test
    func parentStorageDoesNotIncludeTheLargeViewValue() {
        // A chart subtree's inline value can be very large in an -Onone
        // build. Its parent must carry only the builder, regardless of size.
        #expect(MemoryLayout<LargeChartSubtree>.size > 1_000)
        #expect(MemoryLayout<ChartBodyBoundary<LargeChartSubtree>>.size
                == MemoryLayout<ChartBodyBoundary<Text>>.size)
        #expect(MemoryLayout<ChartBodyBoundary<LargeChartSubtree>>.size < 64)
    }
}

private struct LargeChartSubtree: View {
    let data: (SIMD64<Double>, SIMD64<Double>, SIMD64<Double>, SIMD64<Double>)
    var body: some View { Color.clear }
}
