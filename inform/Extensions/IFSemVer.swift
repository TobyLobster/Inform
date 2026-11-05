//
//  IFSemVer.swift
//  Inform
//
//  Created by Toby Nelson on 10/08/2022.
//  Translated from Objective-C in November 2026. The interface is still IFSemVer.h.
//

import Foundation

private let SEMVER_NUMBER_DEPTH = 3

private enum SemVerPart {
    case MMP
    case PRE
    case BM
}

/// The UTF-16 unit of an ASCII character
private func ch(_ scalar: Unicode.Scalar) -> unichar {
    return unichar(scalar.value)
}

// *******************************************************************************************
@objc @implementation extension IFSemVer {

    var version_numbers: NSMutableArray = NSMutableArray()
    var prerelease_segments: NSMutableArray?
    var build_metadata: NSMutableString?

    override init() {
        super.init()
        set_null()
    }

    private final func set_null() {
        version_numbers = NSMutableArray()
        for _ in 0..<SEMVER_NUMBER_DEPTH {
            version_numbers.add(NSNumber(value: Int32(-1)))
        }
        prerelease_segments = nil
        build_metadata      = nil
    }

    private final func version_number(_ i: Int) -> Int32 {
        return (version_numbers[i] as! NSNumber).int32Value
    }

    var to_text: String {
        if is_null() { return "null" }

        var result = ""
        var i = 0
        while (i < SEMVER_NUMBER_DEPTH) && (version_number(i) >= 0) {
            if i > 0 { result += "." }
            result += String(version_number(i))
            i += 1
        }
        if let prerelease_segments = prerelease_segments {
            for i in 0..<prerelease_segments.count {
                result += (i == 0) ? "-" : "."
                result += prerelease_segments[i] as! String
            }
        }
        if let build_metadata = build_metadata { result += "+" + (build_metadata as String) }
        return result
    }

    private final func is_null() -> Bool {
        var allow = true
        for i in 0..<SEMVER_NUMBER_DEPTH {
            if version_number(i) < -1 { return true }    // should never happen
            if version_number(i) == -1 { allow = false }
            else if allow == false { return true }       // should never happen
        }
        if version_number(0) < 0 { return true }
        return false
    }

    private final func add_prerelease_content(_ prerelease: inout NSMutableString) {
        if prerelease.length == 0 { set_null(); return }

        if prerelease_segments == nil {
            prerelease_segments = NSMutableArray()
        }
        prerelease_segments!.add(prerelease)
        prerelease = NSMutableString()
    }

    init(string versionString: String) {
        super.init()
        set_null()

        var str = versionString as NSString

        // Remove 'Version ' at start if present
        if str.starts(withCaseInsensitive: "Version ") {
            str = str.substring(from: 8) as NSString
        }

        // Trim any whitespace
        str = str.trimmingWhitespace as NSString

        var component       = 0
        var val: Int32      = -1
        var dots_used       = 0
        var slashes_used    = 0
        var count           = 0
        var part            = SemVerPart.MMP
        var prerelease      = NSMutableString()

        for pos in 0..<str.length {
            let c = str.character(at: pos)
            switch part {
            case .MMP:
                if c == ch(".") { dots_used += 1 }
                if c == ch("/") { slashes_used += 1 }
                if (c == ch(".")) || (c == ch("/")) || (c == ch("-")) || (c == ch("+")) {
                    if val == -1 { set_null(); return }
                    if component >= SEMVER_NUMBER_DEPTH { set_null(); return }

                    version_numbers[component] = NSNumber(value: val)
                    component += 1; val = -1; count = 0
                    if c == ch("-") { part = .PRE }
                    if c == ch("+") { part = .BM }
                } else if isdigit(Int32(c)) != 0 {
                    let digit = Int32(c) - Int32(ch("0"))
                    if (val == 0) && (slashes_used == 0) { set_null(); return }
                    // Wraps around as the int arithmetic did, rather than trapping
                    if val < 0 { val = digit } else { val = 10 &* val &+ digit }
                    count += 1
                } else { set_null(); return }
            case .PRE:
                if c == ch(".") {
                    add_prerelease_content(&prerelease)
                } else if c == ch("+") {
                    add_prerelease_content(&prerelease)
                    part = .BM
                } else {
                    prerelease.appendFormat("%C", c)
                }
            case .BM:
                if build_metadata == nil {
                    build_metadata = NSMutableString()
                }
                build_metadata!.appendFormat("%C", c)
            }
        }

        if (part == .PRE) && (prerelease.length > 0) { add_prerelease_content(&prerelease) }

        if (dots_used > 0) && (slashes_used > 0) { set_null(); return }
        if slashes_used > 0 {
            if component > 1 { set_null(); return }
            if count != 6 { set_null(); return }
            version_numbers[1] = NSNumber(value: Int32(0))
            component = 2
        }
        if part == .MMP {
            if val == -1 { set_null(); return }
            if component >= SEMVER_NUMBER_DEPTH { set_null(); return }
            version_numbers[component] = NSNumber(value: val)
        }
    }

