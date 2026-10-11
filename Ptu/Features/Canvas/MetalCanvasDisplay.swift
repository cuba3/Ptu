// Copyright 2026 Ptu contributors
// Licensed under the Apache License, Version 2.0

import AppKit
import CoreGraphics
import Metal
import MetalKit

/// Presents the CPU composite as Metal tiles. `nil` when the device or shader is unavailable;
/// the canvas then keeps drawing that same composite with AppKit.
final class MetalCanvasDisplay: NSObject, MTKViewDelegate {
    static let shared: MetalCanvasDisplay? = MetalCanvasDisplay.make()

    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let samplerLinear: MTLSamplerState
    private let samplerNearest: MTLSamplerState
    private var tiles: [TileKey: Tile] = [:]
    private var documentSize = SIMD2<Int>(0, 0)
    private var syncedManaged: [MTLTexture] = []

    var onDraw: ((MTKView) -> Void)?

    private struct TileKey: Hashable {
        var x: Int
        var y: Int
    }

    private struct Tile {
        var rect: CGRect
        var texture: MTLTexture
        var managed: Bool
    }

    private struct GPUVertex {
        var ndcX: Float
        var ndcY: Float
        var texX: Float
        var texY: Float
        var viewX: Float
        var viewY: Float
    }

    private struct Uniforms {
        var documentOrigin: SIMD4<Float>
        var checkerLight: SIMD4<Float>
        var checkerDark: SIMD4<Float>
    }

    private init(
        device: MTLDevice,
        queue: MTLCommandQueue,
        pipeline: MTLRenderPipelineState,
        samplerLinear: MTLSamplerState,
        samplerNearest: MTLSamplerState
    ) {
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.samplerLinear = samplerLinear
        self.samplerNearest = samplerNearest
        super.init()
    }

