import Foundation

/// The single source of truth for build-linked identifiers.
///
/// The CloudKit container is derived from `PRODUCT_BUNDLE_IDENTIFIER` through Info.plist
/// substitution rather than a Swift literal, so the entitlements and the code cannot drift apart.
/// The upstream base this project started from shipped five hardcoded container strings.
enum CaptallyConfiguration {
    static let bundleIdentifier = "com.misswell.Captally"

    static let cloudKitContainerIdentifier: String = {
        let key = "CaptallyCloudKitContainerIdentifier"
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            assertionFailure("Info.plist is missing \(key)")
            return "iCloud.\(bundleIdentifier)"
        }
        return value
    }()
}
