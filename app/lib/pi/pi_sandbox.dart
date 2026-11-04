/// Whether a page referrer is the Pi Developer Portal sandbox.
bool isPiSandboxReferrer(String referrer) {
  final uri = Uri.tryParse(referrer);
  return uri != null && uri.scheme == 'https' && uri.host == 'sandbox.minepi.com';
}
