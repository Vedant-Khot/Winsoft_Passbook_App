/// Thrown when the session cannot be restored after a 401 response.
class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException([
    this.message = 'Your session has expired. Please sign in again.',
  ]);

  @override
  String toString() => message;
}
