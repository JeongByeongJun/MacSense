import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class Storage {
    static let shared = Storage()

    private var db: OpaquePointer?
    private(set) var dbPath: String = ""

    @discardableResult
    func open() -> Bool {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        let dir = support.appendingPathComponent("MacSense", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent("events.db")
        dbPath = url.path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ SQLite open 실패: \(dbPath)")
            return false
        }

        let schema = """
        CREATE TABLE IF NOT EXISTS events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ts REAL NOT NULL,
          app TEXT NOT NULL,
          path TEXT NOT NULL,
          leaf_role TEXT NOT NULL,
          leaf_label TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_events_app_path ON events(app, path);
        CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
        """
        if sqlite3_exec(db, schema, nil, nil, nil) != SQLITE_OK {
            print("❌ schema 생성 실패")
            return false
        }

        print("✅ DB: \(dbPath)")
        return true
    }

    func insert(_ event: ClickEvent) {
        let sql = "INSERT INTO events (ts, app, path, leaf_role, leaf_label) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, event.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 2, event.app, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, event.path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, event.leafRole, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, event.leafLabel, -1, SQLITE_TRANSIENT)

        sqlite3_step(stmt)
    }

    func count(app: String, path: String, withinSeconds seconds: TimeInterval) -> Int {
        let sql = "SELECT COUNT(*) FROM events WHERE app = ? AND path = ? AND ts >= ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        let since = Date().timeIntervalSince1970 - seconds
        sqlite3_bind_text(stmt, 1, app, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, path, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, since)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    func totalCount() -> Int {
        let sql = "SELECT COUNT(*) FROM events;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
}
