// How the gateway connection opens, drops and opens again, against a fake
// gateway on 127.0.0.1: one socket at a time, each attempt within its timeout,
// no socket after destroy(), and the token kept out of the logs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:duvet_client/duvet.dart';
import 'package:duvet_client/gateway/client.dart' show reconnectDelay;
import 'package:duvet_client/http/router.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _token = 'secret-access-token-0123';

/// What the fake gateway does with an upgrade request.
enum _Answer { upgrade, refuse, hold }

/// A gateway on 127.0.0.1 that answers each upgrade request as [plan] says,
/// and identify with READY, as the real one does.
class _FakeGateway {
  _FakeGateway._(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeGateway> start() async =>
      _FakeGateway._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  /// What to do with the nth upgrade request (from 0).
  _Answer Function(int n) plan = (_) => _Answer.upgrade;

  /// Each upgrade request's token, and when it came.
  final tokens = <String?>[];
  final at = <DateTime>[];

  /// The sockets open now, and the most that were open at once.
  final open = <WebSocket>[];
  int mostOpen = 0;

  /// The identify payloads, in order.
  final identified = <Map<String, dynamic>>[];
  final _identifies = StreamController<void>.broadcast();

  final _held = <HttpRequest>[];

  ApiRouter get router => ApiRouter(
      api: '127.0.0.1:${_server.port}',
      ws: '127.0.0.1:${_server.port}',
      secure: false);

  /// Completes once [count] identifies came.
  Future<void> identifies(int count) async {
    while (identified.length < count) {
      await _identifies.stream.first.timeout(const Duration(seconds: 10));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final n = tokens.length;
    tokens.add(request.uri.queryParameters['token']);
    at.add(DateTime.now());
    switch (plan(n)) {
      case _Answer.refuse:
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      case _Answer.hold:
        _held.add(request);
      case _Answer.upgrade:
        final socket = await WebSocketTransformer.upgrade(request);
        open.add(socket);
        mostOpen = max(mostOpen, open.length);
        socket.listen((raw) {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          switch (message['type']) {
            case 'identify':
              identified.add(message['data'] as Map<String, dynamic>);
              socket.add(jsonEncode({
                'event': 'payload',
                'op': 1,
                's': 1,
                'd': {'type': 'READY', 'data': _ready},
              }));
              _identifies.add(null);
            case 'heartbeat':
              socket.add(jsonEncode({'event': 'heartbeat_ack'}));
          }
        }, onDone: () => open.remove(socket));
    }
  }

  Future<void> close() async {
    for (final socket in [...open]) {
      await socket.close();
    }
    await _server.close(force: true);
    await _identifies.close();
  }
}

final _ready = {
  'user': {
    'id': 'u1',
    'username': 'gaby',
    'created_at': '2026-10-23T09:00:00Z',
    'updated_at': '2026-10-23T09:00:00Z',
  },
  'sessionToken': 'session-1',
};

/// A manager for [gateway], keeping its states and logs.
({
  GatewayManager manager,
  List<GatewayConnectionState> states,
  List<String> logs
}) _manager(_FakeGateway gateway, {Duration? connectTimeout}) {
  final logs = <String>[];
  final manager = GatewayManager(
      RestClient(http.Client(), token: _token, router: gateway.router),
      router: gateway.router,
      log: (_, msg) => logs.add(msg),
      connectTimeout: connectTimeout ?? defaultConnectTimeout);
  final states = <GatewayConnectionState>[];
  manager.onConnectionState.listen(states.add);
  return (manager: manager, states: states, logs: logs);
}

void main() {
  late _FakeGateway gateway;

  setUp(() async {
    gateway = await _FakeGateway.start();
    addTearDown(gateway.close);
  });

  test('connects, identifies with the token and hears READY', () async {
    final g = _manager(gateway);
    addTearDown(g.manager.destroy);
    final ready = g.manager.ready;

    await g.manager.connectAll();
    expect((await ready).user.id, 'u1');
    expect(gateway.tokens, [_token]);
    // A person's: no shard, which the gateway would refuse (4000).
    expect(gateway.identified.single, {'token': _token});
    expect(g.states, [
      GatewayConnectionState.connecting,
      GatewayConnectionState.connected,
    ]);
    expect(g.logs, contains(startsWith('connecting to ws://127.0.0.1:')));
    expect(g.logs.join('\n'), isNot(contains(_token)));
  });

  test('a dropped socket is replaced by one new socket, which identifies',
      () async {
    final g = _manager(gateway);
    addTearDown(g.manager.destroy);
    await g.manager.connectAll();
    await gateway.identifies(1);

    final reconnected = g.manager.onConnectionState
        .where((s) => s == GatewayConnectionState.connected)
        .first;
    await gateway.open.single.close(); // the gateway drops it
    await reconnected;
    await gateway.identifies(2);
    // Nothing else opens later.
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(gateway.tokens, [_token, _token]);
    expect(gateway.mostOpen, 1);
    expect(gateway.open, hasLength(1));
    expect(g.states, [
      GatewayConnectionState.connecting,
      GatewayConnectionState.connected,
      GatewayConnectionState.reconnecting,
      GatewayConnectionState.connected,
    ]);
  });

  test('the first connection keeps trying until the gateway takes it',
      () async {
    gateway.plan = (n) => n < 2 ? _Answer.refuse : _Answer.upgrade;
    final g = _manager(gateway);
    addTearDown(g.manager.destroy);

    await g.manager.connectAll();
    await gateway.identifies(1);
    expect(gateway.tokens, hasLength(3));
    expect(g.states, [
      GatewayConnectionState.connecting,
      // The first attempt failed; the manager tries again at once.
      GatewayConnectionState.disconnected,
      GatewayConnectionState.reconnecting,
      GatewayConnectionState.connected,
    ]);
    // The refusals' errors carry the URL, but not the token in it.
    expect(g.logs, contains(contains('was not upgraded to websocket')));
    expect(g.logs.join('\n'), isNot(contains(_token)));

    // As the desktop app waits: a second, then two, each plus up to one.
    final waits = [
      for (final m in g.logs
          .map(RegExp(r'reconnecting in (\d+)ms \(attempt (\d+)\)').firstMatch)
          .nonNulls)
        (int.parse(m[2]!), int.parse(m[1]!)),
    ];
    expect(waits.map((w) => w.$1), [1, 2]);
    expect(waits[0].$2, inInclusiveRange(1000, 1999));
    expect(waits[1].$2, inInclusiveRange(2000, 2999));
    expect(gateway.at[1].difference(gateway.at[0]),
        greaterThanOrEqualTo(const Duration(seconds: 1)));
    expect(gateway.at[2].difference(gateway.at[1]),
        greaterThanOrEqualTo(const Duration(seconds: 2)));
  });

  test('the wait before each attempt grows as the desktop app\'s, to 30 s', () {
    final random = Random(7);
    for (final (failed, seconds) in [
      (0, 1),
      (1, 2),
      (2, 4),
      (3, 8),
      (4, 16),
      (5, 30),
      (6, 30),
      // Far past the cap, where a power of two would overflow.
      (100, 30),
    ]) {
      final wait = reconnectDelay(failed, random);
      expect(wait, greaterThanOrEqualTo(Duration(seconds: seconds)),
          reason: '$failed');
      expect(wait, lessThan(Duration(seconds: seconds + 1)), reason: '$failed');
    }
    // Up to a second at random, not the same for every client.
    final jitters = {
      for (var i = 0; i < 20; i++)
        reconnectDelay(0, random) - const Duration(seconds: 1),
    };
    expect(jitters.length, greaterThan(1));
  });

  test('a bot\'s shards send theirs in identify', () async {
    final g = _manager(gateway);
    addTearDown(g.manager.destroy);

    await g.manager.connectAll(shardCount: 2);
    await gateway.identifies(2);
    expect(gateway.identified, [
      {'token': _token, 'shard_id': 0, 'num_shards': 2},
      {'token': _token, 'shard_id': 1, 'num_shards': 2},
    ]);
  });

  test('an attempt that hangs is dropped after connectTimeout', () async {
    gateway.plan = (n) => n == 0 ? _Answer.hold : _Answer.upgrade;
    final g =
        _manager(gateway, connectTimeout: const Duration(milliseconds: 300));
    addTearDown(g.manager.destroy);

    final watch = Stopwatch()..start();
    await g.manager.connectAll();
    expect(
        watch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 300)));
    await gateway.identifies(1);
    expect(gateway.tokens, hasLength(2));
    expect(gateway.mostOpen, 1);
    expect(g.logs, contains(contains('TimeoutException')));
  });

