// main.swift
// qg-dashboard
//
// A runnable dashboard for quality-gate. Pipe a JSON gate run into it:
//
//     quality-gate --check all --format json | qg-dashboard
//
// It prints a bordered status board — ANSI/color to a terminal, plain text when
// piped or when NO_COLOR is set (honoring the CLI accessibility convention).

import Foundation
import QualityGateDashboard
import SwiftCLIKit

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// Read the whole JSON payload from stdin, in bounded chunks against an explicit ceiling.
let checks: [GateCheck]
do {
    checks = try QualityGateDashboard.checks(fromJSON: StandardInput.readAll())
} catch let error as StandardInput.ReadError {
    FileHandle.standardError.write(Data("qg-dashboard: could not read stdin — \(error)\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("qg-dashboard: could not parse quality-gate JSON — \(error)\n".utf8))
    exit(1)
}

let width = 60
let height = max(8, checks.count + 6)   // border + summary + gaps + rows + gauge

let isTTY = isatty(fileno(stdout)) != 0
let noColor = ProcessInfo.processInfo.environment["NO_COLOR"] != nil

let output = (isTTY && !noColor)
    ? QualityGateDashboard.renderTerminal(checks: checks, width: width, height: height)
    : QualityGateDashboard.renderPlainText(checks: checks, width: width, height: height)

// The rendered board is this tool's product; it goes to stdout so it can be
// piped or redirected. (os.Logger writes to the unified log, not stdout.)
FileHandle.standardOutput.write(Data((output + "\n").utf8))

// Exit non-zero if the gate isn't green, so `qg-dashboard` is CI-friendly.
exit(checks.contains { $0.status == .failed } ? 1 : 0)
