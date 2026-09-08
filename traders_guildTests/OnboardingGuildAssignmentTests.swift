import Foundation
import Testing
@testable import traders_guild

struct OnboardingGuildAssignmentTests {
    private enum TestFailure: Error {
        case responseLost
    }

    @MainActor
    @Test func successfulAssignmentDoesNotRunRecovery() async throws {
        var recoveryCalls = 0

        let guild: String = try await OnboardingGuildAssignmentResolver.resolve(
            assignment: { "System 1" },
            recovery: {
                recoveryCalls += 1
                return "Recovered"
            }
        )

        #expect(guild == "System 1")
        #expect(recoveryCalls == 0)
    }

    @MainActor
    @Test func committedMembershipRecoversALostAssignmentResponse() async throws {
        var recoveryCalls = 0

        let guild: String = try await OnboardingGuildAssignmentResolver.resolve(
            assignment: { throw TestFailure.responseLost },
            recovery: {
                recoveryCalls += 1
                return "System 1"
            }
        )

        #expect(guild == "System 1")
        #expect(recoveryCalls == 1)
    }

    @MainActor
    @Test func genuineAssignmentFailureStillReachesTheInlineRetryState() async {
        do {
            let _: String = try await OnboardingGuildAssignmentResolver.resolve(
                assignment: { throw TestFailure.responseLost },
                recovery: { nil }
            )
            Issue.record("Expected assignment failure")
        } catch TestFailure.responseLost {
            // The caller presents its inline retry state only after recovery fails.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @MainActor
    @Test func cancellationDoesNotTriggerNetworkRecovery() async {
        var recoveryCalls = 0

        do {
            let _: String = try await OnboardingGuildAssignmentResolver.resolve(
                assignment: { throw CancellationError() },
                recovery: {
                    recoveryCalls += 1
                    return "System 1"
                }
            )
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(recoveryCalls == 0)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
