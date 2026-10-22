import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:math' show min;

import 'package:http/http.dart' as http;
import 'package:duvet_client/http/router.dart';
import 'package:duvet_client/http/methods.dart';
import 'package:duvet_client/errors.dart';

/// The tokens logging in or refreshing the session gives.
class SignIn {
  /// The access token, sent as `Authorization: Bearer`.
  final String token;

  /// The session (refresh) token, sent as `X-Session-Token`.
  final String? sessionToken;

  SignIn(this.token, {this.sessionToken});
  SignIn.fromJson(Map<String, dynamic> j)
      : token = j['token'] as String,
        sessionToken = j['session_token'] as String?;
}

// ---------------------------------------------------------------------------
// REST client
// ---------------------------------------------------------------------------

class RestClient with RestMethods {
  @override
  final http.Client client;

  @override
  final ApiRouter router;

  @override
  Map<String, String> get authHeaders => {
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
        if (_sessionToken.isNotEmpty) 'X-Session-Token': _sessionToken,
      };

  String _token;
  String _sessionToken;

  String get token => _token;
  String get sessionToken => _sessionToken;

  bool get isAuthenticated => _token.isNotEmpty;

  /// A client for the API; [token] and [sessionToken] resume a session
  /// [logIn] started before.
  RestClient(this.client,
      {ApiRouter? router, String token = '', String sessionToken = ''})
      : router = router ?? const ApiRouter(),
        _token = token,
        _sessionToken = sessionToken;

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------

  Future<SignIn> logIn(String email, String password) async {
    final response = await request('POST', '/api/auth/login', 'log in',
        json: {'email': email, 'password': password}, renew: false);
    return _keep(response);
  }

  /// Ends the session. Best effort: the tokens are forgotten either way.
  Future<void> logout() async {
    try {
      await request('POST', '/api/auth/logout', 'log out', renew: false);
    } on Exception {
      // Best effort — clear local state regardless
    } finally {
      _token = '';
      _sessionToken = '';
    }
  }

  Future<SignIn>? _refreshing;

  /// Rotates the session's tokens. Concurrent callers share one request. A
  /// rejected session (401/403) forgets the tokens; rate limits, server and
  /// network errors don't.
  Future<SignIn> refreshSession() =>
      _refreshing ??= _requestRefresh().whenComplete(() => _refreshing = null);

  Future<SignIn> _requestRefresh() async {
    final sessionToken = _sessionToken;
    Future<http.Response> refresh() =>
        client.post(router.urlFromPath('/api/auth/refresh'), headers: {
          if (sessionToken.isNotEmpty) 'X-Session-Token': sessionToken,
        });

    var response = await refresh();
    // A 429 means "try again later", not an invalid session: wait as long as
    // the API says, up to 20s per attempt so queued requests aren't held for
    // minutes.
    for (var attempt = 0;
        response.statusCode == 429 && attempt < 3;
        attempt++) {
      final wait = num.tryParse(response.headers['retry-after'] ??
              response.headers['x-ratelimit-reset-after'] ??
              '') ??
          1;
      await Future<void>.delayed(Duration(seconds: min(wait.ceil(), 20)));
      response = await refresh();
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _token = '';
      _sessionToken = '';
      throw DuvetAuthException(
          action: 'refresh session',
          statusCode: response.statusCode,
          body: response.body);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DuvetApiException(
          action: 'refresh session',
          statusCode: response.statusCode,
          reasonPhrase: response.reasonPhrase,
          body: response.body);
    }
    return _keep(response);
  }

  @override
  Future<bool> renewSession() async {
    if (_sessionToken.isEmpty) return false;
    try {
      await refreshSession();
      return true;
    } on Exception {
      return false;
    }
  }

  SignIn _keep(http.Response response) {
    final data =
        SignIn.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _token = data.token;
    if (data.sessionToken case final session? when session.isNotEmpty) {
      _sessionToken = session;
    }
    return data;
  }
}
