import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  Platform,
  TouchableOpacity,
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
  const peripheral = React.useRef<Peripheral>();

  React.useEffect(() => {
    const ble = new Peripheral();
    peripheral.current = ble;
    (async () => {
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
        Buffer.from('22', 'hex')
      );
      await ble.startAdvertising({
        mode: AdvertiseMode.LOW_POWER,
        txPower: TxPower.HIGH,
        connectable: true,
        includeDeviceName: true,
        includeTxPowerLevel: true,
      });
      setAdvertising(true);
    })();
  }, []);

  const notify = React.useCallback(async () => {
    await peripheral.current?.sendNotification(
      hrService,
      hrCharacteristic,
      Buffer.from('11', 'hex')
    );
  }, []);

  return (
    <View style={styles.container}>
      <Text>Advertising: {advertising}</Text>
      <TouchableOpacity onPress={notify} style={styles.box}>
        <Text>Notify</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
