import Foundation
import ILSFoundation

/// Repository implementation — delegates to data source
class DrawingSettingsRepositoryImpl: DrawingSettingsRepository {
    private let dataSource: DrawingSettingsDataSource

    init(dataSource: DrawingSettingsDataSource) {
        self.dataSource = dataSource
    }

    func getSelectedColor() -> ILSColor { dataSource.getSelectedColor() }
    func setSelectedColor(_ value: ILSColor) { dataSource.setSelectedColor(value) }

    func getStrokeWidth() -> Float { dataSource.getStrokeWidth() }
    func setStrokeWidth(_ value: Float) { dataSource.setStrokeWidth(value) }
}
