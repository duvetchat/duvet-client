// The order a listener hears a resume in when the gateway's replay, its
// heartbeat ack and a close come in one read, as a burst over a real network
// can: against a gateway on 127.0.0.1 that answers the upgrade itself and
// writes its frames raw, each burst in one write. resume_test.dart's gateway
// writes each frame apart, and on loopback the client reads them apart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha1;
import 'package:duvet_client/duvet.dart';
import 'package:duvet_client/http/router.dart';
import 'package:duvet_client/utils/extensions.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _token = 'secret-access-token-0123';

/// How many events the gateway replays: enough for a resume heard too early
/// to land among them.
const _replayed = 20;

/// A frame of the gateway's: final, unmasked.
List<int> _frame(int opcode, List<int> payload) => [
      0x80 | opcode,
      ...switch (payload.length) {
        final n && < 126 => [n],
        final n && < 65536 => [126, n >> 8, n & 0xff],
        final n => [127, for (var i = 7; i >= 0; i--) (n >> (8 * i)) & 0xff],
      },
      ...payload,
    ];

List<int> _text(Map<String, dynamic> json) =>
    _frame(0x1, utf8.encode(jsonEncode(json)));

/// A close frame with [code].
List<int> _close(int code) => _frame(0x8, [code >> 8, code & 0xff]);

/// An event of the session, with its sequence number.
List<int> _event(int s, String type, Map<String, dynamic> data) => _text({
      'event': 'payload',
      'op': 1,
      's': s,
      'd': {'type': type, 'data': data},
    });

/// A message's deletion, an event that carries little.
List<int> _deleted(int s, String id) =>
    _event(s, 'MESSAGE_DELETE', {'id': id, 'room_id': 'r1'});

final _ack = _text({'event': 'heartbeat_ack'});

/// The events replayed after READY (1): m1 to m20, numbered 2 to 21.
List<List<int>> _replay() =>
    [for (var i = 1; i <= _replayed; i++) _deleted(i + 1, 'm$i')];

/// A socket of the gateway's, and what the client sends on it.
class _Connection {
  _Connection(this.socket) {
    socket.listen(_read, onDone: _received.close, onError: (Object _) {});
  }

  final Socket socket;
  final _buffer = <int>[];
  final _received = StreamController<void>.broadcast();

  /// The client's messages, in order.
  final messages = <Map<String, dynamic>>[];

  /// The identify's data, once it came: with [resuming], once the heartbeat a
  /// resuming identify sends with it came too.
  Future<Map<String, dynamic>> identify({bool resuming = false}) async {
    bool came(String type) => messages.any((m) => m['type'] == type);
    while (!came('identify') || (resuming && !came('heartbeat'))) {
      await _received.stream.first.timeout(const Duration(seconds: 10));
    }
    return messages.firstWhere((m) => m['type'] == 'identify')['data']
        as Map<String, dynamic>;
  }

  /// Writes [frames] in one write, which the client reads at once.
  void write(List<List<int>> frames) =>
      socket.add([for (final frame in frames) ...frame]);

  // The client's frames are masked; only its text frames are kept.
  void _read(Uint8List chunk) {
    _buffer.addAll(chunk);
    while (_buffer.length >= 2) {
      final opcode = _buffer[0] & 0x0f;
      final masked = (_buffer[1] & 0x80) != 0;
      var length = _buffer[1] & 0x7f;
      var at = 2;
      if (length == 126) {
        if (_buffer.length < 4) return;
        length = (_buffer[2] << 8) | _buffer[3];
        at = 4;
      } else if (length == 127) {
        if (_buffer.length < 10) return;
        length = 0;
        for (var i = 2; i < 10; i++) {
          length = (length << 8) | _buffer[i];
        }
        at = 10;
      }
      final maskLength = masked ? 4 : 0;
      if (_buffer.length < at + maskLength + length) return;
      final mask = masked ? _buffer.sublist(at, at + 4) : const [0, 0, 0, 0];
      at += maskLength;
      final payload = [
        for (var i = 0; i < length; i++) _buffer[at + i] ^ mask[i % 4],
      ];
      _buffer.removeRange(0, at + length);
      if (opcode == 0x1) {
        messages.add(jsonDecode(utf8.decode(payload)) as Map<String, dynamic>);
        _received.add(null);
      }
    }
  }
}

/// A gateway on 127.0.0.1 that answers the upgrade itself and hands over each
/// socket raw, in the order they open.
class _RawGateway {
  _RawGateway._(this._server) {
    _server.listen(_upgrade);
  }

  static Future<_RawGateway> start() async =>
      _RawGateway._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final _opened = StreamController<_Connection>();
  late final _next = StreamIterator(_opened.stream);
  final _connections = <_Connection>[];

  ApiRouter get router => ApiRouter(
      api: '127.0.0.1:${_server.port}',
      ws: '127.0.0.1:${_server.port}',
      secure: false);

  /// The next socket that opens.
  Future<_Connection> next() async {
    if (!await _next.moveNext().timeout(const Duration(seconds: 10))) {
      throw StateError('no more sockets');
    }
    return _next.current;
  }

