// QGDashboardApp.swift
// QGDashboardApp
//
// A native SwiftUI window for the quality-gate dashboard. It renders the SAME
// scene(checks:) that the terminal does — via SwiftUIRenderer — so it's the
// second surface of one scene. It reads a quality-gate JSON report piped in at
// launch or opened from a file; it does not spawn subprocesses.
//
//   quality-gate --check all --format json | QGDashboardApp        # window
//   quality-gate --check all --format json | QGDashboardApp --render board.png
//                                                                  # headless PNG (CI)
//   QGDashboardApp --watch report.json                             # live-refresh window
//   # …then re-run `quality-gate --format json > report.json` and the window updates.

#if canImport(SwiftUI)
import SwiftUI
import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import QualityGateDashboard
// Scoped: a whole-module import would make SwiftCLIKit.App collide with SwiftUI.App.
import enum SwiftCLIKit.StandardInput
import SwiftGUIKit
import SwiftGUIKitSwiftUI

#if canImport(os)
import os
#endif

#if canImport(Darwin)
import Darwin
#endif

/// Diagnostics for the dashboard app (report loading / rendering failures).
private let logger = Logger(subsystem: "com.justinpurnell.SwiftCLIKit", category: "QGDashboardApp")

/// The process entry point. Dispatches between the headless `--render` mode
/// (needs a running AppKit context for `ImageRenderer`) and the SwiftUI window.
@main
enum QGDashboardMain {
    @MainActor
    static func main() {
        if let path = renderPath() {
            headlessRender(to: path)      // renders a PNG and exits
        } else {
            QGDashboardApp.main()         // opens the SwiftUI window
        }
    }

    /// The `--render <path>` argument, if present.
    private static func renderPath() -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--render"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    /// Renders the dashboard to a PNG under a running (but hidden) app, then exits.
    @MainActor
    private static func headlessRender(to path: String) {
        let checks = QGDashboardApp.readPipedChecks() ?? DashboardView.sampleChecks
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)   // background app; still loads control chrome
        Task { @MainActor in
            // Let the app finish launching so SF Symbols / control assets are loaded
            // before ImageRenderer captures the view.
            try? await Task.sleep(for: .milliseconds(400))
            QGDashboardApp.renderPNG(checks: checks, to: path)
            exit(0)
        }
        app.run()   // ImageRenderer needs the run loop; the Task fires once it starts
    }
}

struct QGDashboardApp: App {
    private let initial: [GateCheck]
    private let watchPath: String?

    init() {
        let path = QGDashboardApp.watchPath()
        watchPath = path
        // Prefer a watched file, then piped stdin, then sample data.
        if let path, let checks = QGDashboardApp.loadChecks(fromFile: path) {
            initial = checks
        } else {
            initial = QGDashboardApp.readPipedChecks() ?? DashboardView.sampleChecks
        }
    }

    var body: some Scene {
        WindowGroup("Quality Gate") {
            DashboardView(checks: initial, watchPath: watchPath)
        }
        .defaultSize(width: 440, height: 400)
    }

    /// The `--watch <path>` argument, if present.
    static func watchPath() -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--watch"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    /// Loads and parses a report file, or nil on failure.
    static func loadChecks(fromFile path: String) -> [GateCheck]? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return try QualityGateDashboard.checks(fromJSON: data)
        } catch {
            logger.error("Could not load report from \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Reads a quality-gate JSON report from stdin when it is piped (not a TTY).
    static func readPipedChecks() -> [GateCheck]? {
        guard isatty(fileno(stdin)) == 0 else { return nil }
        do {
            // Bounded chunks against an explicit ceiling: a writer that never closes
            // must not park app launch, and an oversized payload must not buffer.
            let data = try StandardInput.readAll()
            guard !data.isEmpty else { return nil }
            return try QualityGateDashboard.checks(fromJSON: data)
        } catch {
            logger.error("Could not read piped quality-gate JSON: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Renders the dashboard scene to a PNG at `path` via `ImageRenderer`.
    @MainActor
    static func renderPNG(checks: [GateCheck], to path: String) {
        let view = SwiftUIRenderer().view(for: QualityGateDashboard.scene(checks: checks))
            .frame(width: 380, height: 300)
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("QGDashboardApp: could not render image\n".utf8))
            return
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            logger.error("Could not write PNG to \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            FileHandle.standardError.write(Data("QGDashboardApp: could not write \(path) — \(error)\n".utf8))
        }
    }
}

struct DashboardView: View {
    @State private var checks: [GateCheck]
    @State private var status: String
    @State private var watchPath: String?
    @State private var lastModified: Date?

    private let renderer = SwiftUIRenderer()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(checks: [GateCheck], watchPath: String? = nil) {
        _checks = State(initialValue: checks)
        _watchPath = State(initialValue: watchPath)
        _status = State(initialValue: watchPath.map { "Watching \($0)" }
            ?? "Open a quality-gate JSON report, or pipe one in.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            renderer.view(for: QualityGateDashboard.scene(checks: checks))
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 360, minHeight: 320, alignment: .topLeading)
        .toolbar {
            Button {
                openReport()
            } label: {
                Label("Open Report…", systemImage: "doc.text.magnifyingglass")
            }
        }
        .onReceive(ticker) { _ in reloadIfChanged() }
    }

    /// If watching a file and it changed since last check, reload it.
    @MainActor
    private func reloadIfChanged() {
        guard let path = watchPath else { return }
        let modified = (try? URL(fileURLWithPath: path)
            .resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard modified != lastModified else { return }
        lastModified = modified
        guard let updated = QGDashboardApp.loadChecks(fromFile: path) else { return }
        checks = updated
        let failed = checks.contains { $0.status == .failed }
        status = "\(failed ? "FAILED" : "passed") — \(path) (auto-refresh)"
    }

    /// Loads a `quality-gate --format json` report from a file the user picks.
    @MainActor
    private func openReport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            checks = try QualityGateDashboard.checks(fromJSON: data)
            watchPath = url.path            // keep it fresh on subsequent gate runs
            lastModified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let failed = checks.contains { $0.status == .failed }
            status = "\(failed ? "FAILED" : "passed") — \(url.lastPathComponent) (auto-refresh)"
        } catch {
            logger.error("Could not read report from \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            status = "Couldn’t read report: \(error.localizedDescription)"
        }
    }

    /// Fallback data so the window shows a board immediately.
    static let sampleChecks = [
        GateCheck(name: "build", status: .passed),
        GateCheck(name: "safety", status: .passed),
        GateCheck(name: "doc-coverage", status: .warning, warnings: 2),
        GateCheck(name: "tests", status: .passed),
        GateCheck(name: "recursion", status: .failed, errors: 1),
    ]
}

#else
import Foundation

@main
enum QGDashboardMain {
    static func main() {
        // Diagnostic for an unsupported platform; stderr keeps it out of any pipe.
        FileHandle.standardError.write(Data(
            "QGDashboardApp requires SwiftUI (macOS). Use `qg-dashboard` for the terminal board.\n".utf8))
    }
}
#endif
