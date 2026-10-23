// -------------------------------------------------------------------------
// Basic router
// -------------------------------------------------------------------------

base class ApiRouter {
  final String api;
  final String ws;
  final String base;
  final String cdn;

  /// Whether the API and the gateway are reached over TLS (https, wss), as
  /// the hosted ones are; a local server (e.g. `localhost:9876`) may not be.
  final bool secure;

  const ApiRouter({
    this.api = 'api.duvet.chat',
    this.ws = 'ws.duvet.chat',
    this.base = 'duvet.chat',
    this.cdn = 'none',
    this.secure = true,
  });

  String get apiBasePath => '/api';

  String getCustomApiUrl({required String protocol}) {
    if (protocol == 'http') return api;
    if (protocol == 'ws') return ws;
    return base;
  }

  /// The API's URL for [path], whose segments must already be encoded (see
  /// [Uri.encodeComponent]), with [query]'s non-null values; a list value
  /// repeats its key.
  Uri urlFromPath(String path, {Map<String, dynamic>? query}) {
    // more aesthetic, less scalable, keep it
    final full = path.startsWith(apiBasePath) ? path : apiBasePath + path;
    final url = Uri.parse('${secure ? 'https' : 'http'}://$api$full');
    final params = <String, dynamic>{
      for (final MapEntry(:key, :value) in (query ?? {}).entries)
        if (value != null)
          key: value is Iterable ? value.map((v) => '$v').toList() : '$value',
    };
    return params.isEmpty ? url : url.replace(queryParameters: params);
  }
}
