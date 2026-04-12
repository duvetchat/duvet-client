/// Base exception for all Duvet library errors.
class DuvetException implements Exception {
  final String message;
  const DuvetException(this.message);

  @override
  String toString() => 'DuvetException: $message';
}

/// Thrown when an API call returns a non-2xx response.
class DuvetApiException extends DuvetException {
  final int statusCode;
  final String? reasonPhrase;
  final String? body;

  const DuvetApiException({
    required String action,
    required this.statusCode,
    this.reasonPhrase,
    this.body,
  }) : super('Failed to $action: $statusCode $reasonPhrase');

  @override
  String toString() =>
      'DuvetApiException[$statusCode]: $message\n${body ?? ''}';
}

/// Thrown when authentication credentials are invalid or missing.
class DuvetAuthException extends DuvetApiException {
  const DuvetAuthException(
      {required super.action, required super.statusCode, super.body})
      : super(reasonPhrase: 'Unauthorized');
}

/// Thrown when the gateway receives a malformed message.
class DuvetMalformedMessageException extends DuvetException {
  final Object cause;
  const DuvetMalformedMessageException(this.cause)
      : super('Received malformed message from gateway');

  @override
  String toString() => 'DuvetMalformedMessageException: $cause';
}
