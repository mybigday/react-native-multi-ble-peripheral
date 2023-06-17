# react-native-multi-ble-peripheral

React Native Multi BLE Peripheral Manager

## Installation

```sh
npm install react-native-multi-ble-peripheral
```

### iOS

Add these lines in `Info.plist`

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>For advertise as BLE peripheral</string>
```

### Android

- Add these lines in `AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

- Do this patch if you build on SDK 33+

```diff
diff --git a/android/src/main/java/com/fugood/reactnativemultibleperipheral/ReactNativeMultiBlePeripheralModule.kt b/android/src/main/java/com/fugood/reactnativemultibleperipheral/ReactNativeMultiBlePeripheralModule.kt
index 2e763af..746c0c7 100644
--- a/android/src/main/java/com/fugood/reactnativemultibleperipheral/ReactNativeMultiBlePeripheralModule.kt
+++ b/android/src/main/java/com/fugood/reactnativemultibleperipheral/ReactNativeMultiBlePeripheralModule.kt
@@ -241,7 +241,8 @@ class ReactNativeMultiBlePeripheralModule(reactContext: ReactApplicationContext)
       val response = bluetoothGattServer.notifyCharacteristicChanged(
         device,
         characteristic,
-        confirm
+        confirm,
+        value
       )
       Log.d(NAME, "Notify ${device.name} (${device.address}) response = $response")
     }
```

#### Request permission

> Should check permission before create peripheral instance

```js
import { PermissionsAndroid } from 'react-native';

await PermissionsAndroid.request(
  PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
  options,
);
await PermissionsAndroid.request(
  PermissionsAndroid.PERMISSIONS.BLUETOOTH_ADVERTISE,
  options,
);
```

## Usage

```js
import Peripheral, { Permission, Property } from 'react-native-multi-ble-peripheral';
import { Buffer } from 'buffer';

Peripheral.setDeviceName('MyDevice');

const peripheral = new Peripheral();

peripheral.on('ready', async () => {
  await peripheral.addService('1234', true);
  await peripheral.addCharacteristic(
    '1234',
    'ABCD',
    Property.READ | Property.WRITE,
    Permission.READABLE | Permission.WRITEABLE
  );
  await peripheral.updateValue('1234', 'ABCD', Buffer.from('Hello World!'));
  await peripheral.startAdvertising();
});
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)

---

<p align="center">
  <a href="https://bricks.tools">
    <img width="90px" src="https://avatars.githubusercontent.com/u/17320237?s=200&v=4">
  </a>
  <p align="center">
    Built and maintained by <a href="https://bricks.tools">BRICKS</a>.
  </p>
</p>
