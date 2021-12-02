//
//  extantions.swift
//  TestBLE
//
//  Created by Тест on 29.11.2021.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    #if canImport(UIKit)
    var asNative: UIColor { UIColor(self) }
    #elseif canImport(AppKit)
    var asNative: NSColor { NSColor(self) }
    #endif

    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        #if canImport(UIKit)
        let color = UIColor(self)
        #elseif canImport(AppKit)
        let color = asNative.usingColorSpace(.deviceRGB)!
        #endif
        var t = (CGFloat(), CGFloat(), CGFloat(), CGFloat())
        color.getRed(&t.0, green: &t.1, blue: &t.2, alpha: &t.3)
        return t
    }

    var hsva: (hue: CGFloat, saturation: CGFloat, value: CGFloat, alpha: CGFloat) {
        #if canImport(UIKit)
        let color = UIColor(self)
        #elseif canImport(AppKit)
        let color = asNative.usingColorSpace(.deviceRGB)!
        #endif
        var t = (CGFloat(), CGFloat(), CGFloat(), CGFloat())
        color.getHue(&t.0, saturation: &t.1, brightness: &t.2, alpha: &t.3)
        return t
    }
}

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

extension Double {

    /// Returns a random floating point number between 0.0 and 1.0, inclusive.
    static var random: Double {
        return Double(arc4random()) / 0xFFFFFFFF
    }

    /// Random double between 0 and n-1.
    ///
    /// - Parameter n:  Interval max
    /// - Returns:      Returns a random double point number between 0 and n max
    static func random(min: Double, max: Double) -> Double {
        return Double.random * (max - min) + min
    }
}

extension Array {
    func chunks(_ chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}

extension Color {
    
    init(red: UInt8, green: UInt8, blue: UInt8) {
        let redPart: CGFloat = CGFloat(red) / 255
        let greenPart: CGFloat = CGFloat(green) / 255
        let bluePart: CGFloat = CGFloat(blue) / 255
        
        self.init(red: Double(redPart), green: Double(greenPart), blue: Double(bluePart))
    }
}
