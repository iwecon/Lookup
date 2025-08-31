import Testing
@testable import Lookup
import Foundation
#if os(iOS)
import UIKit
#endif

struct Params {
    let lookup: Lookup
    init(_ lookup: Lookup) {
        self.lookup = lookup
    }
}

extension Params: ExpressibleByDictionaryLiteral {
    typealias Key = String
    typealias Value = any Any & Sendable
    init(dictionaryLiteral elements: (String, any Sendable)...) {
        self.init(Lookup(Dictionary(uniqueKeysWithValues: elements)))
    }
}

enum AnimalType: String, Codable {
    case dog, cat
}

enum AnimalIntType: Int, LookupEnum, Codable {
    case dog = 0, cat
    
    var lookupRawValue: Any {
        self.rawValue
    }
}

struct Animal {
    let name: String
    let age: Int
    let type: AnimalType
    let intType: AnimalIntType
}

open class AnimalClass {
    let name: String = "Dog"
    let age: Int = 4
    let type: AnimalType = .dog
    let intType: AnimalIntType = .dog
}

struct KeyboardButton: Codable {
    let text: String
    let url: String?
    let callbackData: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case url
        case callbackData = "callback_data"
    }
    init(text: String, url: String? = nil, callbackData: String? = nil) {
        self.text = text
        self.url = url
        self.callbackData = callbackData
    }
}

struct Markup: Codable {
    var keyboards: [[KeyboardButton]]
    init(keyboards buttons: [[KeyboardButton]]) {
        self.keyboards = buttons
    }
    enum CodingKeys: String, CodingKey {
        case keyboards = "inline_keyboard"
    }
}

struct MessageReply: Codable {
    let text: String
    let toID: Int
    let markup: Markup?
}

final class Species: AnimalClass {
    let start: Date = Date()
}

struct UnwrapModel: LookupUnwrap {
    let id: UUID
    let age: Int
    let type: AnimalType
    let intType: AnimalIntType
    let date: Date
    
    func lookupUnwrap(key: String, value: Any) -> Any? {
        if key == "date" {
            return date.timeIntervalSince1970
        }
        return value
    }
}

struct LookupTests {
    
    @Test("Test Data String Initialization")
    func testDataStringInitialization() {
        let str = "Its a string..."
        let data = str.data(using: .utf8)!
        let lookup = Lookup(data)
        #expect(lookup.string == str)
    }
    
    @Test("Test Json Data Initialization")
    func testJsonDataInitialization() {
        let jsonString = "{\"name\": \"lookup\"}"
        let data = jsonString.data(using: .utf8)!
        let lookup = Lookup(data)
        #expect(lookup.name.string == "lookup")
    }
    
    @Test("Test Array Initialization")
    func testArrayInitialization() {
        let array: [Any] = [1, 2.0, "3", 4.5, -5, -6.0]
        let lookup = Lookup(array)
        #expect(lookup.0.int == 1)
        #expect(lookup.1.double == 2.0)
        #expect(lookup.1.int == 2)
        #expect(lookup.2.string == "3")
        #expect(lookup.2.int == 3)
        #expect(lookup.3.double == 4.5)
        #expect(lookup.4.int == -5)
        #expect(lookup.5.double == -6.0)
    }
    
    @Test("Test Structure Initialization")
    func testStructureInitialization() {
        let animal = Animal(name: "Cat", age: 3, type: .cat, intType: .cat)
        let lookup = Lookup(animal)
        #expect(lookup.name.string == "Cat")
        #expect(lookup.age.int == 3)
        #expect(lookup.type.string == "cat")
        #expect(lookup.intType.int == 1)
    }
    
    @Test("Test Class Initialization")
    func testClassInitialization() {
        let animal = AnimalClass()
        let lookup = Lookup(animal)
        #expect(lookup.name.string == "Dog")
        #expect(lookup.age.int == 4)
        #expect(lookup.type.stringValue == "dog")
        #expect(lookup.intType.intValue == 0)
    }
    
    @Test("Test Super Class Initialization")
    func testSuperClassInitialization() {
        let species = Species()
        let lookup = Lookup(species)
        #expect(lookup.name.string == "Dog")
        #expect(lookup.age.int == 4)
        #expect(lookup.type.string == "dog")
        #expect(lookup.intType.int == 0)
        #expect(lookup.start.double != nil)
    }
    
