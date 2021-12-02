//
//  CurrentView.swift
//  TestBLE
//
//  Created by Тест on 29.11.2021.
//

import SwiftUI
import CoreBluetooth

let colorsMax = 32

struct CurrentView: View {
    var bluetooth: BluetoothSerial

    @State var colorRecords: [ColorRecord] = []
    @State var lastRenderedColor: Color?
    @State var currentColor: Color?
    
    @State var changesPenidng = false

    @State var serialRecieveBuffer: [UInt8] = []
    @State var serialWaitAnswer = false
    
    var body: some View {
        VStack {
            Text("Colors \(colorRecords.count) of \(colorsMax)")
            List {
                ForEach(colorRecords.indices, id: \.self) { idx in
                    ColorView(colorRecord: $colorRecords[idx].onChange(colorChanged))
                }.onDelete(perform: colorRecordDelete)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(action: {
                    saveColors()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Remember preset")
                    }
                }.disabled(!changesPenidng)
                Button(action: colorRecordAdd) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                        Text("Add color")
                    }
                }
            }
            Spacer()
        }
        
        .padding(.leading, -20)
        .padding(.trailing, -20)

        .onAppear{
            bluetooth.delegate = self
            serialSendPing()
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                renderColorByTimer()
            }
        }
    }
    
    func saveColors() {
        for (idx, record) in colorRecords.enumerated() {
            if record.changed {
                print("Saving color \(idx)")
                colorRecords[idx].changed = false
                serialSendSet(colorId: idx, color: record.color)
            }
        }
        serialSendWrite()
    }
    
    func renderColorByTimer() {
        if lastRenderedColor != currentColor {
            lastRenderedColor = currentColor
            
            renderColor(color: currentColor!)
        }
    }
    
    func colorChanged(to colorRecord: ColorRecord) {
        var colorId: Int?
        if colorRecord.current {
            for (idx, record) in colorRecords.enumerated() {
                if record.id == colorRecord.id {
                    colorId = idx
                    continue
                }
                colorRecords[idx].current = false
            }
            print("Record \(colorRecord.color) set as current")
            serialSendRender(n: colorId!)
        }
        if colorId == nil {
            for (idx, record) in colorRecords.enumerated() {
                if record.id == colorRecord.id {
                    colorId = idx
                    break
                }
            }
        }
        if colorId != nil {
            colorRecords[colorId!].changed = true
        }
        currentColor = colorRecord.color
        changesPenidng = true
    }
    
    func renderColor(color: Color) {
        print("Render color \(color)")
        let (r, g, b, w) = colorGetRGBW(color: color)
        serialSendRender(red: r, green: g, blue: b, white: w)
    }
    
    func colorRecordDelete(at offsets: IndexSet) {
        colorRecords.remove(atOffsets: offsets)
        changesPenidng = true
    }
    
    func colorRecordAdd() {
        if colorRecords.count < colorsMax {
            let new = ColorRecord(color: getRandomColor())
            colorRecords.append(new)
            colorChanged(to: colorRecords.last!)
            changesPenidng = true
        }
    }
}

extension CurrentView: BluetoothSerialDelegate {
    func serialDidChangeState() {
        
    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        
    }
    
    func serialSendSet(colorId: Int) {
        if colorRecords.indices.contains(colorId) {
            serialSendSet(colorId: colorId, color: colorRecords[colorId].color)
        } else {
            NSLog("Color # out of range")

        }
    }
    
    func serialSendSet(colorId: Int, color: Color) {
        let (r, g, b, w) = colorGetRGBW(color: color)
        serialSendSet(n: colorId, red: r, green: g, blue: b, white: w)
    }
    
    func serialSendSet(n: Int, red: Int, green: Int, blue: Int, white: Int) {
        let msg = "{\"id\": \"223456\", \"type\":\"SECE\""
        
        if (bluetooth.isReady) {
        bluetooth.isReady
            serialWaitAnswer = true
        bluetooth.sendMessageToDevice(msg)
        
            NSLog("Command 'set' sent")
        } else {
            NSLog("Serial is not ready")
        }
    }

