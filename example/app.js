import AppsFlyer from 'ti.appsflyer';

// Register listeners before initialize()/start() so first-launch results are retained.
AppsFlyer.addEventListener('deepLink', event => {
  if (event.status === 'FOUND') {
    Ti.API.info(`Deep-link value: ${event.deepLinkValue}`);
    Ti.API.info(`Deferred deep link: ${event.isDeferred}`);

    const referralToken = event.deepLinkSub1;
    // Validate referralToken with the application backend; do not log it.
  } else if (event.status === 'ERROR') {
    Ti.API.error(`AppsFlyer deep-link error: ${event.error}`);
  }
});

AppsFlyer.addEventListener('conversionData', event => {
  if (event.success) {
    // Use event.data only as a fallback when Unified Deep Linking has no result.
    Ti.API.info('AppsFlyer conversion data received');
  } else {
    Ti.API.error(`AppsFlyer conversion error: ${event.error}`);
  }
});

AppsFlyer.initialize({
  devKey: 'YOUR_DEV_KEY',
  appID: 'idXXXXXXXXX', // iOS only
  appInviteOneLinkID: 'YOUR_ONELINK_TEMPLATE_ID',
  debug: false
});

AppsFlyer.start();

function generateInviteLink(referralToken) {
  AppsFlyer.generateInviteLink({
    channel: 'in_app_referral',
    campaign: 'traveler_invite',
    parameters: {
      deep_link_value: 'traveler_invite',
      deep_link_sub1: referralToken
    }
  }, result => {
    if (result.success) {
      // Pass result.url directly to the app's share UI; it contains the token.
      Ti.API.info('AppsFlyer invite URL generated');
    } else {
      Ti.API.error(`Unable to generate invite: ${result.error}`);
    }
  });
}

// Call this after the invite is actually sent or shared.
function logSentInvite() {
  AppsFlyer.logInvite('in_app_referral', {
    campaign: 'traveler_invite'
  });
}

// Example only; supply a short-lived opaque token from your own backend.
// generateInviteLink('OPAQUE_SERVER_REFERRAL_TOKEN');
// logSentInvite();

AppsFlyer.logEvent('event_name', { key1: 'value1', key2: 'value2' });
