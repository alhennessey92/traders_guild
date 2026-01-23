// =====================================================================================
// GUILD STATISTICS INTEGRATION - iOS Updates
// =====================================================================================
//
// Backend endpoint: GET /guilds/{guild_id}/statistics
// Returns: GuildStatisticsResponse (matches guild.py schema)
//
// Pattern: Same as announcements/events - cached in LeftDrawerViewModel, fetched via rlAppState
// =====================================================================================


// =====================================================================================
// 1. CoreDTOS.swift - REPLACE RLGuildStatisticsResponse (around line 320)
// =====================================================================================
// Delete the old RLGuildStatisticsDTO (line 313-317) - it's unused
// Replace RLGuildStatisticsResponse with this version that has display computed properties:

/// Guild Statistics Response - matches backend GuildStatisticsResponse exactly
/// Fetched from: GET /guilds/{guild_id}/statistics
struct RLGuildStatisticsResponse: Codable {
    let totalPredictions: Int           // backend: total_predictions
    let correctPredictions: Int         // backend: correct_predictions
    let averageAccuracy: Double         // backend: average_accuracy (0.0 - 1.0)
    let guildRank: Int                  // backend: guild_rank
    let newMembersWeek: Int             // backend: new_members_week
    let activeMembersWeek: Int          // backend: active_members_week
    let predictionsWeek: Int            // backend: predictions_week
    let reputationEarnedWeek: Int       // backend: reputation_earned_week
    let lastCalculatedAt: Date          // backend: last_calculated_at
    
    // MARK: - Display Computed Properties (used by StatisticsView)
    
    var totalPredictionsDisplay: String {
        formatNumber(totalPredictions)
    }
    
    var correctPredictionsDisplay: String {
        formatNumber(correctPredictions)
    }
    
    var averageAccuracyDisplay: String {
        let percentage = averageAccuracy * 100
        return String(format: "%.1f%%", percentage)
    }
    
    var guildRankDisplay: String {
        guildRank == 0 ? "Unranked" : "#\(guildRank)"
    }
    
    var newMembersDisplay: String {
        "+\(newMembersWeek)"
    }
    
    var activeUsersDisplay: String {
        "\(activeMembersWeek)"
    }
    
    var predictionsMadeDisplay: String {
        formatNumber(predictionsWeek)
    }
    
    var reputationEarnedDisplay: String {
        reputationEarnedWeek >= 0 ? "+\(formatNumber(reputationEarnedWeek))" : formatNumber(reputationEarnedWeek)
    }
    
    var lastCalculatedDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastCalculatedAt, relativeTo: Date())
    }
    
    // MARK: - Helper
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        }
        return "\(number)"
    }
}


// =====================================================================================
// 2. RealAPIService.swift - ADD after createEvent (line 649, before closing brace)
// =====================================================================================

/*
    // ================================================================================================
    // MARK: - Statistics Endpoints (port 8001)
    // ================================================================================================
    
    /// Get guild statistics
    func getGuildStatistics(guildId: UUID) async throws -> RLGuildStatisticsResponse {
        print("📊 getGuildStatistics: Calling API for guild \(guildId)")
        let result: RLGuildStatisticsResponse = try await request(
            "/guilds/\(guildId.uuidString)/statistics",
            service: .core,
            auth: true
        )
        print("📊 getGuildStatistics: API returned statistics")
        return result
    }
*/


// =====================================================================================
// 3. RLAppState.swift - ADD after unattendEvent (around line 708)
// =====================================================================================

/*
    // ================================================================================================
    // MARK: - Statistics Management (REAL API)
    // ================================================================================================
    
    /// Fetch guild statistics
    func fetchGuildStatistics(guildId: UUID) async throws -> RLGuildStatisticsResponse {
        print("📊 fetchGuildStatistics: Starting for guild \(guildId)")
        do {
            let response = try await realApi.getGuildStatistics(guildId: guildId)
            print("📊 fetchGuildStatistics: Got statistics")
            return response
        } catch {
            print("📊 fetchGuildStatistics: Error - \(error)")
            // Don't show error toast for statistics - it's not critical
            throw error
        }
    }
    
    /// Fetch statistics for current guild
    func fetchCurrentGuildStatistics() async throws -> RLGuildStatisticsResponse {
        guard let guild = currentGuild else {
            throw RLAppError.noGuildSelected
        }
        return try await fetchGuildStatistics(guildId: guild.id)
    }
*/


// =====================================================================================
// 4. LeftDrawerViewModel.swift - UPDATE Published State (line 34)
// =====================================================================================

