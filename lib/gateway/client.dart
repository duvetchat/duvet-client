import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:duvet_client/http/rest.dart' show RestClient;
import 'package:duvet_client/http/router.dart' show ApiRouter;
import 'package:duvet_client/models/types.dart';
import 'package:duvet_client/errors.dart';

/// How long opening a socket to the gateway may take before the attempt is
/// dropped: 15 seconds.
const defaultConnectTimeout = Duration(seconds: 15);

const _firstReconnectDelay = Duration(seconds: 1);
const _maxReconnectDelay = Duration(seconds: 30);
const _reconnectJitter = Duration(seconds: 1);
final _random = Random();

/// How long the client waits before it opens another socket, after [failed]
/// attempts in a row failed to open one (none when an open socket dropped),
/// as the desktop app waits: a second, doubling with each failure, up to
/// 30, plus up to a second at random, so that clients don't all come back
/// at once.
Duration reconnectDelay(int failed, [Random? random]) {
  // From 2^5 seconds on it's the cap: a higher power would only overflow.
  final doubled = _firstReconnectDelay * (1 << min(failed, 5));
  final base = doubled < _maxReconnectDelay ? doubled : _maxReconnectDelay;
  return base +
      Duration(
          microseconds:
              (random ?? _random).nextInt(_reconnectJitter.inMicroseconds));
}

/// Where a gateway connection is.
enum GatewayConnectionState {
  /// Opening the first socket.
  connecting,

  /// A socket is open and the client identified on it; READY follows, or,
  /// when the gateway resumes the session, the events it missed and
  /// [GatewayClient.onResume].
  connected,

  /// The socket closed, or couldn't open, and the client is opening another.
  reconnecting,

  /// No socket, and none opening: before connecting, after a
  /// [GatewayClient.connect] that failed with nothing trying again, or once
  /// destroyed.
  disconnected,
}

/// A single WebSocket connection to the gateway.
///
/// Owns its own heartbeat loop, reconnect logic, and sequence tracking.
/// All inbound events are pushed onto [events]; callers should not close
/// this stream directly — call [destroy] instead.
///
/// It keeps one socket at a time: a new one opens only once the last is
/// closed, and opening one takes [connectTimeout] at most. When the socket
/// drops, or stops answering heartbeats, it opens a new one and identifies
/// again, until [destroy]: a second after the drop, and longer after each
/// attempt that fails, up to 30 seconds ([reconnectDelay]).
///
/// ### Resuming
/// Each identify starts a new session, which READY begins, unless [resume]
/// is on. Then a socket that replaces one that dropped asks the gateway to
/// resume its session (READY's `sessionToken` and the last sequence number
/// heard), as the desktop app does. The gateway keeps a dropped session for
/// 30 seconds from when it notices the drop, with its last 500 events:
///
/// * when it resumes it, it sends the events the session got after the last
///   one heard, each with its own sequence number, then the new ones, and no
///   READY. The session goes on: its token, its voice and calls. The client
///   tells it by [onResume], after those events.
/// * when it can't (it hasn't noticed the drop yet, the 30 seconds are over,
///   more than 500 events are missing, or it restarted), it starts a new
///   session and sends READY, as without [resume]: what the old session got
///   meanwhile is lost.
///
/// The gateway says nothing when it resumes, so the client asks: it sends a
/// heartbeat right after the identify. The gateway handles a socket's
/// messages in order, so its answer comes after READY when it started a new
/// session, and after the events it replayed when it resumed.
///
/// Parse or protocol errors are pushed to [errors]. Both streams remain
/// open across reconnect cycles and only close when [destroy] is called.
///
/// A bot with more than one shard sends its [shardId] and [shardCount] in the
/// identify: the gateway then gives each shard the spaces whose
/// `fnv32a(space ID) % shardCount` is its [shardId], and their events. With
/// one shard, as by default, the client sends neither: the gateway gives a
/// bot shard 0 of 1, and closes a person's socket that sends them (4000).
class GatewayClient {
  final RestClient api;

  final int shardId;
  final int shardCount;

  /// How long opening a socket may take before the attempt fails with a
  /// [TimeoutException] ([defaultConnectTimeout]).
  final Duration connectTimeout;

