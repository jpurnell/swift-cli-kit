// TerminalSettingsTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("TerminalSettings")
struct TerminalSettingsTests {

    @Test("Loading missing app returns default settings")
    func loadMissing() {
        let settings = TerminalSettings.load(appName: "test-\(UUID().uuidString)")
        #expect(settings.renderWidth == 0)
        #expect(settings.colorMode == .auto)
        #expect(settings.asciiOnly == false)
    }

    @Test("Save and load round-trip preserves all fields")
    func saveLoadRoundTrip() throws {
        let appName = "test-\(UUID().uuidString)"
        let original = TerminalSettings(renderWidth: 120, colorMode: .always, asciiOnly: true)
        try original.save(appName: appName)

        let loaded = TerminalSettings.load(appName: appName)
        #expect(loaded.renderWidth == 120)
        #expect(loaded.colorMode == .always)
        #expect(loaded.asciiOnly == true)

        // Clean up: remove the settings file if it exists
        let configDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let configDir = configDir {
            let filePath = configDir.appendingPathComponent(appName).appendingPathExtension("json")
            try? FileManager.default.removeItem(at: filePath)
        }
    }

    @Test("ColorMode.never resolves to false")
    func resolveNever() {
        let settings = TerminalSettings(colorMode: .never)
        #expect(settings.resolveColor() == false)
    }

    @Test("ColorMode.always resolves to true")
    func resolveAlways() {
        let settings = TerminalSettings(colorMode: .always)
        #expect(settings.resolveColor() == true)
    }

    @Test("ColorMode.auto with isatty override true resolves to true")
    func resolveAutoIsattyTrue() {
        let settings = TerminalSettings(colorMode: .auto)
        #expect(settings.resolveColor(isattyOverride: true) == true)
    }

    @Test("ColorMode.auto with isatty override false resolves to false")
    func resolveAutoIsattyFalse() {
        let settings = TerminalSettings(colorMode: .auto)
        #expect(settings.resolveColor(isattyOverride: false) == false)
    }

    @Test("ColorMode.auto with nil override returns a Bool without crashing")
    func resolveAutoDefault() {
        let settings = TerminalSettings()
        let result = settings.resolveColor(isattyOverride: nil)
        #expect(result == true || result == false)
    }
}
