import Foundation

extension Array {
    var countIndex: Int {
        count - 1
    }
}

// MARK: - Helper for String
fileprivate extension String {
    var isPurnInt: Bool {
        let scan: Scanner = Scanner(string: self)
        var val: Int = 0
        return scan.scanInt(&val) && scan.isAtEnd
    }
}

// MARK: Unwrap
fileprivate func unwrap(_ object: Any?) -> Any {
    switch object {
    case let lookup as Lookup:
        return unwrap(lookup.rawValue)
    case let lookupRawValue as LookupRawValue:
        return lookupRawValue.lookupRawValue
    case let number as NSNumber:
        if String(describing: type(of: number)) == "__NSCFBoolean" {
            return number.boolValue
        }
        return number
    case let str as String:
        return str
    case _ as NSNull:
        return NSNull()
    case nil:
        return NSNull()
        
    case let dictionary as [String: Any]:
        var d = dictionary
        dictionary.forEach { pair in
            d[pair.key] = unwrap(pair.value)
        }
        return d
        
    case let array as [Any]:
        return array.map(unwrap)
        
    default:
        return object ?? NSNull()
    }
}

// MARK: - Lookup
@dynamicMemberLookup
public struct Lookup: @unchecked Sendable {
    
    public enum RawType {
        case none
        case dict
        case array
        case object
        case number
        case string
        case bool
    }
    
    public var rawValue: Any {
        get {
            switch rawType {
            case .none:
                return NSNull()
            case .dict:
                return rawDict
            case .array:
                return rawArray
            case .object:
                return rawDict
            case .number:
                return rawNumber
            case .string:
                return rawString
            case .bool:
                return rawBool
            }
        }
    }
    
    var rawBool: Bool = false
    var rawType: RawType
    var rawDict: [String: Any] = [:]
    var rawArray: [Any] = []
    var rawString: String = ""
    var rawNumber: NSNumber = 0
    
