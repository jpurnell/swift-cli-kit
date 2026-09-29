// LOGGING-EXEMPT: example/demo program
// 01_HelloTerminal.swift
// swiftclikit-examples — Tier 1: Hello Terminal
// Created by Justin Purnell on 2026-05-07.

import SwiftCLIKit

/// Tier 1: A guided tour of terminal rendering fundamentals.
///
/// This tutorial covers the building blocks that every terminal application
/// uses: colors, text styles, the 256-color palette, 24-bit truecolor,
/// cursor positioning, and box drawing. No alternate screen, no event loop —
/// just `print()` and ANSI escape sequences.
enum HelloTerminal {

    // MARK: - Configuration

    /// Width used for boxes and dividers throughout the tutorial.
    private static let displayWidth = 60

    // MARK: - Public entry point

    static func run() {
        section1_welcome()
        waitForEnter()
        section2_standardColors()
        waitForEnter()
        section3_brightColors()
        waitForEnter()
        section4_textStyles()
        waitForEnter()
        section5_256colorPalette()
        waitForEnter()
        section6_truecolorGradient()
        waitForEnter()
        section7_cursorPositioning()
        waitForEnter()
        section8_boxDrawing()

        // Farewell
        print("")
        printSectionHeader("Tutorial Complete", color: .green)
        print("")
        print("  You have seen the fundamental building blocks of terminal rendering.")
        print("  Every TUI framework — including SwiftCLIKit — builds on these primitives.")
        print("")
        print("  " + ANSICodes.bold + "Next up:" + ANSICodes.reset
            + " Tier 2 covers interactive input — reading keys, mouse events,")
        print("  and building a line editor.")
        print("")
        print("  Run: " + ANSICodes.fg(.green) + "swift run swiftclikit-examples 2" + ANSICodes.reset)
        print("")
    }

    // MARK: - Section 1: Welcome

    private static func section1_welcome() {
        print(ANSICodes.clearScreen + ANSICodes.home)

        let box = BoxDrawing.unicode
        let width = displayWidth

        print(ANSICodes.bold + ANSICodes.fg(.cyan) + box.topBorder("", width: width) + ANSICodes.reset)

        let title = "Tier 1: Hello Terminal"
        let subtitle = "A guided tour of terminal rendering basics"
        print(ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset
            + centerPad(ANSICodes.bold + ANSICodes.fg(.white) + title + ANSICodes.reset, visibleLength: title.count, width: width - 2)
            + ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset)
        print(ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset
            + centerPad(ANSICodes.dim + subtitle + ANSICodes.reset, visibleLength: subtitle.count, width: width - 2)
            + ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset)

        print(ANSICodes.bold + ANSICodes.fg(.cyan) + box.bottomBorder(width: width) + ANSICodes.reset)

        print("")
        print("  Terminals render text using " + ANSICodes.bold + "ANSI escape sequences" + ANSICodes.reset + " —")
        print("  invisible control characters that tell the terminal how to style")
        print("  text, move the cursor, and draw shapes.")
        print("")
        print("  SwiftCLIKit wraps these sequences in type-safe Swift APIs so you")
        print("  never have to memorize cryptic codes like " + ANSICodes.dim + "\\e[38;2;255;128;0m" + ANSICodes.reset)
        print("")
        print("  This tour will walk through each layer, from basic colors to")
        print("  box-drawing characters. Each section pauses so you can study")
        print("  the output before moving on.")
    }

    // MARK: - Section 2: Standard ANSI Colors

