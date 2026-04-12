import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:duvet_client/http/router.dart';
import 'package:duvet_client/http/methods.dart';
import 'package:duvet_client/errors.dart';

class SignIn {
  final String token;
  SignIn(this.token);
  SignIn.fromJson(Map<String, dynamic> j) : token = j['token'] as String;
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
        'Authorization': 'Bearer $_token',
        'Cookie': _sessionCookie.value,
        'Content-Type': 'application/json',
      };

  late String _token;
  late Cookie _sessionCookie;

  String get token => _token;
  Cookie get sessionCookie => _sessionCookie;

  bool get isAuthenticated =>
      _token.isNotEmpty && _sessionCookie.value.isNotEmpty;

  RestClient(this.client, {ApiRouter? router})
      : router = router ?? const ApiRouter();

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------

  Future<void> signUp(
      String username, String password, String alias, String email) async {
    final url = router.urlFromPath('/api/auth/signin');
    final response = await client.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'alias': alias,
          'email': email,
        }));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw DuvetApiException(
        action: 'sign up',
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
      );
    }
  }

  Future<SignIn> logIn(String email, String password) async {
    final url = router.urlFromPath('/api/auth/login');
    final response = await client.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw DuvetAuthException(
        action: 'log in',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    if (response.statusCode != 200) {
      throw DuvetApiException(
        action: 'log in',
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
        body: response.body,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = SignIn.fromJson(body);

    for (final MapEntry(:key, :value) in response.headers.entries) {
      if (key.toLowerCase() == 'set-cookie') {
        _sessionCookie = Cookie.fromSetCookieValue(value);
      }
    }
    _token = data.token;
    return data;
  }
}
