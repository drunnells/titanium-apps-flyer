/**
 * Titanium AppsFlyer SDK
 *
 * Created by Hans Knöchel
 * Copyright (c) 2022-present Hans Knöchel. All rights reserved.
 */

#import "TiAppsflyerModule.h"
#import "TiApp.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"

#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AppsFlyerLib/AppsFlyerLib.h>
#import <AppsFlyerLib/AppsFlyerShareInviteHelper.h>

@interface TiAppsflyerModule ()

- (void)callInviteCallback:(KrollCallback *)callback url:(NSString *)url error:(NSString *)error;
- (void)emitEvent:(NSString *)name payload:(NSDictionary *)payload;
- (NSString *)deepLinkStringValue:(AppsFlyerDeepLink *)deepLink key:(NSString *)key;
- (NSDictionary *)stringParametersFromValue:(id)value valid:(BOOL *)valid;

@end

@implementation TiAppsflyerModule

#pragma mark Internal

- (id)moduleGUID
{
  return @"ac995713-e6a6-4463-91cc-5c6b4ffdcb02";
}

- (NSString *)moduleId
{
  return @"ti.appsflyer";
}

- (void)_configure
{
  [super _configure];
  [[TiApp app] registerApplicationDelegate:self];

  // These delegates must be in place before start() to receive first-launch data.
  [[AppsFlyerLib shared] setDelegate:self];
  [[AppsFlyerLib shared] setDeepLinkDelegate:self];
}

- (void)_destroy
{
  [super _destroy];
  [[TiApp app] unregisterApplicationDelegate:self];

  if ([[AppsFlyerLib shared] delegate] == self) {
    [[AppsFlyerLib shared] setDelegate:nil];
  }
  if ([[AppsFlyerLib shared] deepLinkDelegate] == self) {
    [[AppsFlyerLib shared] setDeepLinkDelegate:nil];
  }
}

#pragma mark Public APIs

- (void)initialize:(id)args
{
  ENSURE_SINGLE_ARG(args, NSDictionary);

  NSString *devKey = [TiUtils stringValue:args[@"devKey"]];
  NSString *appID = [TiUtils stringValue:args[@"appID"]];
  NSInteger authorizationTimeout = [TiUtils intValue:args[@"authorizationTimeout"] def:-1];
  BOOL debugMode = [TiUtils boolValue:args[@"debug"] def:NO];
  NSString *appInviteOneLinkID = [args[@"appInviteOneLinkID"] isKindOfClass:[NSString class]] ? args[@"appInviteOneLinkID"] : nil;

  [[AppsFlyerLib shared] setAppsFlyerDevKey:devKey];
  [[AppsFlyerLib shared] setAppleAppID:appID];
  [[AppsFlyerLib shared] setIsDebug:debugMode];
  [[AppsFlyerLib shared] setUseUninstallSandbox:debugMode];

  if (appInviteOneLinkID.length > 0) {
    [[AppsFlyerLib shared] setAppInviteOneLink:appInviteOneLinkID];
  }

  if (authorizationTimeout != -1) {
    [[AppsFlyerLib shared] waitForATTUserAuthorizationWithTimeoutInterval:authorizationTimeout];
  }
}

- (void)start:(id)unused
{
  [[AppsFlyerLib shared] start];
}

- (void)requestTrackingAuthorization:(id)callback
{
  ENSURE_SINGLE_ARG(callback, KrollCallback);

  [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
    [callback call:@[ @{@"status" : @(status)} ] thisObject:self];
  }];
}

- (NSNumber *)trackingAuthorizationStatus
{
  return @(ATTrackingManager.trackingAuthorizationStatus);
}

- (void)fetchAdvertisingIdentifier:(id)callback
{
  ENSURE_SINGLE_ARG(callback, KrollCallback);

  [callback call:@[ @{
    @"idfa" : [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString]
  } ]
      thisObject:self];
}

- (void)logEvent:(id)args
{
  NSString *eventName = [TiUtils stringValue:args[0]];
  NSDictionary *values = args[1];

  [[AppsFlyerLib shared] logEvent:eventName withValues:values];
}

- (void)generateInviteLink:(id)args
{
  NSDictionary *params = nil;
  KrollCallback *callback = nil;
  ENSURE_ARG_AT_INDEX(params, args, 0, NSDictionary);
  ENSURE_ARG_AT_INDEX(callback, args, 1, KrollCallback);

  BOOL parametersAreValid = YES;
  NSDictionary *parameters = [self stringParametersFromValue:params[@"parameters"] valid:&parametersAreValid];
  if (!parametersAreValid) {
    [self callInviteCallback:callback url:nil error:@"parameters must contain only string keys and values"];
    return;
  }

  NSString *channel = [params[@"channel"] isKindOfClass:[NSString class]] ? params[@"channel"] : nil;
  NSString *campaign = [params[@"campaign"] isKindOfClass:[NSString class]] ? params[@"campaign"] : nil;

  @try {
    [AppsFlyerShareInviteHelper
        generateInviteUrlWithLinkGenerator:^AppsFlyerLinkGenerator *(AppsFlyerLinkGenerator *generator) {
          if (channel.length > 0) {
            [generator setChannel:channel];
          }
          if (campaign.length > 0) {
            [generator setCampaign:campaign];
          }
          if (parameters.count > 0) {
            [generator addParameters:parameters];
          }
          return generator;
        }
        completionHandler:^(NSURL *url) {
          NSString *urlString = url.absoluteString;
          if (urlString.length > 0) {
            [self callInviteCallback:callback url:urlString error:nil];
          } else {
            [self callInviteCallback:callback url:nil error:@"Unable to generate AppsFlyer invite URL"];
          }
        }];
  } @catch (NSException *exception) {
    [self callInviteCallback:callback url:nil error:exception.reason ?: @"Unable to generate AppsFlyer invite URL"];
  }
}

