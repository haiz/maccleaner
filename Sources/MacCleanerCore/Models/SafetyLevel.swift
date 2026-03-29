import Foundation

/// Safety classification for cleanable items.
/// - `.safe`: caches, derived data, build artifacts. Always regenerated on demand.
/// - `.caution`: old simulators, archives, backups. Review before deleting.
public enum SafetyLevel: String, Codable, Sendable {
    case safe
    case caution
}