  Future<void> _upgrade(HttpRequest request) async {
    // The answer to the client's key that RFC 6455 asks for: the client
    // checks it.
    final key = request.headers.value('sec-websocket-key')!;
    final accept = base64.encode(sha1
        .convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
        .bytes);
    final response = request.response
      ..statusCode = HttpStatus.switchingProtocols
      ..headers.add(HttpHeaders.connectionHeader, 'Upgrade')
      ..headers.add(HttpHeaders.upgradeHeader, 'websocket')
      ..headers.add('Sec-WebSocket-Accept', accept)
      ..headers.contentLength = 0;
    final connection = _Connection(await response.detachSocket());
    _connections.add(connection);
    _opened.add(connection);
  }

  Future<void> close() async {
    for (final connection in _connections) {
      connection.socket.destroy();
    }
    // Not a close of [_opened]: the iterator pauses it between moves, and
    // the close would wait for ever.
    await _next.cancel();
    await _server.close(force: true);
  }
}

/// What [events], [resumes] and [states] deliver, in order: each event's type
/// (and a deleted message's ID), "resumed", and each state's name.
List<String> _record(Stream<GatewayEventPayload> events,
    Stream<GatewayResume> resumes, Stream<GatewayConnectionState> states) {
  final log = <String>[];
  events.listen((e) => log.add(switch (e) {
        ReadyEvent(:final data) => 'READY ${data.sessionToken}',
        MessageDeletedEvent(:final data) => 'deleted ${data.id}',
        _ => '$e',
      }));
  resumes.listen((_) => log.add('resumed'));
  states.listen((s) => log.add(s.name));
  return log;
}

/// A GatewayClient, or a GatewayManager: how to connect it, and its streams.
typedef _Client = ({
  Future<void> Function() connect,
  Stream<GatewayEventPayload> events,
  Stream<GatewayResume> onResume,
  Stream<GatewayConnectionState> onConnectionState,
});

void main() {
  late _RawGateway gateway;

  setUp(() async {
    gateway = await _RawGateway.start();
    addTearDown(gateway.close);
  });

  _Client open({required bool manager}) {
    final api =
        RestClient(http.Client(), token: _token, router: gateway.router);
    if (manager) {
      final m = GatewayManager(api,
          router: gateway.router, log: (_, __) {}, resume: true);
      addTearDown(m.destroy);
      return (
        connect: m.connectAll,
        events: m.onEvent,
        onResume: m.onResume,
        onConnectionState: m.onConnectionState,
      );
    }
    final c =
        GatewayClient(api, router: gateway.router, log: (_) {}, resume: true);
    addTearDown(c.destroy);
    return (
      connect: c.connect,
      events: c.events,
      onResume: c.onResume,
      onConnectionState: c.onConnectionState,
    );
  }

  // Connects, hears READY on the first socket, drops it, and gives the second
  // socket once the client asked on it to resume the session.
  Future<_Connection> resumeOnSecond(_Client client) async {
    final ready = client.events.whereType<ReadyEvent>().first;
    final connecting = client.connect();
    final first = await gateway.next();
    await first.identify();
    first.write([
      _event(1, 'READY', {
        'user': {
          'id': 'u1',
          'username': 'gaby',
          'created_at': '2026-10-23T09:00:00Z',
          'updated_at': '2026-10-23T09:00:00Z',
        },
        'sessionToken': 'session-1',
      }),
    ]);
    await connecting;
    await ready;
    first.socket.destroy();

    final second = await gateway.next();
    expect(await second.identify(resuming: true),
        {'token': _token, 'last_seq': 1, 'session_token': 'session-1'});
    return second;
  }

  for (final manager in [false, true]) {
    group(manager ? 'a GatewayManager' : 'a GatewayClient', () {
      test(
          'the ack in the same read as the replay: what the gateway replayed, '
          'then onResume', () async {
        final client = open(manager: manager);
        final log =
            _record(client.events, client.onResume, client.onConnectionState);
        final second = await resumeOnSecond(client);

        final resumed = client.onResume.first;
        second.write([..._replay(), _ack]);
        await resumed;
        // A live event after it, in a read of its own.
        final live = client.events
            .whereType<MessageDeletedEvent>()
            .where((e) => e.data.id == 'live')
            .first;
        second.write([_deleted(_replayed + 2, 'live')]);
        await live;
        expect(log, [
          'connecting',
          'connected',
          'READY session-1',
          'reconnecting',
          'connected',
          for (var i = 1; i <= _replayed; i++) 'deleted m$i',
          'resumed',
          'deleted live',
        ]);
      });

      test(
          'a close in the same read as the ack: no onResume until the next '
          'socket resumes', () async {
        final client = open(manager: manager);
        final log =
            _record(client.events, client.onResume, client.onConnectionState);
        final second = await resumeOnSecond(client);

        second.write([..._replay(), _ack, _close(WebSocketStatus.goingAway)]);
        final third = await gateway.next();
        // The replay came through: the session goes on from its last event.
        expect(await third.identify(resuming: true), {
          'token': _token,
          'last_seq': _replayed + 1,
          'session_token': 'session-1',
        });
        final resumed = client.onResume.first;
        third.write([_ack]);
        await resumed;
        expect(log.where((e) => e.startsWith('deleted')),
            [for (var i = 1; i <= _replayed; i++) 'deleted m$i']);
        // As an app reads them, the last of the two says whether the session
        // is live: from the close on, not before the next socket resumed it.
        final closed = log.lastIndexOf('reconnecting');
        expect(log.sublist(closed).where((e) => !e.startsWith('deleted')),
            ['reconnecting', 'connected', 'resumed']);
      });
    });
  }
}
