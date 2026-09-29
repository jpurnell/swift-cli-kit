// AppleTokenResolver.swift
// SwiftGUIKitSwiftUI
//
// The Apple-side token resolver. It resolves the shared SwiftGUIKit token
// vocabulary (ColorRole / TypeRole / Symbol / SpaceToken) to native SwiftUI
// values by DEFERRING TO THE SYSTEM — which is what makes HIG the baseline by
// construction. It is a parallel resolver over the same vocabulary, not a
// conformance to the terminal-shaped TokenResolver (whose Resolved* types are
// cell-based).

#if canImport(SwiftUI)
import SwiftUI
import SwiftGUIKit

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Resolves SwiftGUIKit design tokens to native SwiftUI values.
public struct AppleTokenResolver: Sendable {

    /// The active symbol set (pluggable; `DefaultSymbolSet` unless overridden).
    public let symbols: any SymbolSet
    /// The capability/appearance context. Color and type still defer to the system
    /// (so appearance and Dynamic Type are the OS's job — the HIG baseline), but
    /// `density` and `pointer` are honored here for spacing and hit targets.
    public let context: DesignContext

    /// Creates an Apple token resolver.
    /// - Parameters:
    ///   - symbols: The symbol set (default: `DefaultSymbolSet()`).
    ///   - context: The design context (default: a desktop SwiftUI context —
    ///     `regular` density, `mouse` pointer).
    public init(symbols: any SymbolSet = DefaultSymbolSet(),
                context: DesignContext = DesignContext(density: .regular, pointer: .mouse, surface: .swiftUI)) {
        self.symbols = symbols
        self.context = context
    }

    // MARK: Color — defers to system semantic colors

    /// Resolves a color role to a system semantic `Color`.
    public func color(_ role: ColorRole) -> Color {
        switch role {
        case .label: return .primary
        case .secondaryLabel: return .secondary
        case .accent: return .accentColor
        case .destructive: return .red
        case .success: return .green
        case .warning: return .yellow
        case .background: return Self.systemBackground
        case .secondaryBackground: return Self.secondarySystemBackground
        case .separator: return Self.systemSeparator
        }
    }

    // MARK: Type — defers to Dynamic Type text styles

    /// Resolves a type role to a Dynamic Type `Font`.
    public func font(_ role: TypeRole) -> Font {
        switch role {
        case .title: return .largeTitle
        case .heading: return .headline
        case .body: return .body
        case .caption: return .caption
        case .mono: return .body.monospaced()
        }
    }

    // MARK: Symbols — the sf field becomes SF Symbols

    /// The SF Symbol name for a symbol, from the active ``SymbolSet``.
    public func symbolName(_ symbol: Symbol) -> String {
        symbols.mapping(for: symbol).sf
    }

    /// An SF Symbol `Image` for a symbol.
    public func image(_ symbol: Symbol) -> Image {
        Image(systemName: symbolName(symbol))
    }

    // MARK: Metrics

    /// The minimum interactive hit target, by pointer: 44 pt for touch (and the
    /// keyboard-safe default), 28 pt for a precise mouse pointer (HIG macOS).
    public var minHitTarget: CGFloat {
        switch context.pointer {
        case .touch, .none: return 44
        case .mouse: return 28
        }
    }

    /// Resolves a spacing token to points (8-pt rhythm), scaled by density:
    /// `compact` ×0.75, `regular` ×1, `spacious` ×1.5.
    public func spacing(_ token: SpaceToken) -> CGFloat {
        let base: CGFloat
        switch token {
        case .xs: base = 4
        case .s: base = 8
        case .m: base = 16
        case .l: base = 24
        case .xl: base = 40
        }
        return base * Self.densityScale(context.density)
    }

    /// The multiplier a density applies to the base 8-pt rhythm.
    private static func densityScale(_ density: DesignContext.Density) -> CGFloat {
        switch density {
        case .compact: return 0.75
        case .regular: return 1.0
        case .spacious: return 1.5
        }
    }

    // MARK: Platform-semantic surface colors

    private static var systemBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #elseif canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color.clear
        #endif
    }

    private static var secondarySystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #elseif canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color.gray.opacity(0.1)
        #endif
    }

    private static var systemSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #elseif canImport(UIKit)
        Color(uiColor: .separator)
        #else
        Color.gray.opacity(0.3)
        #endif
    }
}
#endif
