import SwiftUI

struct FilterSheetView: View {
    @Bindable var model: ListingsViewModel
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingSavePreset = false
    @State private var presetName = ""
    @State private var showValidationError = false

    private let presetManager: PresetManager

    init(model: ListingsViewModel, presetManager: PresetManager, onApply: @escaping () -> Void) {
        self.model = model
        self.presetManager = presetManager
        self.onApply = onApply
    }

    private let rarities: [(label: String, value: ListingRarity?)] = [
        ("All",     nil),
        ("Diamond", .diamond),
        ("Gold",    .gold),
        ("Silver",  .silver),
        ("Bronze",  .bronze),
        ("Common",  .common)
    ]

    private let positions: [(label: String, value: DisplayPosition?)] = [
        ("All", nil),
        ("SP", .SP), ("RP", .RP), ("CP", .CP), ("C", .C),
        ("1B", .firstBase), ("2B", .secondBase), ("3B", .thirdBase), ("SS", .SS),
        ("LF", .LF), ("CF", .CF), ("RF", .RF)
    ]

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            VStack(spacing: 0) {
                handle
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        itemTypeSection
                        raritySection
                        positionSection
                        seriesSection
                        priceSection
                        overallSection
                        profitSection
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
                actionBar
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.appBG)
        .task {
            await model.loadMetaData()
        }
        .alert("Save Filter Preset", isPresented: $showingSavePreset) {
            TextField("Preset Name", text: $presetName)
            Button("Cancel", role: .cancel) {
                presetName = ""
                showValidationError = false
            }
            Button("Save") {
                if presetName.trimmingCharacters(in: .whitespaces).isEmpty {
                    showValidationError = true
                    Haptics.error()
                } else {
                    saveCurrentAsPreset()
                    showValidationError = false
                }
            }
        } message: {
            if showValidationError {
                Text("Preset name is required")
            } else {
                Text("Enter a name for this filter combination")
            }
        }
    }

    private var handle: some View {
        Capsule()
            .fill(Color.appSurfaceHi)
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private var raritySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("RARITY")
            FlowLayout(spacing: 8) {
                ForEach(rarities, id: \.label) { item in
                    rarityChip(label: item.label, value: item.value)
                }
            }
        }
    }

    private func rarityChip(label: String, value: ListingRarity?) -> some View {
        let style = RarityStyle.from(value?.rawValue)
        let isSelected = model.selectedRarity == value
        return Button {
            Haptics.selection()
            model.selectedRarity = value
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appBG : (value == nil ? Color.appAccent : style.primaryColor))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? (value == nil ? Color.appAccent : style.primaryColor)
                              : Color.appSurface)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.clear : (value == nil ? Color.appAccent.opacity(0.3) : style.primaryColor.opacity(0.3)),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PressScaleEffect())
    }

    private var itemTypeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("ITEM TYPE")
            FlowLayout(spacing: 8) {
                itemTypeChip(label: "All", value: nil)
                ForEach(ItemType.allCases, id: \.self) { type in
                    itemTypeChip(label: type.displayName, value: type)
                }
            }
        }
    }

    private func itemTypeChip(label: String, value: ItemType?) -> some View {
        let isSelected = model.selectedItemType == value
        return Button {
            Haptics.selection()
            model.selectedItemType = value
        } label: {
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

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("BUY PRICE RANGE (STUBS)")
            HStack(spacing: 12) {
                styledField(placeholder: "Min", text: $model.minBuyStubs)
                Text("—")
                    .foregroundStyle(Color.textTertiary)
                styledField(placeholder: "Max", text: $model.maxBuyStubs)
            }
        }
    }

    private var overallSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("OVERALL RATING")
            HStack(spacing: 12) {
                styledField(placeholder: "Min", text: $model.minOverallStr)
                Text("—")
                    .foregroundStyle(Color.textTertiary)
                styledField(placeholder: "Max", text: $model.maxOverallStr)
            }
        }
    }
    
    private var profitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("PROFIT FILTERS")
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    styledField(placeholder: "Min ROI %", text: $model.minROIStr)
                    styledField(placeholder: "Min Profit/Flip", text: $model.minProfitPerFlipStr)
                }
            }
        }
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("POSITION")
            FlowLayout(spacing: 8) {
                ForEach(positions, id: \.label) { item in
                    positionChip(label: item.label, value: item.value)
                }
            }
        }
    }

    private func positionChip(label: String, value: DisplayPosition?) -> some View {
        let isSelected = model.selectedPosition == value
        return Button {
            Haptics.selection()
            model.selectedPosition = value
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appBG : Color.appAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
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

    private var seriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("SERIES")
            if let series = model.metaData?.series {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        seriesChip(label: "All", id: nil)
                        ForEach(series.filter { $0.seriesId > 0 }.prefix(15)) { s in
                            seriesChip(label: s.name, id: s.seriesId)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
                    .tint(Color.appAccent)
            }
        }
    }

    private func seriesChip(label: String, id: Int?) -> some View {
        let isSelected = model.selectedSeriesId == id
        return Button {
            Haptics.selection()
            model.selectedSeriesId = id
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? Color.appBG : Color.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.textSecondary : Color.appSurface)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.clear : Color.textTertiary.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PressScaleEffect())
    }

    private func styledField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity)
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("Reset") {
                    Haptics.light()
                    model.selectedRarity = nil
                    model.selectedPosition = nil
                    model.selectedSeriesId = nil
                    model.minBuyStubs = ""
                    model.maxBuyStubs = ""
                    model.minOverallStr = ""
                    model.maxOverallStr = ""
                    model.minROIStr = ""
                    model.minProfitPerFlipStr = ""
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Apply & Load All") {
                    Haptics.medium()
                    onApply()
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.appBG)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                Haptics.light()
                showingSavePreset = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Save as Preset")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.25), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .padding(.top, 12)
        .background(Color.appBG)
    }

    private func saveCurrentAsPreset() {
        guard !presetName.trimmingCharacters(in: .whitespaces).isEmpty else {
            showValidationError = true
            return
        }
        let preset = FilterPreset(
            name: presetName,
            rarity: model.selectedRarity,
            position: model.selectedPosition,
            seriesId: model.selectedSeriesId,
            minBuyPrice: Int(model.minBuyStubs),
            maxBuyPrice: Int(model.maxBuyStubs),
            minOverall: Int(model.minOverallStr),
            maxOverall: Int(model.maxOverallStr),
            minROI: Double(model.minROIStr),
            minProfitPerFlip: Int(model.minProfitPerFlipStr),
            itemType: model.selectedItemType,
            notificationsEnabled: false
        )
        presetManager.savePreset(preset)
        presetName = ""
        showValidationError = false
        showingSavePreset = false
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color.textTertiary)
    }
}

// MARK: - FlowLayout (wrapping chip row)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
