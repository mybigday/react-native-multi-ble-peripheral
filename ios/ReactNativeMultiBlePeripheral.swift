import Foundation
import CoreBluetooth
import React

extension Dictionary where Value: Equatable {
  func someKey(forValue val: Value) -> Key? {
    return first(where: { $1 == val })?.key
  }
}

@objc(ReactNativeMultiBlePeripheral)
class ReactNativeMultiBlePeripheral: RCTEventEmitter, CBPeripheralManagerDelegate {

  var hasListeners: Bool = false
  var managers: [Int: CBPeripheralManager] = [:]
  var promises: [Int: (RCTPromiseResolveBlock, RCTPromiseRejectBlock)] = [:]
  var services: [Int: [String:CBMutableService]] = [:]
  var deviceName: String = ""

  deinit {
    managers.forEach { _, manager in
      manager.stopAdvertising()
    }
  }

  override func startObserving() {
    hasListeners = true
  }

  override func stopObserving() {
    hasListeners = false
  }

  override func supportedEvents() -> [String]! {
    return ["onWrite", "onSubscribe", "onUnsubscribe"]
  }

  override class func requiresMainQueueSetup() -> Bool { return false }

  func getCharacteristic(
    _ id: Int,
    _ serviceUUID: String,
    _ characteristicUUID: CBUUID
  ) -> CBMutableCharacteristic? {
    return services[id]?[serviceUUID]?.characteristics?.first(where: { $0.uuid == uuid })
  }

  @objc(setDeviceName:withResolver:withRejecter:)
  func setDeviceName(
    _ name: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    deviceName = name
    resolve(nil)
  }

  @objc(createPeripheral:withResolver:withRejecter:)
  func createPeripheral(
    _ id: Int,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let manager = CBPeripheralManager(delegate: self, queue: nil)
    managers[id] = manager
    services[id] = [:]
    resolve(nil)
  }

  @objc(checkState:withResolver:withRejecter:)
  func checkState(
    _ id: Int,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let manager = managers[id]
    if manager == nil {
      reject("error", "Peripheral id does not exist", nil)
      return
    }
    let stateName: String
    switch manager!.state {
    case .unknown:
      stateName = "unknown"
    case .resetting:
      stateName = "resetting"
    case .unsupported:
      stateName = "unsupported"
    case .unauthorized:
      stateName = "unauthorized"
    case .poweredOff:
      stateName = "off"
    case .poweredOn:
      stateName = "on"
    default:
      stateName = "unknown"
    }
    resolve(stateName)
  }

  @objc(addService:serviceUUID:primary:withResolver:withRejecter:)
  func addService(
    _ id: Int,
    serviceUUID: String,
    primary: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let manager = managers[id]
    if manager == nil {
      reject("error", "Peripheral id does not exist", nil)
      return
    }
    let uuid = CBUUID(string: serviceUUID)
    let service = CBMutableService(type: uuid, primary: primary)
    services[id]?[serviceUUID] = service
    promises[id] = (resolve, reject)
    manager!.add(service)
  }

  @objc(addCharacteristic:serviceUUID:characteristicUUID:properties:permissions:withResolver:withRejecter:)
  func addCharacteristic(
    _ id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    properties: NSNumber,
    permissions: NSNumber,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let manager = managers[id]
    if manager == nil {
      reject("error", "Peripheral id does not exist", nil)
      return
    }
    let uuid = CBUUID(string: characteristicUUID)
    let characteristic = CBMutableCharacteristic(
      type: uuid,
      properties: CBCharacteristicProperties(rawValue: properties.uintValue),
      value: nil,
      permissions: CBAttributePermissions(rawValue: permissions.uintValue)
    )
    services[id]?[serviceUUID]?.characteristics?.append(charateristic)
    resolve(nil)
  }

  @objc(startAdvertising:withServices:withOptions:withResolver:withRejecter:)
  func startAdvertising(
    _ id: Int,
    services: NSDictionary?,
    options: NSDictionary?,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let manager = managers[id]
    if manager == nil {
      reject("error", "Peripheral id does not exist", nil)
      return
    }
    if manager?.state != .poweredOn {
      reject("error", "Peripheral is not powered on", nil)
      return
    }
    if manager?.isAdvertising == true {
      reject("error", "Peripheral is already advertising", nil)
      return
    }
    let uuids = services?.map { key, value in
      CBUUID(string: value as! String)
    }
    let advertisementData = [
      CBAdvertisementDataLocalNameKey: name,
      CBAdvertisementDataServiceUUIDsKey: uuids,
    ] as [String : Any]
    promises[id] = (resolve, reject)
    manager!.startAdvertising(advertisementData)
  }

