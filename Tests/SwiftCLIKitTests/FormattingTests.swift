// FormattingTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-05-07.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Formatting")
struct FormattingTests {

    // MARK: - elapsed

    @Test("elapsed: under 60s returns < 1m")
    func elapsedUnderMinute() {
        #expect(Formatting.elapsed(30) == "< 1m")
    }

    @Test("elapsed: 90s returns 1m 30s")
    func elapsed90Seconds() {
        #expect(Formatting.elapsed(90) == "1m 30s")
    }

    @Test("elapsed: 3723s returns 1h 2m")
    func elapsedOverHour() {
        #expect(Formatting.elapsed(3723) == "1h 2m")
    }

    @Test("elapsed: negative returns < 1m")
    func elapsedNegative() {
        #expect(Formatting.elapsed(-5) == "< 1m")
    }

    @Test("elapsed: zero returns < 1m")
    func elapsedZero() {
        #expect(Formatting.elapsed(0) == "< 1m")
    }

    @Test("elapsed: exactly 60s returns 1m 0s")
    func elapsedExactMinute() {
        #expect(Formatting.elapsed(60) == "1m 0s")
    }

    @Test("elapsed: exactly 7200s returns 2h 0m")
    func elapsedExactTwoHours() {
        #expect(Formatting.elapsed(7200) == "2h 0m")
    }

    // MARK: - duration

    @Test("duration: sub-second returns < 1s")
    func durationSubSecond() {
        #expect(Formatting.duration(0.5) == "< 1s")
    }

    @Test("duration: 45s returns 45s")
    func duration45Seconds() {
        #expect(Formatting.duration(45) == "45s")
    }

    @Test("duration: 330s returns 5m 30s")
    func duration330Seconds() {
        #expect(Formatting.duration(330) == "5m 30s")
    }

    @Test("duration: 3723s returns 1h 2m 3s")
    func durationOverHour() {
        #expect(Formatting.duration(3723) == "1h 2m 3s")
    }

    @Test("duration: negative returns < 1s")
    func durationNegative() {
        #expect(Formatting.duration(-1) == "< 1s")
    }

    // MARK: - bytes

    @Test("bytes: zero returns 0 B")
    func bytesZero() {
        #expect(Formatting.bytes(0) == "0 B")
    }

    @Test("bytes: 512 returns 512 B")
    func bytes512() {
        #expect(Formatting.bytes(512) == "512 B")
    }

    @Test("bytes: 1024 returns 1.0 KB")
    func bytesOneKB() {
        #expect(Formatting.bytes(1024) == "1.0 KB")
    }

    @Test("bytes: 1 MB returns 1.0 MB")
    func bytesOneMB() {
        #expect(Formatting.bytes(1_048_576) == "1.0 MB")
    }

    @Test("bytes: 1 GB returns 1.0 GB")
    func bytesOneGB() {
        #expect(Formatting.bytes(1_073_741_824) == "1.0 GB")
    }

    @Test("bytes: 1536 returns 1.5 KB")
    func bytes1536() {
        #expect(Formatting.bytes(1_536) == "1.5 KB")
    }

    @Test("bytes: negative returns 0 B")
    func bytesNegative() {
        #expect(Formatting.bytes(-1) == "0 B")
    }

    // MARK: - time

    /// A fixed instant on 2026-01-15 in UTC, with the zone used to build it.
    ///
    /// `TimeZone(identifier: "UTC")` and a Gregorian calendar's `date(from:)` for a
    /// fully specified component set are not conditions a formatting test is entitled
    /// to skip over: if either returns nil the fixture is broken, so `try #require`
    /// fails the test rather than letting it report success having asserted nothing.
    private static func utcInstant(
        hour: Int, minute: Int, second: Int
    ) throws -> (date: Date, zone: TimeZone) {
        let zone = try #require(TimeZone(identifier: "UTC"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = zone

        let date = try #require(calendar.date(from: components))
        return (date, zone)
    }

    @Test("time: formats HH:mm:ss in UTC")
    func timeFormatsFull() throws {
        let (date, zone) = try Self.utcInstant(hour: 8, minute: 5, second: 3)
        #expect(Formatting.time(date, timeZone: zone) == "08:05:03")
    }

    @Test("time: formats afternoon HH:mm:ss in UTC")
    func timeFormatsAfternoon() throws {
        let (date, zone) = try Self.utcInstant(hour: 14, minute: 30, second: 0)
        #expect(Formatting.time(date, timeZone: zone) == "14:30:00")
    }

    // MARK: - timeShort

    @Test("timeShort: formats HH:mm in UTC")
    func timeShortFormats() throws {
        let (date, zone) = try Self.utcInstant(hour: 8, minute: 5, second: 3)
        #expect(Formatting.timeShort(date, timeZone: zone) == "08:05")
    }

    // MARK: - rate

    @Test("rate: formats with one decimal and unit")
    func rateFormats() {
        #expect(Formatting.rate(1.5, unit: "games/min") == "1.5 games/min")
    }

    @Test("rate: zero formats as 0.0")
    func rateZero() {
        #expect(Formatting.rate(0.0, unit: "req/s") == "0.0 req/s")
    }

    @Test("rate: negative clamps to 0.0")
    func rateNegative() {
        #expect(Formatting.rate(-1.0, unit: "x/s") == "0.0 x/s")
    }
}
