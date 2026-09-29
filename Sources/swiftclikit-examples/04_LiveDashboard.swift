// LOGGING-EXEMPT: example/demo program
// 04_LiveDashboard.swift
// SwiftCLIKit Tutorial — Tier 4: Live Dashboard
// Created by Justin Purnell on 2026-05-08.

import SwiftCLIKit
import Foundation
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private let shouldExitFlag = Atomic<Bool>(false)

/// Tier 4 is a walkthrough of production TUI architecture patterns, demonstrated
/// through a generic JSON file-watcher dashboard. It simulates a pipeline that
/// progresses through phases, writing status to a JSON file. The dashboard polls
/// that file and renders its contents in real time.
///
/// **Concepts introduced:**
/// - `AlternateScreen` — RAII alternate screen management
/// - JSON polling pattern — atomic reads, stale data resilience
/// - `ScreenBuffer` — composing full-screen frames efficiently
/// - Signal handling — SIGINT cleanup for graceful exit
/// - Error resilience — corrupt file handling, missing file waiting
///
/// Rather than building a full production dashboard, this tier teaches the
/// **patterns** that make real TUI apps work, using the AlphaConquer dashboard
/// as its case study.
enum LiveDashboard {

    // MARK: - Configuration

    /// All tunable constants for the dashboard.
    private enum Config {
        /// How often the dashboard polls the status file.
        static let pollInterval: TimeInterval = 0.25
        /// How often the background updater modifies the status file.
        static let updateInterval: TimeInterval = 1.0
        /// Maximum number of update cycles before auto-exit.
        static let maxUpdates = 15
        /// Path for the sample status file.
        static let statusFilePath = "/tmp/swiftclikit-demo-status.json"
        /// Width of progress gauges in the dashboard.
        static let gaugeWidth = 30
        /// Minimum terminal width for rendering.
        static let minimumWidth = 50
    }

    /// The phases a simulated pipeline progresses through.
    private enum Phase: String, CaseIterable, Sendable {
        case generating = "Generating"
        case encoding = "Encoding"
        case training = "Training"
        case evaluating = "Evaluating"
        case complete = "Complete"

        /// The next phase in the pipeline, or nil if complete.
        var next: Phase? { // LIVE: public API
            let all = Phase.allCases
            guard let idx = all.firstIndex(of: self) else { return nil }
            let nextIdx = all.index(after: idx)
            guard nextIdx < all.endIndex else { return nil }
            return all[nextIdx]
        }
    }

    /// A decoded status from the JSON file.
    private struct PipelineStatus: Sendable {
        let phase: String
        let gamesPlayed: Int
        let gamesTotal: Int
        let winRate: Double
        let elapsedSeconds: Int
        let currentLoss: Double
        let epoch: Int
        let epochsTotal: Int
        let modelVersion: String
    }

    // MARK: - Public Entry Point

    static func run() {
        setvbuf(stdout, nil, _IONBF, 0)

        printIntro()
        waitForEnter()

        // Install SIGINT handler for clean exit
        installSignalHandler()

        // Create the initial status file
        let statusPath = Config.statusFilePath
        createInitialStatusFile(at: statusPath)

        // Start background updater thread
        let updaterThread = Thread {
            runBackgroundUpdater(path: statusPath)
        }
        updaterThread.name = "status-updater"
        updaterThread.start()

        // Run the dashboard (blocks until done or SIGINT)
        runDashboard(statusPath: statusPath)

        // Clean up
        shouldExitFlag.store(true, ordering: .releasing)
        // Give the updater thread a moment to notice the flag
        Thread.sleep(forTimeInterval: 0.1)
        cleanupStatusFile(at: statusPath)

        printSummary()
    }

    // MARK: - Signal Handling

    /// Installs a SIGINT handler that sets the exit flag and restores cursor visibility.
    private static func installSignalHandler() {
        signal(SIGINT) { _ in
            // Restore cursor visibility before exiting
            let showCursor = CursorControl.show
            let bytes = Array(showCursor.utf8)
            // Write directly to stdout fd to avoid Swift runtime in signal context
            bytes.withUnsafeBufferPointer { buffer in
                guard let ptr = buffer.baseAddress else { return }
                _ = write(1, ptr, buffer.count)
            }
            shouldExitFlag.store(true, ordering: .releasing)
        }
    }

