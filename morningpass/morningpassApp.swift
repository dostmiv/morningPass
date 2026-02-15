import SwiftUI
import SwiftData

@main
struct morningpassApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try Self.makeContainer()
        } catch {
            fatalError("Failed to initialize local database: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

private extension morningpassApp {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([AlarmItem.self])
        let storeURL = try storeFileURL()
        let config = ModelConfiguration("MorningPassDB", schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            try removeStoreFiles(at: storeURL)
            return try ModelContainer(for: schema, configurations: [config])
        }
    }

    static func storeFileURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("MorningPassDB.store")
    }

    static func removeStoreFiles(at url: URL) throws {
        let fm = FileManager.default
        let paths = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
        for path in paths where fm.fileExists(atPath: path.path) {
            try fm.removeItem(at: path)
        }
    }
}
