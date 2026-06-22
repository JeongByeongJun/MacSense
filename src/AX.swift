import Cocoa
import ApplicationServices

struct ClickEvent {
    let timestamp: Date
    let app: String
    let path: String
    let leafRole: String
    let leafLabel: String

    var patternKey: String {
        "\(app)::\(path)"
    }
}

func checkAXPermission() -> Bool {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    return AXIsProcessTrustedWithOptions(opts as CFDictionary)
}

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

func extractLabel(_ el: AXUIElement, role: String) -> String {
    if let t = axString(el, kAXTitleAttribute as String) { return t }
    if let d = axString(el, kAXDescriptionAttribute as String) { return d }
    if let h = axString(el, kAXHelpAttribute as String) { return h }

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

func describeElement(at point: CGPoint) -> ClickEvent? {
    let systemWide = AXUIElementCreateSystemWide()
    var element: AXUIElement?
    let result = AXUIElementCopyElementAtPosition(
        systemWide, Float(point.x), Float(point.y), &element
    )

    guard result == .success, let el = element else { return nil }

    var pid: pid_t = 0
    AXUIElementGetPid(el, &pid)
    let appName = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"

    var path: [(String, String)] = [roleAndLabel(el)]
    var current = axParent(el)
    var depth = 0
    while let cur = current, depth < 6 {
        path.insert(roleAndLabel(cur), at: 0)
        current = axParent(cur)
        depth += 1
    }

    let pathStr = path.map { "\($0.0):\($0.1)" }.joined(separator: " > ")
    let leaf = path.last ?? ("?", "?")

    return ClickEvent(
        timestamp: Date(),
        app: appName,
        path: pathStr,
        leafRole: leaf.0,
        leafLabel: leaf.1
    )
}
