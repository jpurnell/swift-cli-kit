// Examples.swift
// swiftclikit-examples
// Created by Justin Purnell on 2026-05-07.

import Foundation
import SwiftCLIKit

@main
struct Examples {
    static func main() {
        let args = CommandLine.arguments
        guard args.count > 1, let tier = Int(args[1]) else {
            printUsage()
            return
        }

        switch tier {
        case 1: HelloTerminal.run()
        case 2: ProgressSpinner.run()
        case 3: SystemMonitor.run()
        case 4: LiveDashboard.run()
        default: printUsage()
        }
    }

    static func printUsage() {
        let box = BoxDrawing.unicode
        let width = 62

        // Title banner
        print("")
        print(ANSICodes.bold + ANSICodes.fg(.cyan) + box.topBorder("", width: width) + ANSICodes.reset)
        print(ANSICodes.bold + ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset
            + centerPad("SwiftCLIKit Tutorial Examples", width: width - 2)
            + ANSICodes.bold + ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset)
        print(ANSICodes.bold + ANSICodes.fg(.cyan) + box.midBorder(width: width) + ANSICodes.reset)

        // Tier entries
        let tiers: [(number: Int, title: String, description: String, color: ANSIColor)] = [
            (1, "Hello Terminal", "Colors, styles, 256-palette, truecolor, cursor, boxes", .green),
            (2, "Interactive Input", "Key reading, line editing, mouse events", .yellow),
            (3, "System Monitor", "Gauges, sparklines, box borders, alternate screen", .blue),
            (4, "Live Dashboard", "JSON polling, atomic writes, signal handling, diff rendering", .magenta),
        ]

        for tier in tiers {
            let numberTag = ANSICodes.bold + ANSICodes.fg(tier.color) + " \(tier.number)" + ANSICodes.reset
            let titleText = ANSICodes.bold + " \(tier.title)" + ANSICodes.reset
            let descText = ANSICodes.dim + "  \(tier.description)" + ANSICodes.reset

            print(ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset
                + numberTag + titleText)
            print(ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset
                + descText)

            if tier.number < tiers.count {
                print(ANSICodes.fg(.cyan) + box.vertical + ANSICodes.reset)
            }
        }

        print(ANSICodes.bold + ANSICodes.fg(.cyan) + box.bottomBorder(width: width) + ANSICodes.reset)

        // Usage instruction
        print("")
        print(ANSICodes.bold + "  Usage: " + ANSICodes.reset
            + ANSICodes.fg(.green) + "swift run swiftclikit-examples "
            + ANSICodes.fg(.yellow) + "<tier-number>" + ANSICodes.reset)
        print(ANSICodes.dim + "  Example: swift run swiftclikit-examples 1" + ANSICodes.reset)
        print("")
    }

    /// Center-pads a string within the given visible width.
    private static func centerPad(_ text: String, width: Int) -> String {
        let textLength = text.count
        guard width > textLength else { return text }
        let totalPad = width - textLength
        let leftPad = totalPad / 2
        let rightPad = totalPad - leftPad
        return String(repeating: " ", count: leftPad) + text + String(repeating: " ", count: rightPad)
    }
}
