import Foundation
import SwiftUI

@Observable
final class ListingsViewModel {
    var listings: [MarketListing] = []
    var isLoading = false
    var isLoadingAll = false
    var errorMessage: String?
    var page = 1
    var totalPages = 1
    var selectedRarity: ListingRarity?
    var selectedPosition: DisplayPosition?
    var selectedSeriesId: Int?
    var minBuyStubs: String = ""
    var maxBuyStubs: String = ""
    var minOverallStr: String = ""
    var maxOverallStr: String = ""
    var minROIStr: String = ""
    var minProfitPerFlipStr: String = ""
    var metaData: MetaData?
    var detailedCache: [String: DetailedListing] = [:]
    var autoRefreshEnabled = true
    var lastRefreshDate: Date?

    private let client = TheShowAPIClient()
    private var refreshTimer: Timer?
    private let presetManager: PresetManager
    private let notificationManager: NotificationManager
    private var currentLoadTask: Task<Void, Never>?
    
    private let listingsCacheKey = "cachedListings"
    private let cacheTimestampKey = "cacheTimestamp"

    init(presetManager: PresetManager, notificationManager: NotificationManager) {
        self.presetManager = presetManager
        self.notificationManager = notificationManager
        Task { @MainActor in
            loadCachedListings()
        }
    }
    
    @MainActor
    private func loadCachedListings() {
        guard let data = UserDefaults.standard.data(forKey: listingsCacheKey),
              let cached = try? JSONDecoder().decode([MarketListing].self, from: data) else {
            return
        }
        listings = cached
        if let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date {
            lastRefreshDate = timestamp
        }
        print("📦 Loaded \(cached.count) cached listings")
    }
    
