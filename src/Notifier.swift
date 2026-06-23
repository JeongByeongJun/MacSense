import Cocoa

enum Notifier {
    private static let delegate = NotificationDelegate()

    static func configure() {
        NSUserNotificationCenter.default.delegate = delegate
    }

    static func show(title: String, subtitle: String? = nil, message: String) {
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = title
            notification.subtitle = subtitle
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName

            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}

private final class NotificationDelegate: NSObject, NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                shouldPresent notification: NSUserNotification) -> Bool {
        true
    }
}
