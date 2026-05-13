import SwiftUI

struct CaptainsView: View {
    @State private var captains: [Captain] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCaptain: Captain?
    @State private var currentPage = 1
    @State private var totalPages = 1
    
    private let client = TheShowAPIClient()
    
    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                
                if isLoading && captains.isEmpty {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    captainsList
                }
            }
        }
        .task {
            await loadCaptains()
        }
        .sheet(item: $selectedCaptain) { captain in
            CaptainDetailSheet(captain: captain)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CAPTAINS")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(Color.white)
            
            Text("\(captains.count) captains loaded")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 16)
    }
    
    // MARK: - Captains List
    
    private var captainsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(captains) { captain in
                    CaptainCard(captain: captain) {
                        Haptics.medium()
                        selectedCaptain = captain
                    }
                }
                
                // Load more button
                if currentPage < totalPages {
                    loadMoreButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .refreshable {
            Haptics.rigid()
            currentPage = 1
            await loadCaptains()
        }
    }
    
    private var loadMoreButton: some View {
        Button {
            Haptics.light()
            currentPage += 1
            Task { await loadCaptains(append: true) }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Load More")
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "arrow.down.circle.fill")
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressScaleEffect())
    }
    
    // MARK: - Loading & Error States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.appAccent)
                .scaleEffect(1.5)
            Text("Loading captains...")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.spreadRed)
            Text("Error Loading Captains")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Helper Functions
    
    private func loadCaptains(append: Bool = false) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client.fetchCaptains(page: currentPage)
            if append {
                captains.append(contentsOf: response.captains)
            } else {
                captains = response.captains
            }
            totalPages = response.totalPages
            Haptics.success()
        } catch {
            errorMessage = "Unable to load captains. Please try again."
            Haptics.error()
        }
        
        isLoading = false
    }
}

// MARK: - Captain Card Component

struct CaptainCard: View {
    let captain: Captain
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    // OVR Badge
                    if let ovr = captain.ovr {
                        Text("\(ovr)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                            .frame(width: 54, height: 54)
                            .background(
                                Circle()
                                    .fill(Color.appAccent)
                                    .shadow(color: Color.appAccent.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                    }
                    
                    // Name & Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(captain.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                        
                        HStack(spacing: 10) {
                            if let position = captain.displayPosition {
                                metadataPill(icon: "figure.baseball", text: position)
                            }
                            if let team = captain.team {
                                metadataPill(icon: "shield.fill", text: team)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                
                // Ability
                if let abilityName = captain.abilityName, let abilityDesc = captain.abilityDesc {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appAccent)
                            Text(abilityName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.appAccent)
                        }
                        
                        Text(abilityDesc)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appBG, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Boost tiers indicator
                if let boosts = captain.boosts, !boosts.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.spreadGreen)
                        Text("\(boosts.count) boost tiers available")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
            )
        }
        .buttonStyle(PressScaleEffect())
    }
    
    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appAccent.opacity(0.2), in: Capsule())
    }
}

// MARK: - Captain Detail Sheet

struct CaptainDetailSheet: View {
    let captain: Captain
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        captainHeader
                        
                        if let boosts = captain.boosts, !boosts.isEmpty {
                            boostsSection(boosts)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
    }
    
    // MARK: - Captain Header
    
    private var captainHeader: some View {
        VStack(spacing: 16) {
            // OVR
            if let ovr = captain.ovr {
                Text("\(ovr)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: 90, height: 90)
                    .background(
                        Circle()
                            .fill(Color.appAccent)
                            .shadow(color: Color.appAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
            }
            
            // Name
            Text(captain.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white)
            
            // Metadata
            HStack(spacing: 12) {
                if let position = captain.displayPosition {
                    metadataPill(icon: "figure.baseball", text: position)
                }
                if let team = captain.team {
                    metadataPill(icon: "shield.fill", text: team)
                }
            }
            
            // Ability
            if let abilityName = captain.abilityName, let abilityDesc = captain.abilityDesc {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.appAccent)
                        Text(abilityName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    
                    Text(abilityDesc)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.appSurface)
                )
            }
        }
        .padding(.top, 20)
    }
    
    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.appAccent.opacity(0.2), in: Capsule())
    }
    
    // MARK: - Boosts Section
    
    private func boostsSection(_ boosts: [CaptainBoost]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.spreadGreen)
                Text("Boosts")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            
            ForEach(boosts) { boost in
                boostTierCard(boost)
            }
        }
    }
    
    private func boostTierCard(_ boost: CaptainBoost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tier header
            HStack(spacing: 8) {
                Text("Tier \(boost.tier)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                
                Spacer()
                
                Image(systemName: "medal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(tierColor(boost.tier))
            }
            
            // Description
            if let description = boost.description {
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
            
            // Attributes
            if let attributes = boost.attributes, !attributes.isEmpty {
                Divider()
                    .background(Color.appBG)
                
                VStack(spacing: 8) {
                    ForEach(attributes) { attribute in
                        attributeRow(attribute)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tierColor(boost.tier).opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private func attributeRow(_ attribute: BoostAttribute) -> some View {
        HStack {
            Text(attribute.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white)
            Spacer()
            Text("+\(attribute.value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.spreadGreen)
        }
    }
    
    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "1": return Color.bronze
        case "2": return Color.silver
        case "3": return Color.gold
        default: return Color.appAccent
        }
    }
}

// Tier colors
extension Color {
    static let bronze = Color(red: 0.804, green: 0.498, blue: 0.196)
    static let silver = Color(red: 0.757, green: 0.812, blue: 0.882)
    static let gold = Color(red: 0.957, green: 0.620, blue: 0.043)
}