    @Test("Test Chain Value")
    func testChainValue() {
        let dict: [String: Any] = [
            "data": [
                "list": ["value0", nil, "value2"]
            ]
        ]
        let lookup = Lookup(dict)
        #expect(lookup.data.list.0.string == "value0")
        #expect(lookup.data.list.1.isNone == true)
        #expect(lookup.data.list.2.string == "value2")
    }
    
    @Test("Test Chain Value 2")
    func testChainValue2() {
        let dict: [String: Any] = [
            "data": [
                ["list": ["value0", nil, "value2"]],
                ["list": ["value3", nil, 4]]
            ]
        ]
        let lookup = Lookup(dict)
        
        #expect(lookup.data.0.list.0.string == "value0")
        #expect(lookup.data.0.list.1.string == nil)
        #expect(lookup.data.0.list.1.isNone == true)
        #expect(lookup.data.0.list.2.string == "value2")
        #expect(lookup.data.1.list.0.string == "value3")
        #expect(lookup.data.1.list.1.string == nil)
        #expect(lookup.data.1.list.1.isNone == true)
        #expect(lookup.data.1.list.2.int == 4)
        #expect(lookup["data.0.list.0"].string == "value0")
        #expect(lookup["data.1.list.1"].isNone == true)
        #expect(lookup["data.1.list.2"].int == 4)
    }
    
    @Test("Test Array Nil Value")
    func testArrayNilValue() {
        let array: [Any?] = [1, 2, "3", nil, 5]
        let lookup = Lookup(array)
        #expect(lookup.3.isNone == true)
    }
    
    @Test("Test Dict Nil Value")
    func testDictNilValue() {
        let dict: [String: Any?] = ["nil": nil]
        let lookup = Lookup(dict)
        #expect(lookup.nil.isNone == true)
    }
    
    @Test("Test Number Convert")
    func testNumberConvert() {
        let dict = ["number": 1]
        let lookup = Lookup(dict)
        #expect(lookup.number.int == 1)
        #expect(lookup.number.string == "1")
        #expect(lookup.number.int16 == 1)
        #expect(lookup.number.int32 == 1)
        #expect(lookup.number.int64 == 1)
        #expect(lookup.number.uInt == 1)
        #expect(lookup.number.uInt16 == 1)
        #expect(lookup.number.uInt32 == 1)
        #expect(lookup.number.uInt64 == 1)
        #expect(lookup.number.float == 1.0)
        #expect(lookup.number.double == 1.0)
        #expect(lookup.number.bool == true)
    }
    
    @Test("Test String to Nubmer Conver")
    func testStringToNubmerConver() {
        let dict = ["number": "1"]
        let lookup = Lookup(dict)
        #expect(lookup.number.int == 1)
        #expect(lookup.number.string == "1")
        #expect(lookup.number.int16 == 1)
        #expect(lookup.number.int32 == 1)
        #expect(lookup.number.int64 == 1)
        #expect(lookup.number.uInt == 1)
        #expect(lookup.number.uInt16 == 1)
        #expect(lookup.number.uInt32 == 1)
        #expect(lookup.number.uInt64 == 1)
        #expect(lookup.number.float == 1.0)
        #expect(lookup.number.double == 1.0)
        #expect(lookup.number.bool == true)
    }
    
    @Test("Test Merge Dict Lookup")
    func testMergeDictLookup() {
        let lookup1 = Lookup(["name": "Lookup", "age": 3])
        let lookup2 = Lookup(["age": 1])
        let merged = lookup1 + lookup2
        #expect(merged.name.string == "Lookup")
        #expect(merged.age.int == 1)
        
        var lookup3 = Lookup(["name": "Lookup", "brief": "A data handle tools."])
        let lookup4 = Lookup(["age": 1])
        lookup3 += lookup4
        #expect(lookup3.age.int == 1)
        #expect(lookup3.name.string == "Lookup")
        #expect(lookup3.brief.string == "A data handle tools.")
        
        let lookup5 = lookup3 + ["brief": "json handle tools"]
        #expect(lookup5.brief.string == "json handle tools")
        
        let lookup6 = Lookup([1, 2, 3, 4, 5])
        let lookup7 = lookup6 + [4, 5, 6, 7, 8]
        #expect(lookup7.arrayValue.count == 10)
        
        let lookup8 = Lookup([
            "userID": 00001,
            "nickname": "Lookup"
        ])
        #expect(lookup8.userID.string == "1")
    }
    
