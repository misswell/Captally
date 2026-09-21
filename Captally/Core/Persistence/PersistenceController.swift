import CoreData

/// Owns the Core Data stack and the CloudKit-backed store.
///
/// `static let shared` only remains so the ledger views ported from the upstream base keep compiling;
/// new code receives an instance through `AppEnvironment` and must not reference it.
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer
    let inMemory: Bool

    init(inMemory: Bool = false, storeURL: URL? = nil) {
        self.inMemory = inMemory
        container = NSPersistentCloudKitContainer(name: "Captally")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Core Data model has no persistent store description")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            // An ephemeral store cannot mirror to CloudKit; leaving the options set makes the
            // store fail to load in previews and tests.
            description.cloudKitContainerOptions = nil
        } else {
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true

            if let storeURL {
                // Scratch store used by the tests that have to prove state survives a relaunch.
                description.url = storeURL
                description.cloudKitContainerOptions = nil
            } else {
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

                #if targetEnvironment(simulator)
                // CloudKit has no simulator account support; run local-only so the app still launches.
                description.cloudKitContainerOptions = nil
                #else
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: CaptallyConfiguration.cloudKitContainerIdentifier
                )
                #endif
            }
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                CaptallyLog.persistence.error(
                    "store load failed code=\(error.code, privacy: .public) domain=\(error.domain, privacy: .public)"
                )
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            block(context)
            Self.saveIfNeeded(in: context)
        }
    }

    /// Runs work on a private context and resumes only after that context has been saved, so
    /// callers can read back what they just wrote.
    func perform<T>(_ work: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            container.performBackgroundTask { context in
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                do {
                    let result = try work(context)
                    Self.saveIfNeeded(in: context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Saves the view context. The failure is returned for callers that can show it and logged
    /// either way, so a lost write is never silent.
    @discardableResult
    func save() -> Error? {
        guard viewContext.hasChanges else { return nil }
        do {
            try viewContext.save()
            return nil
        } catch {
            CaptallyLog.persistence.error("viewContext save failed: \(error.localizedDescription, privacy: .public)")
            return error
        }
    }

    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        save()
    }

    static func saveIfNeeded(in context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            CaptallyLog.persistence.error("context save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
