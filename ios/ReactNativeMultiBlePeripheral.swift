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
  var createRejects: [Int: RCTPromiseRejectBlock] = [:]
  var createResolves: [Int: RCTPromiseResolveBlock] = [:]
  var startRejects: [Int: RCTPromiseRejectBlock] = [:]
  var startResolves: [Int: RCTPromiseResolveBlock] = [:]
  var services: [Int: [String:CBMutableService]] = [:]
  var deviceName: String = ""

  deinit {
    managers.forEach { _, manager in
      if manager.isAdvertising {
        manager.stopAdvertising()
      }
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
    return services[id]?[serviceUUID]?.characteristics?.first(where: {
      $0.uuid == characteristicUUID
    }) as? CBMutableCharacteristic
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
    createResolves[id] = resolve
    createRejects[id] = reject
    managers[id] = CBPeripheralManager(delegate: self, queue: nil, options: nil)
    services[id] = [:]
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
    service.characteristics = [CBCharacteristic]()
    services[id]?[serviceUUID] = service
    manager?.add(service)
    resolve(nil)
  }

  @objc(addCharacteristic:serviceUUID:characteristicUUID:properties:permissions:withResolver:withRejecter:)
  func addCharacteristic(
    _ id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    properties: UInt,
    permissions: UInt,
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
      properties: CBCharacteristicProperties(rawValue: properties),
      value: nil,
      permissions: CBAttributePermissions(rawValue: permissions)
    )
    if let service = services[id]?[serviceUUID] {
      service.characteristics?.append(characteristic)
      manager?.removeAllServices()
      for (_, service) in services[id]! {
        manager?.add(service)
      }
      resolve(nil)
    } else {
      reject("error", "Service does not exist", nil)
    }
  }

  @objc(startAdvertising:withServices:withOptions:withResolver:withRejecter:)
  func startAdvertising(
    _ id: Int,
    advServices: NSDictionary?,
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
    let uuids = advServices?.map { key, _ in
      CBUUID(string: key as! String)
    } ?? services[id]?.map { key, _ in
      CBUUID(string: key)
    }
    let advertisementData = [
      CBAdvertisementDataLocalNameKey: deviceName,
      CBAdvertisementDataServiceUUIDsKey: uuids,
    ] as [String : Any]
    startResolves[id] = resolve
    startRejects[id] = reject
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
    if manager!.isAdvertising {
      manager!.stopAdvertising()
    }
    resolve(nil)
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
    let uuid = CBUUID(string: characteristicUUID)
    if let characteristic = getCharacteristic(id, serviceUUID, uuid) {
      characteristic.value = Data(base64Encoded: value)
      resolve(nil)
    } else {
      reject("error", "Not found characteristic", nil)
    }
  }

  @objc(sendNotification:serviceUUID:characteristicUUID:value:confirm:withResolver:withRejecter:)
  func sendNotification(
    _ id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    value: String,
    confirm: Bool,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    let uuid = CBUUID(string: characteristicUUID)
    if
      let manager = managers[id],
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
    manager!.removeAllServices()
    managers.removeValue(forKey: id)
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
      let serviceUUID = characteristic.service?.uuid.uuidString
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
    if let id = managers.someKey(forValue: peripheral) {
      let state = peripheral.state
      switch state {
      case .poweredOn:
        createResolves[id]?(nil)
        createResolves.removeValue(forKey: id)
        createRejects.removeValue(forKey: id)
      case .poweredOff:
        createRejects[id]?("error", "Peripheral is powered off", nil)
        createRejects.removeValue(forKey: id)
      case .resetting:
        createRejects[id]?("error", "Peripheral is resetting", nil)
        createRejects.removeValue(forKey: id)
      case .unauthorized:
        createRejects[id]?("error", "Peripheral is unauthorized", nil)
        createRejects.removeValue(forKey: id)
      case .unsupported:
        createRejects[id]?("error", "Peripheral is unsupported", nil)
        createRejects.removeValue(forKey: id)
      case .unknown:
        createRejects[id]?("error", "Peripheral state is unknown", nil)
        createRejects.removeValue(forKey: id)
      }
    }
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
      let resolve = startResolves[id],
      let reject = startRejects[id]
    {
      if error != nil {
        reject("error", "Fail to start: \(error)", error)
      } else {
        resolve(nil)
      }
    } else {
      print("Not found ID or promise")
    }
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager,
    didAdd service: CBService,
    error: Error?
  ) {
    if let id = managers.someKey(forValue: peripheral) {
      print("id: \(id), service: \(service), error: \(error)")
    }
  }

  func peripheralManagerDidStopAdvertising(
    _ peripheral: CBPeripheralManager,
    error: Error?
  ) {
    if let id = managers.someKey(forValue: peripheral) {
      print("id: \(id), error: \(error)")
    }
  }

}