    private static func section2_standardColors() {
        printSectionHeader("Standard ANSI Colors (8 colors)", color: .yellow)
        print("")
        print("  Every terminal supports at least 8 colors. These are set with")
        print("  " + ANSICodes.dim + "ANSICodes.fg(.colorName)" + ANSICodes.reset
            + " for foreground and "
            + ANSICodes.dim + "ANSICodes.bg(.colorName)" + ANSICodes.reset + " for background.")
        print("")

        // The 8 standard colors
        let standardColors: [ANSIColor] = [.black, .red, .green, .yellow, .blue, .magenta, .cyan, .white]
        let colorNames = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

        // Foreground demo
        print("  " + ANSICodes.bold + "Foreground:" + ANSICodes.reset)
        var fgLine = "  "
        for (index, color) in standardColors.enumerated() {
            let name = colorNames[index]
            // Use white background for black text visibility
            if color == .black {
                fgLine += ANSICodes.fg(color) + ANSICodes.bg(.white) + " \(name) " + ANSICodes.reset + " "
            } else {
                fgLine += ANSICodes.fg(color) + " \(name) " + ANSICodes.reset + " "
            }
        }
        print(fgLine)
        print("")

        // Background demo
        print("  " + ANSICodes.bold + "Background:" + ANSICodes.reset)
        var bgLine = "  "
        for (index, color) in standardColors.enumerated() {
            let name = colorNames[index]
            // Use white text on dark backgrounds, black text on light ones
            let textColor: ANSIColor = (color == .white || color == .yellow || color == .cyan) ? .black : .white
            bgLine += ANSICodes.bg(color) + ANSICodes.fg(textColor) + " \(name) " + ANSICodes.reset + " "
            // Line break after 4 colors to avoid wrapping
            if index == 3 {
                print(bgLine)
                bgLine = "  "
            }
        }
        print(bgLine)

        print("")
        print("  " + ANSICodes.dim + "Code: ANSICodes.fg(.red) + \"Hello\" + ANSICodes.reset" + ANSICodes.reset)
    }

    // MARK: - Section 3: Bright / High-Intensity Colors

    private static func section3_brightColors() {
        printSectionHeader("Bright / High-Intensity Colors", color: .brightCyan)
        print("")
        print("  Each standard color has a bright variant. These are sometimes called")
        print("  \"high-intensity\" colors and occupy ANSI codes 90-97 (foreground).")
        print("")

        let brightColors: [ANSIColor] = [
            .brightBlack, .brightRed, .brightGreen, .brightYellow,
            .brightBlue, .brightMagenta, .brightCyan, .brightWhite,
        ]
        let brightNames = [
            "brBlack", "brRed", "brGreen", "brYellow",
            "brBlue", "brMagenta", "brCyan", "brWhite",
        ]

        // Side-by-side: standard vs bright
        print("  " + ANSICodes.bold + "Standard vs. Bright:" + ANSICodes.reset)
        print("")

        let standardColors: [ANSIColor] = [.black, .red, .green, .yellow, .blue, .magenta, .cyan, .white]
        let standardNames = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

        for i in 0..<standardColors.count {
            let stdColor = standardColors[i]
            let brtColor = brightColors[i]
            let stdName = standardNames[i].padding(toLength: 9, withPad: " ", startingAt: 0)
            let brtName = brightNames[i]

            let stdBg: ANSIColor = (stdColor == .black) ? .white : .black
            let brtBg: ANSIColor = (brtColor == .brightBlack) ? .white : .black

            let stdSample = ANSICodes.bg(stdBg) + ANSICodes.fg(stdColor) + " \(stdName)" + ANSICodes.reset
            let brtSample = ANSICodes.bg(brtBg) + ANSICodes.fg(brtColor) + " \(brtName)" + ANSICodes.reset

            // Skip black row contrast issues — just show them both on white bg
            if stdColor == .black || stdColor == .white {
                let s = ANSICodes.bg(.white) + ANSICodes.fg(stdColor) + " \(stdName)" + ANSICodes.reset
                let b = ANSICodes.bg(.white) + ANSICodes.fg(brtColor) + " \(brtName)" + ANSICodes.reset
                print("    \(s)  ->  \(b)")
            } else {
                print("    \(stdSample)  ->  \(brtSample)")
            }
        }

        print("")
        print("  " + ANSICodes.dim + "Code: ANSICodes.fg(.brightRed) + \"Bright!\" + ANSICodes.reset" + ANSICodes.reset)
    }

    // MARK: - Section 4: Text Styles

