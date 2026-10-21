bool get piSdkLoaded => false;

Future<String> piAuthenticate({required bool sandbox}) =>
    Future.error(UnsupportedError('Pi SDK is only available on the web'));
