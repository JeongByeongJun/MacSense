import Cocoa

final class EventTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onClick: ((ClickEvent) -> Void)?

    func start() -> Bool {
        let mask = (1 << CGEventType.leftMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            if type == .leftMouseDown, let userInfo = userInfo {
                let loc = event.location
                let tapSelf = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
                if let ev = describeElement(at: loc) {
                    DispatchQueue.main.async {
                        tapSelf.onClick?(ev)
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let createdTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: selfPtr
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: createdTap, enable: true)

        self.tap = createdTap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }
}
