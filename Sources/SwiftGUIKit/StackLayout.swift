// StackLayout.swift
// SwiftGUIKit
//
// Deterministic rect division for stack containers. Resolves fixed sizes, then
// distributes the leftover among flex children by weight — with an exact
// cumulative distribution so child sizes always sum to the available space (no
// rounding gaps). Spacing is reserved before the split.
//
// This is the v1 (explicit) layout; the intrinsic follow-up adds a measure tier
// ahead of the flex distribution (proposal §5.2) without changing this shape.

import SwiftCLIKit

/// Computes child rects for a stack.
public enum StackLayout {

    /// Divides `rect` along `axis` among children of the given sizes, inserting
    /// `gap` cells between them.
    /// - Returns: One rect per size, in order (absolute coordinates).
    public static func rects(in rect: Rect, axis: Axis, gap: Int, sizes: [SizeConstraint]) -> [Rect] {
        let n = sizes.count
        guard n > 0 else { return [] }

        let mainTotal = axis == .vertical ? rect.height : rect.width
        let crossTotal = axis == .vertical ? rect.width : rect.height
        let totalGap = Swift.max(0, n - 1) * Swift.max(0, gap)
        let available = Swift.max(0, mainTotal - totalGap)

        let fixedSum = sizes.reduce(0) { $0 + (fixedValue($1) ?? 0) }
        let totalFlex = sizes.reduce(0) { $0 + (flexWeight($1) ?? 0) }
        let flexSpace = Swift.max(0, available - fixedSum)

        // Resolve each child's main-axis size. Flex children use a cumulative
        // distribution so the pieces sum exactly to `flexSpace`.
        var mainSizes = [Int](repeating: 0, count: n)
        var cumulativeWeight = 0
        var assignedFlex = 0
        for i in 0..<n {
            if let fixed = fixedValue(sizes[i]) {
                mainSizes[i] = fixed
            } else {
                cumulativeWeight += flexWeight(sizes[i]) ?? 0
                let target = totalFlex > 0 ? flexSpace * cumulativeWeight / totalFlex : 0
                mainSizes[i] = target - assignedFlex
                assignedFlex = target
            }
        }

        var result: [Rect] = []
        result.reserveCapacity(n)
        var pos = axis == .vertical ? rect.y : rect.x
        for i in 0..<n {
            let m = mainSizes[i]
            if axis == .vertical {
                result.append(Rect(x: rect.x, y: pos, width: crossTotal, height: m))
            } else {
                result.append(Rect(x: pos, y: rect.y, width: m, height: crossTotal))
            }
            pos += m + Swift.max(0, gap)
        }
        return result
    }

    private static func fixedValue(_ s: SizeConstraint) -> Int? {
        if case .fixed(let v) = s { return v }
        return nil
    }
    private static func flexWeight(_ s: SizeConstraint) -> Int? {
        if case .flex(let w) = s { return w }
        return nil
    }
}
