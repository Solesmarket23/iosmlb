import SwiftUI

struct CardDetailSheet: View {
    let opportunity: FlipOpportunity
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedToast = false

    private var listing: MarketListing { opportunity.listing }
    private var item: ListingItem?    { listing.item }
    private var rarity: RarityStyle   { RarityStyle.from(item?.rarity) }

    private var netProfit: Int? {
        guard let sell = listing.bestSellPrice.intValue,
              let buy  = listing.bestBuyPrice.intValue,
              sell > 0, buy > 0 else { return nil }
        let net = Int(Double(sell) * 0.90) - buy
        return net > 0 ? net : nil
    }

    private var grossSpread: Int? {
        guard let sell = listing.bestSellPrice.intValue,
              let buy  = listing.bestBuyPrice.intValue,
              sell > 0, buy > 0 else { return nil }
        return sell - buy
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.appBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    statsSection
                    if netProfit != nil { profitSection }
                    if let orders = opportunity.detailedData?.completedOrders, !orders.isEmpty {
                        completedOrdersSection(orders: orders)
                    }
                    Spacer(minLength: 40)
                }
            }
            closeButton
            
            if showCopiedToast {
                copiedToast
            }
        }
    }

    private var closeButton: some View {
        Button {
            Haptics.light()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .padding(10)
                .background(Color.appSurfaceHi, in: Circle())
        }
        .padding(.top, 20)
        .padding(.trailing, 20)
    }

    private var heroSection: some View {
        VStack(spacing: 20) {
            cardImageLarge
            VStack(spacing: 6) {
                Button {
                    copyNameToClipboard()
                } label: {
                    HStack(spacing: 6) {
                        Text(item?.name ?? listing.listingName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .multilineTextAlignment(.center)
                
                HStack(spacing: 8) {
                    Text(rarity.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(rarity.primaryColor)
                    if let team = item?.team, team != "Free Agents" {
                        Text("·")
                            .foregroundStyle(Color.textTertiary)
                        Text(team)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
        .padding(.bottom, 28)
    }

    private var cardImageLarge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(rarity.gradient)
                .frame(width: 140, height: 196)
                .shadow(color: rarity.primaryColor.opacity(0.45), radius: 28, x: 0, y: 10)

            if let url = item?.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        Image(systemName: "person.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.white.opacity(0.45))
                    default:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.appSurfaceHi)
                            .shimmer()
                    }
                }
                .frame(width: 140, height: 196)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(rarity.gradient, lineWidth: 2)
        )
    }

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statTile(
                    title: "SELL PRICE",
                    value: listing.bestSellPrice.intValue?.stubsFormatted ?? "—",
                    icon: "arrow.up.circle.fill",
                    color: Color.spreadGreen
                )
                statTile(
                    title: "BUY PRICE",
                    value: listing.bestBuyPrice.intValue?.stubsFormatted ?? "—",
                    icon: "arrow.down.circle.fill",
                    color: Color.priceAmber
                )
            }
            if let spread = grossSpread {
                statTile(
                    title: "GROSS SPREAD",
                    value: spread.stubsFormatted,
                    icon: "arrow.left.arrow.right",
                    color: Color.appAccent,
                    fullWidth: true
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var profitSection: some View {
        VStack(spacing: 8) {
            Text("ESTIMATED NET PROFIT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 24)

            if let profit = netProfit {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.spreadGreen)
                    Text("+\(profit.stubsFormatted) stubs")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.spreadGreen)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.spreadGreen.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.spreadGreen.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)

                Text("After 10% community market tax on sales.")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 20)
            }
        }
    }

    private func statTile(
        title: String,
        value: String,
        icon: String,
        color: Color,
        fullWidth: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color.opacity(0.8))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.textTertiary)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(color.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var copiedToast: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.spreadGreen)
                Text("Copied!")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.appSurfaceHi)
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
            )
            .padding(.top, 80)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(100)
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

    private func completedOrdersSection(orders: [CompletedOrder]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.appAccent.opacity(0.8))
                Text("COMPLETED ORDERS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                Text("\(orders.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.appAccent.opacity(0.15))
                    )
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
            VStack(spacing: 8) {
                ForEach(orders.prefix(20).indices, id: \.self) { index in
                    let order = orders[index]
                    completedOrderRow(order: order)
                }
                
                if orders.count > 20 {
                    Text("Showing 20 of \(orders.count) orders")
                        .font(.caption2)
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func completedOrderRow(order: CompletedOrder) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if let date = order.date {
                    Text(formatOrderDate(date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            
            Spacer()
            
            if let price = order.priceInt {
                Text(price.stubsFormatted)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.spreadGreen)
            } else if let priceStr = order.price {
                Text(priceStr)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.spreadGreen)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.appAccent.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func formatOrderDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = formatter.date(from: dateStr) else {
            return dateStr
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .short
        outputFormatter.timeStyle = .short
        
        return outputFormatter.string(from: date)
    }
}
