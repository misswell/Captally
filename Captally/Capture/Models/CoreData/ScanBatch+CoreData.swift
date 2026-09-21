import CoreData
import Foundation

/// One pass of the screenshot scanner. Device-local, like `ProcessedAsset`.
@objc(ScanBatch)
public class ScanBatch: NSManagedObject {
}

extension ScanBatch {
    @NSManaged public var finishedAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var scannedCount: Int32
    @NSManaged public var startedAt: Date?
    @NSManaged public var status: String?

    var batchStatus: CaptureBatchStatus {
        get { CaptureBatchStatus(rawValue: status ?? "") ?? .running }
        set { status = newValue.rawValue }
    }

    static func begin(in context: NSManagedObjectContext) -> ScanBatch {
        let batch = ScanBatch(context: context)
        batch.id = UUID()
        batch.startedAt = Date()
        batch.status = CaptureBatchStatus.running.rawValue
        batch.scannedCount = 0
        return batch
    }
}
