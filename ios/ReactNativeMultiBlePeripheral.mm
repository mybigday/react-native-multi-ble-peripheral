#import "ReactNativeMultiBlePeripheral.h"
#import <React/RCTLog.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ReactNativeMultiBlePeripheral () <CBPeripheralManagerDelegate>

@property (nonatomic, assign) BOOL hasListeners;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, CBPeripheralManager *> *managers;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, RCTPromiseRejectBlock> *createRejects;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, RCTPromiseResolveBlock> *createResolves;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, RCTPromiseRejectBlock> *startRejects;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, RCTPromiseResolveBlock> *startResolves;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSString *, CBMutableService *> *> *services;
@property (nonatomic, strong) NSString *deviceName;

@end

@implementation ReactNativeMultiBlePeripheral

RCT_EXPORT_MODULE(ReactNativeMultiBlePeripheral)

- (instancetype)init {
  self = [super init];
  if (self) {
    _managers = [NSMutableDictionary new];
    _createRejects = [NSMutableDictionary new];
    _createResolves = [NSMutableDictionary new];
    _startRejects = [NSMutableDictionary new];
    _startResolves = [NSMutableDictionary new];
    _services = [NSMutableDictionary new];
    _deviceName = @"";
    _hasListeners = NO;
  }
  return self;
}

- (void)dealloc {
  for (CBPeripheralManager *manager in self.managers.allValues) {
    if (manager.isAdvertising) {
      [manager stopAdvertising];
    }
  }
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (NSArray<NSString *> *)supportedEvents {
  return @[@"onWrite", @"onSubscribe", @"onUnsubscribe"];
}

- (void)startObserving {
  self.hasListeners = YES;
}

- (void)stopObserving {
  self.hasListeners = NO;
}

#pragma mark - Helper Methods

- (NSNumber *)keyForPeripheral:(CBPeripheralManager *)peripheral {
  for (NSNumber *key in self.managers) {
    if (self.managers[key] == peripheral) {
      return key;
    }
  }
  return nil;
}

- (CBMutableCharacteristic *)getCharacteristic:(NSNumber *)peripheralId
                                     serviceUUID:(NSString *)serviceUUID
                              characteristicUUID:(NSString *)characteristicUUID {
  CBMutableService *service = self.services[peripheralId][serviceUUID];
  if (!service) return nil;
  
  CBUUID *uuid = [CBUUID UUIDWithString:characteristicUUID];
  for (CBCharacteristic *characteristic in service.characteristics) {
    if ([characteristic.UUID isEqual:uuid]) {
      return (CBMutableCharacteristic *)characteristic;
    }
  }
  return nil;
}

#pragma mark - TurboModule Methods

- (void)setDeviceName:(NSString *)name
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject {
  self.deviceName = name;
  resolve(nil);
}

- (void)createPeripheral:(double)peripheralId
                 resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  self.createResolves[key] = resolve;
  self.createRejects[key] = reject;
  
  CBPeripheralManager *manager = [[CBPeripheralManager alloc] initWithDelegate:self
                                                                          queue:nil
                                                                        options:nil];
  self.managers[key] = manager;
  self.services[key] = [NSMutableDictionary new];
}

- (void)checkState:(double)peripheralId
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBPeripheralManager *manager = self.managers[key];
  
  if (!manager) {
    reject(@"error", @"Peripheral id does not exist", nil);
    return;
  }
  
  NSString *stateName;
  switch (manager.state) {
    case CBManagerStateUnknown:
      stateName = @"unknown";
      break;
    case CBManagerStateResetting:
      stateName = @"resetting";
      break;
    case CBManagerStateUnsupported:
      stateName = @"unsupported";
      break;
    case CBManagerStateUnauthorized:
      stateName = @"unauthorized";
      break;
    case CBManagerStatePoweredOff:
      stateName = @"off";
      break;
    case CBManagerStatePoweredOn:
      stateName = @"on";
      break;
  }
  
  resolve(stateName);
}

- (void)addService:(double)peripheralId
              uuid:(NSString *)uuid
           primary:(BOOL)primary
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBPeripheralManager *manager = self.managers[key];
  
  if (!manager) {
    reject(@"error", @"Peripheral id does not exist", nil);
    return;
  }
  
  CBUUID *serviceUUID = [CBUUID UUIDWithString:uuid];
  CBMutableService *service = [[CBMutableService alloc] initWithType:serviceUUID
                                                              primary:primary];
  service.characteristics = @[];
  
  self.services[key][uuid] = service;
  [manager addService:service];
  
  resolve(nil);
}

