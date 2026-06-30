import Foundation
import ILSFoundation

/// Domain-level protocol for persisting drawing preferences
protocol DrawingSettingsRepository {
    func getSelectedColor() -> ILSColor
    func setSelectedColor(_ value: ILSColor)

    func getStrokeWidth() -> Float
    func setStrokeWidth(_ value: Float)
}
