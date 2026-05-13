import SwiftUI

struct FlipsView: View {
    @Bindable var model: ListingsViewModel
    @State private var presetManager: PresetManager
    @State private var showFilter = false
    @State private var showPresets = false
    @State private var selectedOpportunity: FlipOpportunity?
    @State private var headerAppeared = false
    @State private var autoRefreshTimer: Timer?

    init(model: ListingsViewModel) {
        self.model = model
        _presetManager = State(initialValue: PresetManager())
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 130)
                    if let presetName = model.activePresetName {
                        activeFilterBanner(presetName: presetName)
                    }
                    rarityChips
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
        .sheet(isPresented: $showPresets) {
            PresetListSheet(presetManager: presetManager, model: model)
        }
        .sheet(item: $selectedOpportunity) { opportunity in
            CardDetailSheet(opportunity: opportunity)
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("FLIP FINDER")
                        .font(.system(size: 28, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)
                    opportunitySubtitle
                }
                Spacer()
                HStack(spacing: 10) {
                    refreshButton
                    presetsButton
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

    private var opportunitySubtitle: some View {
        Group {
            if model.isLoadingAll {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(Color.appAccent)
                        .scaleEffect(0.7)
                    Text("Loading all cards…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            } else if model.isLoading {
                Text("Loading…")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            } else {
                let count = model.flipRows.count
                let total = model.listings.count
                HStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(count > 0 ? Color.spreadGreen : Color.textSecondary)
                    Text("of \(total) cards · sorted by profit/min")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Haptics.rigid()
            Task { await model.loadAll(forceRefresh: true) }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.isLoading ? Color.textTertiary : Color.appAccent)
                .padding(10)
                .background(Color.appSurface, in: Circle())
                .rotationEffect(.degrees(model.isLoading ? 360 : 0))
                .animation(
                    model.isLoading ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                    value: model.isLoading
                )
        }
        .buttonStyle(PressScaleEffect())
        .disabled(model.isLoading)
    }
    
    private var presetsButton: some View {
        Button {
            Haptics.light()
            showPresets = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 13, weight: .semibold))
                if !presetManager.presets.isEmpty {
                    Text("\(presetManager.presets.count)")
                        .font(.system(size: 11, weight: .bold))
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

    private var filterButton: some View {
        Button {
            Haptics.light()
            showFilter = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                if model.selectedRarity != nil || model.selectedPosition != nil || model.selectedSeriesId != nil {
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

    // MARK: - Rarity Chips

    private var rarityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                rarityChip(label: "All", rarity: nil, style: .unknown)
                rarityChip(label: "◆ Diamond", rarity: .diamond, style: .diamond)
                rarityChip(label: "● Gold",    rarity: .gold,    style: .gold)
                rarityChip(label: "● Silver",  rarity: .silver,  style: .silver)
                rarityChip(label: "● Bronze",  rarity: .bronze,  style: .bronze)
                rarityChip(label: "● Common",  rarity: .common,  style: .common)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollClipDisabled()
    }

    private func rarityChip(label: String, rarity: ListingRarity?, style: RarityStyle) -> some View {
        let isSelected = model.selectedRarity == rarity
        let chipColor: Color = rarity == nil ? Color.appAccent : style.primaryColor
        return Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                model.selectedRarity = rarity
            }
            Task { await model.loadAll() }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appBG : chipColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? chipColor : Color.appSurface)
                        .overlay(
                            Capsule()
                                .strokeBorder(chipColor.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PressScaleEffect())
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.listings.isEmpty {
            loadingState
        } else if let err = model.errorMessage {
            errorState(err)
        } else if model.flipRows.isEmpty && !model.listings.isEmpty {
            emptyFlipsState
        } else {
            flipsList
        }
    }

    private var flipsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(model.flipRows.enumerated()), id: \.element.id) { idx, opp in
                CardTileView(
                    opportunity: opp,
                    showNetProfit: true,
                    animationDelay: min(Double(idx) * 0.045, 0.4)
                ) {
                    selectedOpportunity = opp
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            LazyVStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonTile
                }
            }
            .padding(.horizontal, 16)
        }
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

    private var emptyFlipsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.textTertiary)
                .padding(.top, 60)
            Text("No flips on this page")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
            Text("Try a different rarity, price range,\nor load the next page.")
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
    
    // MARK: - Active Filter Banner
    
    private func activeFilterBanner(presetName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("'\(presetName)' preset active")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                let count = model.flipRows.count
                Text("\(count) \(count == 1 ? "result" : "results") match your filters")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Button {
                Haptics.light()
                model.resetFilters()
                Task { await model.loadAll() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(PressScaleEffect())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appAccent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        // Stop any existing timer first
        stopAutoRefresh()
        
        // Create a timer that fires every 60 seconds
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task {
                await model.silentRefresh()
            }
        }
        
        print("🔄 Auto-refresh started (every 60 seconds)")
    }
    
    private func stopAutoRefresh() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        print("⏸️ Auto-refresh stopped")
    }
}
