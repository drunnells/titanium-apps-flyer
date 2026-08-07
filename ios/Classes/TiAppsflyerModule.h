/**
 * Titanium AppsFlyer SDK
 *
 * Created by Hans Knöchel
 * Copyright (c) 2022-present Hans Knöchel. All rights reserved.
 */

#import "TiModule.h"
#import <AppsFlyerLib/AppsFlyerLib.h>

@interface TiAppsflyerModule : TiModule <UIApplicationDelegate, AppsFlyerLibDelegate, AppsFlyerDeepLinkDelegate> {
}

- (void)initialize:(id)args;

- (void)start:(id)unused;

- (void)requestTrackingAuthorization:(id)callback;

- (NSNumber *)trackingAuthorizationStatus;

- (void)fetchAdvertisingIdentifier:(id)callback;

- (void)logEvent:(id)args;

- (void)generateInviteLink:(id)args;

- (void)logInvite:(id)args;

@end
