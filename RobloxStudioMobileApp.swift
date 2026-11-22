//
//  RobloxStudioMobileApp.swift
//  RobloxStudioMobile
//
//  Created by Andy Lin on 3/28/21.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

@main
struct RobloxStudioMobileApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct InputDocument: FileDocument {
    
    static var readableContentTypes: [UTType] { [.xml] }
    
    var input: String
    
    init(input: String) {
        self.input = input
    }
    
    init(configuration: FileDocumentReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        input = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: input.data(using: .utf8)!)
    }
    
}

extension UTType {
    //rbxlx
    static var rbxlx: UTType {
        // Look up the type from the file extension
        UTType.types(tag: "rbxlx", tagClass: .filenameExtension, conformingTo: .xml).first!
    }
}

final class RbxNode: Identifiable {
    let id = UUID()
    var name: String
    let className: String
    var children: [RbxNode]?
    var propData = ""

    init(className: String) {
        self.className = className
        self.name = className
    }

    func decodeProps() -> [PropertyInfo] {
        var out = [PropertyInfo]()
        for rec in propData.split(separator: "\u{1E}", omittingEmptySubsequences: true) {
            let f = rec.split(separator: "\u{1F}", omittingEmptySubsequences: false).map { String($0) }
            if f.count < 3 { continue }
            var pairs = [OrderedDict]()
            var i = 2
            while i + 1 < f.count {
                pairs.append(OrderedDict(key: f[i], value: f[i + 1]))
                i += 2
            }
            out.append(PropertyInfo(id: out.count, name: f[0], type: f[1], value: pairs))
        }
        return out
    }
}

final class RbxParser: NSObject, XMLParserDelegate {
    var roots: [RbxNode] = []
    private var stack: [RbxNode] = []
    private var inProps = false
    private var level = 0
    private var propName = ""
    private var propType = ""
    private var childKey = ""
    private var buf = ""
    private var pairs: [(String, String)] = []
    private var hadChildren = false
    private var records: [String] = []
    private var totalStored = 0
    private let budget = 120_000_000

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if inProps {
            level += 1
            if level == 1 {
                propType = elementName
                propName = attributeDict["name"] ?? ""
                buf = ""
                pairs = []
                hadChildren = false
            } else if level == 2 {
                childKey = elementName
                buf = ""
                hadChildren = true
            }
            return
        }
        if elementName == "Item" {
            stack.append(RbxNode(className: attributeDict["class"] ?? "Instance"))
        } else if elementName == "Properties" {
            inProps = true
            level = 0
            records = []
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inProps && level >= 1 { buf += string }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if inProps && level >= 1, let s = String(data: CDATABlock, encoding: .utf8) { buf += s }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if inProps {
            if level == 0 {
                if elementName == "Properties" {
                    inProps = false
                    stack.last?.propData = records.joined(separator: "\u{1E}")
                    records = []
                }
                return
            }
            if level == 2 {
                pairs.append((childKey, buf.trimmingCharacters(in: .whitespacesAndNewlines)))
                buf = ""
            } else if level == 1 {
                finishProperty()
            }
            level -= 1
            return
        }
        if elementName == "Item", let node = stack.popLast() {
            if let parent = stack.last {
                if parent.children == nil { parent.children = [] }
                parent.children!.append(node)
            } else {
                roots.append(node)
            }
        }
    }

    private func finishProperty() {
        let isSource = propName == "Source"
        var type = propType
        var out = pairs
        if !hadChildren {
            let v = isSource ? buf : buf.trimmingCharacters(in: .whitespacesAndNewlines)
            if propName == "Name" && propType == "string" { stack.last?.name = v }
            out = [(propName, isSource ? v : String(v.prefix(500)))]
        } else {
            type = "Array"
            out = out.map { ($0.0, String($0.1.prefix(500))) }
        }
        if propType == "BinaryString" || propType == "SharedString" || totalStored > budget { return }
        var fields = [propName, type]
        for p in out { fields.append(p.0); fields.append(p.1) }
        let rec = fields.joined(separator: "\u{1F}")
        totalStored += rec.utf8.count
        records.append(rec)
    }
}

func loadRbxlx(from url: URL) -> [RbxNode] {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
    let delegate = RbxParser()
    let xml = XMLParser(data: data)
    xml.delegate = delegate
    xml.parse()
    return delegate.roots
}

struct PropertyInfo: Equatable, Hashable{
    let id: Int
    let name: String
    let type: String
    var value: Array<OrderedDict>
}

struct OrderedDict: Equatable, Hashable{
    let key: String
    var value: String
}

class PropertyInfoArray: ObservableObject{
    @Published var properties = Array<PropertyInfo>()
    @Published var id: UUID = UUID()
    @Published var name = ""
}

class LoadingFile: ObservableObject{
    @Published var loading = false
}

class ScriptFile: ObservableObject{
    @Published var file = ""
}

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.upperBound
    }
    func indices<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Index] {
        ranges(of: string, options: options).map(\.lowerBound)
    }
    func ranges<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...]
                .range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}
