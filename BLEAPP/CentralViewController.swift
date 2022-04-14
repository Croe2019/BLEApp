//
//  CentralViewController.swift
//  BLEAPP
//
//  Created by 濱田広毅 on 2022/01/29.
//

import UIKit
import CoreBluetooth

class CentralViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var connectStateLabel: UILabel!
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var characteristic: CBCharacteristic!
    var textDataArray = [String]()
    var connectFlag = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        textDataArray = []
        connectFlag = false
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    @IBAction func sendButton(_ sender: Any) {
        
        // テキストフィールドがからならreturn
        if (textField.text == nil || connectFlag == false){
            connectStateLabel.text = "接続中または、テキストが入力されていません"
            return
        }
        
        // 文字が入力されていて、かつ接続がされている場合送信処理を行う
        if textField.text != nil && connectFlag == true{
            
            let text = textField.text!
            let data = text.data(using: .utf8)!
           // 書き込み処理をする
            peripheral.writeValue(data, for: characteristic!, type: CBCharacteristicWriteType.withResponse)
            tableView.reloadData()
            // データ更新の通知の受け取りを開始する
            self.peripheral.setNotifyValue(true, for: self.characteristic)
            tableView.reloadData()
        }
    }
    
    
    @IBAction func scanButton(_ sender: Any) {
        
        self.centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    // 不要な値を配列から削除する
    private func doMultAsyncProcess(){
        
        let dispatchGroup = DispatchGroup()
        let dispatchQueue = DispatchQueue(label: "queue")
        
        // 配列の中にある不要な要素をある分削除
        for i in 0..<textDataArray.count{
            dispatchQueue.async {
                self.textDataArray.removeFirst(i)
            }
            if connectFlag == false{
                self.textDataArray = []
            }
        }
        
        // 全ての非同期処理完了後にメインスレッドで処理
        dispatchGroup.notify(queue: .main){
            self.connectFlag = true
            return
        }
    }
}

extension CentralViewController: CBCentralManagerDelegate{
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        print("state: \(central.state)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        print("発見したBLEデバイス \(peripheral)")
        // 接続開始
        self.peripheral = peripheral
        self.centralManager.connect(self.peripheral, options: nil)
    }
    
    // ペリフェラルへの接続が成功すると呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("接続成功！")
        print("接続したデバイス: \(self.peripheral)")
        self.centralManager.stopScan()
        // サービス検索結果を受け取るためにデリゲートをセット
        connectStateLabel.text = "接続完了"
        self.peripheral.delegate = self
        // サービス検索開始
        self.peripheral.discoverServices(nil)
    }
    
    // ペリフェラルへの接続が失敗すると呼ばれる
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("接続失敗...")
    }
    
}

extension CentralViewController:UITableViewDelegate{
    
    
}

extension CentralViewController:UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return textDataArray.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel!.text = textDataArray[indexPath.row]
        return cell
    }
    
}

extension CentralViewController: CBPeripheralDelegate{
    
    // サービス発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let services: NSArray = peripheral.services as! NSArray
        print("\(services.count)個のサービスを発見! \(services)")
        
        for obj in services{
            if let service = obj as? CBService{
                // キャラクタリスティック検索開始
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    // キャラクタリスティック発見時に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        let characteristics: NSArray = service.characteristics as! NSArray
        print("\(characteristics.count)個のキャラクタリスティックを発見! \(characteristics)")
        
        for obj in characteristics{
            
            if let characteristic = obj as? CBCharacteristic{
                
                // Read専用のキャラクタリスティックに限定して読み出す
                if characteristic.properties == CBCharacteristicProperties.read{
                    peripheral.readValue(for: characteristic)
                }
                // characteristicに送信先のcharacteristicの値を入れる
                self.characteristic = characteristic
                
            }
        }
    }
    
    // ペリフェラルからデータを受け取る
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("読み出し成功！ service uuid: \(characteristic.service!.uuid),characteristic uuid: \(characteristic.uuid), value: \(characteristic.value)")
        print("データ更新! characteristic UUID: \(characteristic.uuid), value: \(characteristic.value)")
        if let error = error{
            print("キャラクタリスティックの更新に失敗....")
            return
        }
        let textData = characteristic.value
        let text = String(decoding: textData!, as: UTF8.self)
        textDataArray.append("\(text)")
        print("配列の中身:\(textDataArray.debugDescription)")
        print("テキスト:\(text)")
        // 受信した時に配列を初期化
        doMultAsyncProcess()
        tableView.reloadData()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if let error = error{
            print("Write失敗...error:\(error)")
            return
        }
        print("Write成功！")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        if error != nil{
            print("Notify状態更新失敗...error:\(error)")
        }else{
            print("Notify状態更新成功！ isNotifying: \(characteristic.isNotifying)")
        }
    }
}
