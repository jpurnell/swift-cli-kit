// LockedStateTests.swift
// SwiftCLIKit

import Testing
import Foundation
@testable import SwiftCLIKit

private struct Ledger: Sendable, Equatable {
    var count: Int = 0
    var entries: [String] = []
}

private enum LedgerError: Error, Equatable {
    case rejected(Int)
}

/// The contract every lock site in the package relies on.
///
/// `LockedState` replaced `Synchronization.Mutex` when the macOS floor moved to 14, where
/// `Mutex` does not exist. These pin what a call site was getting from `Mutex` and still
/// has to get: the state is the state, a throwing body does not strand the lock, and no
/// update is lost however many threads arrive at once.
@Suite("LockedState")
struct LockedStateTests {

    @Test("Reads back the value it was created with")
    func initialValue() {
        let box = LockedState(Ledger(count: 7, entries: ["a"]))
        #expect(box.withLock { $0 } == Ledger(count: 7, entries: ["a"]))
    }

    @Test("A mutation made under the lock is seen by the next caller")
    func mutationPersists() {
        let box = LockedState(Ledger())
        box.withLock { state in
            state.count = 3
            state.entries.append("first")
        }
        box.withLock { $0.entries.append("second") }
        #expect(box.withLock { $0 } == Ledger(count: 3, entries: ["first", "second"]))
    }

    @Test("Returns what the body returns")
    func returnsBodyResult() {
        let box = LockedState(41)
        let result = box.withLock { value -> String in
            value += 1
            return "now \(value)"
        }
        #expect(result == "now 42")
        #expect(box.withLock { $0 } == 42)
    }

    @Test("Holds an optional, and can be reset to nil")
    func optionalState() {
        let box = LockedState<String?>(nil)
        #expect(box.withLock { $0 } == nil)
        box.withLock { $0 = "set" }
        #expect(box.withLock { $0 } == "set")
        box.withLock { $0 = nil }
        #expect(box.withLock { $0 } == nil)
    }

    @Test("A throwing body propagates its error and keeps what it wrote before throwing")
    func throwingBodyPropagates() {
        let box = LockedState(Ledger())
        #expect(throws: LedgerError.rejected(5)) {
            try box.withLock { state in
                state.count = 5
                throw LedgerError.rejected(state.count)
            }
        }
        #expect(box.withLock { $0.count } == 5)
    }

    @Test("A throwing body releases the lock")
    func throwingBodyReleasesLock() {
        let box = LockedState(0)
        for attempt in 1...3 {
            #expect(throws: LedgerError.rejected(attempt)) {
                try box.withLock { value in
                    value += 1
                    throw LedgerError.rejected(value)
                }
            }
        }
        // Reaching this line at all is the assertion: a stranded lock never returns.
        #expect(box.withLock { $0 } == 3)
    }

    @Test("A copy shares the original's state")
    func copiesShareState() {
        let original = LockedState(1)
        let copy = original
        copy.withLock { $0 += 10 }
        #expect(original.withLock { $0 } == 11)
    }

    @Test("No increment is lost across concurrent tasks", .timeLimit(.minutes(1)))
    func concurrentIncrementsFromTasks() async {
        let taskCount = 64
        let incrementsPerTask = 2_000
        let box = LockedState(0)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<taskCount {
                group.addTask {
                    for _ in 0..<incrementsPerTask {
                        box.withLock { $0 += 1 }
                    }
                }
            }
        }
        #expect(box.withLock { $0 } == 128_000)
    }

    @Test("No increment is lost across real threads", .timeLimit(.minutes(1)))
    func concurrentIncrementsFromThreads() {
        // The cooperative pool is only as wide as the machine; this forces more
        // simultaneous contenders than cores.
        let iterations = 256
        let incrementsPerIteration = 500
        let box = LockedState(0)
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            for _ in 0..<incrementsPerIteration {
                box.withLock { $0 += 1 }
            }
        }
        #expect(box.withLock { $0 } == 128_000)
    }

    @Test("A read-modify-write in one body is atomic against other writers", .timeLimit(.minutes(1)))
    func compoundUpdateIsAtomic() async {
        // Every task appends its own index exactly once and bumps the count in the same
        // critical section, so the two can never disagree.
        let taskCount = 200
        let box = LockedState(Ledger())
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<taskCount {
                group.addTask {
                    box.withLock { state in
                        state.entries.append("\(index)")
                        state.count = state.entries.count
                    }
                }
            }
        }
        let final = box.withLock { $0 }
        #expect(final.count == 200)
        #expect(final.entries.count == 200)
        #expect(Set(final.entries) == Set((0..<taskCount).map { "\($0)" }))
    }

    @Test("Is Sendable without the caller vouching for it")
    func isSendable() {
        func requireSendable<T: Sendable>(_ value: T) -> T { value }
        let box = requireSendable(LockedState(["k": 1]))
        #expect(box.withLock { $0 } == ["k": 1])
    }
}