- (void)addCharacteristic:(double)peripheralId
              serviceUUID:(NSString *)serviceUUID
       characteristicUUID:(NSString *)characteristicUUID
               properties:(double)properties
              permissions:(double)permissions
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBPeripheralManager *manager = self.managers[key];
  
  if (!manager) {
    reject(@"error", @"Peripheral id does not exist", nil);
    return;
  }
  
  CBMutableService *service = self.services[key][serviceUUID];
  if (!service) {
    reject(@"error", @"Service does not exist", nil);
    return;
  }
  
  CBUUID *uuid = [CBUUID UUIDWithString:characteristicUUID];
  CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc]
                                             initWithType:uuid
                                             properties:(CBCharacteristicProperties)properties
                                             value:nil
                                             permissions:(CBAttributePermissions)permissions];
  
  NSMutableArray *characteristics = [service.characteristics mutableCopy];
  [characteristics addObject:characteristic];
  service.characteristics = characteristics;
  
  // Re-add all services
  [manager removeAllServices];
  for (CBMutableService *svc in self.services[key].allValues) {
    [manager addService:svc];
  }
  
  resolve(nil);
}

- (void)startAdvertising:(double)peripheralId
                services:(NSDictionary * _Nullable)advServices
                 options:(NSDictionary * _Nullable)options
                 resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBPeripheralManager *manager = self.managers[key];
  
  if (!manager) {
    reject(@"error", @"Peripheral id does not exist", nil);
    return;
  }
  
  if (manager.state != CBManagerStatePoweredOn) {
    reject(@"error", @"Peripheral is not powered on", nil);
    return;
  }
  
  if (manager.isAdvertising) {
    reject(@"error", @"Peripheral is already advertising", nil);
    return;
  }
  
  NSMutableArray *uuids = [NSMutableArray new];
  if (advServices) {
    for (NSString *uuidString in advServices.allKeys) {
      [uuids addObject:[CBUUID UUIDWithString:uuidString]];
    }
  } else {
    for (NSString *uuidString in self.services[key].allKeys) {
      [uuids addObject:[CBUUID UUIDWithString:uuidString]];
    }
  }
  
  NSDictionary *advertisementData = @{
    CBAdvertisementDataLocalNameKey: self.deviceName,
    CBAdvertisementDataServiceUUIDsKey: uuids
  };
  
  self.startResolves[key] = resolve;
  self.startRejects[key] = reject;
  
  [manager startAdvertising:advertisementData];
}

- (void)stopAdvertising:(double)peripheralId
                resolve:(RCTPromiseResolveBlock)resolve
                 reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBPeripheralManager *manager = self.managers[key];
  
  if (!manager) {
    reject(@"error", @"Peripheral id does not exist", nil);
    return;
  }
  
  if (manager.isAdvertising) {
    [manager stopAdvertising];
  }
  
  resolve(nil);
}

- (void)updateValue:(double)peripheralId
        serviceUUID:(NSString *)serviceUUID
 characteristicUUID:(NSString *)characteristicUUID
              value:(NSString *)value
            resolve:(RCTPromiseResolveBlock)resolve
             reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBMutableCharacteristic *characteristic = [self getCharacteristic:key
                                                        serviceUUID:serviceUUID
                                                 characteristicUUID:characteristicUUID];
  
  if (!characteristic) {
    reject(@"error", @"Not found characteristic", nil);
    return;
  }
  
  NSData *data = [[NSData alloc] initWithBase64EncodedString:value options:0];
  characteristic.value = data;
  
  resolve(nil);
}

- (void)sendNotification:(double)peripheralId
             serviceUUID:(NSString *)serviceUUID
      characteristicUUID:(NSString *)characteristicUUID
                   value:(NSString *)value
                 confirm:(BOOL)confirm
                 resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBPeripheralManager *manager = self.managers[key];
  CBMutableCharacteristic *characteristic = [self getCharacteristic:key
                                                        serviceUUID:serviceUUID
                                                 characteristicUUID:characteristicUUID];
  
  if (!manager || !characteristic) {
    reject(@"error", @"Not found characteristic", nil);
    return;
  }
  
  NSData *data = [[NSData alloc] initWithBase64EncodedString:value options:0];
  if (!data) {
    reject(@"error", @"Invalid base64 value", nil);
    return;
  }
  
  BOOL didSend = [manager updateValue:data
                    forCharacteristic:characteristic
                 onSubscribedCentrals:nil];
  
  if (didSend) {
    resolve(nil);
  } else {
    reject(@"error", @"Send notification failed", nil);
  }
}

- (void)destroyPeripheral:(double)peripheralId
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject {
  NSNumber *key = @((NSInteger)peripheralId);
  CBPeripheralManager *manager = self.managers[key];
  
  if (!manager) {
    reject(@"error", @"Peripheral id does not exist", nil);
    return;
  }
  
  if (manager.isAdvertising) {
    [manager stopAdvertising];
  }
  
  [manager removeAllServices];
  [self.managers removeObjectForKey:key];
  [self.services removeObjectForKey:key];
  
  resolve(nil);
}

- (void)addListener:(NSString *)eventName {
  // Required for RCTEventEmitter
}

