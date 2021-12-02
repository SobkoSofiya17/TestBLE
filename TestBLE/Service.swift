//
//  Service.swift
//  TestBLE
//
//  Created by Тест on 29.11.2021.
//

import SwiftUI
//
//  BluetoothSerial.swift (originally DZBluetoothSerialHandler.swift)
//  HM10 Serial
//
//  Created by Alex on 09-08-15.
//  Copyright (c) 2017 Hangar42. All rights reserved.
//
//

import CoreBluetooth

enum serialCommand: UInt8 {
    case ping = 1, current = 2, write = 3, render = 4, list = 5, set = 6, get = 7, version = 8, upgrade = 9, clear = 11, authorise = 12
}

// Delegate functions
protocol BluetoothSerialDelegate {
    // ** Required **
    
    // Called when de state of the CBCentralManager changes (e.g. when bluetooth is turned on/off)
    func serialDidChangeState()
    
    // Called when a peripheral disconnected
    func serialDidDisconnect(_ peripheral: CBPeripheral, error: NSError?)
    
    // ** Optionals **
    
    // Called when a message is received
    func serialDidReceiveString(_ message: String)
    
    // Called when a message is received
    func serialDidReceiveBytes(_ bytes: [UInt8])
    
    // Called when a message is received
    func serialDidReceiveData(_ data: Data)
    
    // Called when the RSSI of the connected peripheral is read
    func serialDidReadRSSI(_ rssi: NSNumber)
    
    // Called when a new peripheral is discovered while scanning. Also gives the RSSI (signal strength)
    mutating func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?)
    
    // Called when a peripheral is connected (but not yet ready for cummunication)
    func serialDidConnect(_ peripheral: CBPeripheral)
    
    // Called when a pending connection failed
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?)

    // Called when a peripheral is ready for communication
    func serialIsReady(_ peripheral: CBPeripheral)
    
    // Called when a peripheral write complete
    func serialDidWriteValueForCharacteristic(characteristic: CBCharacteristic, error: Error?)
}

// Make some of the delegate functions optional
extension BluetoothSerialDelegate {
    func serialDidReceiveString(_ message: String) {}
    func serialDidReceiveBytes(_ bytes: [UInt8]) {}
    func serialDidReceiveData(_ data: Data) {}
    func serialDidReadRSSI(_ rssi: NSNumber) {}
    mutating func serialDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {}
    func serialDidConnect(_ peripheral: CBPeripheral) {}
    func serialDidFailToConnect(_ peripheral: CBPeripheral, error: NSError?) {}
    func serialIsReady(_ peripheral: CBPeripheral) {}
    func serialDidWriteValueForCharacteristic(characteristic: CBCharacteristic, error: Error?) {}
}


final class BluetoothSerial: NSObject {

    struct Device: Identifiable {
        let id: Int
        let RSSI: NSNumber?
        let peripheral: CBPeripheral
    }

    static let shared = BluetoothSerial()

    // The delegate object the BluetoothDelegate methods will be called upon
    var delegate: BluetoothSerialDelegate!
    
    // The CBCentralManager this bluetooth serial handler uses for... well, everything really
    var centralManager: CBCentralManager!
    
    // The peripheral we're trying to connect to (nil if none)
    var pendingPeripheral: CBPeripheral?
    
    // The connected peripheral (nil if none is connected)
    var connectedPeripheral: CBPeripheral?

    // The characteristic 0xFFE1 we need to write to, of the connectedPeripheral
    weak var writeCharacteristic: CBCharacteristic?
    
    // Whether this serial is ready to send and receive data
    var isReady: Bool {
        get {
            return centralManager.state == .poweredOn &&
                   connectedPeripheral != nil &&
                   writeCharacteristic != nil
        }
    }
    
    var isAuthorising: Bool = false
    
    // Whether this serial is looking for advertising peripherals
    var isScanning: Bool {
        return centralManager.isScanning
    }
    
    // Whether the state of the centralManager is .poweredOn
    var isPoweredOn: Bool {
        return centralManager.state == .poweredOn
    }
    
    // UUID of the service to look for.
    var serviceUUID = CBUUID(string: "27404DB3-B1F6-BA3F-D43B-10A4D91A4F11")
    var serviceUUIDstr = "27404DB3-B1F6-BA3F-D43B-10A4D91A4F11"

    // UUID of the characteristic to look for.
    var characteristicUUID = CBUUID(string: "27404DB3-B1F6-BA3F-D43B-10A4D91A4F11")
    
    // Whether to write to the HM10 with or without response. Set automatically.
    // Legit HM10 modules (from JNHuaMao) require 'Write without Response',
    // while fake modules (e.g. from Bolutek) require 'Write with Response'.
    private var writeType: CBCharacteristicWriteType = .withoutResponse
    private var writeTypeWithResponce: CBCharacteristicWriteType = .withResponse

    

    // MARK: functions
    