    @MainActor
    private func saveListingsCache() {
        guard let data = try? JSONEncoder().encode(listings) else { return }
        UserDefaults.standard.set(data, forKey: listingsCacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
    }

    var flipRows: [FlipOpportunity] {
        let minROI = Double(minROIStr.trimmingCharacters(in: .whitespaces))
        let minProfit = Int(minProfitPerFlipStr.trimmingCharacters(in: .whitespaces))
        
        return listings
            .map { listing in
                var opp = FlipOpportunity(listing: listing)
                if let uuid = listing.item?.uuid {
                    opp.detailedData = detailedCache[uuid]
                }
                return opp
            }
            .filter { opp in
                guard opp.netProfit != nil else { return false }
                
                // Filter by min ROI if specified
                if let minRoi = minROI, let roi = opp.roi, roi < minRoi {
                    return false
                }
                
                // Filter by min profit per flip if specified
                if let minProfitFlip = minProfit, let profit = opp.netProfit, profit < minProfitFlip {
                    return false
                }
                
                return true
            }
            .sorted { lhs, rhs in
                // Both have profit per minute - compare them directly
                if let lpm = lhs.profitPerMinute, let rpm = rhs.profitPerMinute {
                    return lpm > rpm
                }
                // Only left has profit per minute - it should come first
                if lhs.profitPerMinute != nil {
                    return true
                }
                // Only right has profit per minute - it should come first
                if rhs.profitPerMinute != nil {
                    return false
                }
                // Neither has profit per minute - sort by net profit
                return (lhs.netProfit ?? 0) > (rhs.netProfit ?? 0)
            }
    }

    @MainActor
    func startAutoRefresh() {
        guard autoRefreshEnabled else { return }
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.silentRefresh()
            }
        }
    }

    @MainActor
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @MainActor
    private func silentRefresh() async {
        guard !isLoading else { return }

        let previousUUIDs = Set(listings.compactMap { $0.item?.uuid })

        do {
            let minBuy = Int(minBuyStubs.trimmingCharacters(in: .whitespaces))
            let maxBuy = Int(maxBuyStubs.trimmingCharacters(in: .whitespaces))
            let all = try await client.fetchAllListings(
                sort: .bestSellPrice,
                order: .desc,
                rarity: selectedRarity,
                position: selectedPosition,
                seriesId: selectedSeriesId,
                minBestBuyPrice: minBuy,
                maxBestBuyPrice: maxBuy,
                maxPages: 20
            )
            listings = all
            lastRefreshDate = Date()
            saveListingsCache() // Save to cache

            await checkForNewMatches(previousUUIDs: previousUUIDs)
        } catch {
            print("Silent refresh failed: \(error)")
        }
    }

    @MainActor
    private func checkForNewMatches(previousUUIDs: Set<String>) async {
        print("🔔 Checking for new matches...")
        print("   Previous cards: \(previousUUIDs.count)")
        print("   Current cards: \(listings.count)")
        print("   Active presets: \(presetManager.presets.count)")
        print("   Presets with notifications: \(presetManager.presets.filter(\.notificationsEnabled).count)")
        
        // Get new opportunities instead of just listings
        let newOpportunities = flipRows.filter { opportunity in
            guard let uuid = opportunity.listing.item?.uuid else { return false }
            return !previousUUIDs.contains(uuid) && !presetManager.seenCardUUIDs.contains(uuid)
        }
        
        print("   New cards found: \(newOpportunities.count)")

        for opportunity in newOpportunities {
            for preset in presetManager.presets where preset.notificationsEnabled {
                // Use the FlipOpportunity matcher that includes profit/min
                if preset.matches(opportunity) {
                    print("   ✅ Match found: \(opportunity.displayName) matches \"\(preset.name)\"")
                    if let ppm = opportunity.profitPerMinute {
                        print("      Profit/min: \(Int(ppm))")
                    }
                    notificationManager.sendNotification(for: opportunity.listing, preset: preset)
                    if let uuid = opportunity.listing.item?.uuid {
                        presetManager.markCardAsSeen(uuid)
                    }
                }
            }
        }
        
        if newOpportunities.isEmpty {
            print("   ℹ️ No new cards to check")
        }
    }

    @MainActor
    func loadMetaData() async {
        guard metaData == nil else { return }
        do {
            metaData = try await client.fetchMetaData()
        } catch {
            print("MetaData fetch failed: \(error)")
        }
    }

    @MainActor
    func checkPresetImmediately(_ preset: FilterPreset) {
        print("🔔 Checking preset \"\(preset.name)\" immediately against current listings...")
        
        var matchCount = 0
        // Check against flip opportunities instead of raw listings
        for opportunity in flipRows {
            // Skip if already seen
            if let uuid = opportunity.listing.item?.uuid, presetManager.seenCardUUIDs.contains(uuid) {
                continue
            }
            
            // Use the new FlipOpportunity matcher that includes profit/min
            if preset.matches(opportunity) {
                matchCount += 1
                print("   ✅ Match found: \(opportunity.displayName)")
                if let ppm = opportunity.profitPerMinute {
                    print("      Profit/min: \(Int(ppm))")
                }
                notificationManager.sendNotification(for: opportunity.listing, preset: preset)
                if let uuid = opportunity.listing.item?.uuid {
                    presetManager.markCardAsSeen(uuid)
                }
            }
        }
        
        if matchCount == 0 {
            print("   ℹ️ No matches found for this preset")
        } else {
            print("   📬 Sent \(matchCount) notification(s)")
        }
    }

    @MainActor
    func loadAll() async {
        // Cancel any existing load task
        currentLoadTask?.cancel()
        
        // Don't start a new load if one is already running
        guard !isLoading else { return }
        
        let task = Task { @MainActor in
            isLoadingAll = true
            isLoading = true
            errorMessage = nil
            defer {
                isLoadingAll = false
                isLoading = false
            }

            do {
                let minBuy = Int(minBuyStubs.trimmingCharacters(in: .whitespaces))
                let maxBuy = Int(maxBuyStubs.trimmingCharacters(in: .whitespaces))
                
                // Track previous cards for notification checking
                let previousUUIDs = Set(listings.compactMap { $0.item?.uuid })
                
                // Check for cancellation
                try Task.checkCancellation()
                
                let all = try await client.fetchAllListings(
                    sort: .bestSellPrice,
                    order: .desc,
                    rarity: selectedRarity,
                    position: selectedPosition,
                    seriesId: selectedSeriesId,
                    minBestBuyPrice: minBuy,
                    maxBestBuyPrice: maxBuy,
                    maxPages: 20
                )
                
                // Check for cancellation before updating
                try Task.checkCancellation()
                
                listings = all
                totalPages = 1
                page = 1
                lastRefreshDate = Date()
                saveListingsCache() // Save to cache
                Haptics.success()

                await enrichTopFlips()
                startAutoRefresh()
                
                // Check for new matches (important for notifications!)
                await checkForNewMatches(previousUUIDs: previousUUIDs)
            } catch is CancellationError {
                // Silently ignore cancellation
                print("Load cancelled by user")
            } catch {
                errorMessage = error.localizedDescription
                listings = []
                Haptics.error()
            }
        }
        
        currentLoadTask = task
        await task.value
    }

    @MainActor
    func load(resetPage: Bool = true) async {
        if resetPage { page = 1 }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let minBuy = Int(minBuyStubs.trimmingCharacters(in: .whitespaces))
            let maxBuy = Int(maxBuyStubs.trimmingCharacters(in: .whitespaces))
            let result = try await client.fetchListings(
                page: page,
                sort: .bestSellPrice,
                order: .desc,
                rarity: selectedRarity,
                position: selectedPosition,
                seriesId: selectedSeriesId,
                minBestBuyPrice: minBuy,
                maxBestBuyPrice: maxBuy
            )
            listings = result.listings
            totalPages = result.totalPages
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            listings = []
            Haptics.error()
        }
    }

    @MainActor
    func nextPage() async {
        guard page < totalPages else { return }
        page += 1
        Haptics.light()
        await load(resetPage: false)
    }

    @MainActor
    func previousPage() async {
        guard page > 1 else { return }
        page -= 1
        Haptics.light()
        await load(resetPage: false)
    }

    func applyFilters() {
        Task { await loadAll() }
    }

    func applyPreset(_ preset: FilterPreset) {
        selectedRarity = preset.rarity
        selectedPosition = preset.position
        selectedSeriesId = preset.seriesId
        minBuyStubs = preset.minBuyPrice.map(String.init) ?? ""
        maxBuyStubs = preset.maxBuyPrice.map(String.init) ?? ""
        minOverallStr = preset.minOverall.map(String.init) ?? ""
        maxOverallStr = preset.maxOverall.map(String.init) ?? ""
        minROIStr = preset.minROI.map { String(format: "%.0f", $0) } ?? ""
        minProfitPerFlipStr = preset.minProfitPerFlip.map(String.init) ?? ""
        Task { await loadAll() }
    }

    func resetFilters() {
        selectedRarity = nil
        selectedPosition = nil
        selectedSeriesId = nil
        minBuyStubs = ""
        maxBuyStubs = ""
        minOverallStr = ""
        maxOverallStr = ""
        minROIStr = ""
        minProfitPerFlipStr = ""
        Task { await loadAll() }
    }

    @MainActor
    private func enrichTopFlips() async {
        // Only enrich top 10 cards to speed up loading
        let topUUIDs = flipRows.prefix(10).compactMap { $0.listing.item?.uuid }
        await withTaskGroup(of: (String, DetailedListing?).self) { group in
            for uuid in topUUIDs {
                group.addTask {
                    let detail = try? await self.client.fetchDetailedListing(uuid: uuid)
                    return (uuid, detail)
                }
            }
            for await (uuid, detail) in group {
                if let detail {
                    detailedCache[uuid] = detail
                }
            }
        }
    }
    
    @MainActor
    func fetchDetailedDataIfNeeded(for uuid: String) async {
        // Skip if already cached
        guard detailedCache[uuid] == nil else { return }
        
        // Fetch detailed data
        if let detail = try? await client.fetchDetailedListing(uuid: uuid) {
            detailedCache[uuid] = detail
        }
    }
}
