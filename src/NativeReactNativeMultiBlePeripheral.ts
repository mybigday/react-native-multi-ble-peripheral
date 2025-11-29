import { TurboModuleRegistry, type TurboModule } from 'react-native';

export interface Spec extends TurboModule {
  setDeviceName(name: string): Promise<void>;
  createPeripheral(id: number): Promise<void>;
  checkState(id: number): Promise<string>;
  addService(id: number, uuid: string, primary: boolean): Promise<void>;
  addCharacteristic(
    id: number,
    serviceUuid: string,
    characteristicUuid: string,
    properties: number,
    permissions: number
  ): Promise<void>;
  updateValue(
    id: number,
    serviceUuid: string,
    characteristicUuid: string,
    value: string
  ): Promise<void>;
  sendNotification(
    id: number,
    serviceUuid: string,
    characteristicUuid: string,
    value: string,
    confirm: boolean
  ): Promise<void>;
  startAdvertising(
    id: number,
    services: Object | null,
    options: Object | null
  ): Promise<void>;
  stopAdvertising(id: number): Promise<void>;
  destroyPeripheral(id: number): Promise<void>;

  // EventEmitter
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.get<Spec>('ReactNativeMultiBlePeripheral');