    // Always use this to initialize an instance
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .none)
        centralManager?.delegate = self
    }
    
    // Start scanning for peripherals
    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        
        // Always wipe auth flag assume that it will set after this method due auth process
        isAuthorising = false
        
        let uuid = UUID(uuidString: serviceUUIDstr)
      
        // retrieve peripherals that are known
        let peripherals2  = centralManager.retrievePeripherals(withIdentifiers: [uuid!])
        for peripheral in peripherals2 {
            delegate.serialDidDiscoverPeripheral(peripheral, RSSI: nil)
        }
        // retrieve peripherals that are already connected
        // see this stackoverflow question http://stackoverflow.com/questions/13286487
        let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID])
        for peripheral in peripherals {
            delegate.serialDidDiscoverPeripheral(peripheral, RSSI: nil)
        }
        
        if connectedPeripheral == nil {
            
            NSLog("Starting scan")
            // start scanning for peripherals with correct service UUID
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    // Stop scanning for peripherals
    func stopScan() {
       
        NSLog("Stopping scan")
        centralManager.stopScan()
    }
    
    // Try to connect to the given peripheral
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        pendingPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    // Disconnect from the connected peripheral or stop connecting to it
    func disconnect() {
        NSLog("Disconnect")
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        } else if let p = pendingPeripheral {
            centralManager.cancelPeripheralConnection(p) //TODO: Test whether its neccesary to set p to nil
        }
    }
    
    // The didReadRSSI delegate function will be called after calling this function
    func readRSSI() {
        guard isReady else { return }
        connectedPeripheral!.readRSSI()
    }
    
    // Send a string to the device
    func sendMessageToDevice(_ message: String) {
        guard isReady else { return }
        
        if let data = message.data(using: String.Encoding.utf8) {
            connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeType)
        }
    }
    
    // Send an array of bytes to the device
    func sendBytesToDevice(_ bytes: [UInt8]) {
        guard isReady else { return }
        
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeType)
    }
    
    // Send data to the device
    func sendDataToDevice(_ data: Data) {
        guard isReady else { return }
        
        connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeType)
    }
    
    // Send an array of bytes to the device with responce
    func sendBytesToDeviceWithResponce(_ bytes: [UInt8]) {
        guard isReady else { return }
        
        let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: writeTypeWithResponce)
    }
}

extension BluetoothSerial: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // just send it to the delegate
        delegate.serialDidWriteValueForCharacteristic(characteristic: characteristic, error: error)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // discover the 0xFFE1 characteristic for all services (though there should only be one)
        guard let name = peripheral.name else {
            return;
        }
        if (name.count > 0) {
            for service in peripheral.services! {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // check whether the characteristic we're looking for (0xFFE1) is present - just to be sure
        for characteristic in service.characteristics! {
            if characteristic.uuid == characteristicUUID {
                // subscribe to this value (so we'll get notified when there is serial data for us..)
                peripheral.setNotifyValue(true, for: characteristic)
                
                // keep a reference to this characteristic so we can write to it
                writeCharacteristic = characteristic
                
                // find out writeType
                writeType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
                
                // notify the delegate we're ready for communication
                delegate.serialIsReady(peripheral)
            }else{
                print("WRIIIIITEEE2")
            }
        }
        print("count:\(service.characteristics)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // notify the delegate in different ways
        // if you don't use one of these, just comment it (for optimum efficiency :])
        let data = characteristic.value
        guard data != nil else { return }
        
        // first the data
        delegate.serialDidReceiveData(data!)
        
        // then the string
        if let str = String(data: data!, encoding: String.Encoding.utf8) {
            delegate.serialDidReceiveString(str)
        } else {
            //print("Received an invalid string!") uncomment for debugging
        }
        
        // now the bytes array
        var bytes = [UInt8](repeating: 0, count: data!.count / MemoryLayout<UInt8>.size)
        (data! as NSData).getBytes(&bytes, length: data!.count)
        delegate.serialDidReceiveBytes(bytes)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        delegate.serialDidReadRSSI(RSSI)
    }
}

extension BluetoothSerial: CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let _ = peripheral.name else { return }
        // just send it to the delegate
        delegate.serialDidDiscoverPeripheral(peripheral, RSSI: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // set some stuff right
        peripheral.delegate = self
        pendingPeripheral = nil
        connectedPeripheral = peripheral
        
        // send it to the delegate
        delegate.serialDidConnect(peripheral)

        // Okay, the peripheral is connected but we're not ready yet!
        // First get the 0xFFE0 service
        // Then get the 0xFFE1 characteristic of this service
        // Subscribe to it & create a weak reference to it (for writing later on),
        // and find out the writeType by looking at characteristic.properties.
        // Only then we're ready for communication

        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        pendingPeripheral = nil

        // send it to the delegate
        delegate.serialDidDisconnect(peripheral, error: error as NSError?)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        pendingPeripheral = nil

        // just send it to the delegate
        delegate.serialDidFailToConnect(peripheral, error: error as NSError?)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // note that "didDisconnectPeripheral" won't be called if BLE is turned off while connected
        connectedPeripheral = nil
        pendingPeripheral = nil

        // send it to the delegate
        delegate.serialDidChangeState()
    }
}
