// KeyQueue.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-10-25.

import Foundation

/// Keys decoded as input arrives, held until a reader asks for them.
///
/// A backend whose input is pushed to it (an SSH channel) puts each decoded key here, and
/// ``TerminalBackend/nextKey()`` takes them out. Readers waiting together are served in the order
/// they started waiting. The queue holds at most `capacity` keys: past that, keys are dropped, so
/// a client typing into a session that isn't reading can't grow it without bound.
package final class KeyQueue: Sendable {

    private struct Waiter: Sendable {
        let id: UInt64
        let continuation: CheckedContinuation<Key?, Never>
    }

    private struct State: Sendable {
        var keys: [Key] = []
        var waiters: [Waiter] = []
        var nextWaiterID: UInt64 = 0
        var ended = false
    }

    private let state = LockedState(State())

    /// The most keys held while nobody reads.
    package let capacity: Int

    /// Creates an empty queue.
    /// - Parameter capacity: The most keys held while nobody reads. Values below 1 are treated as 1.
    package init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    /// How many readers are waiting for a key.
    package var waiterCount: Int {
        state.withLock { $0.waiters.count }
    }

    /// Delivers a key to the longest-waiting reader, or holds it.
    /// - Parameter key: The key.
    /// - Returns: `false` if the key was dropped: the queue is full or input has ended.
    @discardableResult
    package func push(_ key: Key) -> Bool {
        let (waiter, accepted) = state.withLock { state -> (Waiter?, Bool) in
            guard !state.ended else { return (nil, false) }
            if !state.waiters.isEmpty {
                return (state.waiters.removeFirst(), true)
            }
            guard state.keys.count < capacity else { return (nil, false) }
            state.keys.append(key)
            return (nil, true)
        }
        waiter?.continuation.resume(returning: key)
        return accepted
    }

    /// Ends input: waiting readers get `nil`, keys already held are still delivered, and later
    /// pushes are dropped.
    package func end() {
        let waiters = state.withLock { state -> [Waiter] in
            state.ended = true
            defer { state.waiters.removeAll() }
            return state.waiters
        }
        for waiter in waiters {
            waiter.continuation.resume(returning: nil)
        }
    }

    /// The next held key, without waiting.
    /// - Returns: The oldest held key, or `nil` if none is held.
    package func tryNext() -> Key? {
        state.withLock { $0.keys.isEmpty ? nil : $0.keys.removeFirst() }
    }

    /// The next key, waiting for one if none is held.
    /// - Returns: The key, or `nil` once input has ended and nothing is held, or if the calling
    ///   task is cancelled while waiting.
    package func next() async -> Key? {
        let id = state.withLock { state -> UInt64 in
            defer { state.nextWaiterID &+= 1 }
            return state.nextWaiterID
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let immediate = state.withLock { state -> Key?? in
                    if !state.keys.isEmpty { return .some(state.keys.removeFirst()) }
                    // Checked under the lock the cancellation handler takes, so a cancellation
                    // that ran before this waiter was registered is seen here.
                    if state.ended || Task.isCancelled { return .some(nil) }
                    state.waiters.append(Waiter(id: id, continuation: continuation))
                    return .none
                }
                if case .some(let key) = immediate {
                    continuation.resume(returning: key)
                }
            }
        } onCancel: {
            let waiter = state.withLock { state -> Waiter? in
                guard let index = state.waiters.firstIndex(where: { $0.id == id }) else { return nil }
                return state.waiters.remove(at: index)
            }
            waiter?.continuation.resume(returning: nil)
        }
    }
}
