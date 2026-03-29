import SwiftUI
import MacCleanerCore

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var results: [ScanResult] = []
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var totalDiskBytes: Int64 = 0
    @Published var freeDiskBytes: Int64 = 0
    @Published var scanProgress: String = ""
    @Published var apfsVolumes: [APFSVolume] = []

    @Published var selectedSidebarItem: SidebarItem? = .dashboard {
        didSet { updateSelectedView() }
    }
    @Published var selectedView: SelectedView = .dashboard

    private let scanner = DiskScanner()
    lazy var executor = CleanupExecutor(scanner: scanner)

    /// Non-empty results sorted by size descending.
    /// Adds APFS volume entries (VM, Preboot, Simulators) and a final "APFS Overhead" for the remainder.
    var nonEmptyResults: [ScanResult] {
        var items = results
            .filter { $0.totalBytes > 0 }
            .sorted { $0.totalBytes > $1.totalBytes }

        if hasScanned {
            let scanned = results.reduce(Int64(0)) { $0 + $1.totalBytes }
            let usedBytes = totalDiskBytes - freeDiskBytes
            var accounted = scanned

            // Add APFS volumes not covered by file scanning
            for vol in apfsVolumes {
                switch vol.role {
                case "VM":
                    let swapInHealth = results.first { $0.categoryName == "System Overhead" }?
                        .items.first { $0.path == "/var/vm" }?.sizeBytes ?? 0
                    let extra = vol.consumedBytes - swapInHealth
                    if extra > 500_000_000 {
                        items.append(ScanResult(
                            categoryName: "VM Swap Volume", categoryIcon: "memorychip.fill",
                            items: [CleanableItem(path: "/System/Volumes/VM", sizeBytes: extra, safetyLevel: .caution,
                                description: "When your Mac runs out of RAM, macOS uses disk space as virtual memory. This is a dedicated disk partition for swap files. Restart Mac to reset it to near zero.")],
                            totalBytes: extra, safetyLevel: .caution))
                        accounted += extra
                    }
                case "Preboot":
                    let inHealth = results.first { $0.categoryName == "System Overhead" }?
                        .items.first { $0.path == "/System/Volumes/Preboot" }?.sizeBytes ?? 0
                    if inHealth == 0 && vol.consumedBytes > 500_000_000 {
                        items.append(ScanResult(
                            categoryName: "Preboot Volume", categoryIcon: "power",
                            items: [CleanableItem(path: "/System/Volumes/Preboot", sizeBytes: vol.consumedBytes, safetyLevel: .caution,
                                description: "Contains the files your Mac needs to start up: FileVault encryption keys, boot loader, and firmware. Required for your Mac to turn on. Cannot be deleted.")],
                            totalBytes: vol.consumedBytes, safetyLevel: .caution))
                        accounted += vol.consumedBytes
                    }
                case "No specific role" where vol.name.contains("Simulator"):
                    // Parse version from name (e.g., "iOS 18.0 Simulator Bundle" -> "iOS 18.0")
                    let version = vol.name.replacingOccurrences(of: " Simulator Bundle", with: "")
                        .replacingOccurrences(of: " Simulator", with: "")

                    let simItems = [
                        CleanableItem(
                            path: "System Image",
                            sizeBytes: Int64(Double(vol.consumedBytes) * 0.7),
                            safetyLevel: .caution,
                            description: "A complete copy of \(version) operating system. This is the virtual iPhone's 'brain' that runs inside the Simulator. It contains all the iOS frameworks, system apps (Settings, Safari, Photos), and runtime libraries needed to simulate a real iPhone.\n\nThis is the largest part of the Simulator."),
                        CleanableItem(
                            path: "SDK & Frameworks",
                            sizeBytes: Int64(Double(vol.consumedBytes) * 0.2),
                            safetyLevel: .caution,
                            description: "Development frameworks for \(version). These let Xcode compile and run your iOS app code against this specific iOS version. Includes UIKit, SwiftUI, CoreData, and hundreds of other Apple frameworks."),
                        CleanableItem(
                            path: "Device Support Files",
                            sizeBytes: Int64(Double(vol.consumedBytes) * 0.1),
                            safetyLevel: .caution,
                            description: "Debug symbols and device profiles. Allows Xcode to show meaningful error messages and stack traces when debugging apps in this Simulator version."),
                    ]

                    items.append(ScanResult(
                        categoryName: vol.name, categoryIcon: "iphone",
                        items: simItems,
                        totalBytes: vol.consumedBytes, safetyLevel: .caution))
                    accounted += vol.consumedBytes
                default:
                    break
                }
            }

            // Break down the remaining gap into understandable pieces
            let remaining = usedBytes - accounted
            if remaining > 1_000_000_000 {
                // Estimate sub-components of the overhead
                let snapshotEstimate = min(remaining / 3, 50_000_000_000) // ~30-50 GB typically
                let filevaultEstimate = min(remaining / 10, 15_000_000_000) // ~5-15 GB
                let btreeEstimate = min(remaining / 10, 15_000_000_000) // ~5-15 GB
                let smallFilesEstimate = min(remaining / 10, 20_000_000_000)
                let otherEstimate = remaining - snapshotEstimate - filevaultEstimate - btreeEstimate - smallFilesEstimate

                var overheadItems: [CleanableItem] = []

                overheadItems.append(CleanableItem(
                    path: "APFS Snapshots",
                    sizeBytes: snapshotEstimate, safetyLevel: .caution,
                    description: "Every time macOS updates or Time Machine runs, a snapshot is taken. Snapshots save the state of your disk so you can roll back if something goes wrong. They are automatically deleted when space is needed, but can accumulate.\n\nTo delete: sudo tmutil deletelocalsnapshots /"))

                overheadItems.append(CleanableItem(
                    path: "FileVault Encryption",
                    sizeBytes: filevaultEstimate, safetyLevel: .caution,
                    description: "Your disk is encrypted with FileVault. Encryption requires extra space for cryptographic keys, metadata, and conversion tables. This protects your data if your Mac is stolen. Cannot be reduced without disabling FileVault."))

                overheadItems.append(CleanableItem(
                    path: "Filesystem Indexes",
                    sizeBytes: btreeEstimate, safetyLevel: .caution,
                    description: "APFS uses B-tree data structures to index every file on your disk. This is like a library catalog that lets macOS find any file instantly. More files = larger index. Cannot be reduced."))

                overheadItems.append(CleanableItem(
                    path: "Small Scattered Files",
                    sizeBytes: smallFilesEstimate, safetyLevel: .caution,
                    description: "Thousands of small files (configs, preferences, caches under 1 MB each) spread across the filesystem. Individually tiny, collectively they add up. Not practical to clean individually."))

                if otherEstimate > 500_000_000 {
                    overheadItems.append(CleanableItem(
                        path: "Disk Allocation Overhead",
                        sizeBytes: otherEstimate, safetyLevel: .caution,
                        description: "The difference between logical file sizes and actual disk blocks allocated. APFS allocates space in fixed-size blocks (4 KB). A 1 KB file still uses one 4 KB block. This overhead is normal and unavoidable."))
                }

                items.append(ScanResult(
                    categoryName: "APFS Overhead", categoryIcon: "internaldrive",
                    items: overheadItems,
                    totalBytes: remaining, safetyLevel: .caution))
            }
        }

        return items.sorted { $0.totalBytes > $1.totalBytes }
    }

    var totalScannedBytes: Int64 {
        if hasScanned {
            return totalDiskBytes - freeDiskBytes
        }
        return results.reduce(0) { $0 + $1.totalBytes }
    }

    /// Just the scanned categories (excluding synthesized APFS entries).
    var scannedCategoryBytes: Int64 {
        results.reduce(0) { $0 + $1.totalBytes }
    }

    var totalReclaimableBytes: Int64 {
        results.reduce(0) { $0 + $1.effectiveReclaimableBytes }
    }

    var usedPercentage: Double {
        guard totalDiskBytes > 0 else { return 0 }
        return Double(totalDiskBytes - freeDiskBytes) / Double(totalDiskBytes) * 100
    }

    // MARK: - Scanning

    func startScan() async {
        isScanning = true
        results = []
        scanProgress = "Starting scan..."

        let volumeInfo = StorageBreakdown.volumeInfo()
        totalDiskBytes = volumeInfo.total
        freeDiskBytes = volumeInfo.free

        var count = 0
        for await result in scanner.scanProgressively() {
            count += 1
            results.append(result)
            scanProgress = "Scanned \(count)/\(scanner.categories.count): \(result.categoryName)"
        }

        // Load APFS volume breakdown
        apfsVolumes = await APFSVolumeScanner.getVolumes()

        isScanning = false
        hasScanned = true
        scanProgress = ""
    }

    /// Re-scan a single category after cleanup.
    func rescanCategory(named name: String) async {
        guard let updated = await scanner.rescanCategory(named: name) else { return }

        if let index = results.firstIndex(where: { $0.categoryName == name }) {
            results[index] = updated
        }

        // Refresh volume info
        let volumeInfo = StorageBreakdown.volumeInfo()
        totalDiskBytes = volumeInfo.total
        freeDiskBytes = volumeInfo.free
    }

    // MARK: - Navigation

    private func updateSelectedView() {
        switch selectedSidebarItem {
        case .dashboard, .none:
            selectedView = .dashboard
        case .category(let name):
            selectedView = .category(name)
        }
    }
}
