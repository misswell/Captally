import CoreData
import Foundation

/// Dependency container injected at the SwiftUI root.
///
/// Everything Captally's own code needs is reached from here. The ledger views ported from the
/// upstream base still resolve a few singletons directly; new code must not.
@MainActor
final class AppEnvironment: ObservableObject {
    let persistence: PersistenceController
    let transactionRepository: any TransactionRepository
    let capture: CaptallyPipeline

    init(persistence: PersistenceController = .shared) {
        // Defaults to the one container the ported ledger view models still resolve, because two
        // `NSPersistentCloudKitContainer` instances over one store split the ledger in half.
        // Retiring the view models' dependency on it is what removes this default again.
        self.persistence = persistence
        self.transactionRepository = CoreDataTransactionRepository(persistence: persistence)
        self.capture = CaptallyPipeline(
            state: CoreDataCaptureStateStore(persistence: persistence)
        )
    }

    /// In-memory environment for previews and tests; never touches the CloudKit-backed store.
    static func ephemeral() -> AppEnvironment {
        AppEnvironment(persistence: PersistenceController(inMemory: true))
    }
}
