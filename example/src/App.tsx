import * as React from 'react';

import { StyleSheet, View, Text } from 'react-native';
import Peripheral, {
  TxPower,
  AdvertiseMode,
} from '@fugood/react-native-multi-ble-peripheral';
import { Buffer } from 'buffer';

export default function App() {
  const [advertising, setAdvertising] = React.useState<boolean>(false);
  const peripheral = React.useRef<Peripheral>();

  React.useEffect(() => {
    const ble = new Peripheral();
    peripheral.current = ble;
    ble
      .startAdvertising(
        {
          '1234': Buffer.from('1234'),
        },
        {
          mode: AdvertiseMode.LOW_POWER,
          txPower: TxPower.HIGH,
          connectable: true,
          includeDeviceName: true,
          includeTxPowerLevel: true,
          manufacturerId: 0x004c,
          manufacturerData: Buffer.from('1234'),
        }
      )
      .then(() => {
        setAdvertising(true);
      });
  }, []);

  return (
    <View style={styles.container}>
      <Text>Advertising: {advertising}</Text>
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
