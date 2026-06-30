import Foundation
import ILSFoundation

/// Domain-level use case protocol — speaks only in primitives
public protocol DrawingSettingsUseCase {
    func getSelectedColor() -> ILSColor
    func setSelectedColor(_ value: ILSColor)

    func getStrokeWidth() -> Float
    func setStrokeWidth(_ value: Float)
}

/// Concrete use case — delegates to the repository
class DrawingSettingsUseCaseImpl: DrawingSettingsUseCase {
    private let repository: DrawingSettingsRepository

    init(repository: DrawingSettingsRepository) {
        self.repository = repository
    }

    func getSelectedColor() -> ILSColor { repository.getSelectedColor() }
    func setSelectedColor(_ value: ILSColor) { repository.setSelectedColor(value) }

    func getStrokeWidth() -> Float { repository.getStrokeWidth() }
    func setStrokeWidth(_ value: Float) { repository.setStrokeWidth(value) }
}
