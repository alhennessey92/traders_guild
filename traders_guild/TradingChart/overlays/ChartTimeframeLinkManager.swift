import Foundation
import Combine

@MainActor
final class ChartTimeframeLinkManager: ObservableObject {
    @Published private(set) var linkedTimeframes: [String] = []

    var symbolId: UUID? {
        didSet {
            guard oldValue != symbolId else { return }
            load()
        }
    }

    private let maxLinks = 2

    func load() {
        guard let storageKey else {
            linkedTimeframes = []
            return
        }

        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            linkedTimeframes = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([String].self, from: data)
            linkedTimeframes = normalized(decoded)
        } catch {
            linkedTimeframes = []
        }
    }

    func setLinkedTimeframes(_ values: [String]) {
        linkedTimeframes = normalized(values)
        save()
    }

    func upsert(_ backendTimeframe: String) -> Bool {
        let normalizedValue = backendTimeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedValue.isEmpty else { return false }

        if linkedTimeframes.contains(normalizedValue) {
            return true
        }
        guard linkedTimeframes.count < maxLinks else {
            return false
        }

        linkedTimeframes.append(normalizedValue)
        linkedTimeframes = normalized(linkedTimeframes)
        save()
        return true
    }

    func remove(_ backendTimeframe: String) {
        let normalizedValue = backendTimeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        linkedTimeframes.removeAll { $0 == normalizedValue }
        save()
    }

    func isLinked(_ backendTimeframe: String) -> Bool {
        let normalizedValue = backendTimeframe.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return linkedTimeframes.contains(normalizedValue)
    }

    private func normalized(_ values: [String]) -> [String] {
        var seen = Set<String>()
        let deduped = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .filter { value in
                if seen.contains(value) {
                    return false
                }
                seen.insert(value)
                return true
            }
            .prefix(maxLinks)

        return Array(deduped).sorted { lhs, rhs in
            timeframeOrderIndex(lhs) < timeframeOrderIndex(rhs)
        }
    }

    private func timeframeOrderIndex(_ backendTimeframe: String) -> Int {
        guard let timeframe = RLChartTimeframe.fromBackendString(backendTimeframe),
              let index = RLChartTimeframe.allCases.firstIndex(of: timeframe) else {
            return Int.max
        }
        return index
    }

    private var storageKey: String? {
        guard let symbolId else { return nil }
        return "chartTimeframes_\(symbolId.uuidString.lowercased())"
    }

    private func save() {
        guard let storageKey else { return }

        do {
            let data = try JSONEncoder().encode(linkedTimeframes)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Keep in-memory state if persistence fails.
        }
    }
}
