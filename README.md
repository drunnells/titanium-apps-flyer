# Titanium AppsFlyer SDK

<img src="./.github/apps-flyer-logo.png" height="80" />

Use the native AppsFlyer SDKs in Titanium apps. The module currently bundles AppsFlyer 6.17.8 on iOS and 6.17.5 on Android.

## Requirements

- iOS 15 or later
- Android 5 or later
- Titanium SDK 13.0.0 or later
- An AppsFlyer account and configured AppsFlyer app

## Initialization

Register attribution listeners before calling `initialize()` and `start()` so first-launch deferred deep-link and conversion data are not missed.

```js
import AppsFlyer from 'ti.appsflyer';

AppsFlyer.addEventListener('deepLink', event => {
  if (event.status === 'FOUND') {
    Ti.API.info(`Deep-link value: ${event.deepLinkValue}`);
    Ti.API.info(`Deferred: ${event.isDeferred}`);
  } else if (event.status === 'ERROR') {
    Ti.API.error(event.error);
  }
});

AppsFlyer.addEventListener('conversionData', event => {
  if (event.success) {
    // Use event.data as a fallback attribution source when needed.
    Ti.API.info('AppsFlyer conversion data received');
  } else {
    Ti.API.error(event.error);
  }
});

AppsFlyer.initialize({
  devKey: 'YOUR_DEV_KEY',
  appID: 'idXXXXXXXXX', // iOS only; use the App Store ID
  appInviteOneLinkID: 'H5hv',
  authorizationTimeout: 60, // iOS only; defers SDK processing for ATT
  debug: false
});

AppsFlyer.start();
```

`appInviteOneLinkID` is the template ID from the AppsFlyer OneLink template, not a full URL. Set it in `initialize()` before `start()` when using invite links.

## User invite links

### `generateInviteLink(params, callback)`

Generates a user-invite OneLink through the native AppsFlyer SDK. `channel` and `campaign` are optional. All keys and values in `parameters` must be strings; supported AppsFlyer values such as `deep_link_value`, `deep_link_sub1` through `deep_link_sub10`, and `af_sub1` through `af_sub5` can be supplied without module-specific filtering.

```js
AppsFlyer.generateInviteLink({
  channel: 'in_app_referral',
  campaign: 'traveler_invite',
  parameters: {
    deep_link_value: 'traveler_invite',
    deep_link_sub1: 'OPAQUE_SERVER_REFERRAL_TOKEN'
  }
}, result => {
  if (result.success) {
    // Pass result.url directly to the app's share UI.
    Ti.API.info('AppsFlyer invite URL generated');
  } else {
    Ti.API.error(result.error);
  }
});
```

The callback receives either `{ success: true, url }` or `{ success: false, error }`.

### `logInvite(channel, parameters)`

Logs AppsFlyer's native `af_invite` event after the user sends or shares an invite.

```js
AppsFlyer.logInvite('in_app_referral', {
  campaign: 'traveler_invite'
});
```

## Unified Deep Linking

The `deepLink` event is emitted for direct and deferred Unified Deep Linking results. Unified Deep Linking is the primary app-open attribution mechanism; conversion data does not generate duplicate `deepLink` events.

```js
AppsFlyer.addEventListener('deepLink', event => {
  Ti.API.info(event.status); // FOUND, NOT_FOUND, or ERROR
  Ti.API.info(event.isDeferred);
  Ti.API.info(event.deepLinkValue);

  const referralToken = event.deepLinkSub1;
  // Validate referralToken with the application backend; do not log it.
});
```

The normalized event contains:

```js
{
  status: 'FOUND' | 'NOT_FOUND' | 'ERROR',
  isDeferred: true | false,
  deepLinkValue: String | null,
  deepLinkSub1: String | null,
  deepLinkSub2: String | null,
  deepLinkSub3: String | null,
  deepLinkSub4: String | null,
  deepLinkSub5: String | null,
  deepLinkSub6: String | null,
  deepLinkSub7: String | null,
  deepLinkSub8: String | null,
  deepLinkSub9: String | null,
  deepLinkSub10: String | null,
  parameters: Object,
  error: String | null
}
```

`parameters` contains the native AppsFlyer click-event data where available. Treat referral identifiers as sensitive application data and avoid logging them in production.

## Conversion data

The `conversionData` event exposes AppsFlyer install conversion data as a supplemental fallback for deferred attribution.

```js
AppsFlyer.addEventListener('conversionData', event => {
  if (event.success) {
    // Read event.data only when Unified Deep Linking did not provide a result.
    Ti.API.info('AppsFlyer conversion data received');
  } else {
    Ti.API.error(event.error);
  }
});
```

Success events have the shape `{ success: true, data }`; failures have `{ success: false, error }`.

## Existing APIs

### `start()`

```js
AppsFlyer.start();
```

### `requestTrackingAuthorization(callback)` (iOS only)

```js
AppsFlyer.requestTrackingAuthorization(({ status }) => {
  // For example, status === 3 is authorized.
});
```

### `trackingAuthorizationStatus` (iOS only)

```js
Ti.API.info(AppsFlyer.trackingAuthorizationStatus === 3);
```

### `fetchAdvertisingIdentifier(callback)`

```js
AppsFlyer.fetchAdvertisingIdentifier(({ idfa }) => {
  // IDFA on iOS or the advertising ID on Android.
});
```

### `logEvent(eventName, parameters)`

```js
AppsFlyer.logEvent('my_event', { param1: 'hello', param2: 'world' });
```

## AppsFlyer and app configuration

Before testing invites or deep links:

- Create a OneLink template in the AppsFlyer dashboard and pass its template ID as `appInviteOneLinkID`.
- Associate the template with the same iOS App Store ID, Android package, URL scheme, and deep-link values used by the Titanium app.
- Configure iOS Universal Links/Associated Domains and Android App Links/intent filters for the OneLink or branded domain in the consuming app's `tiapp.xml`.
- Configure the OneLink template's redirect and fallback behavior in AppsFlyer.
- Test deferred links using a device that AppsFlyer recognizes as a fresh install, following AppsFlyer's test-device and reinstall guidance.

No app-level Objective-C, Swift, Java, or Kotlin integration is required. Live link generation and direct/deferred attribution still require a valid AppsFlyer dashboard app, OneLink template, credentials, and device installation flow.

## Example

See `example/app.js` for a complete integration outline using placeholder credentials.

## License

MIT

## Author

Hans Knöchel