    func serialDidReceiveBytes(_ bytes: [UInt8]) {
        serialRecieveBuffer.append(contentsOf: bytes)
        if serialRecieveBuffer.count > 3 {
            // minimum command packet size is command + status + [data]? + 2 byte ending sequence
            if bytes.first == 13 && bytes.last == 10 {
                // last 2 bytes is "\r\n" - lets parse answer
                
                serialWaitAnswer = false
                
                // ping --> serialSendList
                // list --> serialSendCurrent
                
                if let command = serialCommand(rawValue: serialRecieveBuffer[0]) {
                    let commandDidSucceed = Bool(serialRecieveBuffer[1] == 1)
                    
                    serialRecieveBuffer.removeFirst(2)   // delete command and status bytes
                    serialRecieveBuffer.removeLast()        // delete trailing byte
                    
                    switch (command) {
                    case serialCommand.ping:
                        if commandDidSucceed {
                            NSLog("Ping OK")
                            serialSendList()
                        } else {
                            NSLog("Ping Failed")
                        }
                    case serialCommand.current:
                        if commandDidSucceed {
                            NSLog("Current OK")
                            var currentColorId = 0
                            if (serialRecieveBuffer.count > 0) {
                                currentColorId = Int(serialRecieveBuffer[0])
                            }
                            for (idx, _) in colorRecords.enumerated() {
                                if idx == currentColorId {
                                    colorRecords[idx].current = true
                                    continue
                                }
                                colorRecords[idx].current = false
                            }
                        } else {
                            NSLog("Current Failed")
                        }
                    case serialCommand.list:
                        if commandDidSucceed {
                            NSLog("List OK")
                            colorRecords.removeAll()
                            for buffer in serialRecieveBuffer.chunks(4) {
                                if buffer.count == 4 {
                                    if colorRecords.count > 0 && buffer[0] == 0 && buffer[1]  == 0 && buffer[2] == 0 && buffer[3] == 0 {
                                        // if its not first zero color (blank/off)
                                        break
                                    }
                                    print("Got buffer \(buffer)")
                                    let record = ColorRecord(color: Color.init(red: buffer[0], green: buffer[1], blue: buffer[2]))
                                    colorRecords.append(record)
                                    print("Got color \(record.color.rgba)")
                                }
                            }
                            serialSendCurrent()
                        } else {
                            NSLog("List Failed")
                        }
                    case serialCommand.render:
                        if commandDidSucceed {
                            NSLog("Render OK")
                        } else {
                            NSLog("Render Failed")
                        }
                    case serialCommand.set:
                        if commandDidSucceed {
                            NSLog("Set OK")
                        } else {
                            NSLog("Set Failed")
                        }
                    case serialCommand.write:
                        if commandDidSucceed {
                            changesPenidng = false
                            NSLog("Write OK")
                        } else {
                            NSLog("Write Failed")
                        }
                    default:
                        NSLog("Got unsupported command")
                    }
                }
                
                // finally clean command buffer
                serialRecieveBuffer.removeAll()
            }
        }
    }
    
    func serialSendRender(n: Int) {
        let msg = "{\"id\": \"223456\", \"type\":\"SECE\""
        
        if (bluetooth.isReady) {
            bluetooth.sendMessageToDevice(msg)
            NSLog("Command 'render' sent")
        } else {
            NSLog("Serial is not ready")
        }
    }
    
    func serialSendRender(red: Int, green: Int, blue: Int, white: Int) {
        let msg = "{\"id\": \"223456\", \"type\":\"SECE\""

        if (bluetooth.isReady) {
            bluetooth.sendMessageToDevice(msg)
            NSLog("Command 'render' sent")
        } else {
            NSLog("Serial is not ready")
        }
    }
    
    func serialSendCommand(cmd: String) {
        serialRecieveBuffer.removeAll();
        let msg = "{\"id\": \"223456\", \"type\":\"SECE\""
        
        if (bluetooth.isReady) {
            bluetooth.sendMessageToDevice(msg)
            NSLog("Command '\(cmd)' sent")
        } else {
            NSLog("Serial is not ready while: \(msg)")
        }
    }
    
    func serialSendPing() {
        serialSendCommand(cmd: "ping")
    }
    
    func serialSendCurrent() {
        serialSendCommand(cmd: "current")
    }
    
    func serialSendList() {
        serialSendCommand(cmd: "list")
    }
    
    func serialSendWrite() {
        serialSendCommand(cmd: "write")
    }
}

struct CurrentView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }

    struct PreviewWrapper: View {
        let colorRecords: [ColorRecord] = [
            ColorRecord(color: Color.red),
            ColorRecord(color: Color.blue),
            ColorRecord(color: Color.green)
        ]
          
        var body: some View {
            CurrentView(bluetooth: BluetoothSerial(), colorRecords: colorRecords)
        }
    }
}
