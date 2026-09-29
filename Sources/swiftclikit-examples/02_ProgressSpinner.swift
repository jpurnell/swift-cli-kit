// LOGGING-EXEMPT: example/demo program
// 02_ProgressSpinner.swift
// SwiftCLIKit Tutorial — Tier 2: Frame-Based Rendering
// Created by Justin Purnell on 2026-05-08.

import SwiftCLIKit
import Foundation

// MARK: - Animation Timing

/// Constants governing animation frame rates and durations.
/// Gathered here so every section is easy to tune without hunting through code.
private enum AnimationTiming {
    /// Interval between spinner frames (seconds).
    static let spinnerFrameInterval: TimeInterval = 0.08
    /// Total number of spinner revolutions to show.
    static let spinnerRevolutions = 3
    /// Interval between progress bar frames (seconds).
    static let progressFrameInterval: TimeInterval = 0.05
    /// Total number of steps for the progress bar animation.
    static let progressSteps = 60
    /// Interval between dashboard refresh frames (seconds).
    static let dashboardFrameInterval: TimeInterval = 0.10
    /// Total number of items the dashboard "processes."
    static let dashboardTotalItems = 47
    /// Interval between sparkline frames (seconds).
    static let sparklineFrameInterval: TimeInterval = 0.08
    /// Total number of data points the sparkline collects.
    static let sparklineTotalPoints = 50
    /// Display width used for gauges and sparklines (columns).
    static let displayWidth = 40
}

// MARK: - Braille Spinner Frames

/// The classic braille dot-circle spinner animation.
private let spinnerFrames: [String] = [
    "\u{280B}", "\u{2819}", "\u{2839}", "\u{2838}",
    "\u{283C}", "\u{2834}", "\u{2826}", "\u{2827}",
    "\u{2807}", "\u{280F}",
]

// MARK: - Public Entry Point

/// Tier 2 of the SwiftCLIKit tutorial system.
///
/// This tier teaches frame-based rendering — updating the terminal in-place
/// instead of scrolling output. You will learn about `ScreenBuffer`,
/// cursor control, unbuffered I/O, and the clear-render-sleep loop that
/// drives every real-time terminal UI.
enum ProgressSpinner {

    static func run() {
        // Disable stdout buffering so every write reaches the terminal immediately.
        // Without this, output would collect in a 4 KB buffer and appear in chunks
        // instead of smooth frames.
        setvbuf(stdout, nil, _IONBF, 0)

        printBanner()

        section1_basicSpinner()
        waitForEnter()
        section2_progressBar()
        waitForEnter()
        section3_multiLineDashboard()
        waitForEnter()
        section4_sparklineAnimation()

        // Always restore cursor visibility before exiting.
        print(CursorControl.show, terminator: "")
        printClosing()
    }

    // MARK: - Sections

    /// Section 1 — Basic Spinner
    ///
    /// Demonstrates the difference between scrolling output (`print` in a loop)
    /// and in-place updates (overwriting the same line each frame).
    private static func section1_basicSpinner() {
        printSectionHeader(
            number: 1,
            title: "Basic Spinner",
            description: """
            A spinner is the simplest frame-based animation: one character that \
            changes in place. The trick is overwriting the previous character \
            instead of printing a new line.

            Key concept: use a carriage return ("\\r") to move the cursor back \
            to the start of the line, then write new content on top of the old.
            """
        )

        let frameCount = spinnerFrames.count * AnimationTiming.spinnerRevolutions

        // --- The wrong way: scrolling output ---
        print(ANSICodes.dim + "  (The wrong way — scrolling output)" + ANSICodes.reset)
        for i in 0..<6 {
            let frame = spinnerFrames[i % spinnerFrames.count]
            print("  \(frame) Loading...")
        }
        print()

        // --- The right way: in-place updates ---
        print(ANSICodes.dim + "  (The right way — in-place updates)" + ANSICodes.reset)
        print(CursorControl.hide, terminator: "")

        for i in 0..<frameCount {
            let frame = spinnerFrames[i % spinnerFrames.count]
            // "\r" returns the cursor to column 1 on the current line.
            print("\r  \(frame) " + ANSICodes.bold + "Loading..." + ANSICodes.reset, terminator: "")
            fflush(stdout)
            Thread.sleep(forTimeInterval: AnimationTiming.spinnerFrameInterval)
        }

        // Clear the spinner line and print a completion message.
        print("\r  " + ANSICodes.fg(.green) + "\u{2714}" + ANSICodes.reset
              + " " + ANSICodes.bold + "Done!" + ANSICodes.reset
              + "       ") // trailing spaces erase leftover characters
        print(CursorControl.show, terminator: "")

        printConceptBox(
            "In-place updates work by moving the cursor back before writing. "
            + "For single-line animations, a carriage return (\"\\r\") is enough. "
            + "For multi-line displays, we need ScreenBuffer (coming in Section 3)."
        )
    }

