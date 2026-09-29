//
//  BufferRef.swift
//  SwiftCLIKit
//
//  Created by Justin Purnell on 2026-04-10.
//

import Foundation
import Synchronization

/// Reference-type wrapper around a ``CellBuffer`` so that multiple ``Frame``
/// instances can share and mutate the same underlying storage.
///
/// `Frame` uses `BufferRef` internally so that sub-frames created via
/// ``Frame/subFrame(_:)`` write into the same buffer as their parent.
public final class BufferRef: Sendable {
    /// The underlying cell buffer, protected by a mutex for thread safety.
    private let _buffer: Mutex<CellBuffer>

    /// The underlying cell buffer.
    public var buffer: CellBuffer {
        get { _buffer.withLock { $0 } }
        set { _buffer.withLock { $0 = newValue } }
    }

    /// Creates a reference wrapping the given buffer.
    public init(_ buffer: CellBuffer) {
        self._buffer = Mutex(buffer)
    }
}