  @objc(stopAdvertising:withResolver:withRejecter:)
  func stopAdvertising(
    _ id: Int,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let manager = managers[id]
    if manager == nil {
      reject("error", "Peripheral id does not exist", nil)
      return
    }
    if manager!.isAdvertising != true {
      reject("error", "Peripheral is not advertising", nil)
      return
    }
    promises[id] = (resolve, reject)
    manager!.stopAdvertising()
  }

  @objc(updateValue:serviceUUID:characteristicUUID:value:withResolver:withRejecter:)
  func updateValue(
    _ id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    value: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    if
      let uuid = CBUUID(string: characteristicUUID),
      let characteristic = getCharacteristic(id, serviceUUID, uuid)
    {
      characteristic.value = Data(base64Encoded: value)
      resolve(nil)
    } else {
      reject("error", "Not found characteristic", nil)
    }
  }

  @objc(sendNotification:serviceUUID:characteristicUUID:value:withResolver:withRejecter:)
  func sendNotification(
    _ id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    value: String,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    if
      let manager = managers[id],
      let uuid = CBUUID(string: characteristicUUID),
      let characteristic = getCharacteristic(id, serviceUUID, uuid),
      let data = Data(base64Encoded: value)
    {
      let didSend = manager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
      if didSend == true {
        resolve(nil)
      } else {
        reject("error", "Send notification failed", nil)
      }
    } else {
      reject("error", "Not found characteristic", nil)
    }
  }

  @objc(destroyPeripheral:withResolver:withRejecter:)
  func destroyPeripheral(
    _ id: Int,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let manager = managers[id]
    if manager == nil {
      reject("error", "Peripheral id does not exist", nil)
      return
    }
    if manager!.isAdvertising == true {
      manager!.stopAdvertising()
    }
    managers.removeValue(forKey: id)
    promises.removeValue(forKey: id)
    services.removeValue(forKey: id)
    resolve(nil)
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    didReceiveRead request: CBATTRequest
  ) {
    guard let value = request.characteristic.value, request.offset <= value.count else {
      peripheral.respond(to: request, withResult: .invalidOffset)
      return
    }
    request.value = value.subdata(in: request.offset..<value.count)
    peripheral.respond(to: request, withResult: .success)
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    didReceiveWrite requests: [CBATTRequest]
  ) {
    let id = managers.someKey(forValue: peripheral)
    for request in requests {
      let characteristic = request.characteristic
      let characteristicUUID = characteristic.uuid.uuidString
      let serviceUUID = characteristic.service.uuid.uuidString
      let base64 = request.value?.base64EncodedString()
      sendEvent(withName: "onWrite", body: [
        "id": id,
        "serviceUUID": serviceUUID,
        "characteristicUUID": characteristicUUID,
        "value": base64,
      ])
    }
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    // not do anything
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    central: CBCentral,
    didSubscribeTo characteristic: CBCharacteristic
  ) {
    let id = managers.someKey(forValue: peripheral)
    let characteristicUUID = characteristic.uuid.uuidString
    let serviceUUID = characteristic.service?.uuid.uuidString
    sendEvent(withName: "onSubscribe", body: [
      "id": id,
      "serviceUUID": serviceUUID,
      "characteristicUUID": characteristicUUID,
    ])
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    central: CBCentral,
    didUnsubscribeFrom characteristic: CBCharacteristic
  ) {
    let id = managers.someKey(forValue: peripheral)
    let characteristicUUID = characteristic.uuid.uuidString
    let serviceUUID = characteristic.service?.uuid.uuidString
    sendEvent(withName: "onUnsubscribe", body: [
      "id": id,
      "serviceUUID": serviceUUID,
      "characteristicUUID": characteristicUUID,
    ])
  }

  func peripheralManagerDidStartAdvertising(
    _ peripheral: CBPeripheralManager,
    error: Error?
  ) {
    if
      let id = managers.someKey(forValue: peripheral),
      let promise = promises[id]
    {
      if error != nil {
        promise.1("error", "Failed to start advertising", error)
      } else {
        promise.0(nil)
      }
    }
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    didAdd service: CBService,
    error: Error?
  ) {
    if
      let id = managers.someKey(forValue: peripheral),
      let promise = promises[id]
    {
      if error != nil {
        promise.1("error", "Failed to add service", error)
      } else {
        promise.0(nil)
      }
    }
  }

  func peripheralManagerDidStopAdvertising(
    _ peripheral: CBPeripheralManager,
    error: Error?
  ) {
    if
      let id = managers.someKey(forValue: peripheral),
      let promise = promises[id]
    {
      if error != nil {
        promise.1("error", "Failed to stop advertising", error)
      } else {
        promise.0(nil)
      }
    }
  }

}
