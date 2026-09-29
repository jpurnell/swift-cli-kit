// Easing.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

/// Pure easing functions that map a linear progress value to an eased curve.
///
/// Each case transforms a normalized time `t` (0...1) into a curved output,
/// shaping the perceived speed of animations.
///
/// ```swift
/// let eased = Easing.easeInOut.apply(0.5) // ≈ 0.5 (symmetric midpoint)
/// let slow = Easing.easeIn.apply(0.5)     // < 0.5 (starts slow)
/// ```
public enum Easing: Sendable, Equatable {
    /// Constant-speed interpolation. Output equals input.
    case linear
    /// Slow start, accelerating toward the end (cubic).
    case easeIn
    /// Fast start, decelerating toward the end (cubic).
    case easeOut
    /// Slow start and end, fastest in the middle (cubic).
    case easeInOut
    /// Custom cubic bezier curve defined by two control points.
    case cubicBezier(x1: Double, y1: Double, x2: Double, y2: Double)
    /// Physically-modeled spring with configurable mass, stiffness, and damping.
    /// May overshoot 1.0 before settling.
    case spring(mass: Double, stiffness: Double, damping: Double)
    /// Multi-bounce effect that hits 1.0 several times before settling.
    case bounce

    /// Apply the easing function to a linear progress value.
    /// - Parameter t: Linear progress in 0...1.
    /// - Returns: Eased value. For most curves this is in 0...1;
    ///   spring and bounce may overshoot slightly.
    public func apply(_ t: Double) -> Double {
        switch self {
        case .linear:
            return clamp(t)
        case .easeIn:
            let clamped = clamp(t)
            return clamped * clamped * clamped
        case .easeOut:
            let clamped = clamp(t)
            let inverted = 1.0 - clamped
            return 1.0 - inverted * inverted * inverted
        case .easeInOut:
            let clamped = clamp(t)
            if clamped < 0.5 {
                return 4.0 * clamped * clamped * clamped
            } else {
                let shifted = -2.0 * clamped + 2.0
                return 1.0 - shifted * shifted * shifted / 2.0
            }
        case .cubicBezier(let x1, let y1, let x2, let y2):
            return solveCubicBezier(t: clamp(t), x1: x1, y1: y1, x2: x2, y2: y2)
        case .spring(let mass, let stiffness, let damping):
            return solveSpring(t: clamp(t), mass: mass, stiffness: stiffness, damping: damping)
        case .bounce:
            return solveBounce(clamp(t))
        }
    }

    // MARK: - Private Helpers

    private func clamp(_ value: Double) -> Double {
        Swift.min(Swift.max(value, 0.0), 1.0)
    }

    /// Solve a cubic bezier curve using Newton-Raphson iteration.
    /// The curve passes through (0,0) and (1,1) with control points (x1,y1) and (x2,y2).
    private func solveCubicBezier(t: Double, x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        guard t > 0.0 else { return 0.0 }
        guard t < 1.0 else { return 1.0 }

        // Find the parameter `u` such that bezierX(u) = t using Newton-Raphson
        var u = t
        let iterationCount = 8
        for _ in 0..<iterationCount {
            let xValue = bezierComponent(u, p1: x1, p2: x2) - t
            let xDerivative = bezierDerivative(u, p1: x1, p2: x2)
            guard abs(xDerivative) > 1e-12 else { break }
            u -= xValue / xDerivative
            u = Swift.min(Swift.max(u, 0.0), 1.0)
        }

        return bezierComponent(u, p1: y1, p2: y2)
    }

    /// Evaluates a single component of a cubic bezier at parameter `u`.
    /// B(u) = 3(1-u)^2 * u * p1 + 3(1-u) * u^2 * p2 + u^3
    private func bezierComponent(_ u: Double, p1: Double, p2: Double) -> Double {
        let oneMinusU = 1.0 - u
        return 3.0 * oneMinusU * oneMinusU * u * p1
             + 3.0 * oneMinusU * u * u * p2
             + u * u * u
    }

    /// Derivative of the bezier component with respect to `u`.
    private func bezierDerivative(_ u: Double, p1: Double, p2: Double) -> Double {
        let oneMinusU = 1.0 - u
        return 3.0 * oneMinusU * oneMinusU * p1
             + 6.0 * oneMinusU * u * (p2 - p1)
             + 3.0 * u * u * (1.0 - p2)
    }

    /// Critically-damped spring approximation using second-order ODE solution.
    private func solveSpring(t: Double, mass: Double, stiffness: Double, damping: Double) -> Double {
        guard mass > 0.0 else { return t }
        guard stiffness > 0.0 else { return t }
        guard t > 0.0 else { return 0.0 }
        guard t < 1.0 else { return 1.0 }

        let omega = (stiffness / mass).squareRoot()
        let massStiffnessRoot = (mass * stiffness).squareRoot()
        guard massStiffnessRoot > 0 else { return t }
        let zeta = damping / (2.0 * massStiffnessRoot)

        // Scale time so that t=1 maps to a reasonable settling period
        let scaledTime = t * 10.0

        if zeta < 1.0 {
            // Under-damped: oscillates
            let omegaD = omega * (1.0 - zeta * zeta).squareRoot()
            guard omegaD > 0 else { return t }
            let decay = exp(-zeta * omega * scaledTime)
            return 1.0 - decay * (cos(omegaD * scaledTime) + (zeta * omega / omegaD) * sin(omegaD * scaledTime))
        } else {
            // Critically or over-damped
            let decay = exp(-omega * scaledTime)
            return 1.0 - decay * (1.0 + omega * scaledTime)
        }
    }

    /// Bounce easing that simulates a ball bouncing and settling.
    private func solveBounce(_ t: Double) -> Double {
        guard t > 0.0 else { return 0.0 }
        guard t < 1.0 else { return 1.0 }

        let scaleFactor = 7.5625
        let segmentWidth1 = 1.0 / 2.75
        let segmentWidth2 = 2.0 / 2.75
        let segmentWidth3 = 2.5 / 2.75

        if t < segmentWidth1 {
            return scaleFactor * t * t
        } else if t < segmentWidth2 {
            let adjusted = t - 1.5 / 2.75
            return scaleFactor * adjusted * adjusted + 0.75
        } else if t < segmentWidth3 {
            let adjusted = t - 2.25 / 2.75
            return scaleFactor * adjusted * adjusted + 0.9375
        } else {
            let adjusted = t - 2.625 / 2.75
            return scaleFactor * adjusted * adjusted + 0.984375
        }
    }
}
