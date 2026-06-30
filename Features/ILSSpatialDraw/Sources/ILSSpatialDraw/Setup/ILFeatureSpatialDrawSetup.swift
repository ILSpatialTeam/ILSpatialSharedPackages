import RealityKit
import ILSFoundation

public struct ILFeatureSpatialDrawSetup {
    @MainActor
    public static func createDrawingSettingsUseCase() -> DrawingSettingsUseCase {
        let dataSource = DrawingSettingsDataSourceImpl()
        let repository = DrawingSettingsRepositoryImpl(dataSource: dataSource)
        return DrawingSettingsUseCaseImpl(repository: repository)
    }

    public static func registerSystems() {
        IsDrawingComponent.registerComponent()
        DrawingComponent.registerComponent()
        CanvasComponent.registerComponent()
        SharePlayReceiverComponent.registerComponent()
        PinkyGestureSystem.registerSystem()
        DrawingSystem.registerSystem()
    }
}
