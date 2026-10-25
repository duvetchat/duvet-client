// Resuming a gateway session, and the reasons the gateway closes a socket
// with, against a fake gateway on 127.0.0.1 that keeps sessions as the real
// one does (services/user.go's OnIdentifyMessage, connection/session.go's
// Resume and SendCloseReason).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duvet_client/duvet.dart';
import 'package:duvet_client/http/router.dart';
import 'package:duvet_client/utils/extensions.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _token = 'secret-access-token-0123';

/// A session: its events, each with its sequence number, kept for a resume.
class _Session {
  _Session(this.token);
  final String token;
  int seq = 0;
  final frames = <Map<String, dynamic>>[];
}

/// A gateway on 127.0.0.1 with one socket at a time. An identify that names
/// a session it has, with last_seq, resumes it when [resumes]: the events
/// after last_seq come again, and no READY. Any other starts a new session,
/// with READY. It answers heartbeats in order with what it sends, as the
/// gateway does.
class _Gateway {
  _Gateway._(this._server) {
    _server.listen(_handle);
  }

  static Future<_Gateway> start() async =>
      _Gateway._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  /// Whether it resumes the sessions it's asked to.
  bool resumes = true;

  /// Off, a socket whose identify asks to resume gets no answer at all, as
  /// if the gateway were slow.
  bool answersResumes = true;

  final sessions = <String, _Session>{};
  _Session? _current;
  WebSocket? _socket;

  /// The identify payloads, in order, and how many heartbeats came.
  final identified = <Map<String, dynamic>>[];
  int heartbeats = 0;
  final _received = StreamController<void>.broadcast();

  ApiRouter get router => ApiRouter(
      api: '127.0.0.1:${_server.port}',
      ws: '127.0.0.1:${_server.port}',
      secure: false);

  /// Completes once [count] identifies came.
  Future<void> identifies(int count) =>
      _until(() => identified.length >= count);

  /// Completes once [count] heartbeats came.
  Future<void> heartbeatsCame(int count) => _until(() => heartbeats >= count);

  Future<void> _until(bool Function() done) async {
    while (!done()) {
      await _received.stream.first.timeout(const Duration(seconds: 10));
    }
  }

  /// Sends an event in the current session, with its next sequence number.
  /// With no socket open, the session only keeps it, for a resume.
  void push(String type, Map<String, dynamic> data) {
    final session = _current!;
    final frame = {
      'event': 'payload',
      'op': 1,
      's': ++session.seq,
      'd': {'type': type, 'data': data},
    };
    session.frames.add(frame);
    _socket?.add(jsonEncode(frame));
  }

  /// Sends an event without a sequence number, as no event of the gateway's
  /// is today.
  void sendBare(String type, Map<String, dynamic> data) {
    _socket?.add(jsonEncode({
      'event': 'payload',
      'op': 1,
      'd': {'type': type, 'data': data},
    }));
  }

  /// Drops the socket, as a network failure does: the session stays.
  Future<void> drop() async {
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  /// Says why, then closes the socket, as SendCloseReason does.
  Future<void> closeWithReason(int code, String reason) async {
    final socket = _socket!;
    _socket = null;
    socket.add(jsonEncode(
        {'event': 'close-with-reason', 'code': code, 'reason': reason}));
    await socket.close(WebSocketStatus.normalClosure, reason);
  }

  Future<void> _handle(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    _socket = socket;
    var silent = false;
    socket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (message['type']) {
        case 'identify':
          final data = message['data'] as Map<String, dynamic>;
          identified.add(data);
          final old = sessions[data['session_token']];
          final lastSeq = data['last_seq'] as int?;
          if (data['session_token'] != null && !answersResumes) {
            silent = true;
          } else if (old != null && lastSeq != null && resumes) {
            _current = old;
            for (final frame in old.frames) {
              if ((frame['s'] as int) > lastSeq) socket.add(jsonEncode(frame));
            }
          } else {
            final session = _Session('session-${sessions.length + 1}');
            sessions[session.token] = _current = session;
            push('READY', {
              'user': {
                'id': 'u1',
                'username': 'gaby',
                'created_at': '2026-10-23T09:00:00Z',
                'updated_at': '2026-10-23T09:00:00Z',
              },
              'sessionToken': session.token,
            });
          }
        case 'heartbeat':
          heartbeats++;
          if (!silent) socket.add(jsonEncode({'event': 'heartbeat_ack'}));
      }
      _received.add(null);
    }, onDone: () {
      if (identical(_socket, socket)) _socket = null;
    });
  }

  Future<void> close() async {
    await _socket?.close();
    await _server.close(force: true);
    await _received.close();
  }
}