    /// Section 2 — Progress Bar Animation
    ///
    /// Animates an `InlineGauge` from 0 to 100%, showing how `ScreenBuffer`
    /// composes a gauge and its label into a single atomic frame write.
    private static func section2_progressBar() {
        printSectionHeader(
            number: 2,
            title: "Progress Bar Animation",
            description: """
            Now we animate a full progress bar using InlineGauge. Instead of \
            writing raw characters, we compose the gauge and a percentage label \
            into a ScreenBuffer, then flush the whole thing as one frame.

            Key concept: ScreenBuffer.raw gives you the composed string without \
            screen-clearing escapes — perfect for single-line in-place updates.
            """
        )

        print(CursorControl.hide, terminator: "")

        let steps = AnimationTiming.progressSteps
        let width = AnimationTiming.displayWidth

        for step in 0...steps {
            let current = step
            let total = steps
            let percentage = (current * 100) / max(total, 1)

            var buf = ScreenBuffer(width: width + 20)
            buf.append("  ")
            buf.append(InlineGauge.render(
                current: current,
                total: total,
                width: width,
                filledColor: .ansi8(.cyan)
            ))
            buf.append(" " + ANSICodes.bold)
            // Right-align the percentage so it doesn't jitter.
            let pctText = "\(percentage)%"
            let padding = String(repeating: " ", count: max(4 - pctText.count, 0))
            buf.append(padding + pctText)
            buf.append(ANSICodes.reset)

            print("\r" + buf.raw, terminator: "")
            fflush(stdout)
            Thread.sleep(forTimeInterval: AnimationTiming.progressFrameInterval)
        }

        print() // newline after the bar
        print(CursorControl.show, terminator: "")

        printConceptBox(
            "ScreenBuffer.append() builds up the frame piece by piece. "
            + "We used .raw here because we only need the composed string, "
            + "not the clear-screen prefix. The gauge, padding, and label "
            + "are all one atomic write — no flicker."
        )
    }

