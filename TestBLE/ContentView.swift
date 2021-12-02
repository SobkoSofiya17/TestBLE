//
//  ContentView.swift
//  TestBLE
//
//  Created by Тест on 29.11.2021.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    var bluetooth = BluetoothSerial.shared
    @State var isConnected = false
    @State var isConnecting = false
    
    @State var list = [BluetoothSerial.Device]()

    var body: some View {
        NavigationView {
//            ZStack{
            List {
                NavigationLink(
                    destination: ConnectView(bluetooth: bluetooth, list: $list, isConnected: $isConnected, isConnecting: $isConnecting),
                    label: {
                        Label("Connect", systemImage: "antenna.radiowaves.left.and.right")
                    })
                NavigationLink(
                    destination: CurrentView(bluetooth: bluetooth),
                    label: {
                        Label("Current", systemImage: "paintpalette")
                    })
                NavigationLink(
                    destination: Text("TODO: Implement color sets"),
                    label: {
                        Label("Color set", systemImage: "list.star")
                    })
            }
            .navigationTitle("Ambient")
//                ConnectView(bluetooth: bluetooth, list: $list, isConnected: $isConnected, isConnecting: $isConnecting)
        }.onAppear{
            bluetooth.delegate = self
        }
    }
}


extension ContentView: BluetoothSerialDelegate {

    mutating func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
        // check whether it is a duplicate
        for exisiting in list {
            if exisiting.peripheral.identifier == peripheral.identifier { return }
        }
        NSLog("Discovered peripheral  %@", peripheral.name ?? "")
        let new = BluetoothSerial.Device(id: list.count, RSSI: RSSI, peripheral: peripheral)
        list.append(new)
        bluetooth.connectToPeripheral(peripheral)
    }
    
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?) {

    }
    
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        isConnected = false
    }
    
    func serialIsReady(_ peripheral: CBPeripheral) {
        NSLog("Connected to %@", peripheral.name ?? "")
        isConnected = true
        bluetooth.stopScan()
    }
    
    func serialDidChangeState() {
        if bluetooth.centralManager.state != .poweredOn {
            
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
