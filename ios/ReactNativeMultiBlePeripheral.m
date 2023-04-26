#import <React/RCTBridgeModule.h>
#import <Foundation/Foundation.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(ReactNativeMultiBlePeripheral, RCTEventEmitter)

RCT_EXTERN_METHOD(createPeripheral:(NSNumber *)index
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(destroyPeripheral:(NSNumber *)index
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addService:(NSNumber *)index
                  serviceUUID:(NSString *)uuid
                  primary:(BOOL)primary
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addCharacteristic:(NSNumber *)index
                  serviceUUID:(NSString *)serviceUUID
                  characteristicUUID:(NSString *)uuid
                  properties:(NSNumber *)properties
                  permissions:(NSNumber *)permissions
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(startAdvertising:(NSNumber *)index
                  withServices:(nullable NSDictionary *)services
                  withOptions:(nullable NSDictionary *)options
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(stopAdvertising:(NSNumber *)index
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(updateValue:(NSNumber *)index
                  serviceUUID:(NSString *)serviceUUID
                  characteristicUUID:(NSString *)characteristicUUID
                  value:(NSString *)value
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(sendNotification:(NSNumber *)index
                  serviceUUID:(NSString *)serviceUUID
                  characteristicUUID:(NSString *)characteristicUUID
                  value:(NSString *)value
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

@end
