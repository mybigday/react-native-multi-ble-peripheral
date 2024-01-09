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
import android.bluetooth.BluetoothGattDescriptor
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
import androidx.core.content.ContextCompat

import java.util.UUID
import java.util.Arrays

import kotlin.collections.MutableSet
import kotlin.collections.MutableMap
import kotlin.collections.LinkedHashMap

@ReactModule(name = ReactNativeMultiBlePeripheralModule.NAME)
class ReactNativeMultiBlePeripheralModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return NAME
  }

  private var bluetoothManager: BluetoothManager? = null
  private var bluetoothAdapter: BluetoothAdapter? = null
  private var bluetoothLeAdvertisers: MutableMap<Int, BluetoothLeAdvertiser> = LinkedHashMap()
  private var bluetoothGattServers: MutableMap<Int, BluetoothGattServer> = LinkedHashMap()
  private var registeredDevices: MutableMap<Int, MutableSet<BluetoothDevice>> = LinkedHashMap()
  private var services: MutableMap<Int, MutableMap<String, BluetoothGattService>> = LinkedHashMap()
  private var advertiseCallbacks: MutableMap<Int, AdvertiseCallback> = LinkedHashMap()

  init {
    bluetoothManager = ContextCompat.getSystemService(
      reactContext,
      BluetoothManager::class.java
    )
    bluetoothAdapter = bluetoothManager?.adapter
  }

  fun sendEvent(name: String, params: WritableMap) {
    getReactApplicationContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(name, params)
  }

  @ReactMethod
  fun setDeviceName(name: String, promise: Promise) {
    if (bluetoothAdapter == null) {
      promise.reject("error", "Not support bluetooth")
      return
    }
    bluetoothAdapter!!.name = name
    promise.resolve(null)
  }

  @ReactMethod
  fun createPeripheral(id: Int, promise: Promise) {
    val bluetoothAdapter = bluetoothAdapter
    val bluetoothManager = bluetoothManager
    if (bluetoothAdapter == null || bluetoothManager == null) {
      promise.reject("error", "Not support bluetooth")
      return
    }
    if (!bluetoothAdapter.isMultipleAdvertisementSupported() && bluetoothLeAdvertisers.isNotEmpty()) {
      promise.reject("error", "Not support multiple advertisement")
      return
    }
    val bluetoothLeAdvertiser = bluetoothAdapter.bluetoothLeAdvertiser
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not support bluetoothLeAdvertiser")
      return
    }
    bluetoothLeAdvertisers[id] = bluetoothLeAdvertiser

    services[id] = LinkedHashMap()

    promise.resolve(null)
  }

  @ReactMethod
  fun checkState(id: Int, promise: Promise) {
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
    val serviceUUID = UUID.fromString(uuid)
    val service = BluetoothGattService(
      serviceUUID,
      if (primary) BluetoothGattService.SERVICE_TYPE_PRIMARY else BluetoothGattService.SERVICE_TYPE_SECONDARY
    )
    services[id]?.put(uuid, service)
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
    if (services[id] == null) {
      promise.reject("error", "Not found peripheral")
      return
    }
    val service = services[id]?.get(serviceUUID)
    if (service == null) {
      promise.reject("error", "Not found service")
      return
    }
    val characteristic = BluetoothGattCharacteristic(
      UUID.fromString(characteristicUUID),
      properties,
      permissions
    )
    if (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) {
      val descriptor = BluetoothGattDescriptor(
        Constants.CLIENT_CONFIG,
        BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
      )
      characteristic.addDescriptor(descriptor)
    }
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
    val service = services[id]?.get(serviceUUID)
    if (service == null) {
      promise.reject("error", "Not found service")
      return
    }
    val characteristic = service.getCharacteristic(UUID.fromString(characteristicUUID))
    if (characteristic == null) {
      promise.reject("error", "Not found characteristic")
      return
    }
    characteristic.value = Base64.decode(value, Base64.DEFAULT)
    promise.resolve(null)
  }

  @ReactMethod
  fun sendNotification(
    id: Int,
    serviceUUID: String,
    characteristicUUID: String,
    value: String,
    confirm: Boolean,
    promise: Promise
  ) {
    val bluetoothGattServer = bluetoothGattServers[id]
    if (bluetoothGattServer == null) {
      promise.reject("error", "Have not started advertising")
      return
    }
    val registeredDevices = registeredDevices[id]
    if (registeredDevices == null) {
      promise.reject("error", "Not found registeredDevices")
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
    var value = Base64.decode(value, Base64.DEFAULT)
    characteristic.value = value
    for (device in registeredDevices) {
      val response = bluetoothGattServer.notifyCharacteristicChanged(
        device,
        characteristic,
        confirm
      )
      Log.d(NAME, "Notify ${device.name} (${device.address}) response = $response")
    }
    promise.resolve(null)
  }

  @ReactMethod
  fun startAdvertising(
    id: Int,
    advServices: ReadableMap?,
    options: ReadableMap?,
    promise: Promise
  ) {
    val bluetoothManager = bluetoothManager
    if (bluetoothManager == null) {
      promise.reject("error", "Not support bluetooth")
      return
    }
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (bluetoothLeAdvertiser == null) {
      promise.reject("error", "Not found bluetoothLeAdvertiser")
      return
    }
    if (advertiseCallbacks[id] != null) {
      promise.reject("error", "Already advertising")
      return
    }

    registeredDevices[id] = mutableSetOf<BluetoothDevice>()

    val bluetoothGattServer = bluetoothManager.openGattServer(
      getReactApplicationContext(),
      object : BluetoothGattServerCallback() {

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
          super.onConnectionStateChange(device, status, newState)
          var registeredDevices = registeredDevices[id]
          if (registeredDevices != null) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
              Log.i(NAME, "BluetoothDevice CONNECTED: $device")
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
              Log.i(NAME, "BluetoothDevice DISCONNECTED: $device")
              registeredDevices.remove(device)
            }
          }
        }

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

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
          super.onNotificationSent(device, status)
          Log.d(NAME, "Notification send to device ${device.address}, status = $status")
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
            sendEvent("onWrite", params)
            if (responseNeeded) {
              gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }
          }
        }

        override fun onDescriptorReadRequest(
          device: BluetoothDevice,
          requestId: Int,
          offset: Int,
          descriptor: BluetoothGattDescriptor
        ) {
          super.onDescriptorReadRequest(device, requestId, offset, descriptor)
          var gattServer = bluetoothGattServers[id]
          var registeredDevices = registeredDevices[id]
          if (gattServer != null && registeredDevices != null) {
            if (Constants.CLIENT_CONFIG == descriptor.uuid) {
                Log.d(NAME, "Config descriptor read")
                val returnValue =
                  if (registeredDevices.contains(device))
                    BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                  else
                    BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                gattServer.sendResponse(
                  device,
                  requestId,
                  BluetoothGatt.GATT_SUCCESS,
                  0,
                  returnValue
                )
            } else {
              Log.w(NAME, "Unknown descriptor write request")
              gattServer.sendResponse(
                device,
                requestId,
                BluetoothGatt.GATT_FAILURE,
                0,
                null
              )
            }
          }
        }

        override fun onDescriptorWriteRequest(
          device: BluetoothDevice,
          requestId: Int,
          descriptor: BluetoothGattDescriptor,
          preparedWrite: Boolean,
          responseNeeded: Boolean,
          offset: Int,
          value: ByteArray
        ) {
          super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)
          var gattServer = bluetoothGattServers[id]
          var registeredDevices = registeredDevices[id]
          if (gattServer != null && registeredDevices != null) {
            if (Constants.CLIENT_CONFIG == descriptor.uuid) {
              if (Arrays.equals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE, value)) {
                Log.d(NAME, "Subscribe device to notifications: $device")
                registeredDevices.add(device)
              } else if (Arrays.equals(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE, value)) {
                Log.d(NAME, "Unsubscribe device from notifications: $device")
                registeredDevices.remove(device)
              }
              if (responseNeeded) {
                gattServer.sendResponse(
                  device,
                  requestId,
                  BluetoothGatt.GATT_SUCCESS,
                  0,
                  null
                )
              }
            } else {
              Log.w(NAME, "Unknown descriptor write request")
              gattServer.sendResponse(
                device,
                requestId,
                BluetoothGatt.GATT_FAILURE,
                0,
                null
              )
            }
          }
        }

      }
    )
    bluetoothGattServers[id] = bluetoothGattServer

    for (service in services[id]!!.values) {
      bluetoothGattServer.addService(service)
    }

    val connectable = Utils.get<Boolean>(options, "connectable", true)
    val includeDeviceName = Utils.get<Boolean>(options, "includeDeviceName", true)
    val includeTxPower = Utils.get<Boolean>(options, "includeTxPower", false)
    val advertiseMode = Utils.get<Int>(options, "mode", AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
    val txPowerLevel = Utils.get<Int>(options, "txPowerLevel", AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
    val manufacturerId = Utils.getInt(options, "manufacturerId")
    val manufacturerData = Utils.getString(options, "manufacturerData")

    val advertiseSettings = AdvertiseSettings.Builder()
      .setAdvertiseMode(advertiseMode)
      .setTxPowerLevel(txPowerLevel)
      .setConnectable(connectable)
      .setTimeout(0)
      .build()

    val advertiseDataBuilder = AdvertiseData.Builder()
      .setIncludeDeviceName(includeDeviceName)
      .setIncludeTxPowerLevel(includeTxPower)
    if (manufacturerId != null && manufacturerData != null) {
      advertiseDataBuilder.addManufacturerData(
        manufacturerId,
        Base64.decode(manufacturerData, Base64.DEFAULT)
      )
    }
    if (advServices != null) {
      for (service in advServices.getEntryIterator()) {
        val uuid = UUID.fromString(service.key)
        if (service.value is String) {
          val data = Base64.decode(service.value as String, Base64.DEFAULT)
          advertiseDataBuilder.addServiceData(ParcelUuid(uuid), data)
        }
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
    registeredDevices.remove(id)
    promise.resolve(null)
  }

  @ReactMethod
  fun destroyPeripheral(
    id: Int,
    promise: Promise
  ) {
    val callback = advertiseCallbacks[id]
    val bluetoothLeAdvertiser = bluetoothLeAdvertisers[id]
    if (callback != null && bluetoothLeAdvertiser != null) {
      bluetoothLeAdvertiser.stopAdvertising(callback)
    }
    bluetoothGattServers[id]?.close()
    bluetoothGattServers.remove(id)
    bluetoothLeAdvertisers.remove(id)
    advertiseCallbacks.remove(id)
    registeredDevices.remove(id)
    promise.resolve(null)
  }


  companion object {
    const val NAME = "ReactNativeMultiBlePeripheral"
  }
}