- (void)removeListeners:(double)count {
  // Required for RCTEventEmitter
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
  NSNumber *peripheralId = [self keyForPeripheral:peripheral];
  if (!peripheralId) return;
  
  CBManagerState state = peripheral.state;
  
  RCTPromiseResolveBlock resolve = self.createResolves[peripheralId];
  RCTPromiseRejectBlock reject = self.createRejects[peripheralId];
  
  switch (state) {
    case CBManagerStatePoweredOn:
      if (resolve) {
        resolve(nil);
        [self.createResolves removeObjectForKey:peripheralId];
        [self.createRejects removeObjectForKey:peripheralId];
      }
      break;
    case CBManagerStatePoweredOff:
      if (reject) {
        reject(@"error", @"Peripheral is powered off", nil);
        [self.createRejects removeObjectForKey:peripheralId];
      }
      break;
    case CBManagerStateResetting:
      if (reject) {
        reject(@"error", @"Peripheral is resetting", nil);
        [self.createRejects removeObjectForKey:peripheralId];
      }
      break;
    case CBManagerStateUnauthorized:
      if (reject) {
        reject(@"error", @"Peripheral is unauthorized", nil);
        [self.createRejects removeObjectForKey:peripheralId];
      }
      break;
    case CBManagerStateUnsupported:
      if (reject) {
        reject(@"error", @"Peripheral is unsupported", nil);
        [self.createRejects removeObjectForKey:peripheralId];
      }
      break;
    case CBManagerStateUnknown:
      if (reject) {
        reject(@"error", @"Peripheral state is unknown", nil);
        [self.createRejects removeObjectForKey:peripheralId];
      }
      break;
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
         didReceiveReadRequest:(CBATTRequest *)request {
  NSData *value = request.characteristic.value;
  
  if (!value || request.offset > value.length) {
    [peripheral respondToRequest:request withResult:CBATTErrorInvalidOffset];
    return;
  }
  
  request.value = [value subdataWithRange:NSMakeRange(request.offset, value.length - request.offset)];
  [peripheral respondToRequest:request withResult:CBATTErrorSuccess];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
        didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
  NSNumber *peripheralId = [self keyForPeripheral:peripheral];
  
  for (CBATTRequest *request in requests) {
    CBCharacteristic *characteristic = request.characteristic;
    NSString *characteristicUUID = characteristic.UUID.UUIDString;
    NSString *serviceUUID = characteristic.service.UUID.UUIDString;
    NSString *base64Value = [request.value base64EncodedStringWithOptions:0];
    
    if (self.hasListeners) {
      [self sendEventWithName:@"onWrite" body:@{
        @"id": peripheralId,
        @"serviceUUID": serviceUUID,
        @"characteristicUUID": characteristicUUID,
        @"value": base64Value ?: [NSNull null]
      }];
    }
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
  NSNumber *peripheralId = [self keyForPeripheral:peripheral];
  NSString *characteristicUUID = characteristic.UUID.UUIDString;
  NSString *serviceUUID = characteristic.service.UUID.UUIDString;
  
  if (self.hasListeners) {
    [self sendEventWithName:@"onSubscribe" body:@{
      @"id": peripheralId,
      @"serviceUUID": serviceUUID,
      @"characteristicUUID": characteristicUUID
    }];
  }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
                  central:(CBCentral *)central
didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
  NSNumber *peripheralId = [self keyForPeripheral:peripheral];
  NSString *characteristicUUID = characteristic.UUID.UUIDString;
  NSString *serviceUUID = characteristic.service.UUID.UUIDString;
  
  if (self.hasListeners) {
    [self sendEventWithName:@"onUnsubscribe" body:@{
      @"id": peripheralId,
      @"serviceUUID": serviceUUID,
      @"characteristicUUID": characteristicUUID
    }];
  }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral
                                       error:(NSError *)error {
  NSNumber *peripheralId = [self keyForPeripheral:peripheral];
  if (!peripheralId) return;
  
  RCTPromiseResolveBlock resolve = self.startResolves[peripheralId];
  RCTPromiseRejectBlock reject = self.startRejects[peripheralId];
  
  if (error) {
    if (reject) {
      reject(@"error", [NSString stringWithFormat:@"Fail to start: %@", error], error);
    }
  } else {
    if (resolve) {
      resolve(nil);
    }
  }
  
  [self.startResolves removeObjectForKey:peripheralId];
  [self.startRejects removeObjectForKey:peripheralId];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral
            didAddService:(CBService *)service
                    error:(NSError *)error {
  NSNumber *peripheralId = [self keyForPeripheral:peripheral];
  if (peripheralId) {
    RCTLogInfo(@"Did add service: %@ for peripheral: %@, error: %@", service, peripheralId, error);
  }
}

- (void)peripheralManagerDidStopAdvertising:(CBPeripheralManager *)peripheral
                                      error:(NSError *)error {
  NSNumber *peripheralId = [self keyForPeripheral:peripheral];
  if (peripheralId) {
    RCTLogInfo(@"Did stop advertising for peripheral: %@, error: %@", peripheralId, error);
  }
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params {
  return std::make_shared<facebook::react::NativeReactNativeMultiBlePeripheralSpecJSI>(params);
}

@end
