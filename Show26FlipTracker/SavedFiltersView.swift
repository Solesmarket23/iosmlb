import SwiftUI

struct SavedFiltersView: View {
    @Bindable var presetManager: PresetManager
    @Bindable var model: ListingsViewModel
    @State private var showingAddSheet = false
    @State private var editingPreset: FilterPreset?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                contentView
            }
            .navigationTitle("Saved Filters")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingAddSheet) {
                PresetEditSheet(
                    preset: nil,
                    onSave: { preset in
                        presetManager.savePreset(preset)
                    },
                    metaData: model.metaData
                )
            }
            .sheet(item: $editingPreset) { preset in
                PresetEditSheet(
                    preset: preset,
                    onSave: { updated in
                        presetManager.savePreset(updated)
                    },
                    metaData: model.metaData
                )
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                presetsSection
                rosterUpdatesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SAVED FILTER PRESETS")
            if presetManager.presets.isEmpty {
                emptyPresetCard
            } else {
                ForEach(presetManager.presets) { preset in
                    PresetRow(
                        preset: preset,
                        onTap: {
                            Haptics.medium()
                            model.applyPreset(preset)
                        },
                        onEdit: {
                            Haptics.light()
                            editingPreset = preset
                        },
                        onDelete: {
                            Haptics.light()
                            presetManager.deletePreset(preset)
                        },
                        onToggleNotifications: {
                            let wasEnabled = presetManager.toggleNotifications(for: preset)
                            // If notifications were just enabled, check immediately
                            if wasEnabled {
                                model.checkPresetImmediately(preset)
                            }
                        }
                    )
                }
            }
        }
    }

    private var rosterUpdatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ROSTER UPDATES")
            NavigationLink(destination: RosterUpdatesView()) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appAccent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("View Update History")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Text("Track card rating changes")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.appAccent.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PressScaleEffect())
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color.textTertiary)
            .padding(.leading, 4)
    }

    private var emptyPresetCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 32))
                .foregroundStyle(Color.textTertiary)
            Text("No Saved Filters")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
            Text("Tap + to create a custom filter preset")
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        testNotification()
                    } label: {
                        Label("Test Notification", systemImage: "bell.badge")
                    }
                    
                    Button {
                        clearSeenCards()
                    } label: {
                        Label("Clear Seen Cards", systemImage: "trash")
                    }
                    
                    Button {
                        Task {
                            await requestNotificationPermission()
                        }
                    } label: {
                        Label("Request Notification Permission", systemImage: "bell.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.light()
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }
    
    private func clearSeenCards() {
        print("🗑️ Clearing seen cards cache...")
        presetManager.seenCardUUIDs.removeAll()
        UserDefaults.standard.set([], forKey: "com.show26flip.seenCards")
        print("   ✅ Cleared \(presetManager.seenCardUUIDs.count) seen cards")
        Haptics.success()
    }
    
    private func requestNotificationPermission() async {
        print("🔔 Requesting notification permission...")
        let notificationManager = NotificationManager.shared
        await notificationManager.requestAuthorization()
        print("   Authorization status: \(notificationManager.isAuthorized)")
    }
    
    private func testNotification() {
        print("🧪 Testing notification system...")
        
        // Create a test listing
        let testListing = model.listings.first ?? MarketListing(
            listingName: "Test Player",
            bestSellPrice: .value(10000),
            bestBuyPrice: .value(5000),
            item: nil
        )
        
        // Create a test preset
        let testPreset = FilterPreset(
            name: "Test Notification",
            notificationsEnabled: true
        )
        
        // Try to send notification
        let notificationManager = NotificationManager.shared
        notificationManager.sendNotification(for: testListing, preset: testPreset)
        
        print("   Test notification sent!")
    }
}

struct PresetRow: View {
    let preset: FilterPreset
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleNotifications: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                iconView
                VStack(alignment: .leading, spacing: 5) {
                    Text(preset.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text(preset.filterDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                actionsMenu
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.appAccent.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressScaleEffect())
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.appAccent.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: preset.notificationsEnabled ? "bell.fill" : "funnel.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(preset.notificationsEnabled ? Color.spreadGreen : Color.appAccent)
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button {
                onToggleNotifications()
            } label: {
                Label(
                    preset.notificationsEnabled ? "Disable Alerts" : "Enable Alerts",
                    systemImage: preset.notificationsEnabled ? "bell.slash" : "bell"
                )
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.textSecondary)
                .padding(8)
                .background(Color.appSurfaceHi, in: Circle())
        }
    }
}

struct PresetEditSheet: View {
    let preset: FilterPreset?
    let onSave: (FilterPreset) -> Void
    let metaData: MetaData?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedRarity: ListingRarity?
    @State private var selectedPosition: DisplayPosition?
    @State private var selectedSeriesId: Int?
    @State private var minBuyPrice: String = ""
    @State private var maxBuyPrice: String = ""
    @State private var minOverall: String = ""
    @State private var maxOverall: String = ""
    @State private var minProfitPerMinute: String = ""
    @State private var notificationsEnabled: Bool = false