    private init(jsonObject: Any) {
        switch jsonObject {
        case Optional<Any>.none:
            self.rawType = .none
        case _ as NSNull:
            self.rawType = .none
            
        default:
            switch unwrap(jsonObject) {
            case let number as NSNumber:
                if String(describing: type(of: number)) == "__NSCFBoolean" {
                    self.rawBool = number.boolValue
                    self.rawType = .bool
                } else {
                    self.rawNumber = number
                    self.rawType = .number
                }
                
            case let str as String:
                self.rawString = str
                self.rawType = .string
                
            case let dictionry as [String: Any]:
                self.rawDict = dictionry
                self.rawType = .dict
                
            case let array as [Any]:
                self.rawArray = array
                self.rawType = .array
                
            case _ as AnyObject:
                switch jsonObject {
                case let encodable as Encodable:
                    do {
                        let data = try JSONEncoder().encode(encodable)
                        if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            self.rawDict = dict
                            self.rawType = .object
                        } else {
                            self.rawType = .none
                        }
                    } catch {
                        self.rawType = .none
                    }
                    
                default:
                    self.rawDict = mirrors(reflecting: jsonObject)
                    self.rawType = .object
                }
                
            default:
                self.rawType = .none
            }
        }
    }
    
    private init(data: Data, options opt: JSONSerialization.ReadingOptions = []) {
        do {
            let object: Any = try JSONSerialization.jsonObject(with: data, options: opt)
            self.init(jsonObject: object)
        } catch let error as NSError {
            // Code=3840 "JSON text did not start with array or object and option to allow fragments not set. around line 1, column 0."
            if error.code == 3840, let str = String(data: data, encoding: .utf8) { // try to initialize using a string
                self.init(jsonObject: str)
            } else {
                self.init(jsonObject: NSNull())
            }
        }
    }
    
    private init(jsonString: String) {
        guard let stringData = jsonString.data(using: .utf8) else {
            self.init(jsonObject: NSNull())
            return
        }
        self.init(data: stringData)
    }
    
    /// Support `JSON-Data`, `String-Data`, `String of JSON`, `Array`, `Dictionary`, `Struct object` and `Class object`
    public init(_ object: Any) {
        switch object {
        case let str as String:
            self.init(jsonString: str)
        case let data as Data:
            self.init(data: data)
        default:
            self.init(jsonObject: object)
        }
    }
    
    // # Resolve build warning:
    // heterogeneous collection literal could only be inferred to '[String : Any]'; add explicit type annotation if this is intentional
    public init(_ anyDictionary: [String: Any]) {
        self.init(anyDictionary as Any)
    }
    
    private func makeLookup(from dynamicMember: String) -> Lookup {
        if dynamicMember.contains(".") {
            var keys = dynamicMember.components(separatedBy: ".")
            
            if let key = keys.first {
                switch rawType {
                case .none:
                    return .null
                    
                case .bool:
                    return Lookup(rawBool)
                
                case .dict, .object:
                    let value: Any = rawDict[key, default: NSNull()]
                    let innerLookup = Lookup(value)
                    keys.removeFirst()
                    
                    let newKey: String = keys.joined(separator: ".")
                    return innerLookup[dynamicMember: newKey]
                case .array, .string:
                    if key.isPurnInt, let index = Int(key) {
                        keys.removeFirst()
                        
                        let newKey: String = keys.joined(separator: ".")
                        return self[index][dynamicMember: newKey]
                    }
                    return .null
                default:
                    return .null
                }
            }
            return .null
        }
        
        switch rawType {
        case .bool:
            return Lookup(rawBool)
            
        case .dict, .object:
            return Lookup(rawDict[dynamicMember, default: NSNull()])
            
        case .array, .string:
            if dynamicMember.isPurnInt,
               let index = Int(dynamicMember)
            {
                return self[index]
            }
            return .null
            
        default:
            return .null
        }
    }
    
    /**
     
     let json = {
        "name": "Lookup",
        "age": 18,
        "versions: [
            "1.0.0", "1.1.0", "1.2.0", "1.3.0"
        ]
     }
     
     let lookup = Lookup(json)
     // > print(lookup.versions.0) -> output: 1.0.0
     lookup["versions.0"] = "0.0.1"
     // > print(lookup.versions.0) -> output: 0.0.1
     // > print(lookup.versions.1) -> output: 1.0.0
     */
    private mutating func setNewValue(for dynamicMember: String, value: Lookup, inner: Bool = false) {
        if dynamicMember.contains(".") {
            var keys = dynamicMember.components(separatedBy: ".")
            let finalKey = keys.removeLast()
            let newKeys = keys.joined(separator: ".")
            var _value = self[dynamicMember: newKeys]
            
            switch _value.rawType {
            case .none, .number, .string:
                _value = value
            case .dict, .object, .bool:
                _value.rawDict[finalKey] = value.rawValue
            case .array:
                if inner {
                    _value.rawArray = [value.rawValue]
                } else {
                    if finalKey.isPurnInt, let index = Int(finalKey) {
                        _value.rawArray.insert(value.rawValue, at: index)
                    } else {
                        _value.rawArray = [value.rawValue]
                    }
                }
            }
            
            setNewValue(for: newKeys, value: _value, inner: true)
            return
        }
        
        switch rawType {
        case .none, .number, .string:
            self = value
        case .dict, .object, .bool:
            rawDict[dynamicMember] = value.rawValue
        case .array:
            if dynamicMember.isPurnInt, let index = Int(dynamicMember) {
                rawArray.insert(value.rawValue, at: index)
            } else {
                rawArray = value.rawArray
            }
        }
    }
    
    public subscript (dynamicMember dynamicMember: String) -> Lookup {
        get {
            makeLookup(from: dynamicMember)
        }
        set {
            setNewValue(for: dynamicMember, value: newValue)
        }
    }
    
    public subscript (_ dynamicMember: String) -> Lookup {
        get {
            self[dynamicMember: dynamicMember]
        }
        set {
            self[dynamicMember: dynamicMember] = newValue
        }
    }
    
    public subscript (_ memberIndex: Int) -> Lookup {
        switch rawType {
        case .string:
            if let convertedArray = array, memberIndex < convertedArray.count {
                return Lookup(convertedArray[memberIndex])
            }
            return .null
        case .array:
            if memberIndex > rawArray.countIndex {
                return .null
            }
            return Lookup(rawArray[memberIndex])
        default:
            return .null
        }
    }
    
    fileprivate static var null: Lookup { Lookup(NSNull()) }
    
    fileprivate mutating func merge(other: Lookup) {
        switch (self.rawType, other.rawType) {
        case (.dict, _):
            switch other.rawType {
            case .dict:
                self.rawDict.merge(other.rawDict, uniquingKeysWith: { $1 })
            default:
                self.rawDict.merge(other.dict ?? [:], uniquingKeysWith: { $1 })
            }
            
        case (.array, _):
            switch other.rawType {
            case .array:
                self.rawArray += other.rawArray
            default:
                self.rawArray += (other.array ?? [])
            }
            
        case (.string, _):
            switch other.rawType {
            case .string:
                self.rawString += other.rawString
            default:
                self.rawString += other.string ?? ""
            }
            
        default:
            break
        }
    }
}

