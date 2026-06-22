import Foundation

struct DetectedPattern {
    let app: String
    let path: String
    let leafRole: String
    let leafLabel: String
    let count: Int
}

final class Detector {
    var onPattern: ((DetectedPattern) -> Void)?

    private let threshold: Int
    private let windowSeconds: TimeInterval
    private let cooldownSeconds: TimeInterval

    private var recentlyAlerted: [String: Date] = [:]

    private let noiseRoles: Set<String> = [
        "AXWindow", "AXScrollArea", "AXSplitGroup", "AXUnknown", "?"
    ]

    init(threshold: Int = 3,
         windowSeconds: TimeInterval = 300,
         cooldownSeconds: TimeInterval = 3600) {
        self.threshold = threshold
        self.windowSeconds = windowSeconds
        self.cooldownSeconds = cooldownSeconds
    }

    func observe(_ event: ClickEvent) {
        guard !event.leafLabel.isEmpty else { return }
        guard !noiseRoles.contains(event.leafRole) else { return }

        let key = event.patternKey

        if let last = recentlyAlerted[key],
           Date().timeIntervalSince(last) < cooldownSeconds {
            return
        }

        let count = Storage.shared.count(
            app: event.app,
            path: event.path,
            withinSeconds: windowSeconds
        )

        if count >= threshold {
            recentlyAlerted[key] = Date()
            let pattern = DetectedPattern(
                app: event.app,
                path: event.path,
                leafRole: event.leafRole,
                leafLabel: event.leafLabel,
                count: count
            )
            onPattern?(pattern)
        }
    }
}
