// EventStreamTests.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Testing
import Foundation
@testable import SwiftCLIKit

@Suite("EventStream")
struct EventStreamTests {

    private func streamFromBytes(_ bytes: [UInt8]) -> EventStream {
        let pipe = Pipe()
        pipe.fileHandleForWriting.write(Data(bytes))
        pipe.fileHandleForWriting.closeFile()
        let terminal = RawTerminal(fileDescriptor: pipe.fileHandleForReading.fileDescriptor)
        return EventStream(terminal: terminal)
    }

    @Test("Arrow-up bytes yield a key event")
    func keyEvent() async {
        let stream = streamFromBytes([0x1B, 0x5B, 0x41])  // arrow-up
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()
        if case .key(let key) = event {
            #expect(key == .arrowUp)
        } else {
            #expect(Bool(false), "Expected .key(.arrowUp), got \(String(describing: event))")
        }
    }

    @Test("EOF ends the stream")
    func eofEndsStream() async {
        let stream = streamFromBytes([])  // empty pipe, already closed
        var iterator = stream.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event == nil)
    }

    @Test("Multiple key sequences yielded in order")
    func multipleEvents() async {
        // 'a' then 'b'
        let stream = streamFromBytes([0x61, 0x62])
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        let second = await iterator.next()

        if case .key(let k1) = first {
            #expect(k1 == .character("a"))
        } else {
            #expect(Bool(false), "Expected .key(.character(\"a\"))")
        }

        if case .key(let k2) = second {
            #expect(k2 == .character("b"))
        } else {
            #expect(Bool(false), "Expected .key(.character(\"b\"))")
        }
    }
}