    private static func section4_textStyles() {
        printSectionHeader("Text Styles (SGR Attributes)", color: .magenta)
        print("")
        print("  Beyond color, terminals support several text decoration styles.")
        print("  These can be combined with each other and with colors.")
        print("")

        let styles: [(name: String, code: String, description: String)] = [
            ("Bold", ANSICodes.bold, "Thicker/brighter text"),
            ("Dim", ANSICodes.dim, "Faint/half-brightness text"),
            ("Italic", ANSICodes.italic, "Slanted text (terminal-dependent)"),
            ("Underline", ANSICodes.underline, "Single underline beneath text"),
            ("Strikethrough", ANSICodes.strikethrough, "Line through the middle of text"),
            ("Reverse", ANSICodes.reverse, "Swaps foreground and background"),
            ("Overline", ANSICodes.overline, "Line above text (modern terminals)"),
        ]

        for style in styles {
            let label = style.name.padding(toLength: 15, withPad: " ", startingAt: 0)
            print("    " + style.code + label + ANSICodes.reset
                + ANSICodes.dim + " — \(style.description)" + ANSICodes.reset)
        }

        print("")
        print("  " + ANSICodes.bold + "Combining styles:" + ANSICodes.reset)
        print("    "
            + ANSICodes.bold + ANSICodes.italic + ANSICodes.fg(.cyan)
            + "Bold + Italic + Cyan"
            + ANSICodes.reset + "  "
            + ANSICodes.underline + ANSICodes.fg(.yellow)
            + "Underline + Yellow"
            + ANSICodes.reset + "  "
            + ANSICodes.bold + ANSICodes.strikethrough + ANSICodes.fg(.red)
            + "Bold + Strike + Red"
            + ANSICodes.reset)
        print("")
        print("  " + ANSICodes.dim + "Code: ANSICodes.bold + ANSICodes.italic + \"styled\" + ANSICodes.reset" + ANSICodes.reset)
    }

    // MARK: - Section 5: 256-Color Palette

    private static func section5_256colorPalette() {
        printSectionHeader("256-Color Extended Palette", color: .blue)
        print("")
        print("  Most modern terminals support 256 colors: the 16 standard/bright colors,")
        print("  a 6x6x6 color cube (indices 16-231), and a 24-step grayscale ramp (232-255).")
        print("")

        // Standard + bright colors (0-15)
        print("  " + ANSICodes.bold + "Standard + Bright (0-15):" + ANSICodes.reset)
        var row = "  "
        for i: UInt8 in 0...15 {
            let textColor: String = (i == 0 || (i >= 4 && i <= 6) || i == 8) ? ANSICodes.fg(.white) : ANSICodes.fg(.black)
            let label = "\(i)".padding(toLength: 4, withPad: " ", startingAt: 0)
            row += ANSICodes.bg256(i) + textColor + label + ANSICodes.reset
            if i == 7 {
                print(row)
                row = "  "
            }
        }
        print(row)
        print("")

        // 6x6x6 color cube (16-231)
        print("  " + ANSICodes.bold + "Color Cube (16-231):" + ANSICodes.reset)
        // Show 6 rows of 36 colors each
        for rowStart in stride(from: 16, to: 232, by: 36) {
            var line = "  "
            let rowEnd = min(rowStart + 36, 232)
            for i in rowStart..<rowEnd {
                line += ANSICodes.bg256(UInt8(i)) + "  " + ANSICodes.reset
            }
            print(line)
        }
        print("")

        // Grayscale ramp (232-255)
        print("  " + ANSICodes.bold + "Grayscale Ramp (232-255):" + ANSICodes.reset)
        var grayLine = "  "
        for i: UInt8 in 232...255 {
            grayLine += ANSICodes.bg256(i) + "  " + ANSICodes.reset
        }
        print(grayLine)

        print("")
        print("  " + ANSICodes.dim + "Code: ANSICodes.bg256(208) + \" orange \" + ANSICodes.reset" + ANSICodes.reset)
    }

    // MARK: - Section 6: Truecolor RGB Gradient

