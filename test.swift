import Cocoa
import ApplicationServices

// MARK: - Permission

func checkAXPermission() -> Bool {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    return AXIsProcessTrustedWithOptions(opts as CFDictionary)
}

// MARK: - AX Helpers

func axString(_ el: AXUIElement, _ attr: String) -> String? {
    var ref: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(el, attr as CFString, &ref)
    guard result == .success, let s = ref as? String, !s.isEmpty else { return nil }
    return s
}

func axChildren(_ el: AXUIElement) -> [AXUIElement] {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success,
          let children = ref as? [AXUIElement] else { return [] }
    return children
}

func axParent(_ el: AXUIElement) -> AXUIElement? {
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &ref) == .success,
          let parent = ref else { return nil }
    return (parent as! AXUIElement)
}

/// 라벨 추출: title → description → help → 자식의 title/description 순으로 시도
func extractLabel(_ el: AXUIElement, role: String) -> String {
    if let t = axString(el, kAXTitleAttribute as String) { return t }
    if let d = axString(el, kAXDescriptionAttribute as String) { return d }
    if let h = axString(el, kAXHelpAttribute as String) { return h }
    
    // 컨테이너성 role은 자식 살짝 까보기
    let containers: Set<String> = ["AXCell", "AXGroup", "AXRow", "AXImage", "AXButton"]
    if containers.contains(role) {
        for child in axChildren(el).prefix(5) {
            if let t = axString(child, kAXTitleAttribute as String) { return t }
            if let d = axString(child, kAXDescriptionAttribute as String) { return d }
        }
    }
    return ""
}

func roleAndLabel(_ el: AXUIElement) -> (String, String) {
    let role = axString(el, kAXRoleAttribute as String) ?? "?"
    return (role, extractLabel(el, role: role))
}

// MARK: - Click handler

func describeElement(at point: CGPoint) {
    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    let result = AXUIElementCopyElementAtPosition(
        systemWide, Float(point.x), Float(point.y), &element
    )
    
    guard result == .success, let el = element else {
        print("  ❌ 요소 못 가져옴 (\(result.rawValue))")
        return
    }
    
    // 앱 이름
    var pid: pid_t = 0
    AXUIElementGetPid(el, &pid)
    let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
    
    // 경로 (leaf 포함 최대 7단계)
    var path: [(String, String)] = [roleAndLabel(el)]
    var current = axParent(el)
    var depth = 0
    while let cur = current, depth < 6 {
        path.insert(roleAndLabel(cur), at: 0)
        current = axParent(cur)
        depth += 1
    }
    
    let pathStr = path.map { "\($0.0):\($0.1)" }.joined(separator: " > ")
    print("  📍 \(appName) | \(pathStr)")
}

// MARK: - Event tap

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .leftMouseDown {
        let loc = event.location
        print("🖱  클릭 (\(Int(loc.x)), \(Int(loc.y)))")
        describeElement(at: loc)
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Main

guard checkAXPermission() else {
    print("⚠️  시스템 설정 → 개인정보 보호 → 접근성에서 Terminal/iTerm 허용 후 다시 실행")
    exit(1)
}

let mask = (1 << CGEventType.leftMouseDown.rawValue)
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: callback,
    userInfo: nil
) else {
    print("❌ EventTap 생성 실패. 입력 모니터링 권한 확인")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("✅ 시작됨. 클릭 테스트 ㄱㄱ. Ctrl+C로 종료.\n")
CFRunLoopRun()