  /// Whether a socket that replaces one that dropped resumes its session
  /// (see "Resuming" above), as the desktop app does. Off, as by default,
  /// each socket starts a new session, with READY.
  final bool resume;

  /// Broadcast stream of every decoded [GatewayEventPayload] received from
  /// the gateway, including the initial [ReadyEvent].
  ///
  /// The stream is never closed by normal reconnect cycles; it only closes
  /// when [destroy] is called.
  Stream<GatewayEventPayload> get events => _eventController.stream;

  /// Broadcast stream of [DuvetException]s encountered during message
  /// processing. Emits [DuvetMalformedMessageException] for invalid JSON
  /// and any other errors that arise in [_onMessage].
  ///
  /// The stream is never closed by normal reconnect cycles; it only closes
  /// when [destroy] is called.
  Stream<DuvetException> get errors => _errorController.stream;

  /// Broadcast stream of the connection's state as it changes.
  Stream<GatewayConnectionState> get onConnectionState =>
      _stateController.stream;

  /// Broadcast stream that fires when the gateway resumed the session on a
  /// new socket ([resume]): the session is live again, as on a READY. The
  /// events it missed came before, on [events]; no READY comes. A socket
  /// whose session the gateway couldn't resume gets READY instead.
  Stream<void> get onResume => _resumeController.stream;

  /// Broadcast stream of the reasons the gateway gives before it closes the
  /// socket: [GatewayCloseCode]. The client opens another one, as after any
  /// drop. After [GatewayCloseCode.invalidCredentials], a socket with the
  /// same token fails again: ask the API about the session, as the desktop
  /// app does.
  Stream<GatewayCloseReason> get onCloseReason => _closeController.stream;

  /// The connection's state now.
  GatewayConnectionState get connectionState => _state;

  /// The number of the socket open now (they're counted from 1 as they open),
  /// or null while none is: a message sent then would be lost.
  ///
  /// What's sent on a socket reaches the session its identify started, or
  /// the one it resumed ([resume], [onResume]). Without [resume] each socket
  /// that opens gets a READY, so a message sent on the socket a READY came on
  /// went out after it, in that session; one sent on an earlier socket
  /// belongs to an earlier session. With it, a socket that resumed carries
  /// on the session of the sockets before it, back to its READY.
  int? get connection =>
      _socket?.readyState == WebSocket.open ? _connections : null;

  /// How long the gateway had been silent (no event, no heartbeat ack) before
  /// the last READY: how long it was out of reach before this session, e.g.
  /// while the device slept. Measured as READY comes, not when a listener
  /// reads it: the events after READY come at once. Zero before the first
  /// READY, and for one that's the first thing heard.
  Duration get silenceBeforeReady => _silenceBeforeReady;

  // The open socket, if any: the only one this client keeps.
  WebSocket? _socket;

  // The HTTP client opening the next socket, closed to give up on it.
  HttpClient? _opening;

  // Grows with each connect: a socket that opens for an attempt that isn't the
  // last one is closed at once.
  int _attempt = 0;

  GatewayConnectionState _state = GatewayConnectionState.disconnected;
  bool _destroyed = false;
  bool _awaitingHeartbeatAck = false;
  int _reconnectAttempts = 0;
  int _lastSeq = 0;

  // The session to resume: the last READY's sessionToken, which a resume
  // keeps.
  String? _sessionToken;

  // Set by wantFreshSession until a READY comes.
  bool _freshSessionWanted = false;

  // The open socket's identify asked to resume, and neither READY nor the
  // first heartbeat ack has said yet whether the gateway did.
  bool _resuming = false;

  // The heartbeat sent right after a resuming identify waits for its ack.
  bool _probing = false;

  // The sockets that opened, counted: see [connection].
  int _connections = 0;

  // When the gateway last sent anything, and how long it had been silent
  // before the last READY: see [silenceBeforeReady].
  DateTime? _lastHeardAt;
  Duration _silenceBeforeReady = Duration.zero;

  Timer? _heartbeat;
  Timer? _heartbeatAckTimer;
  Future<void>? _reconnecting;
  Completer<void>? _reconnectWait;

  final StreamController<GatewayEventPayload> _eventController =
      StreamController<GatewayEventPayload>.broadcast();

  final StreamController<DuvetException> _errorController =
      StreamController<DuvetException>.broadcast();

