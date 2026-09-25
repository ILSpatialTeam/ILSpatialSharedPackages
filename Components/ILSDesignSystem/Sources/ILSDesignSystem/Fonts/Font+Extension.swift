//
//  Font+Extension.swift
//  ILSFoundation
//
//  Created by Guest 2026 on 06/08/26.
//

import SwiftUI

public extension Font {
    static func custom(_ font: AppFont, size: CGFloat) -> Font {
        AppFontRegistrar.registerAll() // no-op after first call, safe to leave here
        return .custom(font.rawValue, size: size)
    }
}
