import Foundation

struct ShortcutEntry: Codable {
    let appAliases: [String]
    let matchAliases: [String]
    let keys: String
    let description: String
}

private struct ShortcutFile: Codable {
    let shortcuts: [ShortcutEntry]
}

final class ShortcutDB {
    private(set) var entries: [ShortcutEntry] = []
    private(set) var loadedFrom: String = "(none)"

    func load() {
        let candidates = candidatePaths()
        for path in candidates {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            guard let parsed = try? JSONDecoder().decode(ShortcutFile.self, from: data) else { continue }
            entries = parsed.shortcuts
            loadedFrom = path
            print("✅ Shortcut DB: \(entries.count)개 (\(path))")
            return
        }
        print("⚠️  shortcuts.json 못 찾음. 시도한 경로:\n  - " + candidates.joined(separator: "\n  - "))
    }

    private func candidatePaths() -> [String] {
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let exeDir = exe.deletingLastPathComponent()
        let exeParent = exeDir.deletingLastPathComponent()
        let cwd = FileManager.default.currentDirectoryPath
        let bundleResource = Bundle.main.resourceURL?.appendingPathComponent("shortcuts.json").path

        return [
            bundleResource,
            exeDir.appendingPathComponent("shortcuts.json").path,
            exeParent.appendingPathComponent("resources/shortcuts.json").path,
            "\(cwd)/resources/shortcuts.json",
            "\(cwd)/shortcuts.json"
        ].compactMap { $0 }
    }

    func match(app: String, leafLabel: String, path: String) -> ShortcutEntry? {
        let normApp = app.lowercased()
        let normLabel = leafLabel.lowercased()
        let normPath = path.lowercased()

        for entry in entries {
            let appOK = entry.appAliases.contains { $0.lowercased() == normApp }
            guard appOK else { continue }

            let labelOK = entry.matchAliases.contains { alias in
                let n = alias.lowercased()
                return normLabel.contains(n) || normPath.contains(n)
            }
            if labelOK { return entry }
        }
        return nil
    }
}