  test('a client\'s connect() fails within its timeout, token masked',
      () async {
    gateway.plan = (n) => n == 0 ? _Answer.hold : _Answer.refuse;
    final client = GatewayClient(
        RestClient(http.Client(), token: _token, router: gateway.router),
        router: gateway.router,
        log: (_) {},
        connectTimeout: const Duration(milliseconds: 200));
    addTearDown(client.destroy);

    final watch = Stopwatch()..start();
    await expectLater(client.connect(), throwsA(isA<TimeoutException>()));
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    await expectLater(
        client.connect(),
        throwsA(isA<WebSocketException>().having((e) => '$e', 'error',
            allOf(contains('not upgraded'), isNot(contains(_token))))));
    // Nothing tries again on its own.
    expect(client.connectionState, GatewayConnectionState.disconnected);
  });

  test('destroy() while waiting to reconnect: no socket opens after it',
      () async {
    final g = _manager(gateway);
    await g.manager.connectAll();
    await gateway.identifies(1);

    final reconnecting = g.manager.onConnectionState
        .where((s) => s == GatewayConnectionState.reconnecting)
        .first;
    await gateway.open.single.close();
    await reconnecting;
    g.manager.destroy();
    // Longer than the wait before the next attempt (2 s at most).
    await Future<void>.delayed(const Duration(milliseconds: 2500));

    expect(gateway.tokens, hasLength(1));
    expect(gateway.open, isEmpty);
    expect(g.states.last, GatewayConnectionState.disconnected);
  });

  test('destroy() while a socket opens: connectAll fails, nothing identifies',
      () async {
    gateway.plan = (_) => _Answer.hold;
    final g = _manager(gateway);
    final connecting = g.manager.connectAll();
    await g.manager.onConnectionState
        .where((s) => s == GatewayConnectionState.connecting)
        .first;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    g.manager.destroy();

    await expectLater(connecting, throwsA(isA<StateError>()));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(gateway.identified, isEmpty);
    expect(gateway.tokens, hasLength(1));
  });

  test('a destroyed client neither connects nor sends', () async {
    final logs = <String>[];
    final client = GatewayClient(
        RestClient(http.Client(), token: _token, router: gateway.router),
        router: gateway.router,
        log: logs.add);
    expect(client.connectionState, GatewayConnectionState.disconnected);
    client.sendMessage('heartbeat', {});
    client.destroy();

    expect(await client.waitForConnection(), isFalse);
    await expectLater(client.connect(), throwsA(isA<StateError>()));
    expect(gateway.tokens, isEmpty);
    expect(logs, contains(startsWith('cannot send "heartbeat"')));
  });
}
