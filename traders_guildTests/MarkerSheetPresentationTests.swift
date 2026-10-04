import SwiftUI
import UIKit
import Testing
@testable import traders_guild

@MainActor
struct MarkerSheetPresentationTests {
    private func surface(view: String = "Markers", add: Bool = true, marker: UUID? = nil,
                         placing: Bool = false, step: MarkerGuidedStep? = nil, experiment: Bool = true) -> MarkerSheetSurface {
        .resolve(experiment: experiment, placing: placing, step: step, intent: .analysis,
                 view: view, primaryAdd: add, viewedMarker: marker)
    }
    private func model() -> MarkerSheetPresentationModel {
        let model = MarkerSheetPresentationModel()
        model.setAvailableHeight(700)
        model.capture(.init(revision: "base", height: 230, width: 370), surface: .add, chrome: 110)
        return model
    }

    @Test(arguments: ["Symbol", "Chat", "Components"])
    func addCanLeaveForEveryRealTabAndReturn(_ tab: String) {
        let model = model()
        let add = model.policy(for: surface())
        let destination = model.policy(for: surface(view: tab))
        let selected = destination.normalized(add.working, from: add)
        #expect(destination.detents.contains(selected))
        #expect(selected == destination.working)
        let returned = add.normalized(selected, from: destination)
        #expect(returned == add.working)
        for userChoice in [add.compact, add.tall] {
            #expect(destination.normalized(userChoice, from: add) == userChoice)
            #expect(add.normalized(userChoice, from: destination) == userChoice)
        }
    }

    @Test
    func selectionAndClearingWhileAddIsCurrentUseSupportedStates() {
        let model = model()
        let add = model.policy(for: surface())
        let viewed = model.policy(for: surface(marker: UUID()))
        #expect(viewed.surface != add.surface)
        let selected = viewed.normalized(add.working, from: add)
        #expect(viewed.detents.contains(selected))
        #expect(add.detents.contains(add.normalized(selected, from: viewed)))
        for userChoice in [add.compact, add.tall] {
            #expect(viewed.normalized(userChoice, from: add) == userChoice)
            #expect(add.normalized(userChoice, from: viewed) == userChoice)
        }
    }

    @Test
    func guidedOtherExitAndEndPlacementKeepTheDockAndTallChoice() {
        let model = model()
        let guided = model.policy(for: surface(placing: true, step: .details))
        let other = model.policy(for: surface(placing: true))
        let add = model.policy(for: surface())
        let otherWorking = other.normalized(guided.working, from: guided)
        #expect(other.detents.contains(otherWorking))
        #expect(add.detents.contains(add.normalized(otherWorking, from: other)))
        #expect(other.normalized(guided.compact, from: guided) == other.compact)
        #expect(add.normalized(other.compact, from: other) == add.compact)
        #expect(other.normalized(guided.tall, from: guided) == guided.tall)
        #expect(add.normalized(guided.tall, from: guided) == guided.tall)
    }

    @Test
    func measuredFitUsesContainerBoundsAndFreezesAcrossTyping() {
        let model = model()
        let compose = surface(placing: true, step: .details)
        model.capture(.init(revision: "title-closed", height: 220, width: 370), surface: compose, chrome: 100)
        let first = model.policy(for: compose)
        model.capture(.init(revision: "title-closed", height: 430, width: 370), surface: compose, chrome: 100)
        #expect(model.policy(for: compose) == first, "typing does not resize the working state")
        model.capture(.init(revision: "title-open", height: 270, width: 370), surface: compose, chrome: 100)
        let titled = model.policy(for: compose)
        #expect(titled.workingHeight > first.workingHeight)
        #expect(titled.normalized(first.working, from: first) == titled.working)
        model.setAvailableHeight(300)
        let smaller = model.policy(for: compose)
        #expect(smaller.workingHeight <= 300 * 0.9)
        #expect(smaller.detents.contains(smaller.normalized(titled.working, from: titled)))
        #expect(smaller.normalized(titled.tall, from: titled) == titled.tall)
    }

    @Test
    func newDraftDiscardsGuidedMeasurementsButKeepsAddFit() {
        let model = model()
        let compose = surface(placing: true, step: .details)
        model.capture(.init(revision: "long", height: 490, width: 370), surface: compose, chrome: 100)
        let add = model.policy(for: surface())
        model.resetGuidedCaptures()
        #expect(model.policy(for: surface()) == add)
        #expect(model.contentHeights[compose.measurementID] == nil)
    }

    @Test
    func experimentOffKeepsTheEstablishedDetentsRegardlessOfRoute() {
        let model = model()
        for route in [surface(experiment: false), surface(view: "Chat", experiment: false),
                      surface(placing: true, step: .details, experiment: false)] {
            let policy = model.policy(for: route)
            #expect(policy.detents == [.fraction(0.11), .fraction(0.35), .fraction(0.5), .fraction(0.9)])
            for detent in policy.detents { #expect(policy.normalized(detent, from: nil) == detent) }
        }
    }
    @Test
    func keyboardRestrictsNativeDetentsWithinOneWindowWithoutResizingOnTyping() {
        let model = model()
        let compose = surface(placing: true, step: .details)
        let original = model.policy(for: compose)
        var geometry = MarkerSheetGeometry(keyboardFrame: CGRect(x: 0, y: 529, width: 402, height: 345),
                               windowFrame: CGRect(x: 0, y: 0, width: 402, height: 874),
                               safeAreaInsets: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0))
        model.updateGeometry(geometry, selection: original.tall)
        let focused = model.policy(for: compose)
        #expect(focused.keyboardConstrained)
        #expect(focused.keyboardRestoreSelection == original.tall)
        model.updateGeometry(geometry, selection: focused.working)
        #expect(model.policy(for: compose).keyboardRestoreSelection == original.tall, "native selection replacement cannot overwrite the prior choice")
        #expect(focused.detents == [focused.working])
        #expect(focused.workingHeight <= 421)
        #expect(focused.normalized(original.tall, from: original) == focused.working)
        #expect(!model.policy(for: surface(view: "Chat")).keyboardConstrained)
        geometry.keyboardFrame = CGRect(x: 80, y: 400, width: 220, height: 200)
        model.updateGeometry(geometry, selection: focused.working)
        #expect(!model.policy(for: compose).keyboardConstrained, "floating keyboards do not shrink the whole viewport")
        geometry.keyboardFrame = .zero
        model.updateGeometry(geometry, selection: original.tall)
        #expect(model.policy(for: compose) == original)
    }

    @Test
    func nestedWorkspaceRoutesRestoreTheirOwnMeasuredHeight() {
        let model = model()
        let context = MarkerSheetSurface.workspace(.context, .analysis)
        let settings = MarkerSheetSurface.workspace(.indicatorSettings, .analysis)
        model.capture(.init(revision: "context", height: 200, width: 370), surface: context, chrome: 156)
        let before = model.policy(for: context)
        model.capture(.init(revision: "settings", height: 420, width: 370), surface: settings, chrome: 156)
        #expect(model.policy(for: settings).workingHeight != before.workingHeight)
        #expect(model.policy(for: context) == before)
        #expect(model.policy(for: settings).compact == .fraction(0.18))
    }

}