extension Lookup: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = any Any & Sendable
    
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self.init(jsonObject: elements)
    }
}

extension Lookup: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = (any Any & Sendable)?
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(jsonObject: Dictionary(uniqueKeysWithValues: elements))
    }
}

extension Lookup: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(jsonObject: value)
    }
}

extension Lookup: ExpressibleByStringInterpolation {
    public init(stringInterpolation: DefaultStringInterpolation) {
        self.init(jsonObject: stringInterpolation.description)
    }
}

extension Lookup: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(jsonObject: value)
    }
}

extension Lookup: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self.init(jsonObject: value)
    }
}

extension Lookup: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.init(jsonObject: NSNull())
    }
}

extension Lookup: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self.init(jsonObject: value)
    }
}

// MARK: - Convert
public extension Lookup {
    
    /// return true when it is invalid `key` or `value`
    var isNone: Bool {
        rawType == .none
    }
    
    var isSome: Bool {
        !isNone
    }
    
    /// Whether to include Key, case sensitive
    func hasKey(_ keyName: String) -> Bool {
        if keyName.contains(".") {
            var keys = keyName.components(separatedBy: ".")
            let finalKey = keys.removeLast()
            
            if let key = keys.first {
                switch rawType {
                case .none:
                    return false
                case .dict, .object:
                    let value: Any = rawDict[key, default: NSNull()]
                    let innerLookup = Lookup(value)
                    keys.removeFirst()
                    
                    let newKey: String = keys.joined(separator: ".")
                    return innerLookup[dynamicMember: newKey].hasKey(finalKey)
                case .array, .string:
                    if key.isPurnInt, let index = Int(key) {
                        keys.removeFirst()
                        
                        let newKey: String = keys.joined(separator: ".")
                        return self[index][dynamicMember: newKey].hasKey(finalKey)
                    }
                    return false
                default:
                    return false
                }
            }
            return false
        }
        
        return rawDict.keys.contains(keyName)
    }
    
    // MARK: - String
    /// Convert value to `String`, available when rawType is in `[.number, .string]`
    var string: String? {
        switch rawType {
        case .number:
            return "\(rawNumber)"
        case .string:
            return rawString
        default:
            return nil
        }
    }
    
    var stringValue: String {
        string!
    }
    
    /**
    /// A 32-bit floating point type.
    public typealias Float32 = Float
    
    /// A 64-bit floating point type.
    public typealias Float64 = Double
     */
    
    // MARK: - Float
    var float: Float? {
        (string as NSString?)?.floatValue
    }
    var floatValue: Float {
        float!
    }
    
    #if !targetEnvironment(macCatalyst) && os(iOS)
    @available(iOS 14.0, *)
    var float16: Float16? {
        if let string = string {
            return .init(string)
        }
        return nil
    }
    @available(iOS 14.0, *)
    var float16Value: Float16 {
        float16!
    }
    #endif
    
