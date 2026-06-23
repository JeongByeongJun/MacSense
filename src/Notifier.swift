import Foundation
import UserNotifications

enum Notifier {
    private static let delegate = NotificationDelegate()

    static func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("❌ 알림 권한 요청 실패: \(error.localizedDescription)")
                return
            }
            print(granted ? "✅ 알림 권한 허용됨" : "⚠️  알림 권한 거부됨")
        }
    }

    static func show(title: String, subtitle: String? = nil, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "macsense-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 알림 전송 실패: \(error.localizedDescription)")
            } else {
                print("🔔 알림 전송: \(title) — \(message)")
            }
        }
    }
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
