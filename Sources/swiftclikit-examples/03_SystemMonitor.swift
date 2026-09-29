// LOGGING-EXEMPT: example/demo program
// 03_SystemMonitor.swift
// SwiftCLIKit Tutorial — Tier 3: System Monitor
// Created by Justin Purnell on 2026-05-08.

import SwiftCLIKit
import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Tier 3 teaches composing a real dashboard using inline widgets, box drawing,
/// and layout. It builds a simulated system monitor that displays CPU, memory,
/// network, and disk gauges alongside a process table — all wrapped in Unicode
/// box borders and responsive to the terminal width.
///
/// **Concepts introduced:**
/// - `BoxDrawing.unicode` — bordered layouts
/// - `TerminalSize.current()` — responsive design
/// - `InlineGauge` + `InlineSparkline` + `Formatting` — composing inline widgets
/// - `AlternateScreen` — full-screen takeover with clean restore
/// - Layout composition — building complex displays from simple parts
enum SystemMonitor {

    // MARK: - Configuration

    /// All tunable constants for the monitor display.
    private enum Config {
        /// Number of animation frames to render.
        static let frameCount = 100
        /// Delay between frames in seconds.
        static let frameDelay: TimeInterval = 0.1
        /// Minimum width before the layout degrades.
        static let minimumWidth = 40
        /// Label column width for resource names.
        static let labelWidth = 6
        /// Percentage column width (e.g. " 42%").
        static let percentWidth = 6
        /// Extra info column width (e.g. "1.2 GB").
        static let infoWidth = 14
        /// Starting memory usage percentage.
        static let initialMemoryPercent = 45.0
        /// Memory drift per frame (slow increase).
        static let memoryDriftPerFrame = 0.08
        /// Maximum memory percentage.
        static let maxMemoryPercent = 92.0
        /// Static disk usage percentage.
        static let diskPercent = 87
        /// Disk used display string.
        static let diskUsed = "412 GB"
        /// Total disk display string.
        static let diskTotal = "475 GB" // LIVE: example display constant
    }

    /// A simulated process entry for the process table.
    private struct ProcessEntry: Sendable {
        let pid: Int
        let name: String
        let cpuPercent: Double
        let memPercent: Double
    }

    /// The static list of fake processes displayed in the table.
    private static let processes: [ProcessEntry] = [
        ProcessEntry(pid: 1234, name: "swift", cpuPercent: 34.2, memPercent: 12.1),
        ProcessEntry(pid: 5678, name: "Xcode", cpuPercent: 22.1, memPercent: 8.4),
        ProcessEntry(pid: 9012, name: "Safari", cpuPercent: 11.3, memPercent: 15.2),
        ProcessEntry(pid: 3456, name: "Terminal", cpuPercent: 8.7, memPercent: 2.1),
        ProcessEntry(pid: 7890, name: "Finder", cpuPercent: 3.2, memPercent: 4.8),
    ]

    // MARK: - Public Entry Point

    static func run() {
        setvbuf(stdout, nil, _IONBF, 0)

        printIntro()
        waitForEnter()

        // Enter alternate screen for full-screen takeover
        let screen = AlternateScreen()
        print(CursorControl.hide, terminator: "")

        // Simulated data that evolves each frame
        var cpuHistory: [Double] = []
        var netHistory: [Double] = []
        var memUsage = Config.initialMemoryPercent

        for _ in 0..<Config.frameCount {
            let size = TerminalSize.current()
            let width = max(size.columns, Config.minimumWidth)

            // Generate fake data for this frame
            let cpuValue = generateCPUValue()
            cpuHistory.append(cpuValue)

            let netValue = generateNetValue()
            netHistory.append(netValue)

            // Memory slowly creeps up
            memUsage = min(memUsage + Config.memoryDriftPerFrame, Config.maxMemoryPercent)

            // Build the dashboard frame
            let dashboard = buildDashboard(
                width: width,
                cpuPercent: Int(cpuValue),
                cpuHistory: cpuHistory,
                memPercent: Int(memUsage),
                memBytes: memoryBytes(for: memUsage),
                netHistory: netHistory,
                netRate: netValue
            )

            print(dashboard, terminator: "")
            Thread.sleep(forTimeInterval: Config.frameDelay)
        }

        // Restore terminal state
        print(CursorControl.show, terminator: "")
        // screen deinit restores original screen content
        _ = screen

        printSummary()
    }

    // MARK: - Dashboard Rendering

