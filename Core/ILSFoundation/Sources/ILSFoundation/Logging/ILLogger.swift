import Foundation
import os

public enum ILSubsystem: String {
    case engine = "com.ilspatial.engine"
    case handTracking = "com.ilspatial.handtracking"
    case headTracking = "com.ilspatial.headtracking"
    case gestures = "com.ilspatial.gestures"
    case spawning = "com.ilspatial.spawning"
    case spatialAudio = "com.ilspatial.spatialaudio"
    case app = "com.ilspatial.app"
}

public struct ILLogger {
    private let logger: Logger
    
    public init(subsystem: ILSubsystem, category: String) {
        self.logger = Logger(subsystem: subsystem.rawValue, category: category)
    }
    
    public func debug(_ message: String) {
        logger.debug("🟣 [DEBUG] \(message)")
    }
    
    public func info(_ message: String) {
        logger.info("🟢 [INFO] \(message)")
    }
    
    public func warning(_ message: String) {
        logger.warning("🟡 [WARNING] \(message)")
    }
    
    public func error(_ message: String) {
        logger.error("🔴 [ERROR] \(message)")
    }
}