    // MARK: - Double
    var double: Double? {
        (string as NSString?)?.doubleValue
    }
    var doubleValue: Double {
        double!
    }
    
    // MARK: - UInt
    var uInt: UInt? {
        if let string = string {
            return .init(string)
        }
        return nil
    }
    var uIntValue: UInt {
        uInt!
    }
    
    var uInt16: UInt16? {
        if let string = string {
            return .init(string)
        }
        return nil
    }
    var uInt16Value: UInt16 {
        uInt16!
    }
    
    var uInt32: UInt32? {
        if let string = string {
            return .init(string)
        }
        return nil
    }
    var uInt32Value: UInt32 {
        uInt32!
    }
    
    var uInt64: UInt64? {
        if let string = string {
            return .init(string)
        }
        return nil
    }
    var uInt64Value: UInt64 {
        uInt64!
    }
    
    // MARK: - Int
    var int: Int? {
        switch rawType {
        case .bool:
            rawBool ? 1 : 0
        default:
            (string as NSString?)?.integerValue
        }
    }
    var intValue: Int {
        int!
    }
    
    var int16: Int16? {
        if let string = string {
            return .init(string)
        }
        return nil
    }
    var int16Value: Int16 {
        int16!
    }
    
    var int32: Int32? {
        (string as NSString?)?.intValue
    }
    var int32Value: Int32 {
        int32!
    }
    
    var int64: Int64? {
        (string as NSString?)?.longLongValue
    }
    var int64Value: Int64 {
        int64!
    }
    
    // MARK: - Bool
    var bool: Bool? {
        switch rawType {
        case .bool:
            rawBool
        default:
            (string as NSString?)?.boolValue
        }
    }
    var boolValue: Bool {
        self.bool!
    }
    
    // MARK: - Dict
    /// Available when rawType is in `[.dict, .string]` (if use string, it **MUST** be jsonString)
    var dict: [String: Any]? {
        switch rawType {
        case .dict, .object:
            return rawDict
        case .string:
            if let originString = rawValue as? String,
               let stringData = originString.data(using: .utf8)
            {
                    return try? JSONSerialization.jsonObject(with: stringData, options: []) as? [String: Any]
            }
            return nil
        default:
            return nil
        }
    }
    var dictValue: [String: Any] {
        dict!
    }
    
    /// Available when rawType is in `[.dict, .string]` (if use string, it **MUST** be jsonString)
    var dictLookup: Lookup {
        switch rawType {
        case .dict, .object:
            return Lookup(rawDict)
        case .string:
            if let originString = rawValue as? String,
               let stringData = originString.data(using: .utf8),
               let _dict = try? JSONSerialization.jsonObject(with: stringData, options: []) as? [String: Any]
            {
                return Lookup(_dict)
            }
            return .null
        default:
            return .null
        }
    }
    
    // MARK: - Array
    /// Available when rawType is in `[.array, .string]` (if use string, it **MUST** be jsonString)
    var array: [Any]? {
        switch rawType {
        case .array:
            return rawArray
        case .string:
            if let originString = rawValue as? String,
               let stringData = originString.data(using: .utf8)
            {
                return try? JSONSerialization.jsonObject(with: stringData, options: []) as? [Any]
            }
            return nil
        default:
            return nil
        }
    }
    var arrayValue: [Any] {
        array!
    }
    
    /// Available when rawType is in `[.array, .string]` (if use string, it **MUST** be jsonString)
    var arrayLookup: [Lookup] {
        switch rawType {
        case .array:
            return rawArray.map { Lookup($0) }
        case .string:
            if let originString = rawValue as? String,
               let stringData = originString.data(using: .utf8),
               let _array = try? JSONSerialization.jsonObject(with: stringData, options: []) as? [Any]
            {
                return _array.map { Lookup($0) }
            }
            return []
        default:
            return []
        }
    }
    
    var uuid: UUID? {
        if let string {
            return UUID(uuidString: string)
        }
        return nil
    }
    
    var lookup: Lookup {
        Lookup(rawValue)
    }
    
