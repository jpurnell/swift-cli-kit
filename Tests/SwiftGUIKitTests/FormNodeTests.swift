// FormNodeTests.swift
// SwiftGUIKit
// Container C4 — Form. Decomposition into generic containers fails byte-parity
// (Form's label/value/error layout leaves gap cells whose attributes wouldn't
// match a single bolded row), so this uses the proposal's documented fallback: a
// dedicated .form case via reconstruct-and-call.

import Testing
import SwiftCLIKit
@testable import SwiftGUIKit

@Suite("Form.node")
struct FormNodeTests {
    @Test("node() carries field id/label/value, focus, and errors")
    func nodeShape() {
        var form = Form(fields: [.init(id: "name", label: "Name", value: "Bob"),
                                 .init(id: "email", label: "Email", value: "")])
        form.focusedFieldIndex = 1
        form.errors = ["email": "Required"]
        #expect(form.node() == .form(
            fields: [FormFieldData(id: "name", label: "Name", value: "Bob"),
                     FormFieldData(id: "email", label: "Email", value: "")],
            focusedIndex: 1, errors: ["email": "Required"], color: .label))
    }
}

@Suite("Form parity (token→node→cell == legacy)")
struct FormParityTests {
    private let renderer = CellRenderer(resolver: TerminalTokenResolver(theme: .dark), context: .terminalTruecolor)
    private func makeFrame(width: Int, height: Int) -> Frame {
        Frame(buffer: CellBuffer(width: width, height: height), rect: Rect(x: 0, y: 0, width: width, height: height))
    }
    private func gridsEqual(_ a: CellBuffer, _ b: CellBuffer, width: Int, height: Int) -> Bool {
        for y in 0..<height { for x in 0..<width where a[x, y] != b[x, y] { return false } }
        return true
    }

    @Test("parity across fields × focus × errors × size")
    func parity() {
        let fieldSets: [[Form.Field]] = [
            [],
            [.init(id: "name", label: "Name", value: "Alice")],
            [.init(id: "name", label: "Name", value: "Bob"),
             .init(id: "email", label: "Email", value: "x@y.z")],
        ]
        for fields in fieldSets {
            for focus in [0, 1] {
                for errors in [[String: String](), ["name": "Required"]] {
                    for (w, h) in [(30, 6), (20, 8)] {
                        var form = Form(fields: fields)
                        if !fields.isEmpty { form.focusedFieldIndex = min(focus, fields.count - 1) }
                        form.errors = errors

                        var legacy = makeFrame(width: w, height: h); form.render(into: &legacy)
                        var node = makeFrame(width: w, height: h); renderer.render(form.node(), into: &node)
                        #expect(gridsEqual(legacy.cellBuffer, node.cellBuffer, width: w, height: h),
                                "mismatch fields=\(fields.count) focus=\(focus) errs=\(errors.count) \(w)x\(h)")
                    }
                }
            }
        }
    }
}
