import SwiftUI

struct PlayerStatsView: View {
    @State private var username: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var playerProfile: UniversalProfile?
    
    private let client = TheShowAPIClient()
    
    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    searchSection
                    
                    if let profile = playerProfile {
                        profileContent(profile)
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if !isLoading {
                        emptyState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Player Stats")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.appAccent)
                    
                    TextField("Enter username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Button {
                    Haptics.medium()
                    Task { await searchPlayer() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 50, height: 50)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(username.isEmpty || isLoading)
                .opacity(username.isEmpty ? 0.5 : 1)
            }
        }
    }
    
    // MARK: - Profile Content
    
    private func profileContent(_ profile: UniversalProfile) -> some View {
        VStack(spacing: 16) {
            profileHeader(profile)
            
            if let online = profile.onlineData?.first(where: { $0.year == "2026" }) {
                onlineStatsCard(online)
            }
            
            if let modes = profile.mostPlayedModes, let top = modes.topMode {
                mostPlayedCard(modeName: top.name, minutes: top.minutes)
            }
        }
    }
    
    private func profileHeader(_ profile: UniversalProfile) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Text(String(profile.username.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.username)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.white)
                    
                    HStack(spacing: 12) {
                        if let level = profile.displayLevel {
                            statPill(icon: "star.fill", value: "Level \(level)")
                        }
                        if let games = profile.gamesPlayed {
                            statPill(icon: "gamecontroller.fill", value: "\(games) games")
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
    }
    
    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.appBG, in: Capsule())
    }
    
    // MARK: - Online Stats Card
    
    private func onlineStatsCard(_ stats: OnlineYearStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("2026 Online Stats")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Color.appAccent)
            }
            
            // Record
            HStack(spacing: 16) {
                recordStat(label: "W", value: stats.wins ?? "0", color: .spreadGreen)
                recordStat(label: "L", value: stats.loses ?? "0", color: .spreadRed)
            }
            
            Divider()
                .background(Color.appSurfaceHi)
            
            // Hitting
            VStack(alignment: .leading, spacing: 12) {
                Text("HITTING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.textTertiary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statItem(label: "AVG", value: stats.battingAverage ?? "—")
                    statItem(label: "HR", value: stats.hr ?? "0")
                    statItem(label: "SB", value: stats.stolenBases ?? "0")
                }
            }
            
            Divider()
                .background(Color.appSurfaceHi)
            
            // Pitching
            VStack(alignment: .leading, spacing: 12) {
                Text("PITCHING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.textTertiary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statItem(label: "ERA", value: stats.era ?? "—")
                    statItem(label: "K/9", value: stats.kPer9 ?? "—")
                    statItem(label: "WHIP", value: stats.whip ?? "—")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
    }
    
    private func recordStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
        }
    }
    
    // MARK: - Most Played Card
    
    private func mostPlayedCard(modeName: String, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Most Played Mode")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.appAccent)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modeName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                    Text("\(formatMinutes(minutes)) played")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
    }
    
    // MARK: - Empty & Error States
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(Color.textTertiary)
            Text("Search for a Player")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
            Text("Enter your MLB The Show username to view your stats")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.spreadRed)
            Text("Player Not Found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Helper Functions
    
    private func searchPlayer() async {
        guard !username.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        playerProfile = nil
        
        do {
            let response = try await client.searchPlayer(username: username.trimmingCharacters(in: .whitespaces))
            if let profile = response.universalProfiles.first {
                playerProfile = profile
                Haptics.success()
            } else {
                errorMessage = "No player found with username '\(username)'"
                Haptics.error()
            }
        } catch {
            errorMessage = "Unable to fetch player stats. Please try again."
            Haptics.error()
        }
        
        isLoading = false
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        if hours < 1 {
            return "\(minutes) min"
        } else if hours < 100 {
            return "\(hours)h \(minutes % 60)m"
        } else {
            return "\(hours) hours"
        }
    }
}
