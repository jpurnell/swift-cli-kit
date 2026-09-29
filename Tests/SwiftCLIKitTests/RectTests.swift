// RectTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Rect")
struct RectTests {

    @Test("Intersection of overlapping rects is correct; non-overlapping returns nil")
    func intersection() throws {
        let a = Rect(x: 0, y: 0, width: 10, height: 10)
        let b = Rect(x: 5, y: 5, width: 10, height: 10)
        let overlap = try #require(a.intersection(b))
        #expect(overlap == Rect(x: 5, y: 5, width: 5, height: 5))

        let c = Rect(x: 20, y: 20, width: 5, height: 5)
        #expect(a.intersection(c) == nil)
    }

    @Test("Contains returns true for interior and edge, false for outside")
    func contains() {
        let r = Rect(x: 5, y: 5, width: 10, height: 10)
        // Interior point
        #expect(r.contains(x: 7, y: 7) == true)
        // Top-left corner (edge)
        #expect(r.contains(x: 5, y: 5) == true)
        // Just outside
        #expect(r.contains(x: 4, y: 5) == false)
        #expect(r.contains(x: 15, y: 5) == false)
    }

    @Test("Area and isEmpty for zero and positive rects")
    func areaAndEmpty() {
        let empty = Rect(x: 0, y: 0, width: 0, height: 5)
        #expect(empty.area == 0)
        #expect(empty.isEmpty == true)

        let normal = Rect(x: 0, y: 0, width: 10, height: 5)
        #expect(normal.area == 50)
        #expect(normal.isEmpty == false)
    }

    @Test("Default init produces all-zero rect")
    func initDefaults() {
        let r = Rect()
        #expect(r.x == 0)
        #expect(r.y == 0)
        #expect(r.width == 0)
        #expect(r.height == 0)
    }
}
