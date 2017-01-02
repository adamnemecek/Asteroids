import Foundation


extension String {
    subscript(range: NSRange) -> String {
        get {
            let start = self.index(self.startIndex, offsetBy: range.location)
            let end = self.index(start, offsetBy: range.length)
            return self.substring(with: start..<end)
        }
    }
}

// Returns a string consisting of all the ref structs and an array of string containing all the renderable names
func preprocessStructs(_ source: String) -> (String, [String]) {
    
    var renderables : [String] = []
    
    let structRegex = try! NSRegularExpression(pattern: "/\\*=\\s*BEGIN_REFSTRUCT\\s*=\\*/\\s*(.*?)\\s*/\\*=\\s*END_REFSTRUCT\\s*=\\*/", options: [.dotMatchesLineSeparators, .allowCommentsAndWhitespace])
    
    let declRegex = try! NSRegularExpression(pattern: "^\\s*struct\\s+([\\w]+)(<[\\w\\s\\,]*>)?\\s*(:\\s*(\\w+)\\s*)?\\{\\s*$", options: [.anchorsMatchLines, .useUnixLineSeparators])
    
    let propertyRegex = try! NSRegularExpression(pattern: "^(\\s+var\\s+(\\w+)\\s+:\\s+([\\w<>\\,\\s\\.]+))\\s+/\\*=\\s(GETSET|GET|SET)\\s=\\*/$", options: [.anchorsMatchLines, .useUnixLineSeparators])
    
    var output = ""
    structRegex.enumerateMatches(in: source, options: [], range: NSMakeRange(0, source.characters.count), using: { (result, flags, stopPtr) in
        
        let range = result!.rangeAt(1)
        let structString = source[range]
        
        declRegex.enumerateMatches(in: structString, options: [], range: NSMakeRange(0, structString.characters.count), using: { (result, flags, stopPtr) in
            
            let typeName = structString[result!.rangeAt(1)]
            var genericType = ""
            
            if result!.rangeAt(2).location != NSNotFound {
                genericType = structString[result!.rangeAt(2)]
            }
            
            var structRefDecl = "struct \(typeName)Ref\(genericType) : "
            
            
            if result!.rangeAt(4).location != NSNotFound {
                let inheritedTypeName = structString[result!.rangeAt(4)]
                if inheritedTypeName != "Renderable" {
                    structRefDecl += inheritedTypeName
                }
                
                if inheritedTypeName == "Entity" || inheritedTypeName == "Renderable" {
                    renderables.append(typeName)
                }
            }
            
            structRefDecl += "Ref {\n    var ptr : Ptr<\(typeName)\(genericType)>\n\n"
            
            propertyRegex.enumerateMatches(in: structString, options: [], range: NSMakeRange(0, structString.characters.count), using: { (result, flags, stopPtr) in
                
                let varName = structString[result!.rangeAt(2)]
                let varType = structString[result!.rangeAt(3)]
                let accessorType = structString[result!.rangeAt(4)]
                
                var propDecl = "    var \(varName) : \(varType) { "
                
                if accessorType == "GET" || accessorType == "GETSET" {
                    propDecl += "get { return ptr.pointee.\(varName) } "
                }
                if accessorType == "SET" || accessorType == "GETSET" {
                    propDecl += "set(val) { ptr.pointee.\(varName) = val } "
                }
                propDecl += "}\n"
                
                structRefDecl += propDecl
            })
            
            output += structRefDecl + "}\n\n"
        })
        
    })
    
    return (output, renderables)
}

var outputString = "/***************************************************\n* ReferenceStructs.swift\n*\n* THIS FILE IS AUTOGENERATED WITH EACH BUILD.\n* DON'T WRITE ANYTHING IMPORTANT IN HERE!\n****************************************************/\n\nprotocol Ref {\n    associatedtype T\n    var ptr : Ptr<T> { get set }\n}\n\n"

let env = ProcessInfo.processInfo.environment

print("Hello world!")

// Preprocess files, generate ref structs, and gather renderable names
var allRenderables : [String] = []

if let numInputsStr = env["SCRIPT_INPUT_FILE_COUNT"] {
    let numInputs = Int(numInputsStr)!
    
    for i in 0..<numInputs {
        if let inputPath = env["SCRIPT_INPUT_FILE_\(i)"] {
            let filename = (inputPath as NSString).lastPathComponent
            var source = try! String(contentsOfFile: inputPath)
            let (refStructs, entityNames) = preprocessStructs(source)
            outputString += "/************************\n * \(filename)\n ************************/\n\n"
            outputString += refStructs + "\n\n"
            allRenderables += entityNames
        }
    }
    
}

// Generate renderable ids
outputString += "/************************\n * Renderable Type Ids\n ************************/\n\n"
for (idx, renderable) in allRenderables.enumerated() {
    // Hash the entity name. This has the nice property of being deterministic between builds
    var hash : UInt64 = 0
    for c in renderable.unicodeScalars {
        print(hash)
        hash = UInt64(c.value) &+ (hash << 6) &+ (hash << 16) &- hash // The &+ and &- allow overflow
    }
    outputString += "extension \(renderable) {\n  static var renderableId : RenderableId = 0x\(String(format:"%08X", hash >> 32))\(String(format:"%08X", hash))\n}\n\n"
}

if let outputPath = env["SCRIPT_OUTPUT_FILE_0"] {
    try! outputString.write(toFile: outputPath, atomically: true, encoding: .utf8)
}
