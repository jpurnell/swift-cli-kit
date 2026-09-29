// Node+Containers.swift
// SwiftGUIKit
//
// Ergonomic constructors for container nodes. The `[Node]` overloads default
// every child to `.flex(1)` (equal division); the `[StackChild]` overloads take
// explicit per-child sizes.

public extension Node {
    /// A vertical stack of equal-flex children.
    static func vstack(spacing: SpaceToken = .xs, _ children: [Node]) -> Node {
        .stack(axis: .vertical, spacing: spacing, children: children.map { StackChild($0) })
    }

    /// A vertical stack with explicit per-child sizes.
    static func vstack(spacing: SpaceToken = .xs, _ children: [StackChild]) -> Node {
        .stack(axis: .vertical, spacing: spacing, children: children)
    }

    /// A horizontal stack of equal-flex children.
    static func hstack(spacing: SpaceToken = .xs, _ children: [Node]) -> Node {
        .stack(axis: .horizontal, spacing: spacing, children: children.map { StackChild($0) })
    }

    /// A horizontal stack with explicit per-child sizes.
    static func hstack(spacing: SpaceToken = .xs, _ children: [StackChild]) -> Node {
        .stack(axis: .horizontal, spacing: spacing, children: children)
    }
}
