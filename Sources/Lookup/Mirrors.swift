//
//  Created by iWw on 2021/1/13.
//

import Foundation

protocol OptionalProtocol {
    var isNil: Bool { get }
}
extension Optional: OptionalProtocol {
    var isNil: Bool { self == nil }
}

func canMirrorInto(_ reflecting: Any?) -> Bool {
    if let _ = reflecting as? LookupRawValue {
        return false
    }
    guard let ref = reflecting else { return false }
    let mirror = Mirror(reflecting: ref)
    guard let displayStyle = mirror.displayStyle else { return false }
    switch displayStyle {
    case .class, .struct:
        return true
    default:
        return canMirrorInto(mirror.children.first?.value)
    }
}

func mirrorValue(_ value: Any) -> Any {
    if let lookupRawValue = value as? LookupRawValue {
        return lookupRawValue.lookupRawValue
    }
    let mirror = Mirror(reflecting: value)
    guard mirror.displayStyle == .enum else {
        return value
    }
    return "\(value)"
}

func unwrapValue(_ value: Any) -> Any? {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        return mirror.children.first?.value
    }
    return value
}

func mirrorArray(_ array: [Any], _ each: ((_: String?, _: Any) -> Void)?) -> [Any] {
    return array.compactMap { item in
        if let nested = item as? [Any] {
            let arr = mirrorArray(nested, each)
            return arr.isEmpty ? nil : arr
        } else if canMirrorInto(item) {
            let mirrored = mirrors(reflecting: item, each)
            return mirrored.isEmpty ? nil : mirrored
        } else {
            let value = mirrorValue(item)
            if let opt = value as? OptionalProtocol, opt.isNil {
                return nil
            } else if value is NSNull {
                return nil
            }
            return value
        }
    }
}

public func mirrors(reflecting: Any?, _ each: ((_: String?, _: Any) -> Void)? = nil) -> [String: Any] {
    guard let reflecting = reflecting else { return [:] }
    
    var map: [String: Any] = [:]
    
    let mirror = Mirror(reflecting: reflecting)
    for child in mirror.children {
        if let label = child.label, !label.isEmpty {
            if let unwrap = reflecting as? LookupUnwrap, let unwrapped = unwrap.lookupUnwrap(key: label, value: child.value) {
                let value = mirrorValue(unwrapped)
                if let opt = value as? OptionalProtocol, opt.isNil {
                    // skip
                } else if value is NSNull {
                    // skip
                } else {
                    map[label] = value
                }
            } else {
                let value = unwrapValue(child.value)
                if let array = value as? [Any] {
                    let mirroredArray = mirrorArray(array, each)
                    if !mirroredArray.isEmpty {
                        map[label] = mirroredArray
                    }
                } else if canMirrorInto(value) {
                    let mirroredDict = mirrors(reflecting: value, each)
                    if !mirroredDict.isEmpty {
                        map[label] = mirroredDict
                    }
                } else {
                    let value = mirrorValue(child.value)
                    if let opt = value as? OptionalProtocol, opt.isNil {
                        // skip
                    } else if value is NSNull {
                        // skip
                    } else {
                        map[label] = value
                    }
                }
            }
        }
        each?(child.label, child.value)
    }
    
    var superMirror = mirror.superclassMirror
    while superMirror != nil {
        for child in superMirror!.children {
            if let label = child.label, !label.isEmpty {
                if let unwrap = reflecting as? LookupUnwrap, let unwrapped = unwrap.lookupUnwrap(key: label, value: child.value) {
                    let value = mirrorValue(unwrapped)
                    if let opt = value as? OptionalProtocol, opt.isNil {
                        // skip
                    } else if value is NSNull {
                        // skip
                    } else {
                        map[label] = value
                    }
                } else {
                    let value = unwrapValue(child.value)
                    if let array = value as? [Any] {
                        let mirroredArray = mirrorArray(array, each)
                        if !mirroredArray.isEmpty {
                            map[label] = mirroredArray
                        }
                    } else if canMirrorInto(value) {
                        let mirroredDict = mirrors(reflecting: value, each)
                        if !mirroredDict.isEmpty {
                            map[label] = mirroredDict
                        }
                    } else {
                        let value = mirrorValue(child.value)
                        if let opt = value as? OptionalProtocol, opt.isNil {
                            // skip
                        } else if value is NSNull {
                            // skip
                        } else {
                            map[label] = value
                        }
                    }
                }
            }
            each?(child.label, child.value)
        }
        superMirror = superMirror?.superclassMirror
    }
    return map
}
