//
//  ContentView.swift
//  TestBLE
//
//  Created by Тест on 29.11.2021.
//

import SwiftUI
import CoreBluetooth

let scanTimeout = TimeInterval(10)

struct ConnectView: View {
    var bluetooth: BluetoothSerial
    
    @Binding var list: [BluetoothSerial.Device]
    @Binding var isConnected: Bool
    @Binding var isConnecting: Bool
    
    var body: some View {
        VStack {
            Text("Press following button to connect to Ambient!")
                .padding().font(.largeTitle)
            if isConnected {
                Text("Connected")
                    .padding().font(.largeTitle)
            } else {
                Button("Connect") {
                    scanStart()
                }.padding(.bottom).disabled(isConnecting)
                
                ProgressView().progressViewStyle(LinearProgressViewStyle())
                    .frame( maxWidth: 100).opacity(isConnecting ? 1 : 0)
            }
            
        }
    }
    
    func scanStart() {
        isConnecting = true
        bluetooth.startScan()
        
        Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { timer in
            isConnecting = false
            scanStop()
        }
    }
    
    func scanStop() {
        isConnecting = false
        bluetooth.stopScan()
    }

}


struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
        
    }

    struct PreviewWrapper: View {
        @State var list = [BluetoothSerial.Device]()
          
        var body: some View {
          ConnectView(bluetooth: BluetoothSerial(), list: $list, isConnected: .constant(false), isConnecting: .constant(false))
        }
    }
}

