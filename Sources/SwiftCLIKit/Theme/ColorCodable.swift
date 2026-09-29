// ColorCodable.swift
// SwiftCLIKit
// Created by Justin Purnell on 2026-04-10.

import Foundation

// MARK: - Color + Codable

extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value, r, g, b
    }

    /// Creates a color by decoding from the given decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "ansi8":
            let val = try container.decode(ANSIColor.self, forKey: .value)
            self = .ansi8(val)
        case "ansi256":
            let val = try container.decode(UInt8.self, forKey: .value)
            self = .ansi256(val)
        case "truecolor":
            let r = try container.decode(UInt8.self, forKey: .r)
            let g = try container.decode(UInt8.self, forKey: .g)
            let b = try container.decode(UInt8.self, forKey: .b)
            self = .truecolor(r: r, g: g, b: b)
        case "default":
            self = .defaultColor
        default:
            self = .ansi8(.white)
        }
    }

    /// Encodes the color into the given encoder.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .defaultColor:
            try container.encode("default", forKey: .type)
        case .ansi8(let color):
            try container.encode("ansi8", forKey: .type)
            try container.encode(color, forKey: .value)
        case .ansi256(let idx):
            try container.encode("ansi256", forKey: .type)
            try container.encode(idx, forKey: .value)
        case .truecolor(let r, let g, let b):
            try container.encode("truecolor", forKey: .type)
            try container.encode(r, forKey: .r)
            try container.encode(g, forKey: .g)
            try container.encode(b, forKey: .b)
        }
    }
}

// MARK: - ANSIColor + Codable

extension ANSIColor: Codable {}
