#import <React/RCTBridgeModule.h>
#import <Foundation/Foundation.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(ReactNativeMultiBlePeripheral, RCTEventEmitter)

RCT_EXTERN_METHOD(setDeviceName:(NSString *)name
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(createPeripheral:(NSInteger *)index
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(destroyPeripheral:(NSInteger *)index
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(checkState:(NSInteger *)index
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addService:(NSInteger *)index
                  serviceUUID:(NSString *)uuid
                  primary:(BOOL)primary
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addCharacteristic:(NSInteger *)index
                  serviceUUID:(NSString *)serviceUUID
                  characteristicUUID:(NSString *)uuid
                  properties:(NSInteger *)properties
                  permissions:(NSInteger *)permissions
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(startAdvertising:(NSInteger *)index
                  withServices:(nullable NSDictionary *)services
                  withOptions:(nullable NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(stopAdvertising:(NSInteger *)index
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(updateValue:(NSInteger *)index
                  serviceUUID:(NSString *)serviceUUID
                  characteristicUUID:(NSString *)characteristicUUID
                  value:(NSString *)value
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(sendNotification:(NSInteger *)index
                  serviceUUID:(NSString *)serviceUUID
                  characteristicUUID:(NSString *)characteristicUUID
                  value:(NSString *)value
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

@end
