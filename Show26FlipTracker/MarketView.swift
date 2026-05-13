import SwiftUI

struct MarketView: View {
    @Bindable var model: ListingsViewModel
    @State private var presetManager: PresetManager
    @State private var showFilter = false
    @State private var selectedOpportunity: FlipOpportunity?
    @State private var headerAppeared = false
    @State private var searchText = ""

    init(model: ListingsViewModel) {
        self.model = model
        _presetManager = State(initialValue: PresetManager())
    }

    private var displayedOpportunities: [FlipOpportunity] {
        let listingsToUse = searchText.isEmpty ? model.listings : model.listings.filter {
            let name = $0.item?.name ?? $0.listingName
            return name.localizedCaseInsensitiveContains(searchText)
        }
        
        return listingsToUse.map { listing in
            var opp = FlipOpportunity(listing: listing)
            if let uuid = listing.item?.uuid {
                opp.detailedData = model.detailedCache[uuid]
            }
            return opp
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 130)
                    searchBar
                    content
                    pagination
                    Spacer(minLength: 40)
                }
            }
            .refreshable {
                Haptics.rigid()
                await model.loadAll()
            }
            stickyHeader
        }
        .sheet(isPresented: $showFilter) {
            FilterSheetView(model: model, presetManager: presetManager, onApply: { model.applyFilters() })
        }
        .sheet(item: $selectedOpportunity) { opportunity in
            CardDetailSheet(opportunity: opportunity)
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MARKET")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)
                    pageSubtitle
                }
                Spacer()
                HStack(spacing: 10) {
                    refreshButton
                    filterButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 58)
            .padding(.bottom, 20)
            .background(Color.appBG)
        }
        .background(
            Color.appBG
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : -10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                headerAppeared = true
            }
        }
    }

    private var pageSubtitle: some View {
        HStack(spacing: 4) {
            Text("Page \(model.page) of \(model.totalPages)")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
            if model.selectedRarity != nil {
                Text("·")
                    .foregroundStyle(Color.textTertiary)
                Text(model.selectedRarity?.rawValue.capitalized ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RarityStyle.from(model.selectedRarity?.rawValue).primaryColor)
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Haptics.rigid()
            Task { await model.loadAll() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.isLoading ? Color.textTertiary : Color.appAccent)
                .padding(10)
                .background(Color.appSurface, in: Circle())
        }
        .buttonStyle(PressScaleEffect())
        .disabled(model.isLoading)
        .rotationEffect(.degrees(model.isLoading ? 360 : 0))
        .animation(
            model.isLoading ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
            value: model.isLoading
        )
    }

    private var filterButton: some View {
        Button {
            Haptics.light()
            showFilter = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                if model.selectedRarity != nil || !model.minSellStubs.isEmpty || model.selectedPosition != nil {
                    Circle()
                        .fill(Color.appAccent)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appSurface, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleEffect())
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.textTertiary)
            TextField("Search cards on this page…", text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(Color.white)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    Haptics.light()
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.listings.isEmpty {
            loadingState
        } else if let err = model.errorMessage {
            errorState(err)
        } else if displayedOpportunities.isEmpty {
            emptyState
        } else {
            listingsList
        }
    }

    private var listingsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(displayedOpportunities.enumerated()), id: \.element.id) { idx, opp in
                CardTileView(
                    opportunity: opp,
                    showNetProfit: false,
                    animationDelay: min(Double(idx) * 0.04, 0.35)
                ) {
                    selectedOpportunity = opp
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    private var loadingState: some View {
        LazyVStack(spacing: 10) {
            ForEach(0..<8, id: \.self) { _ in
                skeletonTile
            }
        }
        .padding(.horizontal, 16)
    }

    private var skeletonTile: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.appSurface)
                .frame(width: 58, height: 80)
                .shimmer()
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.appSurface)
                    .frame(width: 140, height: 14)
                    .shimmer()
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.appSurface)
                    .frame(width: 100, height: 11)
                    .shimmer()
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.appSurface)
                    .frame(width: 120, height: 11)
                    .shimmer()
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.appSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 60)
            Text("No cards found")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
            Text("Try a different search or adjust your filters.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 40)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Color.priceAmber)
                .padding(.top, 60)
            Text("Couldn't load listings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") {
                Haptics.medium()
                Task { await model.loadAll() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.appAccent)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Pagination (hidden for loadAll mode)

    private var pagination: some View {
        EmptyView()
    }
}
