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

        let first = Task {
            try await singleFlight.run {
                _ = await counter.increment()
                try await Task.sleep(nanoseconds: 100_000_000)
                return 42
            }
        }
        while await counter.value() == 0 {
            await Task.yield()
        }

        let second = Task {
            try await singleFlight.run {
                _ = await counter.increment()
                return 99
            }
        }

        let resolvedFirst = try await first.value
        let resolvedSecond = try await second.value

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
