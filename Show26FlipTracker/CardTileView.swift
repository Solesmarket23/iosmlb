import SwiftUI

struct CardTileView: View {
    let opportunity: FlipOpportunity
    var showNetProfit: Bool = false
    var animationDelay: Double = 0
    var onTap: (() -> Void)?

    @State private var appeared = false
    @State private var showCopiedToast = false

    private var listing: MarketListing { opportunity.listing }
    private var item: ListingItem? { listing.item }
    private var rarity: RarityStyle { RarityStyle.from(item?.rarity) }
    private var netProfit: Int? { opportunity.netProfit }
    private var profitPerMin: Double? { opportunity.profitPerMinute }

    var body: some View {
        Button(action: {
            Haptics.medium()
            onTap?()
        }) {
            tileContent
        }
        .buttonStyle(PressScaleEffect())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78).delay(animationDelay)) {
                appeared = true
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var tileContent: some View {
        HStack(spacing: 14) {
            cardImageView
            infoSection
            Spacer(minLength: 0)
            if showNetProfit, let profit = netProfit {
                profitBadge(profit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(tileBackground)
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.appSurface)
            .shadow(color: rarity.glowColor, radius: 14, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(rarity.primaryColor.opacity(0.12), lineWidth: 1)
            )
    }

    private var cardImageView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rarity.gradient)
                .frame(width: 58, height: 80)

            if let url = item?.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        placeholderIcon
                    default:
                        shimmerPlaceholder
                    }
                }
                .frame(width: 58, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                placeholderIcon
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(rarity.gradient, lineWidth: 1.5)
        )
        .shadow(color: rarity.primaryColor.opacity(0.3), radius: 8, x: 0, y: 2)
    }

    private var placeholderIcon: some View {
        Image(systemName: "person.fill")
            .font(.title2)
            .foregroundStyle(Color.white.opacity(0.45))
    }

    private var shimmerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.appSurfaceHi)
            .shimmer()
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            nameRow
            rarityTeamRow
            priceDetailsRow
        }
    }

    private var nameRow: some View {
        Button {
            copyNameToClipboard()
        } label: {
            HStack(spacing: 4) {
                Text(item?.name ?? listing.listingName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var rarityTeamRow: some View {
        HStack(spacing: 5) {
            Text(rarity.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(rarity.primaryColor)
            if let team = item?.team, team != "Free Agents", !team.isEmpty {
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
                Text(team)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var priceDetailsRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.priceAmber)
                Text("Buy:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Text(listing.bestBuyPrice.intValue?.stubsFormatted ?? "—")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.priceAmber)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.spreadGreen)
                Text("Sell:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Text(listing.bestSellPrice.intValue?.stubsFormatted ?? "—")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.spreadGreen)
            }
            
            if let profit = netProfit {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.spreadGreen)
                    Text("Profit:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                    Text("+\(profit.stubsFormatted)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.spreadGreen)
                }
            }
        }
        .padding(.top, 3)
    }

    private func profitBadge(_ amount: Int) -> some View {
        VStack(spacing: 3) {
            if let ppm = profitPerMin, ppm > 1 {
                VStack(spacing: 2) {
                    Text("\(Int(ppm))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.spreadGreen)
                    Text("per min")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.spreadGreen.opacity(0.75))
                }
            } else {
                VStack(spacing: 2) {
                    Text("+\(amount.stubsFormatted)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.spreadGreen)
                    Text("net profit")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.spreadGreen.opacity(0.65))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.spreadGreen.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.spreadGreen.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var copiedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.spreadGreen)
            Text("Copied!")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.appSurfaceHi)
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .offset(y: -8)
    }

    private func copyNameToClipboard() {
        let name = item?.name ?? listing.listingName
        UIPasteboard.general.string = name
        
        Haptics.success()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showCopiedToast = false
            }
        }
    }
}
