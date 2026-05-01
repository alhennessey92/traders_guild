import Foundation
import Testing
@testable import traders_guild

private actor RefreshInvocationCounter {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }

    func value() -> Int {
        count
    }
}

struct AuthSessionRefreshTests {
    @Test
    func asyncSingleFlightCoalescesConcurrentRefreshWork() async throws {
        let singleFlight = AsyncSingleFlight<Int>()
        let counter = RefreshInvocationCounter()

        async let first: Int = singleFlight.run {
            _ = await counter.increment()
            try await Task.sleep(nanoseconds: 50_000_000)
            return 42
        }

        async let second: Int = singleFlight.run {
            _ = await counter.increment()
            return 99
        }

        let resolvedFirst = try await first
        let resolvedSecond = try await second

        #expect(resolvedFirst == 42)
        #expect(resolvedSecond == 42)
        #expect(await counter.value() == 1)
    }

    @Test
    func asyncSingleFlightAllowsFreshWorkAfterCompletion() async throws {
        let singleFlight = AsyncSingleFlight<Int>()
        let counter = RefreshInvocationCounter()

        let first = try await singleFlight.run {
            await counter.increment()
        }
        let second = try await singleFlight.run {
            await counter.increment()
        }

        #expect(first == 1)
        #expect(second == 2)
        #expect(await counter.value() == 2)
    }
}
