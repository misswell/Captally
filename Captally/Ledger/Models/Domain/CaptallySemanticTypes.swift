import Foundation

/// Where a transaction entered Captally from.
///
/// `email`, `sms` and `pdf` are deliberately not modeled yet; adding a case here is the only
/// change a new source requires, which is why this is an enum and not a free-form string.
enum TransactionSource: String, Codable, CaseIterable, Sendable {
    case manual
    case screenshot
    case importFile
}

/// Where a transaction stands in the review queue.
enum ReviewStatus: String, Codable, CaseIterable, Sendable {
    case autoConfirmed
    case needsReview
    case userConfirmed
    case rejected
}

/// The payment or merchant surface a screenshot came from.
///
/// Kept narrow on purpose: 1.0 targets alipay / wechatPay / meituan / taobao / jd / didi /
/// railway12306 plus `generic`, everything else falls through to `generic`.
enum CaptallyPlatform: String, Codable, CaseIterable, Sendable {
    case alipay
    case wechatPay
    case meituan
    case eleme
    case taobao
    case tmall
    case jd
    case pinduoduo
    case didi
    case amap
    case railway12306
    case trip
    case apple
    case generic

    static func from(rawValue: String?) -> CaptallyPlatform {
        guard let rawValue, let match = CaptallyPlatform(rawValue: rawValue) else { return .generic }
        return match
    }
}

/// Which semantic engine produced a classification. User-facing copy names Captally's own
/// tiers, not the underlying model vendor, so swapping models never renames a product surface.
enum AIProviderIdentifier: String, Codable, CaseIterable, Sendable {
    case ruleOnly
    case appleFoundationModel
    case captallyLocalAI
}
