import CoreData
import Foundation

/// Device-local record that a screenshot has already been read.
///
/// Deliberately not CloudKit-syncable: another device has its own photo library, and syncing
/// identifiers would make one device skip screenshots the other has never seen.
@objc(ProcessedAsset)
public class ProcessedAsset: NSManagedObject {
}

extension ProcessedAsset {
    @NSManaged public var assetIdentifier: String?
    @NSManaged public var assetCreationDate: Date?
    @NSManaged public var batchID: UUID?
    @NSManaged public var firstSeenAt: Date?
    @NSManaged public var lastScannedAt: Date?
    @NSManaged public var outcome: String?
    @NSManaged public var retryCount: Int32

    var scanOutcome: AssetScanOutcome {
        get { AssetScanOutcome(rawValue: outcome ?? "") ?? .pending }
        set { outcome = newValue.rawValue }
    }

    @discardableResult
    static func record(
        _ info: ScreenshotAssetInfo,
        batchID: UUID?,
        in context: NSManagedObjectContext
    ) -> ProcessedAsset {
        let asset = ProcessedAsset(context: context)
        asset.assetIdentifier = info.identifier
        asset.assetCreationDate = info.creationDate
        asset.batchID = batchID
        asset.firstSeenAt = Date()
        asset.lastScannedAt = Date()
        asset.outcome = AssetScanOutcome.pending.rawValue
        asset.retryCount = 0
        return asset
    }
}
