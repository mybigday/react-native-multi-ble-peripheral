import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  Platform,
  TouchableOpacity,
  NativeModules,
} from 'react-native';
import Peripheral, {
  TxPower,
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

export default function App() {
  const [advertising, setAdvertising] = React.useState<boolean>(false);
  const [retry, setRetry] = React.useState<number>(0);
  const peripheral = React.useRef<Peripheral>();

  React.useEffect(() => {
    Peripheral.setDeviceName('Example BLE')
      .catch(err => console.error('SET NAME', err));
  }, []);

  React.useEffect(() => {
    if (peripheral.current) {
      const oldBLE = peripheral.current;
      oldBLE.stopAdvertising().then(() =>
        oldBLE.destroy()
      ).catch((err) => {
        console.error(err);
      });
    }
    const ble = new Peripheral();
    peripheral.current = ble;
    ble.on('ready', () => {
      // wait power on
      setTimeout(async () => {
        try {
          console.log('Currect State:', await ble.checkState());
          await ble.addService(hrService, true);
          await ble.addCharacteristic(
            hrService,
            hrCharacteristic,
            Property.READ | Property.NOTIFY, // eslint-disable-line no-bitwise
            Permission.READABLE
          );
          await ble.updateValue(
            hrService,
            hrCharacteristic,
            Buffer.from('00', 'hex')
          );
          await ble.startAdvertising({
            [hrService]: Buffer.from(''),
          }, {
            mode: AdvertiseMode.LOW_POWER,
            txPower: TxPower.HIGH,
            connectable: true,
            includeDeviceName: true,
            includeTxPowerLevel: true,
          });
          setAdvertising(true);
        } catch (err) {
          setAdvertising(false);
          console.error('START', err);
        }
      }, 100);
    });
    ble.on('error', console.error);
  }, [retry]);

  const notify = React.useCallback(() => {
    peripheral.current?.sendNotification(
      hrService,
      hrCharacteristic,
      Buffer.from('11', 'hex')
    ).catch(console.error);
  }, []);

  return (
    <View style={styles.container}>
      <Text style={styles.text}>Advertising: {advertising ? '(YES)' : '(NO)'}</Text>
      <TouchableOpacity onPress={notify} style={styles.box}>
        <Text style={styles.text}>Notify</Text>
      </TouchableOpacity>
      <TouchableOpacity onPress={() => setRetry((i) => i+1)} style={styles.box}>
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
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
  text: {
    fontSize: 20,
    color: 'white',
  },
});