    /// Section 3 — Multi-Line Dashboard
    ///
    /// Builds a 4-line live display that updates every 100 ms. This is where
    /// `ScreenBuffer.frame` shines: it prefixes the content with clear-screen
    /// + home-cursor so the entire display refreshes without scrolling.
    private static func section3_multiLineDashboard() {
        printSectionHeader(
            number: 3,
            title: "Multi-Line Dashboard",
            description: """
            Single-line updates are easy, but real dashboards have multiple rows. \
            ScreenBuffer.frame prepends clear-screen + home-cursor escapes so the \
            entire display redraws from the top-left corner every frame.

            Key concept: compose all lines with appendLine(), then write .frame \
            once — the terminal sees a single coherent image.
            """
        )

        print(CursorControl.hide, terminator: "")

        let totalItems = AnimationTiming.dashboardTotalItems
        let startTime = Date()
        var itemsProcessed = 0

        while itemsProcessed <= totalItems {
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = itemsProcessed

            var buf = ScreenBuffer(width: 60)

            // Title bar
            buf.appendLine(
                "  " + ANSICodes.bold + ANSICodes.fg(.brightCyan)
                + "=== SwiftCLIKit Dashboard ==="
                + ANSICodes.reset
            )
            buf.appendLine("")

            // Line 1: spinner + status
            let spinnerIdx = Int(elapsed / AnimationTiming.dashboardFrameInterval)
            let frame = spinnerFrames[spinnerIdx % spinnerFrames.count]
            let status = itemsProcessed < totalItems ? "Processing..." : "Complete!"
            let statusColor = itemsProcessed < totalItems
                ? ANSICodes.fg(.yellow)
                : ANSICodes.fg(.green)
            buf.appendLine(
                "  " + ANSICodes.fg(.cyan) + frame + ANSICodes.reset
                + " " + statusColor + ANSICodes.bold + status + ANSICodes.reset
            )

            // Line 2: progress bar
            let gauge = InlineGauge.renderWithLabel(
                current: progress,
                total: totalItems,
                width: AnimationTiming.displayWidth,
                filledColor: .ansi8(.green)
            )
            buf.appendLine("  " + gauge)

            // Line 3: items counter
            buf.appendLine(
                "  " + ANSICodes.dim + "Items: " + ANSICodes.reset
                + ANSICodes.bold + "\(progress)" + ANSICodes.reset
                + ANSICodes.dim + " / \(totalItems)" + ANSICodes.reset
            )

            // Line 4: elapsed time
            let elapsedStr = Formatting.duration(elapsed)
            buf.appendLine(
                "  " + ANSICodes.dim + "Elapsed: " + ANSICodes.reset
                + ANSICodes.bold + elapsedStr + ANSICodes.reset
            )

            print(buf.frame, terminator: "")
            fflush(stdout)

            if itemsProcessed >= totalItems {
                // Hold the final frame briefly so the user can read it.
                Thread.sleep(forTimeInterval: 0.5)
                break
            }

            Thread.sleep(forTimeInterval: AnimationTiming.dashboardFrameInterval)

            // Advance by 1-3 items per tick to look organic.
            let advance = min(
                1 + (spinnerIdx % 3),
                totalItems - itemsProcessed
            )
            itemsProcessed += advance
        }

        // Transition out of full-screen mode: clear and print summary below.
        print(ANSICodes.clearScreen + ANSICodes.home, terminator: "")
        print(CursorControl.show, terminator: "")

        printConceptBox(
            "ScreenBuffer.frame = clearScreen + home + content. Every frame "
            + "redraws from row 1, column 1, so multi-line layouts stay anchored. "
            + "This is the core pattern behind every full-screen terminal UI."
        )
    }

    /// Section 4 — Smooth Animation with InlineSparkline
    ///
    /// Generates random data points over time, appending to an array and
    /// re-rendering the sparkline each frame so the user sees it fill up
    /// from left to right.
    private static func section4_sparklineAnimation() {
        printSectionHeader(
            number: 4,
            title: "Live Sparkline",
            description: """
            A sparkline turns numeric data into a compact bar chart using Unicode \
            block characters. Here we generate random data in real time and watch \
            the sparkline fill from left to right — showing how streaming data \
            flows into a live visualization.

            Key concept: InlineSparkline.render() takes an array of values and a \
            width. When the array is shorter than the width, it left-pads with \
            spaces. As data grows, the display fills in naturally.
            """
        )

        print(CursorControl.hide, terminator: "")

        let totalPoints = AnimationTiming.sparklineTotalPoints
        let width = AnimationTiming.displayWidth
        var data: [Double] = []

        // Use a simple random walk so the sparkline looks organic.
        var value = 50.0

        for i in 0..<totalPoints {
            // Random walk: drift +-5, clamped to 0-100.
            let delta = Double.random(in: -5.0...5.0)
            value = min(max(value + delta, 0), 100)
            data.append(value)

            var buf = ScreenBuffer(width: width + 30)
            buf.append("  ")

            // Label
            let label = ANSICodes.dim + "Data " + ANSICodes.reset
                + ANSICodes.bold + "[\(i + 1)/\(totalPoints)]" + ANSICodes.reset
                + " "

            buf.append(label)

            // Sparkline
            let spark = InlineSparkline.render(
                data: data,
                width: width,
                color: .ansi8(.magenta),
                min: 0.0,
                max: 100.0
            )
            buf.append(spark)

            print("\r" + buf.raw, terminator: "")
            fflush(stdout)
            Thread.sleep(forTimeInterval: AnimationTiming.sparklineFrameInterval)
        }

        print() // newline after sparkline
        print(CursorControl.show, terminator: "")

        printConceptBox(
            "InlineSparkline maps each value to a Unicode block character "
            + "(from space to \u{2588}). With explicit min/max, the scale stays "
            + "fixed so new data doesn't rescale the whole chart. "
            + "This is the building block for live CPU monitors, network graphs, "
            + "and training-loss displays."
        )
    }

