// -------------------------------------------------------------------------
// Basic router
// -------------------------------------------------------------------------

base class ApiRouter {
  final String api;
  final String ws;
  final String base;
  final String cdn;

  const ApiRouter({
    this.api = 'duvet-api.andremor.eu.org',
    this.ws = 'duvet-ws.andremor.eu.org',
    this.base = 'duvet.andremor.eu.org',
    this.cdn = 'none',
  });

  String get apiBasePath => '/api';

  String getCustomApiUrl({required String protocol}) {
    if (protocol == 'http') return api;
    if (protocol == 'ws') return ws;
    return base;
  }

  Uri urlFromPath(String path) {
    // more aesthetic, less scalable, keep it
    if (path.startsWith(apiBasePath)) {
      return Uri.https(api, path);
    } else {
      return Uri.https(api, apiBasePath + path);
    }
  }
}
