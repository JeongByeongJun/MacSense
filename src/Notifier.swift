import Foundation

enum Notifier {
    static func show(title: String, subtitle: String? = nil, message: String) {
        var body = "display notification \"\(escape(message))\""
        body += " with title \"\(escape(title))\""
        if let sub = subtitle, !sub.isEmpty {
            body += " subtitle \"\(escape(sub))\""
        }

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", body]
        do {
            try task.run()
        } catch {
            print("❌ 알림 실패: \(error)")
        }
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