    private static func section6_truecolorGradient() {
        printSectionHeader("24-bit Truecolor (16 million colors)", color: .red)
        print("")
        print("  Truecolor lets you specify any of 16,777,216 RGB values directly.")
        print("  Here are smooth gradients that would be impossible with only 256 colors.")
        print("")

        let gradientWidth = 56

        // Red -> Yellow -> Green -> Cyan -> Blue -> Magenta -> Red (rainbow)
        print("  " + ANSICodes.bold + "Rainbow:" + ANSICodes.reset)
        var rainbow = "  "
        for i in 0..<gradientWidth {
            let hue = Double(i) / 56.0
            let (r, g, b) = hueToRGB(hue)
            rainbow += ANSICodes.bgRGB(r, g, b) + " " + ANSICodes.reset
        }
        print(rainbow)
        print("")

        // Fire gradient: black -> red -> orange -> yellow -> white
        print("  " + ANSICodes.bold + "Fire:" + ANSICodes.reset)
        var fire = "  "
        for i in 0..<gradientWidth {
            let t = Double(i) / 55.0
            let (r, g, b) = fireGradient(t)
            fire += ANSICodes.bgRGB(r, g, b) + " " + ANSICodes.reset
        }
        print(fire)
        print("")

        // Ocean gradient: deep blue -> teal -> seafoam
        print("  " + ANSICodes.bold + "Ocean:" + ANSICodes.reset)
        var ocean = "  "
        for i in 0..<gradientWidth {
            let t = Double(i) / 55.0
            let r = UInt8(clamping: Int(10 + t * 60))
            let g = UInt8(clamping: Int(20 + t * 200))
            let b = UInt8(clamping: Int(80 + t * 175))
            ocean += ANSICodes.bgRGB(r, g, b) + " " + ANSICodes.reset
        }
        print(ocean)
        print("")

        // Gradient text
        print("  " + ANSICodes.bold + "Gradient text:" + ANSICodes.reset)
        let message = "SwiftCLIKit makes terminal color easy"
        var gradientText = "  "
        let charCount = Double(message.count)
        guard charCount > 0 else { return }
        for (index, char) in message.enumerated() {
            let hue = Double(index) / charCount
            let (r, g, b) = hueToRGB(hue)
            gradientText += ANSICodes.fgRGB(r, g, b) + String(char)
        }
        gradientText += ANSICodes.reset
        print(gradientText)

        print("")
        print("  " + ANSICodes.dim + "Code: ANSICodes.fgRGB(255, 128, 0) + \"orange\" + ANSICodes.reset" + ANSICodes.reset)
    }

    // MARK: - Section 7: Cursor Positioning

    private static func section7_cursorPositioning() {
        printSectionHeader("Cursor Positioning", color: .green)
        print("")
        print("  ANSI lets you move the cursor to any row/column on screen.")
        print("  This is how TUI apps draw UI elements at precise locations.")
        print("")

        // Save the current position, then draw scattered text
        // We'll use a bounded region to keep things tidy.

        // First, print enough blank lines to create a canvas
        let canvasRows = 8
        for _ in 0..<canvasRows {
            print("")
        }

        // Now move the cursor back up and place text at specific coordinates
        // We use CursorControl.moveUp to get back to the canvas start
        print(CursorControl.moveUp(canvasRows), terminator: "")

        // Save this position as our canvas origin
        print(CursorControl.save, terminator: "")

        // Draw some positioned text relative to current position
        // Using moveDown/moveRight for relative positioning within our canvas
        let placements: [(downFromTop: Int, col: Int, text: String, color: ANSIColor)] = [
            (0, 5, "Row 0, Col 5", .cyan),
            (1, 20, "Row 1, Col 20", .yellow),
            (2, 35, "Row 2, Col 35", .green),
            (3, 10, "Row 3, Col 10", .magenta),
            (4, 25, "Anywhere!", .brightRed),
            (5, 3, "The cursor is your paintbrush", .brightCyan),
        ]

        for placement in placements {
            // Restore to canvas origin, then move to target
            print(CursorControl.restore, terminator: "")
            if placement.downFromTop > 0 {
                print(CursorControl.moveDown(placement.downFromTop), terminator: "")
            }
            if placement.col > 0 {
                print(CursorControl.moveRight(placement.col), terminator: "")
            }
            print(ANSICodes.fg(placement.color) + ANSICodes.bold + placement.text + ANSICodes.reset, terminator: "")
        }

        // Move past the canvas
        print(CursorControl.restore, terminator: "")
        print(CursorControl.moveDown(canvasRows), terminator: "")
        print("") // newline to reset

        print("")
        print("  " + ANSICodes.dim + "Code: CursorControl.moveTo(row: 5, column: 10)" + ANSICodes.reset)
        print("  " + ANSICodes.dim + "      CursorControl.moveUp(3), .moveDown(2), .moveRight(5)" + ANSICodes.reset)
    }

