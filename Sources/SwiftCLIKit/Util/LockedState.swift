// LockedState.swift
// SwiftCLIKit

#if canImport(os)
import os
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// A value that can only be read or written while holding its lock.
///
/// This is the package's one mutual-exclusion primitive. It stands where
/// `Synchronization.Mutex` used to: `Mutex` needs macOS 15, and the package's floor is
/// macOS 14 because that is as far as its deployment host goes. A binary that imports
/// `Synchronization` builds without complaint on a newer machine and then fails to launch
/// on the host, looking for `libswiftSynchronization.dylib`.
///
/// On Apple platforms the lock is `OSAllocatedUnfairLock` (macOS 13, iOS 16) — the same
/// `os_unfair_lock` that `Mutex` wraps there, so contention behaviour is unchanged.
/// Elsewhere it is a `pthread_mutex_t`.
///
/// The lock is **not recursive**. Calling ``withLock(_:)`` on a box from inside its own
/// `withLock` body traps on Apple platforms and deadlocks elsewhere, exactly as `Mutex`
/// did. Copy what a callback needs out of the state and call it after the body returns.
///
/// A copy of a `LockedState` refers to the same lock and the same state.
///
/// Usage is one call: a counter created as `LockedState(0)` is incremented with
/// `withLock { $0 += 1 }` and read with `withLock { $0 }`. There is no compiled example
/// here because the type is `package`-internal — nothing outside this package can name it.
package struct LockedState<State: Sendable>: Sendable {
    #if canImport(os) && !SWIFTCLIKIT_PTHREAD_LOCK
    private let storage: OSAllocatedUnfairLock<State>
    #else
    private let storage: PthreadLockedStorage<State>
    #endif

    /// Creates a box holding `initialState`.
    /// - Parameter initialState: The value the first caller of ``withLock(_:)`` sees.
    package init(_ initialState: State) {
        #if canImport(os) && !SWIFTCLIKIT_PTHREAD_LOCK
        self.storage = OSAllocatedUnfairLock(initialState: initialState)
        #else
        self.storage = PthreadLockedStorage(initialState)
        #endif
    }

    /// Runs `body` with exclusive access to the state and returns what it returns.
    ///
    /// The lock is released when `body` returns or throws; anything `body` wrote before
    /// throwing stays written.
    /// - Parameter body: Reads or mutates the state. Must not call back into this box.
    /// - Returns: The value `body` returns.
    /// - Throws: Whatever `body` throws.
    package func withLock<Result: Sendable>(
        _ body: @Sendable (inout State) throws -> Result
    ) rethrows -> Result {
        try storage.withLock(body)
    }
}

#if !(canImport(os) && !SWIFTCLIKIT_PTHREAD_LOCK)
// Justification: `state` is only ever touched between pthread_mutex_lock and pthread_mutex_unlock on `mutex`; both pointers are immutable and owned by this object.
private final class PthreadLockedStorage<State: Sendable>: @unchecked Sendable {
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>
    private let state: UnsafeMutablePointer<State>

    init(_ initialState: State) {
        mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        mutex.initialize(to: pthread_mutex_t())
        pthread_mutex_init(mutex, nil)
        state = UnsafeMutablePointer<State>.allocate(capacity: 1)
        state.initialize(to: initialState)
    }

    deinit {
        state.deinitialize(count: 1)
        state.deallocate()
        pthread_mutex_destroy(mutex)
        mutex.deinitialize(count: 1)
        mutex.deallocate()
    }

    func withLock<Result: Sendable>(
        _ body: @Sendable (inout State) throws -> Result
    ) rethrows -> Result {
        pthread_mutex_lock(mutex)
        defer { pthread_mutex_unlock(mutex) }
        return try body(&state.pointee)
    }
}
#endif
