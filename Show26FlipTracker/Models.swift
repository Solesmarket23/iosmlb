import Foundation

struct ListingsPage: Decodable {
    let page: Int
    let perPage: Int
    let totalPages: Int
    let listings: [MarketListing]

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case totalPages = "total_pages"
        case listings
    }
}

struct MarketListing: Codable, Identifiable {
    var id: String { item?.uuid ?? listingName }

    let listingName: String
    let bestSellPrice: PriceField
    let bestBuyPrice: PriceField
    let item: ListingItem?

    enum CodingKeys: String, CodingKey {
        case listingName = "listing_name"
        case bestSellPrice = "best_sell_price"
        case bestBuyPrice = "best_buy_price"
        case item
    }
}

struct ListingItem: Codable {
    let uuid: String?
    let type: String?
    let img: String?
    let bakedImg: String?
    let name: String?
    let rarity: String?
    let team: String?
    let ovr: Int?
    let displayPosition: String?

    enum CodingKeys: String, CodingKey {
        case uuid, type, img, name, rarity, team, ovr
        case bakedImg = "baked_img"
        case displayPosition = "display_position"
    }

    var imageURL: URL? {
        // Prefer baked_img as it's more stable, fall back to img
        if let baked = bakedImg, !baked.isEmpty {
            return URL(string: baked)
        }
        guard let img, !img.isEmpty else { return nil }
        if img.hasPrefix("http") { return URL(string: img) }
        return URL(string: "https://mlb26.theshow.com" + img)
    }
}

struct DetailedListing: Codable {
    let listingName: String
    let bestSellPrice: PriceField
    let bestBuyPrice: PriceField
    let item: ListingItem?
    let priceHistory: [PriceHistoryPoint]?
    let completedOrders: [CompletedOrder]?

    enum CodingKeys: String, CodingKey {
        case listingName = "listing_name"
        case bestSellPrice = "best_sell_price"
        case bestBuyPrice = "best_buy_price"
        case item
        case priceHistory = "price_history"
        case completedOrders = "completed_orders"
    }
}

struct PriceHistoryPoint: Codable {
    let date: String?
    let bestSellPrice: Int?
    let bestBuyPrice: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case bestSellPrice = "best_sell_price"
        case bestBuyPrice = "best_buy_price"
    }
}

struct CompletedOrder: Codable {
    let date: String?
    let price: String?
    
    var priceInt: Int? {
        guard let priceStr = price else { return nil }
        let cleaned = priceStr.replacingOccurrences(of: ",", with: "")
        return Int(cleaned)
    }
}

struct MetaData: Decodable {
    let series: [Series]?
    let brands: [Brand]?
    let sets: [String]?

    struct Series: Decodable, Identifiable {
        let seriesId: Int
        let name: String

        var id: Int { seriesId }

        enum CodingKeys: String, CodingKey {
            case seriesId = "series_id"
            case name
        }
    }

    struct Brand: Decodable, Identifiable {
        let brandId: Int
        let name: String

        var id: Int { brandId }

        enum CodingKeys: String, CodingKey {
            case brandId = "brand_id"
            case name
        }
    }
}

struct RosterUpdatesResponse: Decodable {
    let rosterUpdates: [RosterUpdate]

    enum CodingKeys: String, CodingKey {
        case rosterUpdates = "roster_updates"
    }
}

struct RosterUpdate: Decodable, Identifiable {
    let id: Int
    let name: String

    var displayDate: String {
        let components = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return components.joined(separator: ", ")
    }
}

enum PriceField: Codable, Equatable {
    case none
    case value(Int)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .none; return }
        if let n = try? c.decode(Int.self) { self = .value(n); return }
        if let str = try? c.decode(String.self) {
            if str == "-" || str.isEmpty { self = .none; return }
            if let n = Int(str) { self = .value(n); return }
        }
        self = .none
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .none:
            try container.encodeNil()
        case .value(let n):
            try container.encode(n)
        }
    }

    var intValue: Int? {
        if case .value(let n) = self { return n }
        return nil
    }
}

struct FlipOpportunity: Identifiable {
    let listing: MarketListing
    var detailedData: DetailedListing?

    var id: String { listing.id }

    var spread: Int? {
        guard let sell = listing.bestSellPrice.intValue,
              let buy  = listing.bestBuyPrice.intValue,
              sell > 0, buy > 0 else { return nil }
        return sell - buy
    }

    var netProfit: Int? {
        guard let sell = listing.bestSellPrice.intValue,
              let buy  = listing.bestBuyPrice.intValue,
              sell > 0, buy > 0 else { return nil }
        let afterTax = Int(Double(sell) * 0.90)
        let net = afterTax - buy
        return net > 0 ? net : nil
    }
    