    /// Builds a complete dashboard frame as a single string ready to print.
    private static func buildDashboard(
        width: Int,
        cpuPercent: Int,
        cpuHistory: [Double],
        memPercent: Int,
        memBytes: String,
        netHistory: [Double],
        netRate: Double
    ) -> String {
        let box = BoxDrawing.unicode
        let gaugeWidth = width - Config.labelWidth - Config.percentWidth - Config.infoWidth - 4
        // 4 accounts for: box vertical + space + space + box vertical
        let safeGaugeWidth = max(gaugeWidth, 10)

        var buf = ScreenBuffer(width: width)

        // Top border with title
        buf.appendLine(box.topBorder(" System Monitor ", width: width))

        // CPU gauge row
        let cpuGauge = InlineGauge.render(
            current: cpuPercent,
            total: 100,
            width: safeGaugeWidth,
            filledColor: cpuColor(for: cpuPercent)
        )
        let cpuLine = padRow(
            label: "CPU",
            gauge: cpuGauge,
            percent: cpuPercent,
            info: "",
            width: width
        )
        buf.appendLine(cpuLine)

        // CPU sparkline row
        let sparkWidth = safeGaugeWidth
        let cpuSpark = InlineSparkline.render(
            data: cpuHistory,
            width: sparkWidth,
            color: .ansi8(.cyan),
            min: 0.0,
            max: 100.0
        )
        let sparkLine = boxRow(
            content: String(repeating: " ", count: Config.labelWidth) + cpuSpark,
            width: width
        )
        buf.appendLine(sparkLine)

        // Memory gauge row
        let memGauge = InlineGauge.render(
            current: memPercent,
            total: 100,
            width: safeGaugeWidth,
            filledColor: cpuColor(for: memPercent)
        )
        let memLine = padRow(
            label: "MEM",
            gauge: memGauge,
            percent: memPercent,
            info: memBytes,
            width: width
        )
        buf.appendLine(memLine)

        // Network sparkline row
        let netSpark = InlineSparkline.render(
            data: netHistory,
            width: safeGaugeWidth,
            color: .ansi8(.blue),
            min: 0.0,
            max: 10.0
        )
        let netRateStr = Formatting.rate(netRate, unit: "MB/s")
        let netLine = padRow(
            label: "NET",
            gauge: netSpark,
            percent: nil,
            info: "\u{2191} " + netRateStr,
            width: width
        )
        buf.appendLine(netLine)

        // Disk gauge row (static)
        let diskGauge = InlineGauge.render(
            current: Config.diskPercent,
            total: 100,
            width: safeGaugeWidth,
            filledColor: .ansi8(.yellow)
        )
        let diskLine = padRow(
            label: "DISK",
            gauge: diskGauge,
            percent: Config.diskPercent,
            info: Config.diskUsed,
            width: width
        )
        buf.appendLine(diskLine)

        // Mid border (divider)
        buf.appendLine(box.midBorder(width: width))

        // Process table header
        let headerLine = processTableHeader(width: width)
        buf.appendLine(headerLine)

        // Process rows
        for proc in processes {
            let procLine = processRow(proc, width: width)
            buf.appendLine(procLine)
        }

        // Bottom border
        buf.appendLine(box.bottomBorder(width: width))

        return buf.frame
    }

    // MARK: - Row Helpers

    /// Builds a bordered row with label, gauge/sparkline, optional percentage, and info.
    private static func padRow(
        label: String,
        gauge: String,
        percent: Int?,
        info: String,
        width: Int
    ) -> String {
        let box = BoxDrawing.unicode
        let labelPadded = ANSIStringMetrics.padVisible(
            ANSICodes.bold + label + ANSICodes.reset,
            to: Config.labelWidth
        )
        let percentStr: String
        if let p = percent {
            let raw = "\(p)%"
            percentStr = ANSIStringMetrics.padVisible(raw, to: Config.percentWidth)
        } else {
            percentStr = String(repeating: " ", count: Config.percentWidth)
        }
        let infoPadded = ANSIStringMetrics.padVisible(info, to: Config.infoWidth)

        let inner = labelPadded + gauge + percentStr + infoPadded
        let visLen = ANSIStringMetrics.visibleLength(inner)
        let innerWidth = width - 2 // subtract box borders
        let padding = max(0, innerWidth - visLen)

        return box.vertical + " "
            + inner
            + String(repeating: " ", count: max(0, padding - 2))
            + " " + box.vertical
    }

    /// Builds a bordered row from raw content, padding to fill the width.
    private static func boxRow(content: String, width: Int) -> String {
        let box = BoxDrawing.unicode
        let visLen = ANSIStringMetrics.visibleLength(content)
        let innerWidth = width - 2
        let padding = max(0, innerWidth - visLen - 2)

        return box.vertical + " "
            + content
            + String(repeating: " ", count: padding)
            + " " + box.vertical
    }

    /// Builds the process table header row.
    private static func processTableHeader(width: Int) -> String {
        let box = BoxDrawing.unicode
        let header = ANSICodes.bold
            + " PID    Name              CPU%    MEM%"
            + ANSICodes.reset
        let visLen = ANSIStringMetrics.visibleLength(header)
        let innerWidth = width - 2
        let padding = max(0, innerWidth - visLen)

        return box.vertical + header
            + String(repeating: " ", count: padding)
            + box.vertical
    }