    // MARK: - Helpers

    private static func waitForEnter() {
        print(CursorControl.show, terminator: "")
        print(
            "\n"
            + ANSICodes.dim + "Press Enter to continue..."
            + ANSICodes.reset,
            terminator: ""
        )
        _ = readLine()
    }

    private static func printBanner() {
        print()
        print(
            ANSICodes.bold + ANSICodes.fg(.brightCyan)
            + "  ===  Tier 2: Frame-Based Rendering  ==="
            + ANSICodes.reset
        )
        print()
        print(
            "  Welcome! This tier teaches you how to update the terminal "
            + ANSICodes.italic + "in place" + ANSICodes.reset
        )
        print(
            "  instead of scrolling output. You will learn about ScreenBuffer,"
        )
        print(
            "  cursor control, unbuffered I/O, and animation frame loops."
        )
        print()
        print(
            ANSICodes.dim
            + "  Tip: setvbuf(stdout, nil, _IONBF, 0) disables output buffering."
            + ANSICodes.reset
        )
        print(
            ANSICodes.dim
            + "  Without it, frames collect in a 4 KB buffer and appear in chunks."
            + ANSICodes.reset
        )
        print()
    }

    private static func printClosing() {
        print()
        print(
            ANSICodes.bold + ANSICodes.fg(.brightGreen)
            + "  ===  Tier 2 Complete!  ==="
            + ANSICodes.reset
        )
        print()
        print("  You learned:")
        print(
            "    " + ANSICodes.fg(.cyan) + "\u{2022}" + ANSICodes.reset
            + " Unbuffered output with setvbuf"
        )
        print(
            "    " + ANSICodes.fg(.cyan) + "\u{2022}" + ANSICodes.reset
            + " Single-line in-place updates with carriage return"
        )
        print(
            "    " + ANSICodes.fg(.cyan) + "\u{2022}" + ANSICodes.reset
            + " ScreenBuffer for composing multi-part frames"
        )
        print(
            "    " + ANSICodes.fg(.cyan) + "\u{2022}" + ANSICodes.reset
            + " Full-screen redraws with ScreenBuffer.frame"
        )
        print(
            "    " + ANSICodes.fg(.cyan) + "\u{2022}" + ANSICodes.reset
            + " Hiding/showing the cursor during animations"
        )
        print(
            "    " + ANSICodes.fg(.cyan) + "\u{2022}" + ANSICodes.reset
            + " Streaming data into a live sparkline"
        )
        print()
        print(
            ANSICodes.dim
            + "  Next up: Tier 3 — Interactive Input"
            + ANSICodes.reset
        )
        print()
    }

    private static func printSectionHeader(number: Int, title: String, description: String) {
        print()
        print(
            "  " + ANSICodes.bold + ANSICodes.fg(.brightYellow)
            + "--- Section \(number): \(title) ---"
            + ANSICodes.reset
        )
        print()
        // Indent each line of the description.
        for line in description.lines {
            print("  " + line)
        }
        print()
    }

    private static func printConceptBox(_ text: String) {
        print()
        print(
            "  " + ANSICodes.fg(.brightBlue) + ANSICodes.bold
            + "\u{1F4A1} Key Takeaway:" + ANSICodes.reset
        )
        // Wrap text at ~70 columns for readability.
        let words = text.split(separator: " ")
        var line = "  "
        for word in words {
            if line.count + word.count + 1 > 74 {
                print(line)
                line = "  " + word
            } else {
                if line.count > 2 { line += " " }
                line += word
            }
        }
        if line.count > 2 { print(line) }
        print()
    }
}