    var roi: Double? {
        guard let profit = netProfit,
              let buy = listing.bestBuyPrice.intValue,
              buy > 0 else { return nil }
        return (Double(profit) / Double(buy)) * 100.0
    }

    /// Estimated profit per minute based on completed order frequency.
    var profitPerMinute: Double? {
        guard let profit = netProfit,
              let orders = detailedData?.completedOrders,
              orders.count >= 2 else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var timestamps: [Date] = []
        for order in orders {
            guard let dateStr = order.date,
                  let date = dateFormatter.date(from: dateStr) else { continue }
            timestamps.append(date)
        }

        guard timestamps.count >= 2 else { return nil }
        timestamps.sort()

        let totalSeconds = timestamps.last!.timeIntervalSince(timestamps.first!)
        guard totalSeconds > 0 else { return nil }

        let ordersPerMinute = Double(timestamps.count - 1) / (totalSeconds / 60.0)
        return ordersPerMinute * Double(profit)
    }

    var displayName: String { listing.item?.name ?? listing.listingName }
    var rarity: String      { listing.item?.rarity ?? "—" }
    var team: String        { listing.item?.team ?? "—" }
    var position: String    { listing.item?.displayPosition ?? "—" }
    var ovr: Int?           { listing.item?.ovr }
}

// MARK: - Detailed Item Card Models

struct DetailedItemCard: Decodable, Identifiable {
    let uuid: String
    let type: String?
    let name: String?
    let rarity: String?
    let team: String?
    let teamShortName: String?
    let ovr: Int?
    let series: String?
    let seriesYear: Int?
    let displayPosition: String?
    let displaySecondaryPositions: String?
    let jerseyNumber: String?
    let age: Int?
    let batHand: String?
    let throwHand: String?
    let weight: String?
    let height: String?
    let born: String?
    let isHitter: Bool?
    
    // Pitching attributes
    let stamina: Int?
    let pitchingClutch: Int?
    let hitsPerBf: Int?
    let kPerBf: Int?
    let bbPerBf: Int?
    let hrPerBf: Int?
    let pitchVelocity: Int?
    let pitchControl: Int?
    let pitchMovement: Int?
    
    // Hitting attributes
    let contactLeft: Int?
    let contactRight: Int?
    let powerLeft: Int?
    let powerRight: Int?
    let plateVision: Int?
    let plateDiscipline: Int?
    let battingClutch: Int?
    let buntingAbility: Int?
    let dragBuntingAbility: Int?
    let hittingDurability: Int?
    
    // Fielding attributes
    let fieldingDurability: Int?
    let fieldingAbility: Int?
    let armStrength: Int?
    let armAccuracy: Int?
    let reactionTime: Int?
    let blocking: Int?
    let speed: Int?
    let baserunningAbility: Int?
    let baserunningAggression: Int?
    
    let pitches: [PitchInfo]?
    let quirks: [Quirk]?
    let locations: [String]?
    
    var id: String { uuid }
    
    enum CodingKeys: String, CodingKey {
        case uuid, type, name, rarity, team, ovr, series, age, born, speed
        case teamShortName = "team_short_name"
        case seriesYear = "series_year"
        case displayPosition = "display_position"
        case displaySecondaryPositions = "display_secondary_positions"
        case jerseyNumber = "jersey_number"
        case batHand = "bat_hand"
        case throwHand = "throw_hand"
        case weight, height
        case isHitter = "is_hitter"
        case stamina
        case pitchingClutch = "pitching_clutch"
        case hitsPerBf = "hits_per_bf"
        case kPerBf = "k_per_bf"
        case bbPerBf = "bb_per_bf"
        case hrPerBf = "hr_per_bf"
        case pitchVelocity = "pitch_velocity"
        case pitchControl = "pitch_control"
        case pitchMovement = "pitch_movement"
        case contactLeft = "contact_left"
        case contactRight = "contact_right"
        case powerLeft = "power_left"
        case powerRight = "power_right"
        case plateVision = "plate_vision"
        case plateDiscipline = "plate_discipline"
        case battingClutch = "batting_clutch"
        case buntingAbility = "bunting_ability"
        case dragBuntingAbility = "drag_bunting_ability"
        case hittingDurability = "hitting_durability"
        case fieldingDurability = "fielding_durability"
        case fieldingAbility = "fielding_ability"
        case armStrength = "arm_strength"
        case armAccuracy = "arm_accuracy"
        case reactionTime = "reaction_time"
        case blocking
        case baserunningAbility = "baserunning_ability"
        case baserunningAggression = "baserunning_aggression"
        case pitches, quirks, locations
    }
}

