import Foundation

/// Keeps the public API's optional fields intact as the website evolves.
indirect enum JSON: Codable, Hashable, Identifiable {
    case object([String: JSON]), array([JSON]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSON].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSON].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    subscript(_ key: String) -> JSON { if case .object(let v) = self { return v[key] ?? .null }; return .null }
    var string: String { switch self { case .string(let v): return v; case .number(let v): return String(Int(v)); default: return "" } }
    var int: Int { if case .number(let v) = self { return Int(v) }; return Int(string) ?? 0 }
    var bool: Bool { if case .bool(let v) = self { return v }; return false }
    var array: [JSON] { if case .array(let v) = self { return v }; return [] }
    var object: [String: JSON] { if case .object(let v) = self { return v }; return [:] }
    var exists: Bool { self != .null }
    var id: String { self["id"].string }
    var profile: JSON { self["profile"].exists ? self["profile"] : self["card"].exists ? self["card"] : self }
    var text: String { !self["text"].string.isEmpty ? self["text"].string : !self["originalText"].string.isEmpty ? self["originalText"].string : string }
    func text(_ key: String) -> String { self[key + "I18n"].text.isEmpty ? self[key].text : self[key + "I18n"].text }
    static func body(_ values: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: values) }
}

enum ERPRules {
    static func profileID(_ raw: String) -> String? {
        guard let c = URLComponents(string: raw), c.scheme == "https", c.host == "erp.sex", c.user == nil, c.port == nil || c.port == 443 else { return nil }
        let id = c.queryItems?.first(where: { $0.name == "u" })?.value ?? (["/profiles/", "/u/", "/s/"].first(where: { c.path.hasPrefix($0) }).map { String(c.path.dropFirst($0.count)) } ?? "")
        return id.range(of: "^[A-Za-z0-9_-]{1,100}$", options: .regularExpression) == nil ? nil : id
    }
    static func swipe(x: Double, y: Double) -> String? {
        if y < -85 && abs(y) > abs(x) { return "superlike" }
        if abs(x) > 90 && abs(x) > abs(y) { return x > 0 ? "like" : "pass" }
        return nil
    }
    static func isVRC(_ raw: String) -> Bool {
        guard let u = URLComponents(string: raw), u.scheme == "https", u.host == "vrchat.com", u.user == nil, u.port == nil || u.port == 443 else { return false }
        return u.path.range(of: "^/home/user/usr_[0-9a-fA-F-]{36}/?$", options: .regularExpression) != nil
    }
    static func newer(_ tag: String, than current: String) -> Bool {
        func parts(_ s: String) -> ([Int], String) {
            let clean = s.hasPrefix("v") ? String(s.dropFirst()) : s
            let base = clean.components(separatedBy: CharacterSet(charactersIn: "_-"))
            return (base[0].split(separator: ".").compactMap { Int($0) }, base.dropFirst().joined(separator: "-").lowercased())
        }
        let a = parts(tag), b = parts(current)
        guard a.0.count == 3, b.0.count == 3 else { return false }
        for i in 0..<3 where a.0[i] != b.0[i] { return a.0[i] > b.0[i] }
        if a.1.isEmpty { return !b.1.isEmpty }
        if b.1.isEmpty { return false }
        return a.1 > b.1
    }
}

// Convert only at the API boundary so editing nested fields preserves unedited values.
extension JSON {
    var foundation: Any {
        switch self {
        case .object(let values): return values.mapValues { $0.foundation }
        case .array(let values): return values.map { $0.foundation }
        case .string(let value): return value
        case .number(let value): return value
        case .bool(let value): return value
        case .null: return NSNull()
        }
    }
    var records: [JSON] { if case .array = self { return array }; return self["items"].array }
    func value(at path: [String]) -> JSON { path.reduce(self) { $0[$1] } }
    func replacing(at path: [String], with value: JSON) -> JSON {
        guard let first = path.first else { return value }
        var values = object
        values[first] = self[first].replacing(at: Array(path.dropFirst()), with: value)
        return .object(values)
    }
}
