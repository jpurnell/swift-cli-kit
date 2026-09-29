// StandardInput.swift
// SwiftCLIKit

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Bounded reads of a piped payload.
///
/// `FileHandle.readDataToEndOfFile()` returns at end-of-file or never, and it grows its buffer
/// to whatever the writer sends. A tool that reads a pipe that way has no ceiling on either
/// dimension: a writer that stays open parks the process, and a writer that never stops
/// exhausts memory. Neither failure names itself — the tool simply appears to hang.
///
/// ``readAll(fileDescriptor:limit:)`` reads the same bytes in fixed-size chunks and stops with
/// an error the moment the payload passes an explicit ceiling, so both limits are stated in the
/// call rather than discovered in production.
///
/// ```swift
/// // quality-gate --format json | my-tool
/// let payload = try StandardInput.readAll()
/// ```
public enum StandardInput {

    /// The default ceiling on a piped payload: 8 MiB.
    ///
    /// Chosen to sit well above any hand-authored CLI payload (a JSON report runs to tens of
    /// kilobytes) and well below the point where buffering it would strain a CLI process.
    public static let defaultByteLimit = 8 << 20

    /// Why a bounded read stopped short.
    public enum ReadError: Error, CustomStringConvertible, Sendable {

        /// The payload grew past the byte ceiling the caller set.
        case limitExceeded(limit: Int)

        /// `read(2)` failed; the associated value is the `errno` captured at the call.
        case io(code: Int32)

        /// A one-line account of why the read stopped, suitable for a CLI's stderr.
        public var description: String {
            switch self {
            case .limitExceeded(let limit):
                return "input exceeded the \(limit)-byte limit"
            case .io(let code):
                return "reading standard input failed (errno \(code))"
            }
        }
    }

    /// How much is read per `read(2)` call. One page-aligned chunk, reused across the loop.
    private static let chunkSize = 64 * 1024

    /// Reads a file descriptor to end-of-file in bounded chunks.
    ///
    /// Each `read(2)` asks for at most 64 KiB, and the loop stops one byte past `limit`, so the
    /// read fails fast on an oversized payload instead of buffering it. `EINTR` is retried,
    /// since a signal arriving mid-read is not an error.
    ///
    /// - Parameters:
    ///   - fileDescriptor: The descriptor to drain. Defaults to standard input.
    ///   - limit: The largest payload to accept, in bytes. Defaults to ``defaultByteLimit``.
    /// - Returns: Every byte read before end-of-file.
    /// - Throws: ``ReadError/limitExceeded(limit:)`` if the payload passes `limit`, or
    ///   ``ReadError/io(code:)`` if `read(2)` fails.
    public static func readAll(
        fileDescriptor: Int32 = 0,
        limit: Int = defaultByteLimit
    ) throws -> Data {
        guard limit > 0 else { throw ReadError.limitExceeded(limit: limit) }

        // One byte past the limit: reading it is how an oversized payload announces itself.
        // (Clamped so a caller passing `Int.max` cannot overflow the addition.)
        let ceiling = limit == Int.max ? limit : limit + 1

        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var output = Data()

        while output.count < ceiling {
            let want = min(chunkSize, ceiling - output.count)
            let count = buffer.withUnsafeMutableBytes { raw -> Int in
                guard let base = raw.baseAddress else { return 0 }
                return read(fileDescriptor, base, want)
            }

            if count == 0 { return output }             // end-of-file, within the limit

            if count < 0 {
                let code = errno
                if code == EINTR { continue }           // a signal interrupted the read; retry
                throw ReadError.io(code: code)
            }

            output.append(contentsOf: buffer[..<count])
        }

        // The loop only ends by reading past `limit` — end-of-file returns above.
        throw ReadError.limitExceeded(limit: limit)
    }
}
