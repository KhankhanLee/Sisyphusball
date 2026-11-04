bool get piSdkLoaded => false;

Future<String> piAuthenticate({required bool sandbox}) =>
    Future.error(UnsupportedError('Pi SDK is only available on the web'));

Future<String> piShowInterstitial() async => 'ADS_NOT_SUPPORTED';

bool get piInSandboxFrame => false;
