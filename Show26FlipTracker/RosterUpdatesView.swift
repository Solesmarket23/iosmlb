import SwiftUI

struct RosterUpdatesView: View {
    @State private var rosterUpdates: [RosterUpdate] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let client = TheShowAPIClient()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                contentView
            }
            .navigationTitle("Roster Updates")
            .task {
                await loadRosterUpdates()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            ProgressView()
                .tint(Color.appAccent)
        } else if let err = errorMessage {
            errorState(err)
        } else if rosterUpdates.isEmpty {
            emptyState
        } else {
            updatesList
        }
    }

    private var updatesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(rosterUpdates.enumerated()), id: \.element.id) { idx, update in
                    RosterUpdateRow(update: update, isLatest: idx == 0)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(Color.textTertiary)
            Text("No Roster Updates")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Color.priceAmber)
            Text("Couldn't load roster updates")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    @MainActor
    private func loadRosterUpdates() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.fetchRosterUpdates()
            rosterUpdates = response.rosterUpdates.sorted { $0.id > $1.id }
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

private struct RosterUpdateRow: View {
    let update: RosterUpdate
    let isLatest: Bool

    var body: some View {
        HStack(spacing: 14) {
            iconView
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(update.displayDate)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                    if isLatest {
                        latestBadge
                    }
                }
                Text("Update ID: \(update.id)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isLatest ? Color.appAccent.opacity(0.3) : Color.clear, lineWidth: 1.5)
                )
        )
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(isLatest ? Color.appAccent.opacity(0.15) : Color.appSurfaceHi)
                .frame(width: 44, height: 44)
            Image(systemName: isLatest ? "star.fill" : "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isLatest ? Color.appAccent : Color.textSecondary)
        }
    }

    private var latestBadge: some View {
        Text("LATEST")
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .foregroundStyle(Color.appBG)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.appAccent, in: Capsule())
    }
}