    // MARK: - Status File Management

    /// Creates the initial JSON status file with starting values.
    private static func createInitialStatusFile(at path: String) {
        let initial = buildStatusJSON(
            phase: Phase.generating.rawValue,
            gamesPlayed: 0,
            gamesTotal: 500,
            winRate: 0.0,
            elapsedSeconds: 0,
            currentLoss: 2.45,
            epoch: 0,
            epochsTotal: 10,
            modelVersion: "v0.1.0"
        )
        writeAtomically(initial, to: path)
    }

    /// Removes the temporary status file.
    private static func cleanupStatusFile(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    /// Builds a JSON string from pipeline status values.
    /// Hand-rolled to avoid Codable complexity in a tutorial and to guarantee key order.
    private static func buildStatusJSON(
        phase: String,
        gamesPlayed: Int,
        gamesTotal: Int,
        winRate: Double,
        elapsedSeconds: Int,
        currentLoss: Double,
        epoch: Int,
        epochsTotal: Int,
        modelVersion: String
    ) -> String {
        let winRateStr = formatTwoDecimal(winRate)
        let lossStr = formatTwoDecimal(currentLoss)
        return """
        {
          "phase": "\(phase)",
          "games_played": \(gamesPlayed),
          "games_total": \(gamesTotal),
          "win_rate": \(winRateStr),
          "elapsed_seconds": \(elapsedSeconds),
          "current_loss": \(lossStr),
          "epoch": \(epoch),
          "epochs_total": \(epochsTotal),
          "model_version": "\(modelVersion)"
        }
        """
    }

    /// Writes content to a file atomically (write to temp, then rename).
    /// This prevents the dashboard from reading a partially-written file.
    private static func writeAtomically(_ content: String, to path: String) {
        let tmpPath = path + ".tmp"
        do {
            try content.write(toFile: tmpPath, atomically: false, encoding: .utf8)
            // Atomic rename — either the old file or the new one is visible, never a partial
            _ = rename(tmpPath, path)
        } catch {
            // Best effort — dashboard handles missing/corrupt files gracefully
        }
    }

    // MARK: - Background Updater

    /// Simulates a pipeline progressing through phases.
    /// Runs on a background thread and updates the JSON file every second.
    private static func runBackgroundUpdater(path: String) {
        var phase = Phase.generating
        var gamesPlayed = 0
        let gamesTotal = 500
        var winRate = 0.0
        var elapsed = 0
        var loss = 2.45
        var epoch = 0
        let epochsTotal = 10

        for tick in 0..<Config.maxUpdates {
            guard !shouldExitFlag.load(ordering: .acquiring) else { return }

            elapsed = tick + 1

            // Progress through phases based on tick count
            switch phase {
            case .generating:
                gamesPlayed = min(gamesPlayed + 120, gamesTotal)
                if gamesPlayed >= gamesTotal {
                    phase = .encoding
                }
            case .encoding:
                // Encoding is fast, takes 2 ticks
                if tick >= 6 {
                    phase = .training
                    epoch = 1
                }
            case .training:
                epoch = min(epoch + 1, epochsTotal)
                loss = max(0.12, loss * 0.65)
                winRate = min(winRate + Double.random(in: 0.05...0.12), 0.89)
                if epoch >= epochsTotal {
                    phase = .evaluating
                }
            case .evaluating:
                winRate = min(winRate + 0.02, 0.91)
                if tick >= 13 {
                    phase = .complete
                }
            case .complete:
                break
            }

            let json = buildStatusJSON(
                phase: phase.rawValue,
                gamesPlayed: gamesPlayed,
                gamesTotal: gamesTotal,
                winRate: winRate,
                elapsedSeconds: elapsed,
                currentLoss: loss,
                epoch: epoch,
                epochsTotal: epochsTotal,
                modelVersion: phase == .complete ? "v0.2.0" : "v0.1.0"
            )
            writeAtomically(json, to: path)

            Thread.sleep(forTimeInterval: Config.updateInterval)
        }
    }

    // MARK: - Dashboard Renderer

    /// The main dashboard loop. Polls the status file and renders until done or interrupted.
    private static func runDashboard(statusPath: String) {
        let screen = AlternateScreen()
        print(CursorControl.hide, terminator: "")

        var lastContent = ""
        var pollCount = 0
        let maxPolls = Int(Double(Config.maxUpdates) * Config.updateInterval / Config.pollInterval) + 20

        while !shouldExitFlag.load(ordering: .acquiring), pollCount < maxPolls {
            let size = TerminalSize.current()
            let width = max(size.columns, Config.minimumWidth)

            // Read and parse the status file
            let status = readStatusFile(at: statusPath)
            let frame = renderDashboard(status: status, width: width, statusPath: statusPath)

            // Only write to terminal if the content changed (poor man's diff)
            if frame != lastContent {
                print(frame, terminator: "")
                lastContent = frame
            }

            // Auto-exit when the pipeline completes
            if let s = status, s.phase == Phase.complete.rawValue {
                // Show the complete state for a couple seconds
                Thread.sleep(forTimeInterval: 2.0)
                break
            }

            Thread.sleep(forTimeInterval: Config.pollInterval)
            pollCount += 1
        }

        // Restore terminal
        print(CursorControl.show, terminator: "")
        _ = screen
    }

    /// Reads and parses the JSON status file, returning nil on any failure.
    private static func readStatusFile(at path: String) -> PipelineStatus? {
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let phase = json["phase"] as? String,
              let gamesPlayed = json["games_played"] as? Int,
              let gamesTotal = json["games_total"] as? Int,
              let winRate = json["win_rate"] as? Double,
              let elapsed = json["elapsed_seconds"] as? Int,
              let loss = json["current_loss"] as? Double,
              let epoch = json["epoch"] as? Int,
              let epochsTotal = json["epochs_total"] as? Int,
              let version = json["model_version"] as? String else {
            return nil
        }
        return PipelineStatus(
            phase: phase,
            gamesPlayed: gamesPlayed,
            gamesTotal: gamesTotal,
            winRate: winRate,
            elapsedSeconds: elapsed,
            currentLoss: loss,
            epoch: epoch,
            epochsTotal: epochsTotal,
            modelVersion: version
        )
    }

    /// Renders the full dashboard frame for the current status.
    private static func renderDashboard(
        status: PipelineStatus?,
        width: Int,
        statusPath: String
    ) -> String {
        let box = BoxDrawing.unicode
        var buf = ScreenBuffer(width: width)

        buf.appendLine(box.topBorder(" Pipeline Dashboard ", width: width))

        guard let status = status else {
            // File not yet available — show waiting state
            buf.appendLine(boxRow("  Waiting for status file...", width: width))
            buf.appendLine(boxRow("  Path: \(statusPath)", width: width))
            buf.appendLine(box.bottomBorder(width: width))
            return buf.frame
        }

        // Phase indicator with color
        let phaseColor = colorForPhase(status.phase)
        let phaseText = ANSICodes.bold + " Phase: "
            + ANSICodes.reset + foreground(phaseColor) + status.phase
            + ANSICodes.reset
            + "    Model: " + status.modelVersion
            + "    Elapsed: " + Formatting.elapsed(Double(status.elapsedSeconds))
        buf.appendLine(boxRow(phaseText, width: width))

        // Blank separator
        buf.appendLine(boxRow("", width: width))

        // Games progress gauge
        let gamesGauge = InlineGauge.render(
            current: status.gamesPlayed,
            total: status.gamesTotal,
            width: Config.gaugeWidth,
            filledColor: .ansi8(.green)
        )
        let gamesPercent = status.gamesTotal > 0
            ? (status.gamesPlayed * 100) / status.gamesTotal
            : 0
        let gamesLine = " Games    " + gamesGauge
            + "  \(gamesPercent)%"
            + "  (\(status.gamesPlayed)/\(status.gamesTotal))"
        buf.appendLine(boxRow(gamesLine, width: width))

        // Epoch progress gauge
        let epochGauge = InlineGauge.render(
            current: status.epoch,
            total: status.epochsTotal,
            width: Config.gaugeWidth,
            filledColor: .ansi8(.cyan)
        )
        let epochPercent = status.epochsTotal > 0
            ? (status.epoch * 100) / status.epochsTotal
            : 0
        let epochLine = " Epochs   " + epochGauge
            + "  \(epochPercent)%"
            + "  (\(status.epoch)/\(status.epochsTotal))"
        buf.appendLine(boxRow(epochLine, width: width))

        // Blank separator
        buf.appendLine(boxRow("", width: width))

        // Metrics section
        buf.appendLine(box.midBorder(width: width))
        buf.appendLine(boxRow(ANSICodes.bold + " Metrics" + ANSICodes.reset, width: width))
        buf.appendLine(boxRow("", width: width))

        // Win rate with color coding
        let winPct = Int((status.winRate * 100).rounded())
        let winColor = winRateColor(for: winPct)
        let winGauge = InlineGauge.render(
            current: winPct,
            total: 100,
            width: 20,
            filledColor: winColor
        )
        let winLine = "  Win Rate    " + winGauge + "  \(winPct)%"
        buf.appendLine(boxRow(winLine, width: width))

        // Loss value
        let lossStr = formatTwoDecimal(status.currentLoss)
        let lossColor: Color = status.currentLoss < 0.5 ? .ansi8(.green) : .ansi8(.yellow)
        let lossLine = "  Loss        " + foreground(lossColor) + lossStr + ANSICodes.reset
        buf.appendLine(boxRow(lossLine, width: width))

        // Blank separator
        buf.appendLine(boxRow("", width: width))

        // Architecture notes section
        buf.appendLine(box.midBorder(width: width))
        buf.appendLine(boxRow(
            ANSICodes.dim + "  Pattern: JSON poll + atomic write + ScreenBuffer.frame"
            + ANSICodes.reset, width: width
        ))
        buf.appendLine(boxRow(
            ANSICodes.dim + "  Source:  \(statusPath)"
            + ANSICodes.reset, width: width
        ))
        let timeStr = Formatting.time(Date())
        buf.appendLine(boxRow(
            ANSICodes.dim + "  Updated: \(timeStr)"
            + ANSICodes.reset, width: width
        ))

        buf.appendLine(box.bottomBorder(width: width))

        return buf.frame
    }

    // MARK: - Rendering Helpers

    /// Wraps content in box-drawing vertical borders, padding to fill the width.
    private static func boxRow(_ content: String, width: Int) -> String {
        let box = BoxDrawing.unicode
        let visLen = ANSIStringMetrics.visibleLength(content)
        let innerWidth = width - 2
        let padding = max(0, innerWidth - visLen)
        return box.vertical + content
            + String(repeating: " ", count: padding)
            + box.vertical
    }

    /// Returns the appropriate ANSI foreground escape for a Color value.
    private static func foreground(_ color: Color) -> String {
        switch color {
        case .ansi8(let c):
            return ANSICodes.fg(c)
        case .ansi256(let idx):
            return ANSICodes.fg256(idx)
        case .truecolor(let r, let g, let b):
            return ANSICodes.fgRGB(r, g, b)
        case .defaultColor:
            return ""
        }
    }

    /// Returns a color for the pipeline phase name.
    private static func colorForPhase(_ phase: String) -> Color {
        switch phase {
        case Phase.generating.rawValue:
            return .ansi8(.yellow)
        case Phase.encoding.rawValue:
            return .ansi8(.cyan)
        case Phase.training.rawValue:
            return .ansi8(.blue)
        case Phase.evaluating.rawValue:
            return .ansi8(.magenta)
        case Phase.complete.rawValue:
            return .ansi8(.green)
        default:
            return .ansi8(.white)
        }
    }

    /// Returns a color based on win rate percentage.
    private static func winRateColor(for percent: Int) -> Color {
        switch percent {
        case 0..<30:
            return .ansi8(.red)
        case 30..<60:
            return .ansi8(.yellow)
        default:
            return .ansi8(.green)
        }
    }

    /// Formats a Double to two decimal places without locale sensitivity.
    private static func formatTwoDecimal(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        let intPart = Int(rounded)
        let fracPart = Int(((rounded - Double(intPart)) * 100).rounded())
        let fracStr = fracPart < 10 ? "0\(fracPart)" : "\(fracPart)"
        return "\(intPart).\(fracStr)"
    }

    // MARK: - Intro / Summary / Helpers

    private static func printIntro() {
        print(ANSICodes.bold + "Tier 4: Live Dashboard — The AlphaConquer Case Study"
              + ANSICodes.reset)
        print("")
        print("This is the capstone tier. It demonstrates the architecture behind")
        print("production TUI dashboards like the AlphaConquer training monitor.")
        print("")
        print("What you will see:")
        print("  - A simulated ML pipeline progressing through phases:")
        print("    Generating -> Encoding -> Training -> Evaluating -> Complete")
        print("  - A JSON status file polled every 250ms")
        print("  - Atomic file writes to prevent partial reads")
        print("  - Progress gauges that update as the pipeline advances")
        print("  - Graceful SIGINT handling (try Ctrl+C during the demo)")
        print("  - Automatic cleanup of temporary files")
        print("")
        print("Key architecture patterns:")
        print("  1. The pipeline writes status to /tmp as JSON (atomic rename)")
        print("  2. The dashboard polls that file independently")
        print("  3. ScreenBuffer.frame replaces the entire screen each tick")
        print("  4. Content-diff skips writes when nothing changed")
        print("  5. SIGINT handler restores the cursor before exit")
        print("")
        print("The demo runs for ~15 seconds and auto-exits when the pipeline completes.")
        print("")
    }

    private static func printSummary() {
        print("")
        print(ANSICodes.bold + "What you just saw:" + ANSICodes.reset)
        print("")
        print("  1. " + ANSICodes.bold + "JSON Polling Architecture" + ANSICodes.reset)
        print("     The dashboard and pipeline are fully decoupled. The pipeline writes")
        print("     JSON; the dashboard reads it. They share nothing but a file path.")
        print("     This pattern works across processes, machines, and languages.")
        print("")
        print("  2. " + ANSICodes.bold + "Atomic File Writes" + ANSICodes.reset)
        print("     The updater writes to a .tmp file then renames it. rename(2) is")
        print("     atomic on POSIX — the reader sees either the old file or the new")
        print("     one, never a half-written buffer. This prevents JSON parse errors.")
        print("")
        print("  3. " + ANSICodes.bold + "Content-Based Diff" + ANSICodes.reset)
        print("     The dashboard compares each rendered frame to the previous one.")
        print("     If nothing changed, it skips the write entirely. For more advanced")
        print("     use cases, SwiftCLIKit provides DiffRenderer which compares at the")
        print("     cell level and emits only cursor-move + character sequences for")
        print("     changed cells — dramatically reducing terminal I/O.")
        print("")
        print("  4. " + ANSICodes.bold + "Signal Handling" + ANSICodes.reset)
        print("     SIGINT (Ctrl+C) sets a flag that the main loop checks. The handler")
        print("     itself only does two things: restore cursor visibility and set the")
        print("     flag. Never do complex work in a signal handler.")
        print("")
        print("  5. " + ANSICodes.bold + "Error Resilience" + ANSICodes.reset)
        print("     readStatusFile() returns nil on any failure — missing file, corrupt")
        print("     JSON, missing keys. The dashboard shows a 'waiting' state instead")
        print("     of crashing. Real pipelines restart, files get deleted mid-read,")
        print("     and disks fill up. Handle all of it.")
        print("")
        print("  6. " + ANSICodes.bold + "ScreenBuffer.frame" + ANSICodes.reset)
        print("     Each frame prepends clear-screen + home-cursor, then the content.")
        print("     This gives flicker-free full-screen updates without managing a")
        print("     cell buffer. For simple dashboards, this is all you need.")
        print("")
        print(ANSICodes.bold + "You have completed all four tiers." + ANSICodes.reset
              + " You now know enough to build")
        print("production terminal UIs with SwiftCLIKit.")
        print("")
    }

    private static func waitForEnter() {
        print("Press Enter to start the demo...")
        _ = readLine()
    }
}