- (void)logInvite:(id)args
{
  NSString *channel = nil;
  NSDictionary *inputParameters = nil;
  ENSURE_ARG_AT_INDEX(channel, args, 0, NSString);
  ENSURE_ARG_AT_INDEX(inputParameters, args, 1, NSDictionary);

  BOOL parametersAreValid = YES;
  NSDictionary *parameters = [self stringParametersFromValue:inputParameters valid:&parametersAreValid];
  if (!parametersAreValid) {
    [self throwException:TiExceptionInvalidType
               subreason:@"parameters must contain only string keys and values"
                location:CODELOCATION];
    return;
  }

  [AppsFlyerShareInviteHelper logInvite:channel parameters:parameters];
}

#pragma mark AppsFlyer delegates

- (void)didResolveDeepLink:(AppsFlyerDeepLinkResult *)result
{
  NSString *status = @"ERROR";
  switch (result.status) {
  case AFSDKDeepLinkResultStatusFound:
    status = @"FOUND";
    break;
  case AFSDKDeepLinkResultStatusNotFound:
    status = @"NOT_FOUND";
    break;
  case AFSDKDeepLinkResultStatusFailure:
    status = @"ERROR";
    break;
  }

  AppsFlyerDeepLink *deepLink = result.deepLink;
  NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:@{
    @"status" : status,
    @"isDeferred" : @(deepLink != nil ? deepLink.isDeferred : NO),
    @"deepLinkValue" : NULL_IF_NIL(deepLink.deeplinkValue),
    @"parameters" : deepLink.clickEvent ?: @{},
    @"error" : NULL_IF_NIL(result.error.localizedDescription)
  }];

  for (NSInteger index = 1; index <= 10; index++) {
    NSString *parameterName = [NSString stringWithFormat:@"deep_link_sub%ld", (long)index];
    NSString *eventName = [NSString stringWithFormat:@"deepLinkSub%ld", (long)index];
    event[eventName] = NULL_IF_NIL([self deepLinkStringValue:deepLink key:parameterName]);
  }

  [self emitEvent:@"deepLink" payload:event];
}

- (void)onConversionDataSuccess:(NSDictionary *)conversionInfo
{
  [self emitEvent:@"conversionData"
          payload:@{
            @"success" : @YES,
            @"data" : conversionInfo ?: @{}
          }];
}

- (void)onConversionDataFail:(NSError *)error
{
  [self emitEvent:@"conversionData"
          payload:@{
            @"success" : @NO,
            @"error" : error.localizedDescription ?: @"Unable to retrieve AppsFlyer conversion data"
          }];
}

#pragma mark UIApplication delegate

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
  [[AppsFlyerLib shared] handleOpenUrl:url options:options];
  return YES;
}

- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *_Nullable restorableObjects))restorationHandler
{
  return [[AppsFlyerLib shared] continueUserActivity:userActivity
                                  restorationHandler:^(NSArray *restorableObjects) {
                                    restorationHandler(restorableObjects);
                                  }];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
  [[AppsFlyerLib shared] registerUninstall:deviceToken];
}

#pragma mark Helpers

- (void)callInviteCallback:(KrollCallback *)callback url:(NSString *)url error:(NSString *)error
{
  NSDictionary *result = url != nil
      ? @{ @"success" : @YES, @"url" : url }
      : @{ @"success" : @NO, @"error" : error ?: @"Unable to generate AppsFlyer invite URL" };
  [callback callAsync:@[ result ] thisObject:self];
}

- (void)emitEvent:(NSString *)name payload:(NSDictionary *)payload
{
  TiThreadPerformOnMainThread(^{
    [self fireEvent:name withObject:payload];
  },
      NO);
}

- (NSString *)deepLinkStringValue:(AppsFlyerDeepLink *)deepLink key:(NSString *)key
{
  id value = deepLink.clickEvent[key];
  if ([value isKindOfClass:[NSString class]]) {
    return value;
  }
  if ([value respondsToSelector:@selector(stringValue)]) {
    return [value stringValue];
  }
  return nil;
}

- (NSDictionary *)stringParametersFromValue:(id)value valid:(BOOL *)valid
{
  if (value == nil || value == [NSNull null]) {
    *valid = YES;
    return @{};
  }
  if (![value isKindOfClass:[NSDictionary class]]) {
    *valid = NO;
    return @{};
  }

  NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
  for (id key in value) {
    id parameterValue = value[key];
    if (![key isKindOfClass:[NSString class]] || ![parameterValue isKindOfClass:[NSString class]]) {
      *valid = NO;
      return @{};
    }
    parameters[key] = parameterValue;
  }

  *valid = YES;
  return parameters;
}

@end
