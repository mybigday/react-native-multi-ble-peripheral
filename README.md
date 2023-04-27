# react-native-multi-ble-peripheral

React Native Multi BLE Peripheral Manager

## Installation

```sh
npm install react-native-multi-ble-peripheral
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
})
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