// CHANGE:
//     @Published var statistics: GuildStatisticsDTO?
// TO:
//     @Published var statistics: RLGuildStatisticsResponse?


// =====================================================================================
// 5. LeftDrawerViewModel.swift - UPDATE preloadData statistics task (lines 254-264)
// =====================================================================================

// REPLACE:
/*
            // Statistics
            group.addTask {
                do {
                    let fetched = try await appState.fetchGuildStatistics(guildId: guildId)
                    await MainActor.run { self.statistics = fetched }
                } catch is CancellationError {
                    // Silent
                } catch {
                    print("⚠️ Failed to fetch statistics: \(error)")
                }
            }
*/

// WITH:
/*
            // Statistics (from rlAppState - like announcements/events)
            group.addTask {
                do {
                    let fetched = try await rlAppState.fetchGuildStatistics(guildId: guildId)
                    await MainActor.run { self.statistics = fetched }
                    print("📋 preloadData: Fetched statistics")
                } catch is CancellationError {
                    // Silent - expected during navigation
                } catch {
                    print("⚠️ Failed to fetch statistics: \(error)")
                }
            }
*/


// =====================================================================================
// 6. LeftDrawerViewModel.swift - UPDATE refreshStatistics method (lines 398-409)
// =====================================================================================

// REPLACE:
/*
    /// Refresh only statistics - use this in StatisticsView
    func refreshStatistics(guildId: UUID, appState: AppState) async {
        do {
            let fetched = try await appState.fetchGuildStatistics(guildId: guildId)
            await MainActor.run {
                self.statistics = fetched
            }
        } catch is CancellationError {
            print("📋 refreshStatistics: Cancelled")
        } catch {
            print("⚠️ Failed to refresh statistics: \(error)")
        }
    }
*/

// WITH:
/*
    /// Refresh only statistics - use this in StatisticsView
    func refreshStatistics(guildId: UUID, rlAppState: RLAppState) async {
        do {
            let fetched = try await rlAppState.fetchGuildStatistics(guildId: guildId)
            await MainActor.run {
                self.statistics = fetched
            }
            print("📊 refreshStatistics: Refreshed successfully")
        } catch is CancellationError {
            print("📊 refreshStatistics: Cancelled")
        } catch {
            print("⚠️ Failed to refresh statistics: \(error)")
        }
    }
*/


// =====================================================================================
// 7. LeftDrawerMainView.swift - UPDATE refreshCurrentSection (around line 629)
// =====================================================================================

// CHANGE:
//     case .statistics:
//         await leftDrawerViewModel.refreshStatistics(guildId: guildId, appState: appState)
// TO:
//     case .statistics:
//         await leftDrawerViewModel.refreshStatistics(guildId: guildId, rlAppState: rlAppState)


// =====================================================================================
// 8. LeftDrawerViewModel.swift - UPDATE legacy preloadData (optional cleanup)
// =====================================================================================

// The legacy preloadData (lines 275-320) still uses appState.fetchGuildStatistics
// If you want to keep it working during migration, leave it as-is
// Or remove statistics from legacy mode since it now requires rlAppState


// =====================================================================================
// 9. StatisticsView.swift - NO CHANGES NEEDED ✅
// =====================================================================================
// The view already uses the correct property names:
// - statistics.totalPredictionsDisplay
// - statistics.correctPredictionsDisplay
// - statistics.averageAccuracyDisplay
// - statistics.guildRankDisplay
// - statistics.newMembersDisplay
// - statistics.activeUsersDisplay
// - statistics.predictionsMadeDisplay
// - statistics.reputationEarnedDisplay


// =====================================================================================
// SUMMARY
// =====================================================================================
//
// Files to modify:
// 1. CoreDTOS.swift         - Replace RLGuildStatisticsResponse with display properties
// 2. RealAPIService.swift   - Add getGuildStatistics() method
// 3. RLAppState.swift       - Add fetchGuildStatistics() methods
// 4. LeftDrawerViewModel    - Change type + update preload/refresh to use rlAppState
// 5. LeftDrawerMainView     - Update refreshCurrentSection call
//
// Backend endpoint: GET /guilds/{guild_id}/statistics
// Response matches: RLGuildStatisticsResponse
//
// Statistics are:
// - Fetched during preloadData (with announcements/events)
// - Cached in leftDrawerViewModel.statistics
// - Refreshed via pull-to-refresh in StatisticsView
// - Fairly static (updated by backend CRON job periodically)
//
// =====================================================================================