    /// Builds a single process table row.
    private static func processRow(_ proc: ProcessEntry, width: Int) -> String {
        let box = BoxDrawing.unicode
        let pidStr = ANSIStringMetrics.padVisible(" \(proc.pid)", to: 7)
        let nameStr = ANSIStringMetrics.padVisible(proc.name, to: 18)
        let cpuStr = ANSIStringMetrics.padVisible(formatPercent(proc.cpuPercent), to: 8)
        let memStr = ANSIStringMetrics.padVisible(formatPercent(proc.memPercent), to: 8)

        let content = pidStr + nameStr + cpuStr + memStr
        let visLen = ANSIStringMetrics.visibleLength(content)
        let innerWidth = width - 2
        let padding = max(0, innerWidth - visLen)

        return box.vertical + content
            + String(repeating: " ", count: padding)
            + box.vertical
    }

    // MARK: - Data Generation

    /// Generates a simulated CPU value with realistic-looking fluctuation.
    private static func generateCPUValue() -> Double {
        // Base load around 30-50% with occasional spikes
        let base = 40.0
        let noise = Double.random(in: -20...25)
        return min(max(base + noise, 5), 98)
    }

    /// Generates a simulated network throughput value.
    private static func generateNetValue() -> Double {
        Double.random(in: 0.1...8.5)
    }

    /// Converts a memory usage percentage to a human-readable byte string.
    private static func memoryBytes(for percent: Double) -> String {
        // Simulate 16 GB total RAM
        let totalGB = 16.0
        let usedGB = totalGB * (percent / 100.0)
        let usedBytes = Int64(usedGB * 1_073_741_824)
        return Formatting.bytes(usedBytes)
    }

    /// Formats a Double as a one-decimal percentage string (e.g. "34.2").
    private static func formatPercent(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let intPart = Int(rounded)
        let fracPart = Int(((rounded - Double(intPart)) * 10).rounded())
        return "\(intPart).\(fracPart)"
    }

    /// Selects a gauge color based on usage level.
    private static func cpuColor(for percent: Int) -> Color {
        switch percent {
        case 0..<60:
            return .ansi8(.green)
        case 60..<80:
            return .ansi8(.yellow)
        default:
            return .ansi8(.red)
        }
    }

    // MARK: - Intro / Summary / Helpers

    private static func printIntro() {
        print(ANSICodes.bold + "Tier 3: System Monitor" + ANSICodes.reset)
        print("")
        print("This demo builds a complete system monitor dashboard using SwiftCLIKit.")
        print("You will see:")
        print("  - Live CPU and memory gauges with color-coded thresholds")
        print("  - A CPU history sparkline showing recent activity")
        print("  - Network I/O sparkline with throughput rate")
        print("  - A static disk usage gauge")
        print("  - A process table with fake system data")
        print("  - All wrapped in Unicode box-drawing borders")
        print("")
        print("The dashboard adapts to your terminal width and runs for ~10 seconds")
        print("inside an alternate screen buffer — your current screen will be restored")
        print("when it finishes.")
        print("")
    }

    private static func printSummary() {
        print("")
        print(ANSICodes.bold + "What you just saw:" + ANSICodes.reset)
        print("")
        print("  1. " + ANSICodes.bold + "AlternateScreen" + ANSICodes.reset
              + " — RAII pattern: create it, and the terminal switches to a clean")
        print("     buffer. When it goes out of scope (deinit), the original content returns.")
        print("")
        print("  2. " + ANSICodes.bold + "BoxDrawing.unicode" + ANSICodes.reset
              + " — topBorder, midBorder, bottomBorder, and vertical")
        print("     characters create bordered panels without manual character wrangling.")
        print("")
        print("  3. " + ANSICodes.bold + "InlineGauge.render()" + ANSICodes.reset
              + " — returns an ANSI string of exact visible width,")
        print("     perfect for embedding in composed layouts.")
        print("")
        print("  4. " + ANSICodes.bold + "InlineSparkline.render()" + ANSICodes.reset
              + " — visualizes time-series data as Unicode")
        print("     block characters. Right-aligned, auto-scrolling as data grows.")
        print("")
        print("  5. " + ANSICodes.bold + "TerminalSize.current()" + ANSICodes.reset
              + " — queried every frame so the layout adapts")
        print("     if you resize the terminal during the demo.")
        print("")
        print("  6. " + ANSICodes.bold + "ScreenBuffer" + ANSICodes.reset
              + " — .frame property prepends clear-screen + home-cursor,")
        print("     so each frame replaces the previous one flicker-free.")
        print("")
        print("  7. " + ANSICodes.bold + "Formatting" + ANSICodes.reset
              + " — .bytes() and .rate() produce human-readable strings")
        print("     for data sizes and throughput.")
        print("")
        print("Next up: Tier 4 (Live Dashboard) — JSON polling, diff rendering, and signal")
        print("handling for production-grade TUI apps.")
        print("")
    }

    private static func waitForEnter() {
        print("Press Enter to start the demo...")
        _ = readLine()
    }
}