    // The effect of this is to read unspecified versions of major, minor or patch as if they were 0:
    private final func floor(_ N: Int32) -> Int32 {
        if N < 0 { return 0 }
        return N
    }

    // This returns a non-negative integer if T contains only digits, and -1 otherwise. If the value has more than about 10 digits, then the result will not be meaningful, which I think is a technical violation of the standard.
    // A missing string gives 0, as sending messages to nil did in Objective-C.
    private final func strict_atoi(_ str: NSString?) -> Int32 {
        guard let str = str else { return 0 }

        for i in 0..<str.length {
            if isdigit(Int32(str.character(at: i))) == 0 {
                return -1
            }
        }
        let c = str.character(at: 0)
        if (c == ch("0")) && str.length > 1 { return -1 }
        return str.intValue
    }

    private final func le(_ v2: IFSemVer) -> Bool {
        let v1 = self

        for i in 0..<SEMVER_NUMBER_DEPTH {
            let N1 = floor(v1.version_number(i))
            let N2 = floor(v2.version_number(i))
            if N1 > N2 { return false }
            if N1 < N2 { return true }
        }

        func segment(_ v: IFSemVer, _ i: Int) -> NSString? {
            guard let segments = v.prerelease_segments, segments.count > i else { return nil }
            return (segments[i] as! NSString)
        }

        var i1 = 0
        var i2 = 0

        var str1 = segment(v1, i1)
        var str2 = segment(v2, i2)

        if (str1 == nil) && (str2 != nil) { return false }
        if (str1 != nil) && (str2 == nil) { return true }
        repeat {
            let N1 = strict_atoi(str1)
            let N2 = strict_atoi(str2)
            if (N1 >= 0) && (N2 >= 0) {
                if N1 < N2 { return true }
                if N1 > N2 { return false }
            } else {
                // Only reached with two strings, as a missing one gives 0 above
                let c = str1!.compare(str2! as String)
                if c == .orderedAscending { return true }
                if c == .orderedDescending { return false }
            }
            i1 += 1
            i2 += 1
            str1 = segment(v1, i1)
            str2 = segment(v2, i2)
        } while (str1 != nil) && (str2 != nil)
        if (str1 == nil) && (str2 != nil) { return true }
        if (str1 != nil) && (str2 == nil) { return false }
        return true
    }

    private final func eq(_ v2: IFSemVer) -> Bool {
        return le(v2) && v2.le(self)
    }

    private final func ne(_ v2: IFSemVer) -> Bool {
        return !eq(v2)
    }

    private final func gt(_ v2: IFSemVer) -> Bool {
        return !le(v2)
    }

    private final func ge(_ v2: IFSemVer) -> Bool {
        return v2.le(self)
    }

    private final func lt(_ v2: IFSemVer) -> Bool {
        return !ge(v2)
    }

    // And the following can be used for sorting, following the strcmp convention.
    func cmp(_ v2: IFSemVer) -> Int32 {
        if eq(v2) { return 0 }
        if gt(v2) { return 1 }
        return -1
    }
}