    init(preset: FilterPreset?, onSave: @escaping (FilterPreset) -> Void, metaData: MetaData?) {
        self.preset = preset
        self.onSave = onSave
        self.metaData = metaData
        _name = State(initialValue: preset?.name ?? "")
        _selectedRarity = State(initialValue: preset?.rarity)
        _selectedPosition = State(initialValue: preset?.position)
        _selectedSeriesId = State(initialValue: preset?.seriesId)
        _minBuyPrice = State(initialValue: preset?.minBuyPrice.map(String.init) ?? "")
        _maxBuyPrice = State(initialValue: preset?.maxBuyPrice.map(String.init) ?? "")
        _minOverall = State(initialValue: preset?.minOverall.map(String.init) ?? "")
        _maxOverall = State(initialValue: preset?.maxOverall.map(String.init) ?? "")
        _minProfitPerMinute = State(initialValue: preset?.minProfitPerMinute.map { String(format: "%.0f", $0) } ?? "")
        _notificationsEnabled = State(initialValue: preset?.notificationsEnabled ?? false)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        nameSection
                        raritySection
                        positionSection
                        priceSection
                        overallSection
                        profitPerMinuteSection
                        notificationToggle
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(preset == nil ? "New Filter" : "Edit Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Haptics.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.medium()
                        savePreset()
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PRESET NAME")
            TextField("e.g. Gold Under 3K", text: $name)
                .font(.system(size: 15))
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
        }
    }

    private var raritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("RARITY (OPTIONAL)")
            FlowLayout(spacing: 8) {
                rarityChip(label: "Any", value: nil)
                ForEach(ListingRarity.allCases, id: \.self) { rarity in
                    rarityChip(label: rarity.rawValue.capitalized, value: rarity)
                }
            }
        }
    }

    private func rarityChip(label: String, value: ListingRarity?) -> some View {
        let isSelected = selectedRarity == value
        let style = RarityStyle.from(value?.rawValue)
        return Button {
            Haptics.selection()
            selectedRarity = value
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.appBG : (value == nil ? Color.appAccent : style.primaryColor))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? (value == nil ? Color.appAccent : style.primaryColor) : Color.appSurface)
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

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("POSITION (OPTIONAL)")
            FlowLayout(spacing: 8) {
                positionChip(label: "Any", value: nil)
                ForEach(DisplayPosition.allCases, id: \.self) { pos in
                    positionChip(label: pos.displayName, value: pos)
                }
            }
        }
    }

    private func positionChip(label: String, value: DisplayPosition?) -> some View {
        let isSelected = selectedPosition == value
        return Button {
            Haptics.selection()
            selectedPosition = value
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
                                .strokeBorder(isSelected ? Color.clear : Color.appAccent.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PressScaleEffect())
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("BUY PRICE RANGE (STUBS)")
            HStack(spacing: 12) {
                styledField(placeholder: "Min", text: $minBuyPrice)
                Text("—").foregroundStyle(Color.textTertiary)
                styledField(placeholder: "Max", text: $maxBuyPrice)
            }
        }
    }

    private var overallSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("OVERALL RATING")
            HStack(spacing: 12) {
                styledField(placeholder: "Min", text: $minOverall)
                Text("—").foregroundStyle(Color.textTertiary)
                styledField(placeholder: "Max", text: $maxOverall)
            }
        }
    }

    private var profitPerMinuteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("PROFIT PER MINUTE")
            styledField(placeholder: "Min (e.g. 100)", text: $minProfitPerMinute)
        }
    }

    private var notificationToggle: some View {
        Button {
            Haptics.selection()
            notificationsEnabled.toggle()
        } label: {
            HStack {
                Image(systemName: notificationsEnabled ? "bell.fill" : "bell")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(notificationsEnabled ? Color.spreadGreen : Color.textSecondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Push Notifications")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white)
                    Text("Alert when new cards match this filter")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
                    .tint(Color.spreadGreen)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(notificationsEnabled ? Color.spreadGreen.opacity(0.25) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(Color.textTertiary)
    }

    private func savePreset() {
        let newPreset = FilterPreset(
            id: preset?.id ?? UUID(),
            name: name,
            rarity: selectedRarity,
            position: selectedPosition,
            seriesId: selectedSeriesId,
            minBuyPrice: Int(minBuyPrice),
            maxBuyPrice: Int(maxBuyPrice),
            minOverall: Int(minOverall),
            maxOverall: Int(maxOverall),
            minProfitPerMinute: Double(minProfitPerMinute),
            notificationsEnabled: notificationsEnabled
        )
        onSave(newPreset)
    }
}
