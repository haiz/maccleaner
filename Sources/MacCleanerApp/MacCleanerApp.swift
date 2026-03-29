import SwiftUI
import AppKit
import MacCleanerCore

@main
struct MacCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = DashboardViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
    }
}

/// Required to make SPM-built SwiftUI apps visible as proper GUI applications.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        AppIconGenerator.setDockIcon()
    }
}

struct ContentView: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            switch viewModel.selectedView {
            case .dashboard:
                DashboardView()
            case .category(let name):
                CategoryDetailView(categoryName: name)
            }
        }
        .task {
            if !viewModel.hasScanned {
                await viewModel.startScan()
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        List(selection: $viewModel.selectedSidebarItem) {
            Section("Overview") {
                Label("Dashboard", systemImage: "gauge.with.dots.needle.33percent")
                    .tag(SidebarItem.dashboard)
            }

            if !viewModel.nonEmptyResults.isEmpty {
                Section {
                    ForEach(viewModel.nonEmptyResults, id: \.categoryName) { result in
                        Label {
                            HStack {
                                Text(result.categoryName)
                                Spacer()
                                Text(ByteCountFormatter.string(
                                    fromByteCount: result.totalBytes,
                                    countStyle: .file
                                ))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            }
                        } icon: {
                            Image(systemName: result.categoryIcon)
                                .foregroundStyle(result.safetyLevel == .safe ? .green : .orange)
                        }
                        .tag(SidebarItem.category(result.categoryName))
                    }
                } header: {
                    HStack {
                        Text("Categories")
                        Spacer()
                        Text(ByteCountFormatter.string(
                            fromByteCount: viewModel.totalScannedBytes,
                            countStyle: .file
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem {
                Button(action: {
                    Task { await viewModel.startScan() }
                }) {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning)
            }
        }
    }
}

// MARK: - Navigation Model

enum SidebarItem: Hashable {
    case dashboard
    case category(String)
}

enum SelectedView {
    case dashboard
    case category(String)
}
