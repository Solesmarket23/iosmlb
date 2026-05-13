import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published var isAuthorized = false
    
    // Notification action identifiers
    private let copyNameActionID = "COPY_NAME_ACTION"
    private let flipMatchCategoryID = "FLIP_MATCH_CATEGORY"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationActions()
    }
    
    private func setupNotificationActions() {
        // Create the "Copy Name" action
        let copyNameAction = UNNotificationAction(
            identifier: copyNameActionID,
            title: "Copy Name",
            options: [.foreground]
        )
        
        // Create the category with the action
        let flipMatchCategory = UNNotificationCategory(
            identifier: flipMatchCategoryID,
            actions: [copyNameAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([flipMatchCategory])
        print("🔔 Notification actions registered")
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                Haptics.success()
            }
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    func sendNotification(for card: MarketListing, preset: FilterPreset) {
        print("📬 Attempting to send notification...")
        print("   Authorized: \(isAuthorized)")
        print("   Card: \(card.item?.name ?? card.listingName)")
        print("   Preset: \(preset.name)")
        
        guard isAuthorized else {
            print("   ❌ Not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "New Flip Match"
        content.body = "\(card.item?.name ?? card.listingName) matches \"\(preset.name)\""
        content.sound = .default
        content.categoryIdentifier = flipMatchCategoryID // Add category for actions

        if let sellPrice = card.bestSellPrice.intValue,
           let buyPrice = card.bestBuyPrice.intValue {
            let net = Int(Double(sellPrice) * 0.90) - buyPrice
            if net > 0 {
                content.subtitle = "+\(net.stubsFormatted) stubs net profit"
            }
        }

        content.userInfo = [
            "cardUUID": card.item?.uuid ?? "",
            "presetID": preset.id.uuidString,
            "playerName": card.item?.name ?? card.listingName // Add player name for copying
        ]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("   ❌ Notification send failed: \(error)")
            } else {
                print("   ✅ Notification sent successfully")
            }
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // This allows notifications to show while app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 Notification will present in foreground")
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification taps and actions
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "COPY_NAME_ACTION":
            // User tapped "Copy Name" button
            if let playerName = userInfo["playerName"] as? String {
                print("📋 Copying player name: \(playerName)")
                Task { @MainActor in
                    UIPasteboard.general.string = playerName
                    Haptics.success()
                }
            }
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            print("👆 User tapped notification")
            
        default:
            break
        }
        
        completionHandler()
    }
}
