import Foundation
import ILSFoundation

/// Protocol for the raw data source
protocol DrawingSettingsDataSource {
    func getSelectedColor() -> ILSColor
    func setSelectedColor(_ value: ILSColor)

    func getStrokeWidth() -> Float
    func setStrokeWidth(_ value: Float)
}

/// Concrete implementation backed by UserDefaults.
/// Stores ILSColor as 4 discrete float keys — no string encoding, no enum dependency.
class DrawingSettingsDataSourceImpl: DrawingSettingsDataSource {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let colorR = "drawing_color_r"
        static let colorG = "drawing_color_g"
        static let colorB = "drawing_color_b"
        static let colorA = "drawing_color_a"
        static let strokeWidth = "drawing_strokeWidth"
    }
    
    // In-memory cache
    private var cachedColor: ILSColor?
    private var cachedStrokeWidth: Float?
    
    private var colorSaveTask: Task<Void, Never>?
    private var widthSaveTask: Task<Void, Never>?

    func getSelectedColor() -> ILSColor {
        if let cached = cachedColor { return cached }
        
        guard defaults.object(forKey: Keys.colorR) != nil else { return .white }
        let color = ILSColor(
            r: defaults.float(forKey: Keys.colorR),
            g: defaults.float(forKey: Keys.colorG),
            b: defaults.float(forKey: Keys.colorB),
            a: defaults.float(forKey: Keys.colorA)
        )
        cachedColor = color
        return color
    }

    func setSelectedColor(_ value: ILSColor) {
        cachedColor = value
        
        colorSaveTask?.cancel()
        colorSaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            
            self.defaults.set(value.r, forKey: Keys.colorR)
            self.defaults.set(value.g, forKey: Keys.colorG)
            self.defaults.set(value.b, forKey: Keys.colorB)
            self.defaults.set(value.a, forKey: Keys.colorA)
        }
    }

    func getStrokeWidth() -> Float {
        if let cached = cachedStrokeWidth { return cached }
        
        let val = defaults.float(forKey: Keys.strokeWidth)
        let width = val == 0.0 ? 0.005 : val
        cachedStrokeWidth = width
        return width
    }

    func setStrokeWidth(_ value: Float) {
        cachedStrokeWidth = value
        
        widthSaveTask?.cancel()
        widthSaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            
            self.defaults.set(value, forKey: Keys.strokeWidth)
        }
    }
}
