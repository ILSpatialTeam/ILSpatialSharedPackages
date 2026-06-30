import RealityKit

public protocol SpatialAudioServiceProtocol {
    func playSound(named name: String, on entity: Entity) async throws
    func preloadSound(named name: String) async throws
    func playPreloadedSound(named name: String, on entity: Entity)
}

public final class SpatialAudioService: SpatialAudioServiceProtocol {
    
    private var preloadedResources: [String: AudioFileResource] = [:]
    
    public init() {}
    
    public func preloadSound(named name: String) async throws {
        if preloadedResources[name] != nil { return }
        let resource = try await AudioFileResource(named: name)
        preloadedResources[name] = resource
    }
    
    public func playPreloadedSound(named name: String, on entity: Entity) {
        guard let resource = preloadedResources[name] else { return }
        let audioController = entity.prepareAudio(resource)
        audioController.play()
    }
    
    public func playSound(named name: String, on entity: Entity) async throws {
        let resource = try await AudioFileResource(named: name)
        let audioController = entity.prepareAudio(resource)
        audioController.play()
    }
}