    private static func make() -> MetalCanvasDisplay? {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        do {
            let library = try device.makeLibrary(source: shader, options: nil)
            guard let vertex = library.makeFunction(name: "tileVertex"),
                  let fragment = library.makeFunction(name: "tileFragment") else { return nil }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
            guard let linear = device.makeSamplerState(descriptor: sampler(.linear)),
                  let nearest = device.makeSamplerState(descriptor: sampler(.nearest)) else { return nil }
            return MetalCanvasDisplay(
                device: device,
                queue: queue,
                pipeline: pipeline,
                samplerLinear: linear,
                samplerNearest: nearest
            )
        } catch {
            return nil
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        onDraw?(view)
    }

    func render(
        bytes: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        dirtyTiles: [CGRect],
        pan: CGPoint,
        zoom: CGFloat,
        viewSize: CGSize,
        checkerLight: SIMD4<Float>,
        checkerDark: SIMD4<Float>,
        backdrop: SIMD4<Float>,
        in view: MTKView
    ) {
        if documentSize.x != width || documentSize.y != height {
            tiles.removeAll()
            documentSize = SIMD2(width, height)
        }
        syncedManaged.removeAll()
        for rect in dirtyTiles {
            upload(bytes: bytes, bytesPerRow: bytesPerRow, rect: rect)
        }
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer() else { return }
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(backdrop.x), green: Double(backdrop.y), blue: Double(backdrop.z), alpha: 1
        )
        pass.colorAttachments[0].storeAction = .store
        if !syncedManaged.isEmpty, let blit = command.makeBlitCommandEncoder() {
            for texture in syncedManaged {
                blit.synchronize(resource: texture)
            }
            blit.endEncoding()
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        var uniforms = Uniforms(
            documentOrigin: SIMD4(Float(pan.x), Float(pan.y), 0, 0),
            checkerLight: checkerLight,
            checkerDark: checkerDark
        )
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentSamplerState(zoom >= 1 ? samplerNearest : samplerLinear, index: 0)
        let visible = visibleDocument(pan: pan, zoom: zoom, viewSize: viewSize)
        for tile in tiles.values where tile.rect.intersects(visible) {
            var vertices = quad(tile.rect, pan: pan, zoom: zoom, viewSize: viewSize)
            vertices.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress else { return }
                encoder.setVertexBytes(base, length: raw.count, index: 0)
            }
            encoder.setFragmentTexture(tile.texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }

    private func upload(bytes: UnsafePointer<UInt8>, bytesPerRow: Int, rect: CGRect) {
        let x = Int(rect.minX)
        let y = Int(rect.minY)
        let width = Int(rect.width)
        let height = Int(rect.height)
        guard width > 0, height > 0 else { return }
        let key = TileKey(x: x, y: y)
        let managed = !device.hasUnifiedMemory
        let texture: MTLTexture
        if let existing = tiles[key], Int(existing.rect.width) == width, Int(existing.rect.height) == height {
            texture = existing.texture
        } else {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            descriptor.storageMode = managed ? .managed : .shared
            guard let made = device.makeTexture(descriptor: descriptor) else { return }
            texture = made
            tiles[key] = Tile(rect: rect, texture: made, managed: managed)
        }
        var tileBytes = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let source = bytes + (y + row) * bytesPerRow + x * 4
            tileBytes.withUnsafeMutableBytes { raw in
                guard let base = raw.baseAddress else { return }
                memcpy(base.advanced(by: row * width * 4), source, width * 4)
            }
        }
        tileBytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: base,
                bytesPerRow: width * 4
            )
        }
        if managed { syncedManaged.append(texture) }
    }

    private func quad(_ rect: CGRect, pan: CGPoint, zoom: CGFloat, viewSize: CGSize) -> [GPUVertex] {
        let viewRect = CGRect(
            x: pan.x + rect.minX * zoom,
            y: pan.y + rect.minY * zoom,
            width: rect.width * zoom,
            height: rect.height * zoom
        )
        let corners: [(CGPoint, Float, Float)] = [
            (CGPoint(x: viewRect.minX, y: viewRect.minY), 0, 0),
            (CGPoint(x: viewRect.maxX, y: viewRect.minY), 1, 0),
            (CGPoint(x: viewRect.maxX, y: viewRect.maxY), 1, 1),
            (CGPoint(x: viewRect.minX, y: viewRect.maxY), 0, 1),
        ]
        return [0, 1, 2, 0, 2, 3].map { index in
            let corner = corners[index]
            return GPUVertex(
                ndcX: Float(corner.0.x / viewSize.width) * 2 - 1,
                ndcY: 1 - Float(corner.0.y / viewSize.height) * 2,
                texX: corner.1,
                texY: corner.2,
                viewX: Float(corner.0.x),
                viewY: Float(corner.0.y)
            )
        }
    }

    private func visibleDocument(pan: CGPoint, zoom: CGFloat, viewSize: CGSize) -> CGRect {
        CGRect(x: -pan.x / zoom, y: -pan.y / zoom, width: viewSize.width / zoom, height: viewSize.height / zoom)
            .insetBy(dx: -1, dy: -1)
    }

    private static func sampler(_ filter: MTLSamplerMinMagFilter) -> MTLSamplerDescriptor {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = filter
        descriptor.magFilter = filter
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        return descriptor
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float ndcX;
        float ndcY;
        float texX;
        float texY;
        float viewX;
        float viewY;
    };

    struct VertexOut {
        float4 position [[position]];
        float2 tex;
        float2 viewPoint;
    };

    struct Uniforms {
        float4 documentOrigin;
        float4 checkerLight;
        float4 checkerDark;
    };

    vertex VertexOut tileVertex(uint vid [[vertex_id]], constant VertexIn *vertices [[buffer(0)]]) {
        VertexIn input = vertices[vid];
        VertexOut output;
        output.position = float4(input.ndcX, input.ndcY, 0, 1);
        output.tex = float2(input.texX, input.texY);
        output.viewPoint = float2(input.viewX, input.viewY);
        return output;
    }

    fragment float4 tileFragment(
        VertexOut input [[stage_in]],
        constant Uniforms &uniforms [[buffer(0)]],
        texture2d<float> texture [[texture(0)]],
        sampler imageSampler [[sampler(0)]]
    ) {
        float4 source = texture.sample(imageSampler, input.tex);
        float alpha = source.a;
        float3 color = alpha > 0.001 ? source.rgb / alpha : float3(0);
        float2 local = input.viewPoint - uniforms.documentOrigin.xy;
        float check = fmod(floor(local.x / 8.0) + floor(local.y / 8.0), 2.0);
        float3 background = check < 0.5 ? uniforms.checkerLight.rgb : uniforms.checkerDark.rgb;
        return float4(mix(background, color, alpha), 1);
    }
    """
}

extension SIMD4 where Scalar == Float {
    static func srgb(_ color: NSColor) -> SIMD4<Float> {
        guard let converted = color.usingColorSpace(.sRGB) else { return SIMD4(0.5, 0.5, 0.5, 1) }
        return SIMD4(Float(converted.redComponent), Float(converted.greenComponent), Float(converted.blueComponent), 1)
    }
}
