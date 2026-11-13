import AppKit
import SceneKit
import simd

/// A deliberately bounded reader for the five bundled, uncompressed glTF 2.0
/// assets. No network, scripts, animation, lights, cameras or external URI loads.
/// Unsupported layouts fail rather than silently dropping geometry.
final class ConsoleAsset {
    enum Failure: Error { case malformed(String) }
    private let document: [String: Any]
    private let binary: Data
    private var materials: [SCNMaterial] = []
    private var images: [Int: NSImage] = [:]
    private let accessors: [[String: Any]]
    private let views: [[String: Any]]

    init(url: URL) throws {
        let file = try Data(contentsOf: url, options: .mappedIfSafe)
        func uint(_ offset: Int) throws -> Int {
            guard offset >= 0, offset + 4 <= file.count else { throw Failure.malformed("GLB header") }
            return Int(file.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian })
        }
        guard try uint(0) == 0x46546C67, try uint(4) == 2, try uint(8) == file.count,
              try uint(16) == 0x4E4F534A else { throw Failure.malformed("GLB version or length") }
        let jsonLength = try uint(12)
        guard jsonLength <= file.count - 28 else { throw Failure.malformed("JSON length") }
        document = try JSONSerialization.jsonObject(with: file.subdata(in: 20..<(20 + jsonLength))) as? [String: Any] ?? [:]
        accessors = document["accessors"] as? [[String: Any]] ?? []
        views = document["bufferViews"] as? [[String: Any]] ?? []
        let start = 20 + jsonLength
        let size = try uint(start)
        guard try uint(start + 4) == 0x004E4942, size == file.count - start - 8,
              Set(document["extensionsRequired"] as? [String] ?? []).isSubset(of: ["KHR_materials_pbrSpecularGlossiness"]),
              (document["skins"] as? [Any] ?? []).isEmpty,
              (document["animations"] as? [Any] ?? []).isEmpty else { throw Failure.malformed("Unsupported asset layout") }
        binary = file.subdata(in: (start + 8)..<file.count)
    }

    func load(console: Console) throws -> SCNNode {
        materials = try (document["materials"] as? [[String: Any]] ?? []).map { try material($0, console: console) }
        let meshDescriptions = document["meshes"] as? [[String: Any]] ?? []
        let definitions = document["nodes"] as? [[String: Any]] ?? []
        let nodes = definitions.map { _ in SCNNode() }
        for (i, description) in definitions.enumerated() {
            let node = nodes[i]
            node.name = description["name"] as? String
            if let matrix = description["matrix"] as? [Double], matrix.count == 16 {
                node.simdTransform = simd_float4x4(columns: (SIMD4(matrix[0..<4].map(Float.init)), SIMD4(matrix[4..<8].map(Float.init)), SIMD4(matrix[8..<12].map(Float.init)), SIMD4(matrix[12..<16].map(Float.init))))
            } else {
                if let p = description["translation"] as? [Double], p.count == 3 { node.simdPosition = SIMD3(p.map(Float.init)) }
                if let s = description["scale"] as? [Double], s.count == 3 { node.simdScale = SIMD3(s.map(Float.init)) }
                if let q = description["rotation"] as? [Double], q.count == 4 { node.simdOrientation = simd_quatf(vector: SIMD4(q.map(Float.init))) }
            }
            // The Switch 2 source includes a full kit. Display its handheld assembly.
            let assembly = (description["extras"] as? [String: Any])?["assembly"] as? String ?? ""
            if console == .switch2 && ["Dock", "DockInternal", "Grip", "StrapL", "StrapR"].contains(assembly) { continue }
            if let mesh = description["mesh"] as? Int {
                guard meshDescriptions.indices.contains(mesh) else { throw Failure.malformed("Mesh index") }
                for primitive in meshDescriptions[mesh]["primitives"] as? [[String: Any]] ?? [] {
                    node.addChildNode(SCNNode(geometry: try geometry(primitive)))
                }
            }
        }
        for (i, description) in definitions.enumerated() {
            for child in description["children"] as? [Int] ?? [] {
                guard nodes.indices.contains(child), child != i else { throw Failure.malformed("Node hierarchy") }
                nodes[i].addChildNode(nodes[child])
            }
        }
        let scenes = document["scenes"] as? [[String: Any]] ?? []
        let selected = document["scene"] as? Int ?? 0
        guard scenes.indices.contains(selected) else { throw Failure.malformed("Scene") }
        let root = SCNNode()
        for i in scenes[selected]["nodes"] as? [Int] ?? [] {
            guard nodes.indices.contains(i) else { throw Failure.malformed("Root node") }
            root.addChildNode(nodes[i])
        }
        return root
    }

    private func slice(_ index: Int) throws -> Data {
        guard views.indices.contains(index) else { throw Failure.malformed("Buffer view") }
        let view = views[index], offset = view["byteOffset"] as? Int ?? 0, length = view["byteLength"] as? Int ?? 0
        guard (view["buffer"] as? Int ?? 0) == 0, offset >= 0, length >= 0, offset <= binary.count, length <= binary.count - offset else { throw Failure.malformed("Buffer bounds") }
        return binary.subdata(in: offset..<(offset + length))
    }

    private func accessor(_ index: Int) throws -> (Data, Int, Int, Int) {
        guard accessors.indices.contains(index) else { throw Failure.malformed("Accessor") }
        let a = accessors[index]
        guard let v = a["bufferView"] as? Int, views.indices.contains(v), a["sparse"] == nil,
              let type = a["componentType"] as? Int, let count = a["count"] as? Int, count > 0 else { throw Failure.malformed("Accessor layout") }
        let width: Int
        switch type { case 5126, 5125: width = 4; case 5123: width = 2; case 5121: width = 1; default: throw Failure.malformed("Component type") }
        let components: Int
        switch a["type"] as? String { case "SCALAR": components = 1; case "VEC2": components = 2; case "VEC3": components = 3; case "VEC4": components = 4; default: throw Failure.malformed("Attribute shape") }
        let bytes = try slice(v), offset = a["byteOffset"] as? Int ?? 0, stride = views[v]["byteStride"] as? Int ?? width * components
        guard offset >= 0, stride >= width * components, offset <= bytes.count,
              count <= (bytes.count - offset + stride - width * components) / stride else { throw Failure.malformed("Attribute bounds") }
        if stride == width * components { return (bytes.subdata(in: offset..<(offset + count * stride)), count, components, width) }
        var packed = Data(capacity: count * width * components)
        for row in 0..<count { packed.append(bytes.subdata(in: (offset + row * stride)..<(offset + row * stride + width * components))) }
        return (packed, count, components, width)
    }

    private func geometry(_ primitive: [String: Any]) throws -> SCNGeometry {
        guard (primitive["mode"] as? Int ?? 4) == 4, let attributes = primitive["attributes"] as? [String: Int],
              attributes["POSITION"] != nil, let index = primitive["indices"] as? Int else { throw Failure.malformed("Triangle mesh") }
        var sources: [SCNGeometrySource] = []
        for (name, semantic) in [("POSITION", SCNGeometrySource.Semantic.vertex), ("NORMAL", .normal), ("TEXCOORD_0", .texcoord)] {
            guard let accessorIndex = attributes[name] else { continue }
            let (bytes, count, components, width) = try accessor(accessorIndex)
            guard accessors[accessorIndex]["componentType"] as? Int == 5126 else { throw Failure.malformed("Expected float attribute") }
            sources.append(SCNGeometrySource(data: bytes, semantic: semantic, vectorCount: count, usesFloatComponents: true, componentsPerVector: components, bytesPerComponent: width, dataOffset: 0, dataStride: width * components))
        }
        let (indices, count, components, width) = try accessor(index)
        guard components == 1, count % 3 == 0, accessors[index]["componentType"] as? Int != 5126 else { throw Failure.malformed("Triangle indices") }
        let geometry = SCNGeometry(sources: sources, elements: [SCNGeometryElement(data: indices, primitiveType: .triangles, primitiveCount: count / 3, bytesPerIndex: width)])
        if let m = primitive["material"] as? Int, materials.indices.contains(m) { geometry.materials = [materials[m]] }
        return geometry
    }

    private func texture(_ info: Any?) throws -> NSImage? {
        guard let info = info as? [String: Any], let i = info["index"] as? Int else { return nil }
        let textures = document["textures"] as? [[String: Any]] ?? [], descriptions = document["images"] as? [[String: Any]] ?? []
        guard textures.indices.contains(i), let source = textures[i]["source"] as? Int, descriptions.indices.contains(source) else { throw Failure.malformed("Texture") }
        if let image = images[source] { return image }
        guard let view = descriptions[source]["bufferView"] as? Int, let image = NSImage(data: try slice(view)) else { throw Failure.malformed("Embedded image") }
        images[source] = image
        return image
    }

    private func material(_ description: [String: Any], console: Console) throws -> SCNMaterial {
        let m = SCNMaterial(), pbr = description["pbrMetallicRoughness"] as? [String: Any] ?? [:]
        m.name = description["name"] as? String
        m.lightingModel = .physicallyBased
        let rgba = (pbr["baseColorFactor"] as? [Double] ?? [1, 1, 1, 1]).map { CGFloat($0) }
        m.diffuse.contents = try texture(pbr["baseColorTexture"]) ?? linear(rgba)
        m.metalness.contents = pbr["metallicFactor"] as? Double ?? 1
        m.roughness.contents = pbr["roughnessFactor"] as? Double ?? 1
        if let map = try texture(pbr["metallicRoughnessTexture"]) {
            m.metalness.contents = map; m.metalness.textureComponents = .blue
            m.roughness.contents = map; m.roughness.textureComponents = .green
            m.metalness.intensity = CGFloat(pbr["metallicFactor"] as? Double ?? 1)
            m.roughness.intensity = CGFloat(pbr["roughnessFactor"] as? Double ?? 1)
        }
        // The credited Xbox mesh uses glTF's older specular/glossiness workflow.
        if let spec = (description["extensions"] as? [String:Any])?["KHR_materials_pbrSpecularGlossiness"] as? [String:Any] {
            m.lightingModel = .blinn
            m.diffuse.contents = try texture(spec["diffuseTexture"]) ?? linear((spec["diffuseFactor"] as? [Double] ?? [1,1,1,1]).map { CGFloat($0) })
            m.specular.contents = linear((spec["specularFactor"] as? [Double] ?? [0.2,0.2,0.2]).map { CGFloat($0) } + [CGFloat(1)])
            m.shininess = CGFloat(spec["glossinessFactor"] as? Double ?? 0.5)
        }
        m.normal.contents = try texture(description["normalTexture"])
        m.normal.intensity = CGFloat((description["normalTexture"] as? [String: Any])?["scale"] as? Double ?? 1)
        m.ambientOcclusion.contents = try texture(description["occlusionTexture"])
        m.ambientOcclusion.textureComponents = .red
        if let emission = description["emissiveFactor"] as? [Double], emission.count == 3 {
            m.emission.contents = linear(emission.map { CGFloat($0) } + [CGFloat(1)])
        }
        if let map = try texture(description["emissiveTexture"]) { m.emission.contents = map }
        m.isDoubleSided = description["doubleSided"] as? Bool ?? false
        if description["alphaMode"] as? String == "BLEND" { m.transparency = rgba.count == 4 ? rgba[3] : 1; m.writesToDepthBuffer = false }
        // Existing authored LEDs become the light sources; no floating fake strips.
        if console == .ps5 && m.name == "Light" {
            m.emission.contents = NSColor(srgbRed: 0.03, green: 0.42, blue: 1, alpha: 1)
            m.shaderModifiers = [.surface: "_surface.emission.rgb *= 12.0;"]
            m.diffuse.contents = NSColor(srgbRed: 0.06, green: 0.30, blue: 1, alpha: 1)
        }
        if console == .ps4 && m.name == "wire_028089177" { m.emission.contents = NSColor.systemBlue; m.shaderModifiers = [.surface: "_surface.emission.rgb *= 3.0;"] }
        if console == .xbox {
            if m.name == "Material.002" {
                m.diffuse.contents = NSColor(white: 0.8, alpha: 1)
                m.emission.contents = NSColor.white
                m.shaderModifiers = [.surface: "_surface.emission.rgb *= 3.0;"]
            } else {
                // The green vent backing is painted plastic, not an LED.
                m.emission.contents = NSColor.black
            }
        }
        if console == .switch2 && m.name == "led" {
            m.emission.contents = NSColor(srgbRed: 0.30, green: 1, blue: 0.08, alpha: 1)
            m.shaderModifiers = [.surface: "_surface.emission.rgb *= 3.0;"]
        }
        return m
    }

    private func linear(_ components: [CGFloat]) -> NSColor {
        NSColor(cgColor: CGColor(colorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!, components: components)!)!
    }
}
