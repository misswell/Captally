import CoreData
import Foundation

/// Device-local bookkeeping of which screenshots Captally has already read.
///
/// This single table is what makes scanning incremental, stops a re-dated or restored screenshot
/// from being tallied twice, and lets the app restart mid-scan without losing the thread: the
/// verdict is stored the moment it is known, and only unfinished rows come back for a retry.
protocol CaptureStateStoring: Sendable {
    /// Screenshots the scanner must leave alone: they either reached a verdict or burned their
    /// retry budget. Everything registered but unsettled stays eligible, so a screenshot left
    /// `pending` by a crash or by an upgrade is read again instead of being lost.
    func settledIdentifiers(maxRetries: Int) async -> Set<String>
    func processedCount() async -> Int
    func beginBatch() async -> UUID
    func endBatch(_ id: UUID, status: CaptureBatchStatus, scannedCount: Int) async
    func register(_ assets: [ScreenshotAssetInfo], batchID: UUID) async
    func setOutcome(_ outcome: AssetScanOutcome, for identifier: String) async
}

enum CaptureStateStoreError: Error, Equatable {
    case unknownAsset(String)
}

actor CoreDataCaptureStateStore: CaptureStateStoring {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func settledIdentifiers(maxRetries: Int) async -> Set<String> {
        let rows: [SettledRow] = (try? await persistence.perform { context in
            let request = NSFetchRequest<NSDictionary>(entityName: "ProcessedAsset")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["assetIdentifier", "outcome", "retryCount"]
            return ((try? context.fetch(request)) ?? []).compactMap { row in
                guard let identifier = row["assetIdentifier"] as? String else { return nil }
                return SettledRow(
                    identifier: identifier,
                    outcome: AssetScanOutcome(rawValue: row["outcome"] as? String ?? "") ?? .pending,
                    retryCount: (row["retryCount"] as? NSNumber)?.int32Value ?? 0
                )
            }
        }) ?? []
        return Set(rows.filter { $0.settles(for: maxRetries) }.map(\.identifier))
    }

    func processedCount() async -> Int {
        (try? await persistence.perform { context in
            try context.count(for: NSFetchRequest<ProcessedAsset>(entityName: "ProcessedAsset"))
        }) ?? 0
    }

    func beginBatch() async -> UUID {
        (try? await persistence.perform { context in
            ScanBatch.begin(in: context).id ?? UUID()
        }) ?? UUID()
    }

    func endBatch(_ id: UUID, status: CaptureBatchStatus, scannedCount: Int) async {
        _ = try? await persistence.perform { context in
            let request = NSFetchRequest<ScanBatch>(entityName: "ScanBatch")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let batch = try? context.fetch(request).first else { return }
            batch.batchStatus = status
            batch.scannedCount = Int32(scannedCount)
            batch.finishedAt = Date()
        }
    }

    func register(_ assets: [ScreenshotAssetInfo], batchID: UUID) async {
        guard !assets.isEmpty else { return }
        _ = try? await persistence.perform { context in
            let known = Set(try Self.identifiers(in: context))
            for info in assets where !known.contains(info.identifier) {
                ProcessedAsset.record(info, batchID: batchID, in: context)
            }
        }
    }

    func setOutcome(_ outcome: AssetScanOutcome, for identifier: String) async {
        _ = try? await persistence.perform { context in
            let request = NSFetchRequest<ProcessedAsset>(entityName: "ProcessedAsset")
            request.predicate = NSPredicate(format: "assetIdentifier == %@", identifier)
            request.fetchLimit = 1
            guard let asset = try context.fetch(request).first else {
                throw CaptureStateStoreError.unknownAsset(identifier)
            }
            asset.scanOutcome = outcome
            asset.lastScannedAt = Date()
            if outcome == .failed {
                asset.retryCount += 1
            }
        }
    }

    /// Reads just the identifier column: a library can hold tens of thousands of screenshots.
    private static func identifiers(in context: NSManagedObjectContext) throws -> [String] {
        let request = NSFetchRequest<NSDictionary>(entityName: "ProcessedAsset")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["assetIdentifier"]
        return try context.fetch(request).compactMap { $0["assetIdentifier"] as? String }
    }

    private struct SettledRow {
        let identifier: String
        let outcome: AssetScanOutcome
        let retryCount: Int32

        func settles(for maxRetries: Int) -> Bool {
            if outcome.isTerminal { return true }
            return outcome == .failed && Int(retryCount) >= max(1, maxRetries)
        }
    }
}