    // MARK: - Section 8: Box Drawing

    private static func section8_boxDrawing() {
        printSectionHeader("Box Drawing Characters", color: .brightYellow)
        print("")
        print("  Unicode box-drawing characters create clean borders and frames.")
        print("  SwiftCLIKit provides both Unicode and ASCII fallback sets.")
        print("")

        let box = BoxDrawing.unicode
        let width = 40

        // Simple box
        print("  " + ANSICodes.bold + "Simple box:" + ANSICodes.reset)
        print("  " + ANSICodes.fg(.cyan) + box.topBorder("", width: width) + ANSICodes.reset)
        printBoxLine(box: box, width: width, content: "A simple bordered box", color: .white)
        printBoxLine(box: box, width: width, content: "with multiple lines of content", color: .white)
        print("  " + ANSICodes.fg(.cyan) + box.bottomBorder(width: width) + ANSICodes.reset)
        print("")

        // Box with header
        print("  " + ANSICodes.bold + "Box with inline header:" + ANSICodes.reset)
        print("  " + ANSICodes.fg(.green) + box.topBorder(" Status ", width: width) + ANSICodes.reset)
        printBoxLine(box: box, width: width, content: ANSICodes.fg(.green) + "All systems operational" + ANSICodes.reset, color: .green)
        print("  " + ANSICodes.fg(.green) + box.midBorder(width: width) + ANSICodes.reset)
        printBoxLine(box: box, width: width, content: "CPU: 23%   MEM: 1.2 GB", color: .green)
        printBoxLine(box: box, width: width, content: "Uptime: 47 days", color: .green)
        print("  " + ANSICodes.fg(.green) + box.bottomBorder(width: width) + ANSICodes.reset)
        print("")

        // ASCII fallback comparison
        let asciiBox = BoxDrawing.ascii
        print("  " + ANSICodes.bold + "ASCII fallback (for minimal terminals):" + ANSICodes.reset)
        print("  " + ANSICodes.fg(.yellow) + asciiBox.topBorder(" ASCII ", width: width) + ANSICodes.reset)
        printBoxLine(box: asciiBox, width: width, content: "Works everywhere, even over SSH", color: .yellow)
        print("  " + ANSICodes.fg(.yellow) + asciiBox.bottomBorder(width: width) + ANSICodes.reset)
        print("")

        // Nested boxes to show composability
        print("  " + ANSICodes.bold + "Character reference:" + ANSICodes.reset)
        let chars = [
            ("\(box.topLeft) topLeft", "\(box.topRight) topRight"),
            ("\(box.bottomLeft) bottomLeft", "\(box.bottomRight) bottomRight"),
            ("\(box.horizontal) horizontal", "\(box.vertical) vertical"),
            ("\(box.leftTee) leftTee", "\(box.rightTee) rightTee"),
            ("\(box.topTee) topTee", "\(box.bottomTee) bottomTee"),
            ("\(box.cross) cross", ""),
        ]
        for pair in chars {
            let left = pair.0.padding(toLength: 20, withPad: " ", startingAt: 0)
            print("    " + ANSICodes.fg(.cyan) + left + ANSICodes.reset
                + ANSICodes.fg(.cyan) + pair.1 + ANSICodes.reset)
        }

        print("")
        print("  " + ANSICodes.dim + "Code: let box = BoxDrawing.unicode" + ANSICodes.reset)
        print("  " + ANSICodes.dim + "      box.topBorder(\" Title \", width: 40)" + ANSICodes.reset)
    }

    // MARK: - Helpers

