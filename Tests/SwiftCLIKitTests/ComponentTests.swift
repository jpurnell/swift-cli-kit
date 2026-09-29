// ComponentTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("Component")
struct ComponentTests {

    // MARK: - Test Types

    struct ChildModel: Sendable, Equatable { var count: Int = 0 }
    enum ChildMsg: Sendable, Equatable { case increment, decrement }
    enum ParentMsg: Sendable, Equatable { case child(ChildMsg), other }

    private func makeCounter() -> Component<ChildModel, ChildMsg, ParentMsg> {
        Component(
            initialModel: ChildModel(count: 0),
            update: { model, msg in
                switch msg {
                case .increment: model.count += 1
                case .decrement: model.count -= 1
                }
                return []
            },
            view: { model in { frame in
                frame.writeText("Count: \(model.count)", x: 0, y: 0)
            }},
            toParent: { .child($0) }
        )
    }

    @Test("Sending a message updates the child model")
    func childModelUpdated() {
        var counter = makeCounter()
        _ = counter.send(.increment)
        #expect(counter.model.count == 1)
    }

    @Test("Send returns mapped parent commands")
    func childMessageMapped() {
        var component = Component<ChildModel, ChildMsg, ParentMsg>(
            initialModel: ChildModel(count: 0),
            update: { model, msg in
                model.count += 1
                return [.task { .increment }]
            },
            view: { _ in { _ in } },
            toParent: { .child($0) }
        )
        let cmds = component.send(.increment)
        #expect(cmds.isEmpty == false)
    }

    @Test("Render writes into the frame")
    func childRender() {
        let counter = Component<ChildModel, ChildMsg, ParentMsg>(
            initialModel: ChildModel(count: 5),
            update: { _, _ in [] },
            view: { model in { frame in
                frame.writeText("Count: \(model.count)", x: 0, y: 0)
            }},
            toParent: { .child($0) }
        )
        var frame = Frame(
            buffer: CellBuffer(width: 20, height: 1),
            rect: Rect(x: 0, y: 0, width: 20, height: 1)
        )
        counter.render(into: &frame)
        // Check that the frame has content (first cell should be 'C' from "Count: 5")
        let cell = frame.cellBuffer[0, 0]
        #expect(cell.character == "C")
    }

    @Test("Update returning no commands maps to empty parent commands")
    func childCommandsEmpty() {
        var counter = makeCounter()
        let cmds = counter.send(.increment)
        // Update returns [], so mapped result should also be []
        #expect(cmds.isEmpty == true)
    }

    @Test("Send returns empty commands array while still updating model")
    func sendReturnsEmptyForNoCommands() {
        var counter = makeCounter()
        #expect(counter.model.count == 0)
        let cmds = counter.send(.increment)
        // Model was updated
        #expect(counter.model.count == 1)
        // No commands returned
        #expect(cmds.isEmpty == true)
    }
}