  final StreamController<GatewayConnectionState> _stateController =
      StreamController<GatewayConnectionState>.broadcast();

  final StreamController<void> _resumeController =
      StreamController<void>.broadcast();

  final StreamController<GatewayCloseReason> _closeController =
      StreamController<GatewayCloseReason>.broadcast();

  static const Duration _heartbeatInterval = Duration(seconds: 45);
  static const Duration _heartbeatAckTimeout = Duration(seconds: 15);

  final ApiRouter router;
  String get _wsHost => router.getCustomApiUrl(protocol: 'ws');

  final void Function(String msg) _log;

  GatewayClient(
    this.api, {
    this.shardId = 0,
    this.shardCount = 1,
    void Function(String msg)? log,
    ApiRouter? router,
    this.connectTimeout = defaultConnectTimeout,
    this.resume = false,
  })  : _log = log ?? ((msg) => print('[gateway:shard-$shardId] $msg')),
        router = router ?? const ApiRouter();

  String get token => api.token;

  /// The gateway's URL, with the access token in its query, as the gateway
  /// reads it. Don't log it.
  String get streamUrl =>
      Uri.parse('${router.secure ? 'wss' : 'ws'}://$_wsHost/gateway')
          .replace(queryParameters: {'token': token}).toString();

  /// Completes with true once a socket is open (at once if one is), or with
  /// false if the client is destroyed first.
  Future<bool> waitForConnection() async {
    if (_state == GatewayConnectionState.connected) return true;
    if (_destroyed) return false;
    final state = await onConnectionState.firstWhere(
        (s) =>
            s == GatewayConnectionState.connected ||
            s == GatewayConnectionState.disconnected,
        orElse: () => GatewayConnectionState.disconnected);
    return state == GatewayConnectionState.connected;
  }

  /// Opens a socket and identifies on it, after closing the one open before.
  ///
  /// Throws when the socket doesn't open: a [TimeoutException] after
  /// [connectTimeout], or the error that stopped it; [reconnect] keeps trying.
  /// Throws a [StateError] once the client is destroyed.
  Future<void> connect() async {
    if (_destroyed) {
      throw StateError('Shard $shardId is destroyed — cannot connect.');
    }
    final attempt = ++_attempt;
    _closeSocket();
    if (_state != GatewayConnectionState.reconnecting) {
      _setState(GatewayConnectionState.connecting);
    }

    final uri = Uri.parse(streamUrl);
    // Not the URL itself: its query holds the token.
    _log('connecting to ${uri.scheme}://${uri.authority}${uri.path}');

    final http = _opening = HttpClient();
    final opening = WebSocket.connect(uri.toString(),
        headers: api.authHeaders, customClient: http);
    final WebSocket socket;
    try {
      socket = await opening.timeout(connectTimeout);
    } catch (e, st) {
      // Gives up on the handshake; a socket that opens anyway is closed.
      http.close(force: true);
      opening.then(_discard, onError: (Object _) {});
      if (_destroyed) {
        throw StateError('Shard $shardId was destroyed while connecting.');
      }
      // Unless [reconnect] is trying, nothing is.
      if (_reconnecting == null) {
        _setState(GatewayConnectionState.disconnected);
      }
      Error.throwWithStackTrace(_masked(e), st);
    } finally {
      if (identical(_opening, http)) _opening = null;
    }
    // The socket is the client's now, not the HTTP client's.
    http.close();

    if (_destroyed) {
      _discard(socket);
      throw StateError('Shard $shardId was destroyed while connecting.');
    }
    if (attempt != _attempt) {
      // Another attempt started meanwhile: that one's socket is the one kept.
      _discard(socket);
      return;
    }

    _socket = socket;
    _connections++;
    _reconnectAttempts = 0;
    socket.listen(
      (raw) {
        if (identical(socket, _socket)) _onMessage(raw);
      },
      onError: (Object e) {
        if (identical(socket, _socket)) _log('socket error: ${_mask('$e')}');
      },
      onDone: () {
        if (identical(socket, _socket)) {
          _dropped('socket closed (${socket.closeCode} ${socket.closeReason})');
        }
      },
      cancelOnError: false,
    );
    _identify();
    _startHeartbeat();
    _setState(GatewayConnectionState.connected);
    _log('connected');
  }