    /// Prints a section header with a horizontal rule.
    private static func printSectionHeader(_ title: String, color: ANSIColor) {
        print("")
        let rule = String(repeating: BoxDrawing.unicode.horizontal, count: displayWidth)
        print(ANSICodes.fg(color) + rule + ANSICodes.reset)
        print(ANSICodes.bold + ANSICodes.fg(color) + "  \(title)" + ANSICodes.reset)
        print(ANSICodes.fg(color) + rule + ANSICodes.reset)
    }

    /// Prints a line of content inside a box (with padding).
    private static func printBoxLine(box: BoxDrawing, width: Int, content: String, color: ANSIColor) {
        let visibleLen = visibleLength(content)
        let innerWidth = width - 2  // subtract the two vertical bars
        let paddingCount = max(0, innerWidth - visibleLen)
        print("  " + ANSICodes.fg(color) + box.vertical + ANSICodes.reset
            + " " + content + String(repeating: " ", count: paddingCount > 0 ? paddingCount - 1 : 0)
            + ANSICodes.fg(color) + box.vertical + ANSICodes.reset)
    }

    /// Pauses until the user presses Enter.
    private static func waitForEnter() {
        print("")
        print(ANSICodes.dim + "  Press Enter to continue..." + ANSICodes.reset, terminator: "")
        _ = readLine()
    }

    /// Center-pads a styled string within a given width, using the known visible length.
    private static func centerPad(_ styledText: String, visibleLength: Int, width: Int) -> String {
        guard width > visibleLength else { return styledText }
        let totalPad = width - visibleLength
        let leftPad = totalPad / 2
        let rightPad = totalPad - leftPad
        return String(repeating: " ", count: leftPad) + styledText + String(repeating: " ", count: rightPad)
    }

    /// Strips ANSI escape sequences and returns the visible character count.
    private static func visibleLength(_ text: String) -> Int {
        // Strip all CSI sequences: ESC [ ... final_byte
        var stripped = text
        while let escRange = stripped.range(of: "\u{001B}[", options: .literal) {
            // Find the end of the CSI sequence (first letter in @-~ range after the [)
            let searchStart = escRange.upperBound
            var endIndex = searchStart
            while endIndex < stripped.endIndex {
                let scalar = stripped[endIndex].unicodeScalars.first?.value ?? 0
                endIndex = stripped.index(after: endIndex)
                if scalar >= 0x40 && scalar <= 0x7E {
                    break
                }
            }
            stripped.removeSubrange(escRange.lowerBound..<endIndex)
        }
        return stripped.count
    }

    /// Converts a hue (0.0-1.0) to RGB. Simple HSV-to-RGB with full saturation and value.
    private static func hueToRGB(_ hue: Double) -> (UInt8, UInt8, UInt8) {
        let h = hue * 6.0
        let sector = Int(h) % 6
        let f = h - Double(Int(h))
        let q = 1.0 - f
        let t = f

        let rf: Double
        let gf: Double
        let bf: Double

        switch sector {
        case 0: rf = 1; gf = t; bf = 0
        case 1: rf = q; gf = 1; bf = 0
        case 2: rf = 0; gf = 1; bf = t
        case 3: rf = 0; gf = q; bf = 1
        case 4: rf = t; gf = 0; bf = 1
        default: rf = 1; gf = 0; bf = q
        }

        return (
            UInt8(clamping: Int(rf * 255)),
            UInt8(clamping: Int(gf * 255)),
            UInt8(clamping: Int(bf * 255))
        )
    }

    /// Generates a fire gradient color for parameter t in 0.0...1.0.
    /// Progresses through: black -> dark red -> red -> orange -> yellow -> white.
    private static func fireGradient(_ t: Double) -> (UInt8, UInt8, UInt8) {
        let r: Double
        let g: Double
        let b: Double

        if t < 0.33 {
            // Black to red
            let local = t / 0.33
            r = local
            g = 0
            b = 0
        } else if t < 0.66 {
            // Red to yellow
            let local = (t - 0.33) / 0.33
            r = 1
            g = local
            b = 0
        } else {
            // Yellow to white
            let local = (t - 0.66) / 0.34
            r = 1
            g = 1
            b = local
        }

        return (
            UInt8(clamping: Int(r * 255)),
            UInt8(clamping: Int(g * 255)),
            UInt8(clamping: Int(b * 255))
        )
    }
}