struct PitchInfo: Decodable, Identifiable {
    let name: String
    let speed: Int?
    let control: Int?
    let movement: Int?
    
    var id: String { name }
}

struct Quirk: Decodable, Identifiable {
    let name: String
    let description: String?
    let img: String?
    
    var id: String { name }
}

// MARK: - Player Search Models

struct PlayerSearchResponse: Decodable {
    let universalProfiles: [UniversalProfile]
    
    enum CodingKeys: String, CodingKey {
        case universalProfiles = "universal_profiles"
    }
}

struct UniversalProfile: Decodable, Identifiable {
    let username: String
    let displayLevel: String?
    let gamesPlayed: String?
    let vanity: Vanity?
    let mostPlayedModes: MostPlayedModes?
    let lifetimeHittingStats: [[String: Double]]?
    let lifetimeDefensiveStats: [[String: Double]]?
    let onlineData: [OnlineYearStats]?
    
    var id: String { username }
    
    enum CodingKeys: String, CodingKey {
        case username
        case displayLevel = "display_level"
        case gamesPlayed = "games_played"
        case vanity
        case mostPlayedModes = "most_played_modes"
        case lifetimeHittingStats = "lifetime_hitting_stats"
        case lifetimeDefensiveStats = "lifetime_defensive_stats"
        case onlineData = "online_data"
    }
}

struct Vanity: Decodable {
    let nameplateEquipped: String?
    let iconEquipped: String?
    
    enum CodingKeys: String, CodingKey {
        case nameplateEquipped = "nameplate_equipped"
        case iconEquipped = "icon_equipped"
    }
}

struct MostPlayedModes: Decodable {
    let leagueTime: String?
    let ddTime: String?
    let playnowTime: String?
    let playoffTime: String?
    let franchiseTime: String?
    let seasonTime: String?
    let showliveTime: String?
    let rttsTime: String?
    let cowTime: String?
    let hrdTime: String?
    
    enum CodingKeys: String, CodingKey {
        case leagueTime = "league_time"
        case ddTime = "dd_time"
        case playnowTime = "playnow_time"
        case playoffTime = "playoff_time"
        case franchiseTime = "franchise_time"
        case seasonTime = "season_time"
        case showliveTime = "showlive_time"
        case rttsTime = "rtts_time"
        case cowTime = "cow_time"
        case hrdTime = "hrd_time"
    }
    
    var topMode: (name: String, minutes: Int)? {
        let modes = [
            ("Diamond Dynasty", Int(ddTime ?? "0") ?? 0),
            ("Play Now", Int(playnowTime ?? "0") ?? 0),
            ("Franchise", Int(franchiseTime ?? "0") ?? 0),
            ("Road to the Show", Int(rttsTime ?? "0") ?? 0)
        ]
        return modes.max(by: { $0.1 < $1.1 })
    }
}

struct OnlineYearStats: Decodable, Identifiable {
    let year: String
    let wins: String?
    let loses: String?
    let hr: String?
    let runsPerGame: String?
    let stolenBases: String?
    let battingAverage: String?
    let era: String?
    let kPer9: String?
    let whip: String?
    
    var id: String { year }
    
    enum CodingKeys: String, CodingKey {
        case year, wins, loses, hr, era, whip
        case runsPerGame = "runs_per_game"
        case stolenBases = "stolen_bases"
        case battingAverage = "batting_average"
        case kPer9 = "k_per_9"
    }
}

// MARK: - Captains Models

struct CaptainsPage: Decodable {
    let page: Int
    let perPage: Int
    let totalPages: Int
    let totalCaptains: Int
    let captains: [Captain]
    
    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case totalPages = "total_pages"
        case totalCaptains = "total_captains"
        case captains
    }
}

struct Captain: Decodable, Identifiable {
    let uuid: String
    let name: String
    let displayPosition: String?
    let team: String?
    let ovr: Int?
    let abilityName: String?
    let abilityDesc: String?
    let boosts: [CaptainBoost]?
    
    var id: String { uuid }
    
    enum CodingKeys: String, CodingKey {
        case uuid, name, team, ovr, boosts
        case displayPosition = "display_position"
        case abilityName = "ability_name"
        case abilityDesc = "ability_desc"
    }
}

struct CaptainBoost: Decodable, Identifiable {
    let tier: String
    let description: String?
    let attributes: [BoostAttribute]?
    
    var id: String { tier }
}

struct BoostAttribute: Decodable, Identifiable {
    let name: String
    let value: String
    
    var id: String { name }
}