    @Test("Test Codable")
    func testCodable() throws {
        let jsonString = "{\"name\": \"Lookup\", \"age\": 1, \"list\": \"[1,2,3]\"}"
        var lookup = try JSONDecoder().decode(Lookup.self, from: jsonString.data(using: .utf8)!)
        #expect(lookup.name.string == "Lookup")
        #expect(lookup.age.int == 1)
        #expect(lookup.list.0.int == 1)
        #expect(lookup.list.1.int == 2)
        #expect(lookup.list.2.int == 3)
        #expect(lookup.list.0.intValue == 1)
        
        lookup["list"] = ["a", "b", "c"]
        #expect(lookup.list.0.string == "a")
        #expect(lookup.list.1.string == "b")
        #expect(lookup.list.2.string == "c")
        #expect(lookup.list.3.string == nil)
        
        lookup["address"] = "in Hangzhou"
        #expect(lookup.address.string == "in Hangzhou")
        
        lookup["list.0"] = "d"
        #expect(lookup.list.0.string == "d")
        
        let jsonData = try JSONEncoder().encode(lookup)
        let _jsonString = String(data: jsonData, encoding: .utf8)
        #expect(_jsonString != nil)
        let rLookup = Lookup(_jsonString!)
        #expect(rLookup.name.string == "Lookup")
        #expect(rLookup.age.int == 1)
        
        lookup["age"] = "8"
        #expect(lookup.age.int == 8)
    }
    
    @Test("Test Set Value")
    func testSetValue() {
        let jsonString = "{\"name\": \"lookup\"}"
        let data = jsonString.data(using: .utf8)
        #expect(data != nil)
        
        var lookup = Lookup(data!)
        lookup.name = "Lookup YYDS"
        #expect(lookup.name.string == "Lookup YYDS")
        
        lookup.name = 1.0
        #expect(lookup.name.double == 1.0)
        
        lookup.name = nil
        #expect(lookup.name.isNone == true)
    }
    
    @Test("Test Change Value")
    func testChangeValue() throws {
        let jsonString = """
{
"name": "Lookap",
"version": "2.3.1",
"age": 2.5
}
"""
        var lookup = Lookup(jsonString)
        lookup.name = "Lookup"
        
        let newVersion = "2.4.0"
        lookup.version = "\(newVersion)"
        lookup.age = 3
        
        let newProperty = Lookup(["birthday": "2023/2/3", "info": 1])
        lookup += newProperty
        
        lookup += ["describe": "a magic json handle package", "info": 2, "url": nil]
        #expect(lookup.name.string == "Lookup")
        #expect(lookup.version.string == "2.4.0")
        #expect(lookup.age.double == 3)
        #expect(lookup.birthday.string == "2023/2/3")
        #expect(lookup.describe.string == "a magic json handle package")
        #expect(lookup.abc.string == nil)
        #expect(lookup.info.int == 2)
        #expect(lookup.abc.isNone == true)
        
        lookup["url"] = 2
        #expect(lookup.url.int == 2)
        
        lookup["url"] = "https://github.com/iwecon"
        lookup.url += "/lookup"
        #expect(lookup.url.string == "https://github.com/iwecon/lookup")
        
        #expect(lookup.hasKey("package") == false)
        
        #expect(lookup.hasKey("package.info.type") == false)
        lookup += ["package": ["info": ["type": 1]]]
        #expect(lookup.hasKey("package.info.type") == true)
        #expect(lookup["package.info.type"].int == 1)
        
        #expect(lookup.hasKey("package.info.wow") == false)
        
        lookup += """
{
"highlights": "@dynamicMemberLookup"
}
"""
        #expect(lookup.highlights.string == "@dynamicMemberLookup")
    }
    
