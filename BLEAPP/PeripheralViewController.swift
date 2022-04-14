//
//  PeripheralViewController.swift
//  BLEAPP
//
//  Created by 濱田広毅 on 2022/01/29.
//

import UIKit
import CoreBluetooth

class PeripheralViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var textField: UITextField!
    var peripheralManager:CBPeripheralManager!
    var connectFlag = false
    // サービスのID
    let serviceUUID = CBUUID(string: "0000")
    var service:CBMutableService!
    // キャラクタリスティックのID
    let characteristicUUID = CBUUID(string: "0001")
    var characteristic:CBMutableCharacteristic!
    var textDataArray = [String]()
    // アドバタイズしたいサービスのUUIDのリスト
    let serviceUUIDs = [CBUUID(string: "0000")]
    var advertisementData: [String: AnyObject] = [:]
    let value:UInt8 = UInt8(arc4random() & 0xFF)
    var data = NSData()
    let properties:CBCharacteristicProperties = [CBCharacteristicProperties.notify,CBCharacteristicProperties.read, CBCharacteristicProperties.write]
    let permissions:CBAttributePermissions = [CBAttributePermissions.readable, CBAttributePermissions.writeable]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textDataArray = []
        service = CBMutableService(type: serviceUUID, primary: true)
        self.characteristic = CBMutableCharacteristic(type: characteristicUUID, properties: properties, value: nil, permissions: permissions)
        service?.characteristics = [characteristic]
        advertisementData =
        [
            CBAdvertisementDataLocalNameKey: "Test Device",
            CBAdvertisementDataServiceUUIDsKey: serviceUUIDs
        ] as! [String : AnyObject]
        data = NSData(bytes: [value] as [UInt8], length: 1)
        tableView.delegate = self
        tableView.dataSource = self
        textField.delegate = self
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
    }
    
    @IBAction func sendButton(_ sender: Any) {
        
        // テキストフィールドがからならreturn
        if (textField.text == nil || connectFlag == false){
            return
        }
        
        // 文字が入力されていて、かつ接続がされている場合送信処理を行う
        if textField.text != nil && connectFlag == true{
            
            let text = textField.text!
            let data = text.data(using: .utf8)!
            //セントラルへデータ送信
            peripheralManager.updateValue(data, for: characteristic!, onSubscribedCentrals: nil)
            //メッセージ配列に追加
            //textDataArray.append("\(text)")
            self.peripheralManager.updateValue(data as Data, for: self.characteristic, onSubscribedCentrals: nil)
            //更新
            tableView.reloadData()
        }
    }
    
    @IBAction func scanButton(_ sender: Any) {
        
        // サービスの追加は1回のみ行う
        if connectFlag == false{
            
            self.peripheralManager.startAdvertising(advertisementData)
            // サービスの追加
            self.peripheralManager.add(service)
            // キャラクタリスティックのvalueに値をセットする
            self.characteristic.value = data as! Data
            connectFlag = true
        }
        
    }
    
    @IBAction func stopButton(_ sender: Any) {
        
        self.peripheralManager.stopAdvertising()
    }
    
    @IBAction func updateButton(_ sender: Any) {
        
        self.peripheralManager.updateValue(data as Data, for: self.characteristic, onSubscribedCentrals: nil)
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return textDataArray.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel!.text = textDataArray[indexPath.row]
        return cell
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension PeripheralViewController:CBPeripheralManagerDelegate{
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        print("state: \(peripheral.state)")
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        
        print("アドバタイズ開始成功！")
        self.peripheralManager.stopAdvertising()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if error != nil{
            print("サービス追加失敗! error:\(error)")
            return
        }
        print("サービス追加成功！")
    }
    
    // Readリクエストを受け取る
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        
        print("Readリクエスト受信！ requested service uuid: \(request.characteristic.service?.uuid) characteristic uuid:\(request.characteristic.uuid) value:\(request.characteristic.value)")
        // プロパティで保持しているキャラクタリスティックへのReadリクエストかどうかを判定
        if request.characteristic.uuid.isEqual(self.characteristic.uuid){
            
            // CBMutableCharacteristicのvalueをCBATTRequestのvalueにセット
            request.value = self.characteristic.value
            //　リクエストに応答
            self.peripheralManager.respond(to: request, withResult: CBATTError.success)
        }
    }
    
    // Writeリクエストを受け取る
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        print("\(requests.count)件のWriteリクエストを受信！")
        
        for obj in requests{
            
            if let request = obj as? CBATTRequest{
                
                if request.characteristic.uuid.isEqual(self.characteristic.uuid){
                    // CBMutableCharacteristicのvalueに、CBATTRequestのvalueをセット
                    self.characteristic.value = request.value
                }
            }
        }
        
        guard let request = requests.first, let data = request.value else { return }
        let text = String(decoding: data, as: UTF8.self)
        //メッセージ配列に追加
        textDataArray.append("\(text)")
        //更新
        tableView.reloadData()
        // リクエストに応答
        self.peripheralManager.respond(to: requests[0] as CBATTRequest, withResult: CBATTError.success)
    }
    
    // Notify開始リクエストを受け取る
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        print("Notify開始リクエストを受信")
        print("Notify中のセントラル:\(self.characteristic.subscribedCentrals)")
    }
    
    // Notify停止リクエストを受け取る
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {

        print("Notify停止リクエストを受信")
        print("Notify中のセントラル:\(self.characteristic.subscribedCentrals)")
    }
}
