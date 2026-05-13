import SwiftUI

struct PlayerFinderView: View {
    @Bindable var model: ListingsViewModel
    @State private var searchText = ""
    @State private var selectedCard: DetailedItemCard?
    @State private var showingFilters = false
    @State private var selectedPosition: DisplayPosition?
    @State private var selectedRarity: ListingRarity?
    
    private var filteredListings: [MarketListing] {
        var listings = model.listings
        
        // Apply search filter
        if !searchText.isEmpty {
            listings = listings.filter {
                let name = $0.item?.name ?? $0.listingName
                return name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply position filter
        if let position = selectedPosition {
            listings = listings.filter { $0.item?.displayPosition == position.rawValue }
        }
        
        // Apply rarity filter
        if let rarity = selectedRarity {
            listings = listings.filter { $0.item?.rarity?.lowercased() == rarity.rawValue }
        }
        
        return listings
    }
    
    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                searchBar
                filterChips
                
                if model.isLoading {
                    loadingView
                } else if filteredListings.isEmpty {
                    emptyState
                } else {
                    playerGrid
                }
            }
        }
        .sheet(item: $selectedCard) { card in
            PlayerDetailSheet(card: card)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PLAYER FINDER")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.white)
            
            Text("\(filteredListings.count) players")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 16)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)
                
                TextField("Search players...", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Haptics.light()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Position filters
                ForEach([DisplayPosition.SP, .RP, .CP, .C, .firstBase, .secondBase, .thirdBase, .SS, .LF, .CF, .RF], id: \.self) { position in
                    filterChip(
                        label: position.displayName,
                        isSelected: selectedPosition == position,
                        action: {
                            Haptics.selection()
                            selectedPosition = selectedPosition == position ? nil : position
                        }
                    )
                }
                
                Divider()
                    .frame(height: 24)
                    .background(Color.appSurfaceHi)
                
                // Rarity filters
                ForEach(ListingRarity.allCases, id: \.self) { rarity in
                    rarityChip(rarity: rarity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
    
    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appBG : Color.appAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.appAccent : Color.appSurface)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.clear : Color.appAccent.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PressScaleEffect())
    }
    
    private func rarityChip(rarity: ListingRarity) -> some View {
        let style = RarityStyle.from(rarity.rawValue)
        let isSelected = selectedRarity == rarity
        
        return Button {
            Haptics.selection()
            selectedRarity = selectedRarity == rarity ? nil : rarity
        } label: {
            Text(rarity.rawValue.capitalized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appBG : style.primaryColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? style.primaryColor : Color.appSurface)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.clear : style.primaryColor.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PressScaleEffect())
    }
    
    // MARK: - Player Grid
    
    private var playerGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(filteredListings) { listing in
                    PlayerCard(listing: listing) {
                        Haptics.medium()
                        Task {
                            await loadDetailedCard(for: listing)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .refreshable {
            Haptics.rigid()
            await model.loadAll()
        }
    }
    
    // MARK: - Empty & Loading States
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(Color.textTertiary)
            Text("No Players Found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
            Text("Try adjusting your search or filters")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 60)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.appAccent)
                .scaleEffect(1.5)
            Text("Loading players...")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    
    private func loadDetailedCard(for listing: MarketListing) async {
        guard let uuid = listing.item?.uuid else { return }
        
        do {
            let client = TheShowAPIClient()
            let detailedCard = try await client.fetchDetailedItem(uuid: uuid)
            selectedCard = detailedCard
        } catch {
            print("Failed to load detailed card: \(error)")
        }
    }
}

// MARK: - Player Card Component

struct PlayerCard: View {
    let listing: MarketListing
    let onTap: () -> Void
    
    private var item: ListingItem? { listing.item }
    private var rarityStyle: RarityStyle {
        RarityStyle.from(item?.rarity)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Card Image
                ZStack(alignment: .topTrailing) {
                    cardImage
                    
                    // OVR Badge
                    if let ovr = item?.ovr {
                        ovrBadge(ovr)
                            .padding(8)
                    }
                }
                
                // Card Info
                VStack(spacing: 6) {
                    Text(item?.name ?? listing.listingName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        if let position = item?.displayPosition {
                            positionBadge(position)
                        }
                        if let team = item?.team {
                            teamBadge(team)
                        }
                    }
                }
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(rarityStyle.primaryColor.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PressScaleEffect())
    }
    
    private var cardImage: some View {
        Group {
            if let url = item?.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderIcon
                    default:
                        shimmerPlaceholder
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .background(Color.appBG)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var placeholderIcon: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 50))
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var shimmerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.appSurface)
    }
    
    private func ovrBadge(_ ovr: Int) -> some View {
        Text("\(ovr)")
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(rarityStyle.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(rarityStyle.primaryColor)
                    .shadow(color: rarityStyle.primaryColor.opacity(0.4), radius: 4, x: 0, y: 2)
            )
    }
    
    private func positionBadge(_ position: String) -> some View {
        Text(position)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appAccent.opacity(0.2), in: Capsule())
    }
    
    private func teamBadge(_ team: String) -> some View {
        Text(team)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appBG, in: Capsule())
    }
}