    /// Available when rawType is in `[.array, .dict, .string]`
    var jsonData: Data? {
        switch rawType {
        case .array:
            return try? JSONSerialization.data(withJSONObject: rawArray)
        case .dict:
            return try? JSONSerialization.data(withJSONObject: rawDict)
        case .string:
            return rawString.data(using: .utf8)
        default:
            return nil
        }
    }
    
    /// Available when rawType is in `[.array, .dict, .string]`
    var isEmpty: Bool {
        switch rawType {
        case .array:
            return rawArray.isEmpty
        case .dict:
            return rawDict.isEmpty
        case .string:
            return rawString.isEmpty
        default:
            return false
        }
    }
    
    /// Available when rawType is in `[.array, .dict, .string]`
    var count: Int {
        switch rawType {
        case .array:
            return rawArray.count
        case .dict:
            return rawDict.count
        case .string:
            return rawString.count
        default:
            return 0
        }
    }
}

// MARK: Decode
extension Lookup {
    
    public func decode<D>(as decodable: D.Type, using decoder: JSONDecoder = JSONDecoder()) throws -> D? where D: Decodable {
        guard let encoded = try? JSONEncoder().encode(self) else {
            return nil
        }
        return try decoder.decode(D.self, from: encoded)
    }
}


// MARK: - Operator
public func + (lhs: Lookup, rhs: Lookup) -> Lookup {
    switch (lhs.rawType, rhs.rawType) {
    case (.dict, .dict):
        let lhsRawDict = lhs.rawDict
        return Lookup(lhsRawDict.merging(rhs.rawDict, uniquingKeysWith: { $1 }))
    case (.array, .array):
        return Lookup(lhs.rawArray + rhs.rawArray)
    default:
        return .null
    }
}

public func += (lhs: inout Lookup, rhs: Lookup) {
    lhs.merge(other: rhs)
}

// MARK: - Codable
extension Lookup: Codable {
    
    private var codableDictionary: [String: Lookup]? {
        switch rawType {
        case .dict, .object:
            var d = [String: Lookup](minimumCapacity: rawDict.count)
            rawDict.forEach { pair in
                d[pair.key] = Lookup(pair.value)
            }
            return d
        default:
            return nil
        }
    }
    
    private var codableArray: [Lookup]? {
        rawType == .array ? rawArray.map { Lookup($0) } : nil
    }
    
    private static var codableTypes: [Codable.Type] {
        [
            Bool.self,
            Int.self, Int8.self, Int16.self, Int32.self, Int64.self,
            UInt.self, UInt8.self, UInt16.self, UInt32.self, UInt64.self,
            Double.self,
            String.self,
            [Lookup].self,
            [String: Lookup].self
        ]
    }
    public init(from decoder: Decoder) throws {
        var object: Any?

        if let container = try? decoder.singleValueContainer(), !container.decodeNil() {
            for type in Lookup.codableTypes {
                if object != nil {
                    break
                }
                // ⚠️ refer: https://github.com/vapor/postgres-nio/pull/120
                // try to decode value
                switch type {
                case let boolType as Bool.Type:
                    object = try? container.decode(boolType)
                case let stringType as String.Type:
                    object = try? container.decode(stringType)
                case let jsonValueArrayType as [Lookup].Type:
                    object = try? container.decode(jsonValueArrayType)
                case let jsonValueDictType as [String: Lookup].Type:
                    object = try? container.decode(jsonValueDictType)
                case let doubleType as Double.Type:
                    object = try? container.decode(doubleType)
                case _ as UInt.Type,
                    _ as UInt8.Type,
                    _ as UInt16.Type,
                    _ as UInt32.Type,
                    _ as UInt64.Type:
                    object = try? container.decode(Int64.self)
                case _ as Int.Type,
                    _ as Int8.Type,
                    _ as Int16.Type,
                    _ as Int32.Type,
                    _ as Int64.Type:
                    object = try? container.decode(Int64.self)
                default:
                    break
                }
            }
        }
        self.init(object ?? NSNull())
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if rawValue is NSNull {
            try container.encodeNil()
            return
        }
        switch rawValue {
        case let intValue as Int:
            try container.encode(intValue)
        case let int16Value as Int16:
            try container.encode(int16Value)
        case let int32Value as Int32:
            try container.encode(int32Value)
        case let int64Value as Int64:
            try container.encode(int64Value)
        case let int8Value as Int8:
            try container.encode(int8Value)
        case let uintValue as UInt:
            try container.encode(uintValue)
        case let uint16Value as UInt16:
            try container.encode(uint16Value)
        case let uint32Value as UInt32:
            try container.encode(uint32Value)
        case let uint64Value as UInt64:
            try container.encode(uint64Value)
        case let uint8Value as UInt8:
            try container.encode(uint8Value)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case is [Any]:
            let jsonValueArray = codableArray ?? []
            try container.encode(jsonValueArray)
        case is [String: Any]:
            let jsonValueDictValue = codableDictionary ?? [:]
            try container.encode(jsonValueDictValue)
        default:
            break
        }
    }
}

