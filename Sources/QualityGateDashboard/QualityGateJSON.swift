// QualityGateJSON.swift
// QualityGateDashboard
//
// Ingests real `quality-gate --format json` output into the dashboard's
// GateCheck model, so the scene reflects an actual gate run.

import Foundation

public extension QualityGateDashboard {

    /// The subset of `quality-gate --format json` we need. Unlisted keys
    /// (duration, overrides, complianceRecords…) are ignored by `Decodable`.
    private struct Report: Decodable {
        let results: [CheckResult]
        struct CheckResult: Decodable {
            let checkerId: String
            let status: String
            let diagnostics: [Diagnostic]
        }
        struct Diagnostic: Decodable {
            let severity: String   // "note" | "warning" | "error"
        }
    }

    /// Parses `quality-gate --format json` output into ``GateCheck`` results.
    /// - Parameter data: The JSON payload.
    /// - Returns: One ``GateCheck`` per checker, with error/warning counts from
    ///   its diagnostics and a rolled-up ``GateStatus``.
    /// - Throws: A decoding error if the payload isn't the expected shape.
    static func checks(fromJSON data: Data) throws -> [GateCheck] {
        // `quality-gate --format json` may append a human-readable banner after the
        // JSON object; decode just the first balanced top-level object.
        let report = try JSONDecoder().decode(Report.self, from: firstJSONObject(in: data))
        return report.results.map { result in
            let errors = result.diagnostics.filter { $0.severity == "error" }.count
            let warnings = result.diagnostics.filter { $0.severity == "warning" }.count
            let status: GateStatus = (result.status.lowercased() == "failed" || errors > 0) ? .failed
                : (warnings > 0 ? .warning : .passed)
            return GateCheck(name: result.checkerId, status: status, errors: errors, warnings: warnings)
        }
    }

    /// Returns the first balanced `{ … }` object in `data` (tolerating any
    /// trailing banner text), or the original data if no object is found.
    static func firstJSONObject(in data: Data) -> Data {
        let bytes = [UInt8](data)
        guard let start = bytes.firstIndex(of: UInt8(ascii: "{")) else { return data }
        var depth = 0, inString = false, escaped = false
        var index = start
        while index < bytes.count {
            let byte = bytes[index]
            if inString {
                if escaped { escaped = false }
                else if byte == UInt8(ascii: "\\") { escaped = true }
                else if byte == UInt8(ascii: "\"") { inString = false }
            } else if byte == UInt8(ascii: "\"") {
                inString = true
            } else if byte == UInt8(ascii: "{") {
                depth += 1
            } else if byte == UInt8(ascii: "}") {
                depth -= 1
                if depth == 0 { return Data(bytes[start...index]) }
            }
            index += 1
        }
        return data
    }
}
