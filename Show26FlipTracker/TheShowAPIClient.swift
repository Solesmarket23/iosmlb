import Foundation

enum ListingSort: String {
    case rank
    case bestSellPrice = "best_sell_price"
    case bestBuyPrice = "best_buy_price"
}

enum ListingRarity: String, CaseIterable, Codable {
    case diamond, gold, silver, bronze, common
}

enum ListingOrder: String {
    case asc, desc
}

enum DisplayPosition: String, CaseIterable, Codable {
    case SP, RP, CP, C
    case firstBase = "1B"
    case secondBase = "2B"
    case thirdBase = "3B"
    case SS, LF, CF, RF

    var displayName: String {
        switch self {
        case .firstBase: return "1B"
        case .secondBase: return "2B"
        case .thirdBase: return "3B"
        default: return rawValue
        }
    }
}

private let theShow26BaseURL = URL(string: "https://mlb26.theshow.com")!

actor TheShowAPIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = theShow26BaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchMetaData() async throws -> MetaData {
        let url = baseURL.appendingPathComponent("apis/meta_data.json")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MetaData.self, from: data)
    }

    func fetchRosterUpdates() async throws -> RosterUpdatesResponse {
        let url = baseURL.appendingPathComponent("apis/roster_updates.json")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RosterUpdatesResponse.self, from: data)
    }

    func fetchDetailedListing(uuid: String) async throws -> DetailedListing {
        var components = URLComponents(url: baseURL.appendingPathComponent("apis/listing.json"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "uuid", value: uuid)]
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(DetailedListing.self, from: data)
    }

    func fetchListings(
        page: Int = 1,
        sort: ListingSort = .bestSellPrice,
        order: ListingOrder = .desc,
        rarity: ListingRarity? = nil,
        position: DisplayPosition? = nil,
        seriesId: Int? = nil,
        minBestBuyPrice: Int? = nil,
        maxBestBuyPrice: Int? = nil
    ) async throws -> ListingsPage {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "type", value: "mlb_card"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "order", value: order.rawValue)
        ]
        if let rarity {
            items.append(URLQueryItem(name: "rarity", value: rarity.rawValue))
        }
        if let position {
            items.append(URLQueryItem(name: "display_position", value: position.rawValue))
        }
        if let seriesId {
            items.append(URLQueryItem(name: "series_id", value: String(seriesId)))
        }
        if let minBestBuyPrice {
            items.append(URLQueryItem(name: "min_best_buy_price", value: String(minBestBuyPrice)))
        }
        if let maxBestBuyPrice {
            items.append(URLQueryItem(name: "max_best_buy_price", value: String(maxBestBuyPrice)))
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("apis/listings.json"), resolvingAgainstBaseURL: false)!
        components.queryItems = items
        guard let url = components.url else { throw URLError(.badURL) }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ListingsPage.self, from: data)
    }

    /// Fetch ALL listings by fetching multiple pages concurrently.
    func fetchAllListings(
        sort: ListingSort = .bestSellPrice,
        order: ListingOrder = .desc,
        rarity: ListingRarity? = nil,
        position: DisplayPosition? = nil,
        seriesId: Int? = nil,
        minBestBuyPrice: Int? = nil,
        maxBestBuyPrice: Int? = nil,
        maxPages: Int = 50
    ) async throws -> [MarketListing] {
        let firstPage = try await fetchListings(
            page: 1,
            sort: sort,
            order: order,
            rarity: rarity,
            position: position,
            seriesId: seriesId,
            minBestBuyPrice: minBestBuyPrice,
            maxBestBuyPrice: maxBestBuyPrice
        )

        var allListings = firstPage.listings
        let totalPages = min(firstPage.totalPages, maxPages)

        guard totalPages > 1 else { return allListings }

        try await withThrowingTaskGroup(of: [MarketListing].self) { group in
            for page in 2...totalPages {
                group.addTask {
                    let pageResult = try await self.fetchListings(
                        page: page,
                        sort: sort,
                        order: order,
                        rarity: rarity,
                        position: position,
                        seriesId: seriesId,
                        minBestBuyPrice: minBestBuyPrice,
                        maxBestBuyPrice: maxBestBuyPrice
                    )
                    return pageResult.listings
                }
            }

            for try await pageListings in group {
                allListings.append(contentsOf: pageListings)
            }
        }

        return allListings
    }
}
