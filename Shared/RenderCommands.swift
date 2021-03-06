//
//  Shared.swift
//  SwiftBot
//
//  Created by Sean Hickey on 10/23/16.
//
//

import simd

public struct RenderCommandBufferHeader {
    var commandCount : U32 = 0
    var firstCommandBase : RawPtr? = nil
    var lastCommandBase : RawPtr? = nil
    var lastCommandHead : RawPtr? = nil
    
    var windowSize : Size = Size(0, 0)
}

public enum RenderCommandType {
    case header
    case options
    case uniforms
    case triangles
    case polyline
    case text
}

public protocol RenderCommand {
    var type : RenderCommandType { get }
    var next : RawPtr? { get set }
}

// Memory layout compatible struct for determining
// type of command, next pointer, etc.
public struct RenderCommandHeader {
    public let type = RenderCommandType.options
    public var next : RawPtr? = nil
}

public struct RenderCommandOptions : RenderCommand {
    public let type = RenderCommandType.options
    public var next : RawPtr? = nil
    
    public enum FillModes {
        case fill
        case wireframe
    }
    
    public var fillMode = FillModes.fill
}

public struct RenderCommandUniforms : RenderCommand {
    public let type = RenderCommandType.uniforms
    public var next : RawPtr? = nil
    
    public var transform = float4x4(1)
}

public struct RenderCommandTriangles : RenderCommand {
    public let type = RenderCommandType.triangles
    public var next : RawPtr? = nil
    
    public var transform = float4x4(1)
    public var vertexBuffer : RawPtr! = nil
    public var vertexCount : Int = 0
    public var selected : Bool = false
}

public struct RenderCommandPolyline : RenderCommand {
    public let type = RenderCommandType.polyline
    public var next : RawPtr? = nil
    
    public var transform = float4x4(1)
    public var vertexBuffer : RawPtr! = nil
    public var vertexCount : Int = 0
}

public struct RenderCommandText : RenderCommand {
    public let type = RenderCommandType.text
    public var next : RawPtr? = nil
    
    public var transform = float4x4(1)
    
    public var quadCount : Int = 0
    public var quads : RawPtr! = nil
    public var indices : RawPtr! = nil
    
    public var texels : RawPtr! = nil
}


