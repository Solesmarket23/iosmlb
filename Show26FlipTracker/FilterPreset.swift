import Foundation
import SwiftUI

struct FilterPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var rarity: ListingRarity?
    var position: DisplayPosition?
    var seriesId: Int?
    var minBuyPrice: Int?
    var maxBuyPrice: Int?
    var minOverall: Int?
    var maxOverall: Int?
    var minProfitPerMinute: Double?
    var minROI: Double?
    var minProfitPerFlip: Int?
    var itemType: ItemType?
    var notificationsEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        rarity: ListingRarity? = nil,
        position: DisplayPosition? = nil,
        seriesId: Int? = nil,
        minBuyPrice: Int? = nil,
        maxBuyPrice: Int? = nil,
        minOverall: Int? = nil,
        maxOverall: Int? = nil,
        minProfitPerMinute: Double? = nil,
        minROI: Double? = nil,
        minProfitPerFlip: Int? = nil,
        itemType: ItemType? = nil,
        notificationsEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.position = position
        self.seriesId = seriesId
        self.minBuyPrice = minBuyPrice
        self.maxBuyPrice = maxBuyPrice
        self.minOverall = minOverall
        self.maxOverall = maxOverall
        self.minProfitPerMinute = minProfitPerMinute
        self.minROI = minROI
        self.minProfitPerFlip = minProfitPerFlip
        self.itemType = itemType
        self.notificationsEnabled = notificationsEnabled
    }

    var filterDescription: String {
        var parts: [String] = []
        if let itemType { parts.append(itemType.displayName) }
        if let r = rarity { parts.append(r.rawValue.capitalized) }
        if let p = position { parts.append(p.displayName) }
        if let max = maxBuyPrice { parts.append("≤\(max) buy") }
        if let min = minOverall { parts.append("≥\(min) OVR") }
        if let minPPM = minProfitPerMinute { parts.append("≥\(Int(minPPM))/min") }
        if let minRoi = minROI { parts.append("≥\(Int(minRoi))% ROI") }
        if let minProfit = minProfitPerFlip { parts.append("≥\(minProfit) profit") }
        return parts.isEmpty ? "No filters" : parts.joined(separator: " · ")
    }

    func matches(_ listing: MarketListing) -> Bool {
        if let itemType, listing.item?.type != itemType.rawValue { return false }
        if let r = rarity, listing.item?.rarity?.lowercased() != r.rawValue { return false }
        if let p = position, listing.item?.displayPosition != p.rawValue { return false }
        if let minPrice = minBuyPrice, (listing.bestBuyPrice.intValue ?? 0) < minPrice { return false }
        if let maxPrice = maxBuyPrice, (listing.bestBuyPrice.intValue ?? Int.max) > maxPrice { return false }
        if let minOvr = minOverall, (listing.item?.ovr ?? 0) < minOvr { return false }
        if let maxOvr = maxOverall, (listing.item?.ovr ?? Int.max) > maxOvr { return false }
        return true
    }
    
    func matches(_ opportunity: FlipOpportunity) -> Bool {
        // First check basic listing criteria
        if !matches(opportunity.listing) { return false }
        
        // Check profit per minute if specified
        if let minPPM = minProfitPerMinute {
            guard let ppm = opportunity.profitPerMinute, ppm >= minPPM else {
                return false
            }
        }
        
        // Check ROI if specified
        if let minRoi = minROI {
            guard let roi = opportunity.roi, roi >= minRoi else {
                return false
            }
        }
        
        // Check min profit per flip if specified
        if let minProfit = minProfitPerFlip {
            guard let profit = opportunity.netProfit, profit >= minProfit else {
                return false
            }
        }
        
        return true
    }
}

@Observable
final class PresetManager {
    private static let storageKey = "com.show26flip.savedPresets"
    var presets: [FilterPreset] = []
    var seenCardUUIDs: Set<String> = []

    init() {
        loadPresets()
        loadSeenCards()
    }

    func savePreset(_ preset: FilterPreset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persistPresets()
        Haptics.success()
    }

    func deletePreset(_ preset: FilterPreset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
        Haptics.light()
    }

    func toggleNotifications(for preset: FilterPreset) -> Bool {
        guard let idx = presets.firstIndex(where: { $0.id == preset.id }) else { return false }
        presets[idx].notificationsEnabled.toggle()
        let wasEnabled = presets[idx].notificationsEnabled
        persistPresets()
        Haptics.selection()
        return wasEnabled
    }

    func markCardAsSeen(_ uuid: String) {
        seenCardUUIDs.insert(uuid)
        UserDefaults.standard.set(Array(seenCardUUIDs), forKey: "com.show26flip.seenCards")
    }

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([FilterPreset].self, from: data) else {
            presets = []
            return
        }
        presets = decoded
    }

    private func persistPresets() {
        guard let encoded = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }

    private func loadSeenCards() {
        if let seen = UserDefaults.standard.array(forKey: "com.show26flip.seenCards") as? [String] {
            seenCardUUIDs = Set(seen)
        }
    }
}
