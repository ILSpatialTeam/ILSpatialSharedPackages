//
//  FontsRegister.swift
//  ILSFoundation
//
//  Created by Guest 2026 on 06/08/26.
//

import SwiftUI

public enum AppFont: String {
    case b612Bold = "B612Mono-Bold"
    case b612BoldItalic = "B612Mono-BoldItalic"
    case b612Italic = "B612Mono-Italic"
    case b612Regular = "B612Mono-Regular"
    case digitalNumbersRegular = "DigitalNumbers-Regular"

    var fileExtension: String { "ttf" } // or "ttf", adjust per family
}

public enum AppFontRegistrar {
    private static var registeredFonts: Set<String> = []

    public static func registerAll() {
        for font in [
            AppFont.b612Regular,
            .b612Italic,
            .b612Bold,
            .b612Bold,
            .digitalNumbersRegular ] {
            register(font)
        }
    }

    private static func register(_ font: AppFont) {
        guard !registeredFonts.contains(font.rawValue) else { return }

        guard let url = Bundle.module.url(
            forResource: font.rawValue,
            withExtension: font.fileExtension
        ) else {
            assertionFailure("Font file \(font.rawValue).\(font.fileExtension) not found in module bundle")
            return
        }

        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)

        if success {
            registeredFonts.insert(font.rawValue)
        } else if let error = error?.takeRetainedValue() {
            print("Failed to register font \(font.rawValue): \(error)")
        }
    }
}