  /// Closes the socket, if one is open, and opens a new one: after a delay
  /// that grows with each failed attempt ([reconnectDelay]), it tries until a
  /// socket opens or the client is destroyed. Calls while it's trying share
  /// that attempt.
  Future<void> reconnect() {
    if (_destroyed) return Future.value();
    return _reconnecting ??= _reconnectLoop();
  }

  Future<void> _reconnectLoop() async {
    try {
      while (!_destroyed) {
        _closeSocket();
        _setState(GatewayConnectionState.reconnecting);
        final delay = reconnectDelay(_reconnectAttempts);
        _log('reconnecting in ${delay.inMilliseconds}ms '
            '(attempt ${_reconnectAttempts + 1})');
        // A wait destroy() can end early.
        final wait = _reconnectWait = Completer<void>();
        final timer = Timer(delay, () {
          if (!wait.isCompleted) wait.complete();
        });
        await wait.future;
        timer.cancel();
        if (_destroyed) return;
        _reconnectAttempts++;
        try {
          await connect();
          return;
        } catch (e) {
          if (_destroyed) return;
          _log('reconnect failed: $e');
        }
      }
    } finally {
      // At once, so a socket that drops right after this one opened gets a
      // loop of its own.
      _reconnecting = null;
    }
  }

  // The socket closed, or stopped answering: a new one opens.
  void _dropped(String why) {
    _log(why);
    _closeSocket();
    if (!_destroyed) unawaited(reconnect());
  }

  void _closeSocket() {
    _stopHeartbeat();
    _probing = false;
    if (_resuming) {
      // Gone before the gateway said whether it resumed the session: what
      // came on this socket may have been a new session's, whose sequence
      // numbers would resume the old one at the wrong place. The next socket
      // starts a new one.
      _resuming = false;
      _sessionToken = null;
    }
    final socket = _socket;
    if (socket == null) return;
    _socket = null;
    _discard(socket);
  }

  void _discard(WebSocket socket) {
    socket.close(WebSocketStatus.normalClosure).then((_) {},
        onError: (Object e) => _log('error closing a socket: ${_mask('$e')}'));
  }

  // [text] with the token masked.
  String _mask(String text) {
    final t = token;
    if (t.isEmpty) return text;
    return text
        .replaceAll(Uri.encodeQueryComponent(t), '***')
        .replaceAll(t, '***');
  }

  // [e] with the token masked: a failed handshake's error carries the URL,
  // query and all.
  Object _masked(Object e) => switch (e) {
        WebSocketException(:final message) =>
          WebSocketException(_mask(message)),
        HttpException(:final message, :final uri) => HttpException(
            _mask(message),
            uri: uri == null ? null : Uri.parse(_mask('$uri'))),
        _ => e,
      };

