import SwiftUI

struct PlayerDetailSheet: View {
    let card: DetailedItemCard
    @Environment(\.dismiss) private var dismiss
    
    private var rarityStyle: RarityStyle {
        RarityStyle.from(card.rarity)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        playerHeader
                        
                        if card.isHitter == false {
                            pitchingSection
                            if let pitches = card.pitches, !pitches.isEmpty {
                                pitchesSection(pitches)
                            }
                        } else {
                            hittingSection
                        }
                        
                        fieldingSection
                        bioSection
                        
                        if let quirks = card.quirks, !quirks.isEmpty {
                            quirksSection(quirks)
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
    
    // MARK: - Player Header
    
    private var playerHeader: some View {
        VStack(spacing: 16) {
            // OVR Badge
            if let ovr = card.ovr {
                Text("\(ovr)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(rarityStyle.textColor)
                    .padding(20)
                    .background(
                        Circle()
                            .fill(rarityStyle.primaryColor)
                            .shadow(color: rarityStyle.primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
            }
            
            // Player Name
            Text(card.name ?? "Unknown Player")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white)
            
            // Metadata
            HStack(spacing: 12) {
                if let position = card.displayPosition {
                    metadataPill(icon: "figure.baseball", text: position)
                }
                if let team = card.teamShortName {
                    metadataPill(icon: "shield.fill", text: team)
                }
                if let series = card.series {
                    metadataPill(icon: "star.fill", text: series)
                }
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
        .background(rarityStyle.primaryColor.opacity(0.2), in: Capsule())
    }
    
    // MARK: - Pitching Section
    
    private var pitchingSection: some View {
        statsCard(title: "Pitching", icon: "figure.baseball.circle") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                if let stamina = card.stamina {
                    statBar(label: "Stamina", value: stamina)
                }
                if let clutch = card.pitchingClutch {
                    statBar(label: "Clutch", value: clutch)
                }
                if let velocity = card.pitchVelocity {
                    statBar(label: "Velocity", value: velocity)
                }
                if let control = card.pitchControl {
                    statBar(label: "Control", value: control)
                }
                if let movement = card.pitchMovement {
                    statBar(label: "Movement", value: movement)
                }
                if let kRate = card.kPerBf {
                    statBar(label: "K/9", value: kRate)
                }
                if let bbRate = card.bbPerBf {
                    statBar(label: "BB/9", value: bbRate)
                }
                if let hrRate = card.hrPerBf {
                    statBar(label: "HR/9", value: hrRate)
                }
            }
        }
    }
    
    private func pitchesSection(_ pitches: [PitchInfo]) -> some View {
        statsCard(title: "Pitches", icon: "baseball.fill") {
            VStack(spacing: 12) {
                ForEach(pitches) { pitch in
                    pitchRow(pitch)
                }
            }
        }
    }
    
    private func pitchRow(_ pitch: PitchInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pitch.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                Spacer()
                if let speed = pitch.speed {
                    Text("\(speed) MPH")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appAccent)
                }
            }
            
            HStack(spacing: 12) {
                if let control = pitch.control {
                    miniStatBar(label: "Control", value: control)
                }
                if let movement = pitch.movement {
                    miniStatBar(label: "Movement", value: movement)
                }
            }
        }
        .padding(12)
        .background(Color.appBG, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Hitting Section
    
    private var hittingSection: some View {
        statsCard(title: "Hitting", icon: "figure.baseball.circle.fill") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                if let conL = card.contactLeft {
                    statBar(label: "Contact (L)", value: conL)
                }
                if let conR = card.contactRight {
                    statBar(label: "Contact (R)", value: conR)
                }
                if let pwrL = card.powerLeft {
                    statBar(label: "Power (L)", value: pwrL)
                }
                if let pwrR = card.powerRight {
                    statBar(label: "Power (R)", value: pwrR)
                }
                if let vision = card.plateVision {
                    statBar(label: "Vision", value: vision)
                }
                if let discipline = card.plateDiscipline {
                    statBar(label: "Discipline", value: discipline)
                }
                if let clutch = card.battingClutch {
                    statBar(label: "Clutch", value: clutch)
                }
                if let bunt = card.buntingAbility {
                    statBar(label: "Bunting", value: bunt)
                }
            }
        }
    }
    
    // MARK: - Fielding Section
    
    private var fieldingSection: some View {
        statsCard(title: "Fielding & Speed", icon: "glove.fill") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                if let fielding = card.fieldingAbility {
                    statBar(label: "Fielding", value: fielding)
                }
                if let arm = card.armStrength {
                    statBar(label: "Arm Strength", value: arm)
                }
                if let accuracy = card.armAccuracy {
                    statBar(label: "Accuracy", value: accuracy)
                }
                if let reaction = card.reactionTime {
                    statBar(label: "Reaction", value: reaction)
                }
                if let speed = card.speed {
                    statBar(label: "Speed", value: speed)
                }
                if let baserunning = card.baserunningAbility {
                    statBar(label: "Baserunning", value: baserunning)
                }
            }
        }
    }
    
    // MARK: - Bio Section
    
    private var bioSection: some View {
        statsCard(title: "Player Info", icon: "person.text.rectangle") {
            VStack(spacing: 12) {
                if let age = card.age {
                    bioRow(label: "Age", value: "\(age) years old")
                }
                if let height = card.height {
                    bioRow(label: "Height", value: height)
                }
                if let weight = card.weight {
                    bioRow(label: "Weight", value: weight)
                }
                if let jersey = card.jerseyNumber {
                    bioRow(label: "Jersey", value: "#\(jersey)")
                }
                if let born = card.born {
                    bioRow(label: "Born", value: born)
                }
                if let bats = card.batHand {
                    bioRow(label: "Bats", value: bats == "L" ? "Left" : "Right")
                }
                if let throwsHand = card.throwHand {
                    bioRow(label: "Throws", value: throwsHand == "L" ? "Left" : "Right")
                }
            }
        }
    }
    
    private func bioRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white)
        }
    }
    
    // MARK: - Quirks Section
    
    private func quirksSection(_ quirks: [Quirk]) -> some View {
        statsCard(title: "Quirks", icon: "sparkles") {
            VStack(spacing: 10) {
                ForEach(quirks) { quirk in
                    quirkRow(quirk)
                }
            }
        }
    }
    
    private func quirkRow(_ quirk: Quirk) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.appAccent)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(quirk.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                if let description = quirk.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.appBG, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Stat Components
    
    private func statsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.appAccent)
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appSurface)
        )
    }
    
    private func statBar(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.appBG)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(statColor(for: value))
                        .frame(width: geometry.size.width * CGFloat(value) / 99.0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    private func miniStatBar(label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textSecondary)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.appSurface)
                    .frame(width: 60, height: 4)
                
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(statColor(for: value))
                    .frame(width: 60 * CGFloat(value) / 99.0, height: 4)
            }
            
            Text("\(value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
        }
    }
    
    private func statColor(for value: Int) -> Color {
        switch value {
        case 80...99: return Color.spreadGreen
        case 60...79: return Color.appAccent
        case 40...59: return Color.priceAmber
        default: return Color.spreadRed
        }
    }
}
