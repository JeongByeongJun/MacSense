import Cocoa
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let eventTap = EventTap()
    private let detector = Detector(threshold: 3, windowSeconds: 300, cooldownSeconds: 1800)
    private let shortcutDB = ShortcutDB()
    private let llm = LLMClient()

    private var sessionClicks = 0
    private var lastEventLabel = "—"
    private var statusMenuItem: NSMenuItem!
    private var countMenuItem: NSMenuItem!
    private var lastMenuItem: NSMenuItem!
    private var dbMenuItem: NSMenuItem!
    private var patternMenuItem: NSMenuItem!
    private var recommendationMenuItem: NSMenuItem!
    private var automationMenuItem: NSMenuItem!
    private var openShortcutsMenuItem: NSMenuItem!
    private var latestAutomationSuggestion: String?
    private let supportedApps: Set<String> = ["Finder", "Google Chrome", "Chrome", "Notes", "메모"]
    private let recommendableRoles: Set<String> = ["AXMenuItem", "AXButton"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard checkAXPermission() else {
            print("⚠️  접근성 권한 필요. 시스템 설정 → 개인정보 보호 → 접근성에서 허용 후 재실행.")
            NSApp.terminate(nil)
            return
        }

        if !Storage.shared.open() {
            print("❌ Storage 초기화 실패")
            NSApp.terminate(nil)
            return
        }

        shortcutDB.load()
        Notifier.configure()

        setupStatusBar()

        eventTap.onClick = { [weak self] event in
            self?.handle(event)
        }

        detector.onPattern = { [weak self] pattern in
            self?.handlePattern(pattern)
        }

        if !eventTap.start() {
            print("❌ EventTap 생성 실패. 입력 모니터링 권한 확인.")
            NSApp.terminate(nil)
            return
        }

        print("✅ MacSense 시작됨 (메뉴바 💡)")
        Notifier.show(
            title: "MacSense 실행 중",
            subtitle: "데모 준비 완료",
            message: "반복 행동을 감지하고 있습니다"
        )
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "💡"
            button.toolTip = "MacSense — 행동 패턴 감지 중"
        }

        let menu = NSMenu()

        let header = NSMenuItem(title: "MacSense", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        statusMenuItem = NSMenuItem(title: "상태: 감지 중", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        countMenuItem = NSMenuItem(title: "이번 세션: 0회", action: nil, keyEquivalent: "")
        countMenuItem.isEnabled = false
        menu.addItem(countMenuItem)

        dbMenuItem = NSMenuItem(title: "DB 누적: \(Storage.shared.totalCount())회", action: nil, keyEquivalent: "")
        dbMenuItem.isEnabled = false
        menu.addItem(dbMenuItem)

        lastMenuItem = NSMenuItem(title: "마지막: —", action: nil, keyEquivalent: "")
        lastMenuItem.isEnabled = false
        menu.addItem(lastMenuItem)

        menu.addItem(NSMenuItem.separator())

        patternMenuItem = NSMenuItem(title: "감지된 패턴: 아직 없음", action: nil, keyEquivalent: "")
        patternMenuItem.isEnabled = false
        menu.addItem(patternMenuItem)

        recommendationMenuItem = NSMenuItem(title: "추천 단축키: —", action: nil, keyEquivalent: "")
        recommendationMenuItem.isEnabled = false
        menu.addItem(recommendationMenuItem)

        automationMenuItem = NSMenuItem(title: "자동화 제안: —", action: nil, keyEquivalent: "")
        automationMenuItem.isEnabled = false
        menu.addItem(automationMenuItem)

        menu.addItem(NSMenuItem.separator())

        openShortcutsMenuItem = NSMenuItem(title: "Shortcuts에서 만들기", action: #selector(openShortcuts), keyEquivalent: "s")
        openShortcutsMenuItem.target = self
        openShortcutsMenuItem.isEnabled = false
        menu.addItem(openShortcutsMenuItem)

        let quit = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func handle(_ event: ClickEvent) {
        guard shouldTrack(event) else { return }

        Storage.shared.insert(event)

        sessionClicks += 1
        lastEventLabel = "[\(event.app)] \(event.leafRole):\(event.leafLabel)"
        countMenuItem.title = "이번 세션: \(sessionClicks)회"
        dbMenuItem.title = "DB 누적: \(Storage.shared.totalCount())회"
        lastMenuItem.title = "마지막: \(lastEventLabel)"
        print("🖱 \(event.app) | \(event.path)")

        detector.observe(event)
    }

    private func shouldTrack(_ event: ClickEvent) -> Bool {
        guard supportedApps.contains(event.app) else { return false }
        guard recommendableRoles.contains(event.leafRole) else { return false }
        guard !event.leafLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }

    private func handlePattern(_ pattern: DetectedPattern) {
        print("🔥 패턴 감지: [\(pattern.app)] \(pattern.leafLabel) — \(pattern.count)회 반복")
        patternMenuItem.title = "감지: \(pattern.leafLabel) (\(pattern.count)회)"

        if let entry = shortcutDB.match(app: pattern.app, leafLabel: pattern.leafLabel, path: pattern.path) {
            print("💡 추천: \(entry.keys) — \(entry.description)")
            recommendationMenuItem.title = "추천: \(entry.keys)  (\(entry.description))"
            clearAutomationSuggestion()

            Notifier.show(
                title: "오늘 \(pattern.count)번 반복하셨어요",
                subtitle: "\(pattern.app) · \(pattern.leafLabel)",
                message: "\(entry.keys) — \(entry.description)"
            )
        } else {
            print("🤖 DB 미스 — LLM 폴백")
            recommendationMenuItem.title = "추천: (AI 분석 중…)"
            automationMenuItem.title = "자동화 제안: 분석 중…"
            openShortcutsMenuItem.isEnabled = false

            Notifier.show(
                title: "반복 패턴 감지 (\(pattern.count)회)",
                subtitle: "\(pattern.app) · \(pattern.leafLabel)",
                message: "Shortcuts 자동화 방법을 찾는 중…"
            )

            llm.suggest(for: pattern) { [weak self] suggestion in
                guard let self = self else { return }
                if let text = suggestion {
                    print("🤖 자동화 제안: \(text)")
                    self.recommendationMenuItem.title = "추천: 공식 단축키 없음"
                    self.setAutomationSuggestion(text)
                    Notifier.show(
                        title: "자동화 제안 도착",
                        subtitle: "\(pattern.app) · \(pattern.leafLabel)",
                        message: text
                    )
                } else {
                    self.recommendationMenuItem.title = "추천: 공식 단축키 없음"
                    self.automationMenuItem.title = "자동화 제안: 응답 없음"
                    self.openShortcutsMenuItem.isEnabled = false
                }
            }
        }
    }

    private func setAutomationSuggestion(_ text: String) {
        latestAutomationSuggestion = text
        automationMenuItem.title = "자동화 제안: \(shortMenuText(text))"
        openShortcutsMenuItem.isEnabled = true
    }

    private func clearAutomationSuggestion() {
        latestAutomationSuggestion = nil
        automationMenuItem.title = "자동화 제안: —"
        openShortcutsMenuItem.isEnabled = false
    }

    private func shortMenuText(_ text: String, maxLength: Int = 54) -> String {
        let singleLine = text
            .replacingOccurrences(of: "\n", with: " / ")
            .replacingOccurrences(of: "  ", with: " ")

        if singleLine.count <= maxLength {
            return singleLine
        }

        let end = singleLine.index(singleLine.startIndex, offsetBy: maxLength)
        return String(singleLine[..<end]) + "..."
    }

    @objc private func openShortcuts() {
        let appURL = URL(fileURLWithPath: "/System/Applications/Shortcuts.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { [weak self] _, error in
            if let error = error {
                print("❌ Shortcuts 열기 실패: \(error.localizedDescription)")
                return
            }

            if let suggestion = self?.latestAutomationSuggestion {
                print("🛠 Shortcuts 생성 가이드:\n\(suggestion)")
            }
        }
    }

    @objc private func quit() {
        eventTap.stop()
        Storage.shared.close()
        NSApp.terminate(nil)
    }
}