  /// Permanently shuts down this client. The [events], [errors],
  /// [onConnectionState], [onResume] and [onCloseReason] streams are closed
  /// and the socket is disconnected; no other one opens. Do not reuse after
  /// calling this.
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    _attempt++;
    final wait = _reconnectWait;
    if (wait != null && !wait.isCompleted) wait.complete();
    _opening?.close(force: true);
    _closeSocket();
    _setState(GatewayConnectionState.disconnected);
    _eventController.close();
    _errorController.close();
    _stateController.close();
    _resumeController.close();
    _closeController.close();
    _log('destroyed');
  }

  /// Makes the next identify start a new session, with READY, rather than
  /// resume this one ([resume]); until a READY comes. The desktop app asks
  /// for one when voice has to join while no socket is open: it joins on the
  /// next session's READY, which a resume doesn't send, and a resume would
  /// replay what the earlier sockets were sent.
  void wantFreshSession() => _freshSessionWanted = true;

  /// Sends an arbitrary event message to the gateway, and answers whether it
  /// went out on an open socket.
  ///
  /// Equivalent to the TypeScript `sendEventMessage(type, data)` helper.
  /// Drops the message (with a log warning) when no socket is open, so callers
  /// that don't care need not guard against transient connection races.
  ///
  /// ```dart
  /// client.sendMessage('VOICE_LEAVE', {'room_id': roomId});
  /// ```
  bool sendMessage(String type, Map<String, dynamic> data) {
    if (_send({'type': type, 'data': data})) return true;
    _log('cannot send "$type" – socket not open (state: ${_state.name})');
    return false;
  }

  // Whether the message went out on the open socket.
  bool _send(Map<String, dynamic> message) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return false;
    socket.add(jsonEncode(message));
    return true;
  }

  void _setState(GatewayConnectionState state) {
    if (state == _state) return;
    _state = state;
    _log('state: ${state.name}');
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _heartbeatAckTimer?.cancel();
    _heartbeatAckTimer = null;
    _awaitingHeartbeatAck = false;
  }

  void _sendHeartbeat() {
    if (_socket == null) return;

    if (_awaitingHeartbeatAck) {
      _dropped('missed heartbeat ack – closing');
      return;
    }

    _awaitingHeartbeatAck = true;
    _log('♥ heartbeat');
    _send({'type': 'heartbeat', 'data': <String, dynamic>{}});

    _heartbeatAckTimer?.cancel();
    _heartbeatAckTimer = Timer(_heartbeatAckTimeout, () {
      if (_awaitingHeartbeatAck) _dropped('heartbeat ack timeout – closing');
    });
  }

  void _handleHeartbeatAck() {
    if (_resuming) {
      // The first ack since the identify that asked to resume, and no READY
      // before it: the gateway resumed the session, and what it replayed
      // came first.
      _resuming = false;
      _log('session resumed (seq=$_lastSeq)');
      if (!_resumeController.isClosed) _resumeController.add(null);
    }
    if (_probing) {
      // The heartbeat sent with the identify: a periodic one may still wait
      // for its own ack.
      _probing = false;
      return;
    }
    _awaitingHeartbeatAck = false;
    _heartbeatAckTimer?.cancel();
    _log('♥ ack');
  }

  void _identify() {
    final session = _sessionToken;
    final resuming =
        resume && session != null && _lastSeq > 0 && !_freshSessionWanted;
    final data = <String, dynamic>{
      'token': token,
      if (_lastSeq > 0) 'last_seq': _lastSeq,
      if (resuming) 'session_token': session,
      // Only to shard: see the class's doc.
      if (shardCount > 1) ...{'shard_id': shardId, 'num_shards': shardCount},
    };
    final sent = _send({'type': 'identify', 'data': data});
    _log('identify sent (shard=$shardId/$shardCount, seq=$_lastSeq'
        '${resuming ? ', resuming' : ''})');
    if (resuming && sent) {
      // Its ack comes after READY when the gateway starts a new session
      // instead, and after the events it replays when it resumes this one:
      // an ack with no READY before it says the gateway resumed.
      _resuming = true;
      _probing = _send({'type': 'heartbeat', 'data': <String, dynamic>{}});
    }
  }

  void _onMessage(dynamic raw) {
    final now = DateTime.now();
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;

      final String type = decoded['event'] as String? ?? '';
      if (type.toLowerCase() == 'close-with-reason') {
        // It doesn't count as hearing from the gateway (silenceBeforeReady):
        // a refused identify after a sleep would hide how long it lasted.
        final close = GatewayCloseReason.fromJson(decoded);
        _log('the gateway closes the socket: ${close.code} ${close.reason}');
        if (!_closeController.isClosed) _closeController.add(close);
        return;
      }

      final last = _lastHeardAt;
      final silence = last == null ? Duration.zero : now.difference(last);
      _lastHeardAt = now;
      if (type.toUpperCase() == 'HEARTBEAT_ACK') {
        _handleHeartbeatAck();
        return;
      }

      final envelope = GatewayEnvelope.fromJson(decoded);
      _lastSeq = envelope.s;

      final payload = envelope.d;
      if (payload == null) {
        _log('warning: received event with null payload (type=$type)');
        return;
      }
      if (payload is ReadyEvent) {
        _silenceBeforeReady = silence;
        // A new session, which says how a resuming identify went.
        _sessionToken = payload.data.sessionToken;
        _freshSessionWanted = false;
        _resuming = false;
      }

      if (!_eventController.isClosed) {
        _eventController.add(payload);
      }
    } on FormatException catch (e) {
      _log('malformed message: $e');
      if (!_errorController.isClosed) {
        _errorController.add(DuvetMalformedMessageException(e));
      }
    } catch (e) {
      _log('error processing message: $e');
      if (!_errorController.isClosed) {
        _errorController.add(DuvetMalformedMessageException(e));
      }
    }
  }
}