    @Test("Test Select")
    func testSelect() throws {
        struct User {
            let id: UUID = UUID()
            let name: String
            let age: Int
        }
        let user = User(name: "wei", age: 18)
        let lookup = Lookup(user)
        let keepLookup = lookup.keep(keys: ["name"])
        
        #expect(keepLookup.id.isNone == true)
        #expect(keepLookup.name.string == "wei")
        /**
         {
         id: xxx,
         cars: [Car]
         }
         let lookup = Lookup(cars)
         
         let carsLookup = Lookup(cars)
         carsLookup.0.name = .null
         carsLookup.compactMapValues()
         
         lookup.cars = carsLookup
         */
        let rejectLookup = lookup.setNull(keys: ["id"])
            .compactMapValues()
        #expect(rejectLookup.id.isNone == true)
        #expect(rejectLookup.name.string == "wei")
        #expect(rejectLookup.age.int == 18)
        
        var aLookup = Lookup(
            [
                "name": "iwecon", "childs":[
                    [
                        "name": "lookup", "id": nil, "age": 18,
                        "childs": [
                            ["name": "Lookup.dynamicMember", "age": 12, "id": nil]
                        ]
                    ]
                ]
            ]
        )
            .compactMapValues()
        #expect(aLookup.hasKey("childs.0.id") == false)
        #expect(aLookup.hasKey("childs.0.age") == true)
        #expect(aLookup.hasKey("childs.0.childs.0.id") == false)
        #expect(aLookup.childs.0.age.int == 18)
        #expect(aLookup.childs.0.childs.0.name.string == "Lookup.dynamicMember")
        
        aLookup["childs.0.id"] = "1"
        #expect(aLookup.childs.0.id.string == "1")
        
        let anlookup = aLookup.setNull(keys: ["childs.0.age"])
        #expect(anlookup.hasKey("childs.0.age") == true)
        var canlookup = anlookup.compactMapValues()
        #expect(canlookup.hasKey("childs.0.age") == false)
        
        canlookup["childs.0.childs.0.id"] = 1
        canlookup["childs.0.childs.0.age"] = 18
        #expect(canlookup.childs.0.childs.0.id.int == 1)
        #expect(canlookup.childs.0.childs.0.age.int == 18)
        
        canlookup["childs.0.childs.0.birth"] = "2024"
        #expect(canlookup.childs.0.childs.0.birth.string == "2024")
    }
    
    @Test("Test Bool Value")
    /// 确保传入 `true/false` ，JSONEncoder 得到的还是 `true/false` 而不是 `1/0`
    func testBoolValue() throws {
        let json = """
        {
            "b": true,
            "i": 1
        }
        """
        let clookup = Lookup(json)
        #expect(clookup.b.bool == true)
        #expect(clookup.b.int == 1)
        #expect(clookup.i.int == 1)
        #expect(clookup.i.bool == true)
        #expect(clookup.description.contains("true"))
        
        let data = try JSONEncoder().encode(clookup)
        let encoded = String(data: data, encoding: .utf8)
        print(encoded ?? "empty")
        #expect(encoded != nil)
        #expect(encoded?.contains("true") == true)
        #expect(encoded?.contains("1") == true)
    }
    
    @Test("Test ExpressionByDictionary")
    func testExpressionByDictionary() throws {
        
        let params: Params = ["ids": [UUID(), UUID(), UUID()]]
        print(params.lookup)
        #expect(params.lookup.ids.count == 3)
    }
    
    @Test("Test Nesting Codable")
    func testNestingCodable() throws {
        let markup = MessageReply(
            text: "This is a reply message!",
            toID: 10086,
            markup: Markup(
                keyboards: [
                    [KeyboardButton(text: "Hang up", callbackData: "/hang-up")],
                    [KeyboardButton(text: "Recording", callbackData: "/recording")]
                ]
            )
        )
        let lookup = Lookup(markup)
        print(lookup.description)
        #expect(lookup.text.string == "This is a reply message!")
        #expect(lookup.toID.string == "10086")
        #expect(lookup.toID.int == 10086)
        
        #expect(lookup.markup.keyboards.0.0.text.string == "Hang up")
        #expect(lookup.markup.keyboards.0.0.callbackData.string == "/hang-up")
        
        #expect(lookup.markup.keyboards.1.0.text.string == "Recording")
        #expect(lookup.markup.keyboards.1.0.callbackData.string == "/recording")
    }
    
    @Test("Test Unwrap")
    func testUnwrap() throws {
        let model = UnwrapModel(id: UUID(), age: 1, type: .cat, intType: .cat, date: Date())
        let lookup = Lookup(model)
        print(lookup)
        
        let json = """
{
"user": { "id": null },
"id": 1
}
"""
        let clookup = Lookup(json).compactMapValues()
        #expect(clookup.hasKey("user") == false)
    }
    
    @Test("Test Array")
    func testArray() async throws {
        let lookup: Lookup = ["ids": [UUID()]]
        print(lookup.description)
        #expect(lookup.ids.count == 1)
    }
    
    #if os(iOS)
    @Test("Test UIView")
    func testUIView() throws {
        let view = UIView()
        let lookup = Lookup(["view": view])
        #expect(lookup.description, """
{
"view" : "\(view)"
}
""")
    }
    #endif
}
