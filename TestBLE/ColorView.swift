//
//  ColorView.swift
//  TestBLE
//
//  Created by Тест on 29.11.2021.
//


import SwiftUI

struct ColorRecord: Identifiable {
    var id: String = UUID().uuidString
    var color: Color
    var current: Bool = false
    var changed: Bool = false
}

struct ColorView: View {
    @Binding var colorRecord: ColorRecord
    
    var body: some View {
        GeometryReader { gp in
            Rectangle()
                .fill(colorRecord.color)
                .overlay(Toggle("", isOn: $colorRecord.current).labelsHidden().padding(.leading, 20), alignment: .leading)
                .onTapGesture {
                    colorRecord.current = true
                }.overlay(ColorPicker("", selection: $colorRecord.color).labelsHidden())
        }.frame(minHeight: 50)
    }
}

func getRandomColor() -> Color {
    let red:Double = Double.random(min: 0.0, max: 1.0)
    let green:Double = Double.random(min: 0.0, max: 1.0)
    let blue:Double = Double.random(min: 0.0, max: 1.0)
   
    return Color(Color.RGBColorSpace.displayP3, red: Double(red), green: green, blue: blue, opacity: 1.0)
}

func saturation(r: Int, g: Int, b: Int) -> Int {
    // Find the smallest of all three parameters.
    let low = min(r, min(g, b));
    // Find the highest of all three parameters.
    let high = max(r, max(g, b));
    // The difference between the last two variables
    // divided by the highest is the saturation.
    return Int(100 * ((high - low) / high));
}

func getWhite(r: Int, g: Int, b: Int) -> Int {
    return (255 - saturation(r: r ,g: g ,b: b)) / 255 * (r + g + b) / 3;
}

func colorGetRGBW(color: Color) -> (Int, Int, Int, Int) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
    (red: r, green: g, blue: b, alpha: _) = color.rgba
    
    var saturation: CGFloat = 0
    (hue: _, saturation: saturation, value: _, alpha: _) = color.hsva
    
    var redInt = Int(r * 255.0), grnInt = Int(g * 255.0), bluInt = Int(b * 255.0), saturationInt = Int(saturation * 255.0)
    
    if redInt < 0 {redInt = 0}
    if grnInt < 0 {grnInt = 0}
    if bluInt < 0 {bluInt = 0}
    if saturationInt < 0 { saturationInt = 0 }
    
    if redInt > 255 {redInt = 255}
    if grnInt > 255 {grnInt = 255}
    if bluInt > 255 {bluInt = 255}
    if saturationInt > 255 { saturationInt = 255 }
    
    saturationInt = 255 - saturationInt
    
    return (redInt, grnInt, bluInt, saturationInt)
}

struct ColorView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }

    struct PreviewWrapper: View {
        @State var colorRecord: ColorRecord = ColorRecord(color: Color.red)
          
        var body: some View {
            ColorView(colorRecord: $colorRecord)
        }
    }
}
