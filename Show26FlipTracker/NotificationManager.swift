import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published var isAuthorized = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
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

        if let sellPrice = card.bestSellPrice.intValue,
           let buyPrice = card.bestBuyPrice.intValue {
            let net = Int(Double(sellPrice) * 0.90) - buyPrice
            if net > 0 {
                content.subtitle = "+\(net.stubsFormatted) stubs net profit"
            }
        }

        content.userInfo = [
            "cardUUID": card.item?.uuid ?? "",
            "presetID": preset.id.uuidString
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
    
    // Handle notification taps
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("👆 User tapped notification")
        completionHandler()
    }
}
