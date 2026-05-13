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

struct MarketListing: Decodable, Identifiable {
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

struct ListingItem: Decodable {
    let uuid: String?
    let img: String?
    let name: String?
    let rarity: String?
    let team: String?
    let ovr: Int?
    let displayPosition: String?

    enum CodingKeys: String, CodingKey {
        case uuid, img, name, rarity, team, ovr
        case displayPosition = "display_position"
    }

    var imageURL: URL? {
        guard let img, !img.isEmpty else { return nil }
        if img.hasPrefix("http") { return URL(string: img) }
        return URL(string: "https://mlb26.theshow.com" + img)
    }
}

struct DetailedListing: Decodable {
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

struct PriceHistoryPoint: Decodable {
    let date: String?
    let bestSellPrice: Int?
    let bestBuyPrice: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case bestSellPrice = "best_sell_price"
        case bestBuyPrice = "best_buy_price"
    }
}

struct CompletedOrder: Decodable {
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

enum PriceField: Decodable, Equatable {
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
