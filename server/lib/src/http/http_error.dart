/// Thrown anywhere below the HTTP layer; the error middleware turns it into
/// a JSON response with [status].
class HttpError implements Exception {
  HttpError(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'HttpError($status, $message)';
}
