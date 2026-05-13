import SwiftUI

struct PresetListSheet: View {
    @Bindable var presetManager: PresetManager
    @Bindable var model: ListingsViewModel
    @State private var showingAddSheet = false
    @State private var editingPreset: FilterPreset?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                contentView
            }
            .navigationTitle("Filter Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
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
        if presetManager.presets.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(presetManager.presets) { preset in
                        PresetRow(
                            preset: preset,
                            onTap: {
                                Haptics.medium()
                                model.applyPreset(preset)
                                dismiss()
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
                                if wasEnabled {
                                    model.checkPresetImmediately(preset)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Saved Presets")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white)
                
                Text("Create a preset to save your favorite filter combinations and get notified when matching cards appear.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                Haptics.medium()
                showingAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Preset")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appBG)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.appAccent, in: Capsule())
            }
            .buttonStyle(PressScaleEffect())
            .padding(.top, 8)
        }
    }
}
