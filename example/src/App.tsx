import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  Platform,
  TouchableOpacity,
  PermissionsAndroid,
  Alert,
} from 'react-native';
import Peripheral, {
  TxPowerLevel,
  AdvertiseMode,
  Permission,
  Property,
} from '@fugood/react-native-multi-ble-peripheral';
import { Buffer } from 'buffer';

const hrService = Platform.select({
  ios: '180d',
  default: '0000180d-0000-1000-8000-00805f9b34fb',
});

const hrCharacteristic = Platform.select({
  ios: '2a37',
  default: '00002a37-0000-1000-8000-00805f9b34fb',
});

const createValue = () => {
  const val = Math.random() * 100;
  const payload = Buffer.alloc(1);
  payload.writeUInt8(val, 0);
  return payload;
};

export default function App() {
  const [hasPerm, setHasPerm] = React.useState<boolean>(false);
  const [advertising, setAdvertising] = React.useState<boolean>(false);
  const [retry, setRetry] = React.useState<number>(0);
  const peripheral = React.useRef<Peripheral>();

  React.useEffect(() => {
    if (Platform.OS === 'android') {
      (async () => {
        const connGranted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
          {
            title: 'BLE Peripheral Example',
            message: 'BLE Peripheral needs access to your bluetooth',
            buttonNeutral: 'Ask Me Later',
            buttonNegative: 'Cancel',
            buttonPositive: 'OK',
          }
        );
        if (connGranted !== PermissionsAndroid.RESULTS.GRANTED) {
          Alert.alert(
            'Permission Denied',
            'BLE Peripheral Example will not work without bluetooth permission'
          );
          return;
        }
        const advGranted = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_ADVERTISE,
          {
            title: 'BLE Peripheral Example',
            message: 'BLE Peripheral needs access to your bluetooth',
            buttonNeutral: 'Ask Me Later',
            buttonNegative: 'Cancel',
            buttonPositive: 'OK',
          }
        );
        if (advGranted !== PermissionsAndroid.RESULTS.GRANTED) {
          Alert.alert(
            'Permission Denied',
            'BLE Peripheral Example will not work without bluetooth permission'
          );
          return;
        }
        setHasPerm(true);
      })();
    } else {
      setHasPerm(true);
    }
  }, []);

  React.useEffect(() => {
    if (!hasPerm) return;
    Peripheral.setDeviceName(`Example @ ${Platform.OS}`).catch((err) =>
      console.error('SET NAME', err)
    );
  }, [hasPerm]);

  React.useEffect(() => {
    if (!hasPerm) return;
    if (peripheral.current) {
      const oldBLE = peripheral.current;
      oldBLE
        .stopAdvertising()
        .then(() => oldBLE.destroy())
        .catch((err) => {
          console.error(err);
        });
    }
    const ble = new Peripheral();
    peripheral.current = ble;
    ble.on('ready', async () => {
      try {
        console.log('Currect State:', await ble.checkState());
        await ble.addService(hrService, true);
        await ble.addCharacteristic(
          hrService,
          hrCharacteristic,
          // eslint-disable-next-line no-bitwise
          Property.READ | Property.NOTIFY | Property.INIDICATE,
          Permission.READABLE
        );
        await ble.updateValue(
          hrService,
          hrCharacteristic,
          Buffer.from('00', 'hex')
        );
        await ble.startAdvertising(
          {
            [hrService]: Buffer.from(''),
          },
          {
            mode: AdvertiseMode.LOW_POWER,
            txPowerLevel: TxPowerLevel.HIGH,
            connectable: true,
            includeDeviceName: true,
            includeTxPowerLevel: true,
          }
        );
        setAdvertising(true);
      } catch (err) {
        setAdvertising(false);
        console.error('START', err);
      }
    });
    ble.on('error', console.error);
  }, [hasPerm, retry]);

  const update = React.useCallback(() => {
    peripheral.current
      ?.updateValue(hrService, hrCharacteristic, createValue())
      .catch(console.error);
  }, []);

  const notify = React.useCallback(() => {
    peripheral.current
      ?.sendNotification(hrService, hrCharacteristic, createValue(), true)
      .catch(console.error);
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.text}>
        Advertising: {advertising ? '(YES)' : '(NO)'}
      </Text>
      <TouchableOpacity onPress={update} style={styles.btn}>
        <Text style={styles.text}>Random New</Text>
      </TouchableOpacity>
      <TouchableOpacity onPress={notify} style={styles.btn}>
        <Text style={styles.text}>Notify</Text>
      </TouchableOpacity>
      <TouchableOpacity
        onPress={() => setRetry((i) => i + 1)}
        style={styles.btn}
      >
        <Text style={styles.text}>Restart</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'black',
  },
  btn: {
    marginVertical: 5,
  },
  text: {
    fontSize: 20,
    color: 'white',
  },
});
