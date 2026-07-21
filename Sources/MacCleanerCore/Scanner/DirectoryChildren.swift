import Foundation

/// Lazy directory drill-down: list the immediate children of a directory,
/// each with its own recursively-computed size. Powers the GUI's
/// expand/collapse folder tree.
extension SizeCalculator {

    /// Whether a path is an existing directory that can be expanded.
    /// Synthesized items (e.g. "APFS Snapshots") and plain files return false.
    public static func isExpandableDirectory(_ path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue
    }

    /// Immediate children of a directory, each with its total size, sorted
    /// largest first. Returns an empty array for files, missing paths, or on
    /// enumeration error. Hidden files are skipped to stay consistent with
    /// `calculateSize`, so child sizes sum to roughly the parent's total.
    public static func childEntries(at path: String) async -> [DirectoryEntry] {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        let fm = FileManager.default

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }

        var entries: [DirectoryEntry] = []
        for child in contents {
            if Task.isCancelled { break }

            let childIsDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            let size: Int64
            switch await calculateSize(at: child.path) {
            case .success(let value): size = value
            case .failure: size = 0
            }

            entries.append(DirectoryEntry(
                path: child.path,
                name: child.lastPathComponent,
                sizeBytes: size,
                isDirectory: childIsDir
            ))
        }

        return entries.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