// MARK: Description
extension Lookup: Swift.CustomStringConvertible, Swift.CustomDebugStringConvertible {
    
    private func castValueToString(value: Any) -> String {
        #if os(macOS)
        if #available(macOS 10.15, *) {
            if let data: Data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted, .fragmentsAllowed, .withoutEscapingSlashes]),
               let str = String(data: data, encoding: .utf8)
            {
                return str
            }
        } else {
            // Fallback on earlier versions
            if let data: Data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted, .fragmentsAllowed]),
               let str = String(data: data, encoding: .utf8)
            {
                return str
            }
        }
        #elseif os(iOS)
        if #available(iOS 13, *) {
            if let data: Data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted, .fragmentsAllowed, .withoutEscapingSlashes]),
               let str = String(data: data, encoding: .utf8)
            {
                return str
            }
        } else {
            // Fallback on earlier versions
            if let data: Data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted, .fragmentsAllowed]),
               let str = String(data: data, encoding: .utf8)
            {
                return str
            }
        }
        #else
        if let data: Data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted, .fragmentsAllowed]),
           let str = String(data: data, encoding: .utf8)
        {
            return str
        }
        #endif
        return "Can not cast value to string"
    }
    
    public var description: String {
        let desc: String
        switch rawType {
        case .dict, .object:
            desc = castValueToString(value: rawDict)
        case .array:
            desc = castValueToString(value: rawArray)
        case .number:
            desc = "\(rawNumber)"
        case .string:
            desc = "\(rawValue)"
        case .bool:
            desc = "\(rawBool)"
        case .none:
            desc = "nil"
        }
        return desc
    }
    
    public var debugDescription: String { description }
    
}

// MARK: - Filter
extension Lookup {
    
    public func keep(keys: [String]) -> Lookup {
        let res = keys.map { key -> (String, Any?) in
            (key, self[key].rawValue)
        }
        return Lookup(Dictionary(uniqueKeysWithValues: res))
    }
    
    public func setNull(keys: [String]) -> Lookup {
        var new = self
        for key in keys {
            new[dynamicMember: key] = nil
        }
        return new
    }
    
    public func compactMapValues(keepKeyOfEmptyValue: Bool = false) -> Lookup {
        switch rawType {
        case .none, .number, .bool:
            return self
        case .string:
            return self
        case .array:
            let map = rawArray.map { value in
                Lookup(value).compactMapValues(keepKeyOfEmptyValue: keepKeyOfEmptyValue)
            }
            return Lookup(map)
        case .object, .dict:
            let map = rawDict.compactMap { (k: String, v: Any) -> (String, Any)? in
                let vl = Lookup(v)
                if vl.isNone || (!keepKeyOfEmptyValue && vl.isEmpty) {
                    return nil
                }
                let newValue = vl.compactMapValues(keepKeyOfEmptyValue: keepKeyOfEmptyValue)
                if (!keepKeyOfEmptyValue && newValue.isEmpty) {
                    return nil
                }
                return (k, newValue)
            }
            return Lookup(Dictionary(uniqueKeysWithValues: map))
        }
    }
}

