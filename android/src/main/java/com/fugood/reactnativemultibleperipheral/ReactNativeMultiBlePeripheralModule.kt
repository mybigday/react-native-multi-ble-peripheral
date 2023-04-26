package com.fugood.reactnativemultibleperipheral

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSet
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.provider.SyncStateContract
import android.util.Log
import android.util.Base64
import android.os.ParcelUuid

import java.nio.charset.StandardCharsets
import java.util.HashMap
import java.util.HashSet
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.Map

@ReactModule(name = ReactNativeMultiBlePeripheralModule.NAME)
class ReactNativeMultiBlePeripheralModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return NAME
  }

  private var bluetoothAdapter: BluetoothAdapter? = null
  private var bluetoothLeAdvertisers: HashMap<Int, BluetoothLeAdvertiser> = HashMap()
  private var bluetoothGattServers: HashMap<Int, BluetoothGattServer> = HashMap()
  private var advertiseCallbacks: HashMap<Int, AdvertiseCallback> = HashMap()

  init {
    val bluetoothManager = reactContext.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    bluetoothAdapter = bluetoothManager?.adapter
  }

  fun sendEvent(name: String, params: WritableMap) {
    reactApplicationContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(name, params)
  }

  @ReactMethod
  fun setDeviceName(name: String, promise: Promise) {
    val bluetoothAdapter = bluetoothAdapter
    if (bluetoothAdapter == null) {
      promise.reject("error", "Not support bluetooth")
      return
    }
    bluetoothAdapter.name = name
    promise.resolve(null)
  }

  @ReactMethod
  fun createPeripheral(id: Int, promise: Promise) {
    if (!bluetoothAdapter.isMultipleAdvertisementSupported()) {
      promise.reject("error", "Not support multiple advertisement")
      return
    }
    val bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not support bluetoothLeAdvertiser")
      return
    }
    bluetoothLeAdvertisers[id] = bluetoothLeAdvertiser

    val bluetoothGattServer = bluetoothManager.openGattServer(reactContext, object : BluetoothGattServerCallback() {
      override fun onCharacteristicReadRequest(
        device: BluetoothDevice,
        requestId: Int,
        offset: Int,
        characteristic: BluetoothGattCharacteristic
      ) {
        super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
        var gattServer = bluetoothGattServers[id]
        if (gattServer != null) {
          if (offset > characteristic.value.size) {
            gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null)
          } else {
            gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, characteristic.value)
          }
        }
      }

      override fun onCharacteristicWriteRequest(
        device: BluetoothDevice,
        requestId: Int,
        characteristic: BluetoothGattCharacteristic,
        preparedWrite: Boolean,
        responseNeeded: Boolean,
        offset: Int,
        value: ByteArray
      ) {
        super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
        var gattServer = bluetoothGattServers[id]
        if (gattServer != null) {
          val params = Arguments.createMap()
          params.putString("id", id.toString())
          params.putString("device", device.address)
          params.putString("service", characteristic.service.uuid.toString())
          params.putString("characteristic", characteristic.uuid.toString())
          params.putInt("offset", offset)
          params.putString("value", Base64.encodeToString(value, Base64.NO_WRAP))
          sendEvent(reactApplicationContext, "onWrite", params)
          if (responseNeeded) {
            gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
          }
        }
      }
    })
    if (bluetoothGattServer == null) {
      bluetoothLeAdvertiser.close()
      bluetoothLeAdvertisers.remove(id)
      promise.reject("error", "Not support bluetoothGattServer")
      return
    }
    bluetoothGattServers[id] = bluetoothGattServer

    promise.resolve(null)
  }

  @ReactMethod
  fun checkState(promise: Promise) {
    val bluetoothAdapter = bluetoothAdapter
    if (bluetoothAdapter == null) {
      promise.reject("error", "Not support bluetooth")
      return
    }
    var stateString = when (bluetoothAdapter.state) {
      BluetoothAdapter.STATE_ON -> "on"
      BluetoothAdapter.STATE_OFF -> "off"
      BluetoothAdapter.STATE_TURNING_ON -> "turning_on"
      BluetoothAdapter.STATE_TURNING_OFF -> "turning_off"
      else -> "unknown"
    }
    promise.resolve(stateString)
  }

  @ReactMethod
  fun addService(
    id: Int,
    uuid: String,
    primary: Boolean,
    promise: Promise
  ) {
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    val bluetoothGattServer = bluetoothGattServers[id]
    if (bluetoothGattServer == null) {
      promise.reject("error", "Not found bluetoothGattServer")
      return
    }
    val serviceUUID = UUID.fromString(uuid)
    val service = BluetoothGattService(serviceUUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
    bluetoothGattServer.addService(service)
    promise.resolve(null)
  }

  @ReactMethod
  fun addCharacteristic(
    id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    properties: Int,
    permissions: Int,
    promise: Promise
  ) {
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    val bluetoothGattServer = bluetoothGattServers[id]
    if (bluetoothGattServer == null) {
      promise.reject("error", "Not found bluetoothGattServer")
      return
    }
    val service = bluetoothGattServer.getService(UUID.fromString(serviceUUID))
    if (service == null) {
      promise.reject("error", "Not found service")
      return
    }
    val characteristic = BluetoothGattCharacteristic(
      UUID.fromString(characteristicUUID),
      properties,
      permissions
    )
    service.addCharacteristic(characteristic)
    promise.resolve(null)
  }

  @ReactMethod
  fun updateValue(
    id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    value: String,
    promise: Promise
  ) {
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    val bluetoothGattServer = bluetoothGattServers[id]
    if (bluetoothGattServer == null) {
      promise.reject("error", "Not found bluetoothGattServer")
      return
    }
    val service = bluetoothGattServer.getService(UUID.fromString(serviceUUID))
    if (service == null) {
      promise.reject("error", "Not found service")
      return
    }
    val characteristic = service.getCharacteristic(UUID.fromString(characteristicUUID))
    if (characteristic == null) {
      promise.reject("error", "Not found characteristic")
      return
    }
    characteristic.value = Base64.decode(value, Base64.NO_WRAP)
    promise.resolve(null)
  }

  @ReactMethod
  fun sendNotification(
    id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    value: String,
    promise: Promise
  ) {
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    val bluetoothGattServer = bluetoothGattServers[id]
    if (bluetoothGattServer == null) {
      promise.reject("error", "Not found bluetoothGattServer")
      return
    }
    val service = bluetoothGattServer.getService(UUID.fromString(serviceUUID))
    if (service == null) {
      promise.reject("error", "Not found service")
      return
    }
    val characteristic = service.getCharacteristic(UUID.fromString(characteristicUUID))
    if (characteristic == null) {
      promise.reject("error", "Not found characteristic")
      return
    }
    characteristic.value = Base64.decode(value, Base64.NO_WRAP)
    for (device in bluetoothGattServer.getConnectedDevices(BluetoothProfile.STATE_CONNECTED)) {
      bluetoothGattServer.notifyCharacteristicChanged(device, characteristic, false)
    }
    promise.resolve(null)
  }

  @ReactMethod
  fun startAdvertising(
    id: Int,
    services?: ReadableMap,
    options?: ReadableMap,
    promise: Promise
  ) {
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    val bluetoothGattServer = bluetoothGattServers[id]
    if (bluetoothGattServer == null) {
      promise.reject("error", "Not found bluetoothGattServer")
      return
    }

    val connectable =
      if (options?.hasKey("connectable")) options?.getBoolean("connectable")
      else true
    val includeDeviceName =
      if (options?.hasKey("includeDeviceName")) options?.getBoolean("includeDeviceName")
      else true
    val includeTxPower =
      if (options?.hasKey("includeTxPower")) options?.getBoolean("includeTxPower")
      else false
    val advertiseMode =
      if (options?.hasKey("mode")) options?.getInt("mode")
      else AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY
    val txPowerLevel =
      if (options?.hasKey("txPowerLevel")) options?.getInt("txPowerLevel")
      else AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM
    val manufacturerId =
      if (options?.hasKey("manufacturerId")) options?.getInt("manufacturerId")
      else null
    val manufacturerData =
      if (options?.hasKey("manufacturerData")) options?.getString("manufacturerData")
      else null

    val advertiseSettings = AdvertiseSettings.Builder()
      .setAdvertiseMode(advertiseMode)
      .setTxPowerLevel(txPower)
      .setConnectable(connectable)
      .setTimeout(0)
      .build()

    val advertiseDataBuilder = AdvertiseData.Builder()
      .setIncludeDeviceName(includeDeviceName)
      .setIncludeTxPowerLevel(includeTxPower)
    if (manufacturerData != null) {
      advertiseDataBuilder.addManufacturerData(manufacturerId, Base64.decode(manufacturerData, Base64.DEFAULT))
    }
    if (services != null) {
      for (service in services.entrySet()) {
        val uuid = UUID.fromString(service.key)
        val data = Base64.decode(service.value, Base64.DEFAULT)
        advertiseDataBuilder.addServiceData(ParcelUuid(uuid), data)
        advertiseDataBuilder.addServiceUuid(ParcelUuid(uuid))
      }
    }

    if (advertiseCallbacks[id] == null) {
      advertiseCallbacks[id] = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
          super.onStartSuccess(settingsInEffect)
          promise.resolve(null)
        }
        override fun onStartFailure(errorCode: Int) {
          super.onStartFailure(errorCode)
          promise.reject("error", "startAdvertising error")
        }
      }
    }

    val advertiseData = advertiseDataBuilder.build()
    bluetoothLeAdvertiser.startAdvertising(advertiseSettings, advertiseData, advertiseCallbacks[id])
  }

  @ReactMethod
  fun stopAdvertising(
    id: Int,
    promise: Promise
  ) {
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    if (advertiseCallbacks[id] == null) {
      promise.reject("error", "Had not start advertising")
      return
    }
    bluetoothLeAdvertiser.stopAdvertising(advertiseCallbacks[id])
    promise.resolve(null)
  }

  @ReactMethod
  fun destroyPeripheral(
    id: Int,
    promise: Promise
  ) {
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    val bluetoothGattServer = bluetoothGattServers[id]
    if (bluetoothGattServer == null) {
      promise.reject("error", "Not found bluetoothGattServer")
      return
    }
    bluetoothGattServer.close()
    bluetoothLeAdvertiser.close()
    bluetoothGattServers.remove(id)
    bluetoothLeAdvertisers.remove(id)
    advertiseCallbacks.remove(id)
    promise.resolve(null)
  }


  companion object {
    const val NAME = "ReactNativeMultiBlePeripheral"
  }
}