/// A message's deletion, an event that carries little.
Map<String, dynamic> _deleted(String id) => {'id': id, 'room_id': 'r1'};

/// What [events] and [resumes] deliver, in order: each event's type (and a
/// deleted message's ID), and "resumed".
List<String> _record(Stream<GatewayEventPayload> events, Stream<void> resumes) {
  final log = <String>[];
  events.listen((e) => log.add(switch (e) {
        ReadyEvent(:final data) => 'READY ${data.sessionToken}',
        MessageDeletedEvent(:final data) => 'deleted ${data.id}',
        _ => '$e',
      }));
  resumes.listen((_) => log.add('resumed'));
  return log;
}

void main() {
  late _Gateway gateway;

  setUp(() async {
    gateway = await _Gateway.start();
    addTearDown(gateway.close);
  });

  GatewayClient client({bool resume = false}) {
    final c = GatewayClient(
        RestClient(http.Client(), token: _token, router: gateway.router),
        router: gateway.router,
        log: (_) {},
        resume: resume);
    addTearDown(c.destroy);
    return c;
  }

  test('without resume, each socket starts a new session, as before', () async {
    final c = client();
    final log = _record(c.events, c.onResume);
    await c.connect();
    await gateway.identifies(1);
    gateway.push('MESSAGE_DELETE', _deleted('m1'));
    await c.events.whereType<MessageDeletedEvent>().first;

    final ready = c.events.whereType<ReadyEvent>().first;
    await gateway.drop();
    await ready;
    expect(gateway.identified, [
      {'token': _token},
      // The last sequence number heard, and no session: the gateway starts
      // a new one.
      {'token': _token, 'last_seq': 2},
    ]);
    expect(log, ['READY session-1', 'deleted m1', 'READY session-2']);
  });

  test('with resume, the session goes on: what it missed, then onResume',
      () async {
    final manager = GatewayManager(
        RestClient(http.Client(), token: _token, router: gateway.router),
        router: gateway.router,
        log: (_, __) {},
        resume: true);
    addTearDown(manager.destroy);
    final log = _record(manager.onEvent, manager.onResume);
    final states = <GatewayConnectionState>[];
    manager.onConnectionState.listen(states.add);

    final ready = manager.ready;
    await manager.connectAll();
    await ready;
    gateway.push('MESSAGE_DELETE', _deleted('m1'));
    await manager.onMessageDelete.first;

    final resumed = manager.onResume.first;
    await gateway.drop();
    // Sent while no socket was open: the session keeps them.
    gateway.push('MESSAGE_DELETE', _deleted('m2'));
    gateway.push('MESSAGE_DELETE', _deleted('m3'));
    await resumed;
    expect(gateway.identified.last,
        {'token': _token, 'last_seq': 2, 'session_token': 'session-1'});
    expect(manager.connection, 2);

    gateway.push('MESSAGE_DELETE', _deleted('m4'));
    await manager.onMessageDelete.first;
    expect(log, [
      'READY session-1',
      'deleted m1',
      'deleted m2',
      'deleted m3',
      'resumed',
      'deleted m4',
    ]);
    expect(states, [
      GatewayConnectionState.connecting,
      GatewayConnectionState.connected,
      GatewayConnectionState.reconnecting,
      GatewayConnectionState.connected,
    ]);

    // A resumed session keeps its token: it resumes again.
    final again = manager.onResume.first;
    await gateway.drop();
    await again;
    expect(gateway.identified.last,
        {'token': _token, 'last_seq': 5, 'session_token': 'session-1'});
    expect(log.where((e) => e.startsWith('READY')), hasLength(1));
  });

  test('a session the gateway can\'t resume: READY, and no onResume', () async {
    gateway.resumes = false;
    final c = client(resume: true);
    final log = _record(c.events, c.onResume);
    final first = c.events.whereType<ReadyEvent>().first;
    await c.connect();
    await first;

    final ready = c.events.whereType<ReadyEvent>().first;
    await gateway.drop();
    await ready;
    expect(gateway.identified.last['session_token'], 'session-1');
    // The heartbeat sent with the identify is answered after READY: that
    // answer says nothing more.
    await gateway.heartbeatsCame(1);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(log, ['READY session-1', 'READY session-2']);

    // The new session is the one to resume from now on.
    gateway.resumes = true;
    final resumed = c.onResume.first;
    await gateway.drop();
    await resumed;
    expect(gateway.identified.last,
        {'token': _token, 'last_seq': 1, 'session_token': 'session-2'});
  });

  test('wantFreshSession: the next socket starts a new session, then resumes',
      () async {
    final c = client(resume: true);
    final log = _record(c.events, c.onResume);
    final first = c.events.whereType<ReadyEvent>().first;
    await c.connect();
    await first;

    c.wantFreshSession();
    final ready = c.events.whereType<ReadyEvent>().first;
    await gateway.drop();
    await ready;
    expect(gateway.identified.last, {'token': _token, 'last_seq': 1});

    // READY ends the wish.
    final resumed = c.onResume.first;
    await gateway.drop();
    await resumed;
    expect(gateway.identified.last['session_token'], 'session-2');
    expect(log, ['READY session-1', 'READY session-2', 'resumed']);
  });

  test(
      'a socket gone before the gateway answered, with nothing on it: the '
      'next one resumes from the same place', () async {
    final c = client(resume: true);
    final log = _record(c.events, c.onResume);
    await c.connect();
    await gateway.identifies(1);
    gateway.push('MESSAGE_DELETE', _deleted('m1'));
    await c.events.whereType<MessageDeletedEvent>().first;

    gateway.answersResumes = false;
    await gateway.drop();
    await gateway.identifies(2);
    expect(gateway.identified.last['session_token'], 'session-1');
    // Nothing came on it, so the sequence number didn't move.
    gateway.answersResumes = true;
    final resumed = c.onResume.first;
    await gateway.drop();
    await resumed;
    expect(gateway.identified.last,
        {'token': _token, 'last_seq': 2, 'session_token': 'session-1'});
    expect(log, ['READY session-1', 'deleted m1', 'resumed']);
  });

  test(
      'a socket gone before the gateway answered, with an event on it: the '
      'next one starts a new session', () async {
    final c = client(resume: true);
    final log = _record(c.events, c.onResume);
    await c.connect();
    await gateway.identifies(1);
    gateway.push('MESSAGE_DELETE', _deleted('m1'));
    await c.events.whereType<MessageDeletedEvent>().first;

    gateway.answersResumes = false;
    await gateway.drop();
    await gateway.identifies(2);
    // It may have been a new session's, whose number would resume the old
    // one at the wrong place.
    gateway.push('MESSAGE_DELETE', _deleted('m2'));
    await c.events.whereType<MessageDeletedEvent>().first;
    final ready = c.events.whereType<ReadyEvent>().first;
    await gateway.drop();
    await ready;
    expect(gateway.identified.last, {'token': _token, 'last_seq': 3});
    expect(log,
        ['READY session-1', 'deleted m1', 'deleted m2', 'READY session-2']);
  });

  test('an event without a sequence number leaves where a resume starts',
      () async {
    final c = client(resume: true);
    final first = c.events.whereType<ReadyEvent>().first;
    await c.connect();
    await first;
    gateway.push('MESSAGE_DELETE', _deleted('m1'));
    gateway.sendBare('MESSAGE_DELETE', _deleted('m2'));
    await c.events.whereType<MessageDeletedEvent>().skip(1).first;

    final resumed = c.onResume.first;
    await gateway.drop();
    final resume = await resumed;
    expect(resume.shardId, 0);
    expect(gateway.identified.last,
        {'token': _token, 'last_seq': 2, 'session_token': 'session-1'});
  });

  test('a close with 4000: the client stops until the app connects again',
      () async {
    // A bot's second shard, whose options the gateway refuses.
    final c = GatewayClient(
        RestClient(http.Client(), token: _token, router: gateway.router),
        router: gateway.router,
        log: (_) {},
        shardId: 1,
        shardCount: 2);
    addTearDown(c.destroy);
    final first = c.events.whereType<ReadyEvent>().first;
    await c.connect();
    await first;

    final closed = c.onCloseReason.first;
    final stopped = c.onConnectionState
        .where((s) => s == GatewayConnectionState.disconnected)
        .first;
    await gateway.closeWithReason(4000, 'shard_id out of range');
    final close = await closed;
    expect((close.code, close.reason, close.shardId),
        (GatewayCloseCode.invalidShard, 'shard_id out of range', 1));
    await stopped;
    // Longer than the wait before another attempt: none comes.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    expect(gateway.identified, hasLength(1));
    expect(c.connectionState, GatewayConnectionState.disconnected);
    expect(c.retryNow(), isFalse);

    await c.connect();
    await gateway.identifies(2);
    expect(c.connectionState, GatewayConnectionState.connected);
    expect(gateway.identified.last,
        {'token': _token, 'last_seq': 1, 'shard_id': 1, 'num_shards': 2});
    // Going again: a drop is followed by another socket, as before.
    await gateway.drop();
    await gateway.identifies(3);
  });

  test(
      'close-with-reason: its code and reason, then another socket that '
      'resumes', () async {
    final manager = GatewayManager(
        RestClient(http.Client(), token: _token, router: gateway.router),
        router: gateway.router,
        log: (_, __) {},
        resume: true);
    addTearDown(manager.destroy);
    final closes = <GatewayCloseReason>[];
    manager.onCloseReason.listen(closes.add);
    final ready = manager.ready;
    await manager.connectAll();
    await ready;
    gateway.push('MESSAGE_DELETE', _deleted('m1'));
    await manager.onMessageDelete.first;

    final resumed = manager.onResume.first;
    await gateway.closeWithReason(4004, 'session ended');
    await resumed;
    expect(closes.map((c) => (c.code, c.reason)),
        [(GatewayCloseCode.invalidCredentials, 'session ended')]);
    // The close frame is no event, and left the sequence number alone.
    expect(gateway.identified.last,
        {'token': _token, 'last_seq': 2, 'session_token': 'session-1'});
  });

  test(
      'a close-with-reason isn\'t hearing from the gateway: the silence '
      'before READY counts from what came before it', () async {
    final c = client();
    final first = c.events.whereType<ReadyEvent>().first;
    await c.connect();
    await first;
    final heard = DateTime.now();

    await Future<void>.delayed(const Duration(seconds: 1));
    final ready = c.events.whereType<ReadyEvent>().first;
    await gateway.closeWithReason(4004, 'authentication failed');
    await ready;
    // As the desktop app measures it: a refused identify after a sleep
    // would hide how long the sleep lasted.
    final sinceHeard = DateTime.now().difference(heard);
    expect(c.silenceBeforeReady,
        greaterThan(sinceHeard - const Duration(milliseconds: 300)));
  });
}
