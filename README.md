# @fugood/react-native-multi-ble-peripheral

React Native Multi BLE Peripheral Manager

## Installation

```sh
npm install @fugood/react-native-multi-ble-peripheral
```

## Usage

```js
import Peripheral, { Permission, Property } from '@fugood/react-native-multi-ble-peripheral';
import { Buffer } from 'buffer';

Peripheral.setDeviceName('MyDevice');

const peripheral = new Peripheral();

peripheral.addService('1234', true);

peripheral.addCharacteristic(
  '1234',
  'ABCD',
  Property.READ | Property.WRITE,
  Permission.READABLE | Permission.WRITEABLE
);

peripheral.updateValue('1234', 'ABCD', Buffer.from('Hello World!'));

peripheral.startAdvertising();
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
