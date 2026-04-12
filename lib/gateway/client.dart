import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_client/web_socket_client.dart' as ws;
import 'package:duvet_client/http/rest.dart' show RestClient;
import 'package:duvet_client/http/router.dart' show ApiRouter;
import 'package:duvet_client/models/types.dart';
import 'package:duvet_client/errors.dart';

/// A single WebSocket connection to the gateway.
///
/// Owns its own heartbeat loop, reconnect logic, and sequence tracking.
/// All inbound events are pushed onto [events]; callers should not close
/// this stream directly — call [destroy] instead.
///
/// Parse or protocol errors are pushed to [errors]. Both streams remain
/// open across reconnect cycles and only close when [destroy] is called.
///
/// [shardId] and [shardCount] are forwarded in the IDENTIFY payload so the
/// server can route traffic correctly once sharding is active. They default
/// to shard 0-of-1 (i.e. no sharding) and can be ignored until then.
class GatewayClient {
  final RestClient api;

  final int shardId;
  final int shardCount;

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

  late ws.WebSocket _socket;

  bool _connected = false;
  bool _awaitingHeartbeatAck = false;
  bool _destroyed = false;
  int _reconnectAttempts = 0;
  int _lastSeq = 0;

  StreamSubscription<dynamic>? _heartbeatSub;
  Timer? _heartbeatAckTimer;
  StreamSubscription<dynamic>? _messageSub;
  StreamSubscription<dynamic>? _connectionSub;

  final StreamController<GatewayEventPayload> _eventController =
      StreamController<GatewayEventPayload>.broadcast();

  final StreamController<DuvetException> _errorController =
      StreamController<DuvetException>.broadcast();

  static const Duration _heartbeatInterval = Duration(seconds: 45);
  static const Duration _heartbeatAckTimeout = Duration(seconds: 15);
  static const Duration _maxReconnectDelay = Duration(milliseconds: 2500);

  final ApiRouter router;
  String get _wsHost => router.getCustomApiUrl(protocol: 'ws');

  final void Function(String msg) _log;

  GatewayClient(
    this.api, {
    this.shardId = 0,
    this.shardCount = 1,
    void Function(String msg)? log,
    ApiRouter? router,
  })  : _log = log ?? ((msg) => print('[gateway:shard-$shardId] $msg')),
        router = router ?? const ApiRouter();

  String get token => api.token;
  String get streamUrl => 'wss://$_wsHost/gateway?token=$token';

  Future<bool> waitForConnection() async {
    await _socket.connection.firstWhere((s) => s is ws.Connected);
    return true;
  }

  Future<void> connect() async {
    if (_destroyed) {
      throw StateError('Shard $shardId is destroyed — cannot connect.');
    }

    final uri = Uri.parse(streamUrl);
    _log('connecting to $uri');

    _socket = ws.WebSocket(uri, headers: api.authHeaders);

    _connected = await waitForConnection();
    _reconnectAttempts = 0;
    _log('connected');

    _connectionSub?.cancel();
    _connectionSub = _socket.connection.listen(_onConnectionState);

    _identify();

    _messageSub?.cancel();
    _messageSub = _socket.messages.listen(_onMessage);

    _startHeartbeat();
  }

  Future<void> reconnect() async {
    if (_destroyed) return;

    await _cleanup(cancelHeartbeat: true);

    final delay = _reconnectDelay();
    _log('reconnecting in ${delay.inMilliseconds}ms '
        '(attempt ${_reconnectAttempts + 1})');
    await Future.delayed(delay);
    _reconnectAttempts++;

    try {
      await connect();
    } catch (e) {
      _log('reconnect failed: $e');
      unawaited(reconnect());
    }
  }

  void _closeSocket() {
    if (_connected) {
      _socket.close();
      _connected = false;
      return;
    }
    _log('warning: socket already closed, did nothing');
  }

  /// Permanently shuts down this client. The [events] and [errors] streams
  /// are closed and the underlying socket is disconnected.
  /// Do not reuse after calling this.
  void destroy() {
    _destroyed = true;
    _cleanup(cancelHeartbeat: true);
    _closeSocket();
    _eventController.close();
    _log('destroyed');
  }

  /// Sends an arbitrary event message to the gateway.
  ///
  /// Equivalent to the TypeScript `sendEventMessage(type, data)` helper.
  /// Silently drops the message (with a log warning) when the socket is not
  /// in the [ws.Connected] state so callers do not need to guard against
  /// transient connection races themselves.
  ///
  /// ```dart
  /// client.sendMessage('join_voice', {'room_id': roomId});
  /// client.sendMessage('WEBRTC_ICE_CANDIDATE', {'candidate': '...', ...});
  /// ```
  void sendMessage(String type, Map<String, dynamic> data) {
    if (_socket.connection.state is ws.Connected) {
      _socket.send(jsonEncode({'type': type, 'data': data}));
    } else {
      _log('cannot send "$type" – socket not open '
          '(state: ${_socket.connection.state})');
    }
  }

  void _startHeartbeat() {
    _heartbeatSub?.cancel();
    _heartbeatSub =
        Stream.periodic(_heartbeatInterval).listen((_) => _sendHeartbeat());
  }

  void _sendHeartbeat() {
    if (_socket.connection.state is! ws.Connected) return;

    if (_awaitingHeartbeatAck) {
      _log('missed heartbeat ack – closing');
      _closeSocket();
      return;
    }

    _awaitingHeartbeatAck = true;
    _log('♥ heartbeat');
    _socket.send(jsonEncode({'type': 'heartbeat', 'data': {}}));

    _heartbeatAckTimer?.cancel();
    _heartbeatAckTimer = Timer(_heartbeatAckTimeout, () {
      if (_awaitingHeartbeatAck) {
        _log('heartbeat ack timeout – closing');
        _closeSocket();
      }
    });
  }

  void _handleHeartbeatAck() {
    _awaitingHeartbeatAck = false;
    _heartbeatAckTimer?.cancel();
    _log('♥ ack');
  }

  void _identify() {
    final data = <String, dynamic>{
      'token': token,
      if (_lastSeq > 0) 'last_seq': _lastSeq,
    };
    _socket.send(jsonEncode({'type': 'identify', 'data': data}));
    _log('identify sent (shard=$shardId/$shardCount, seq=$_lastSeq)');
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;

      final String type = decoded['event'] as String? ?? '';
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

  void _onConnectionState(ws.ConnectionState state) {
    _log('state: $state');
    if (state is ws.Disconnected || state is ws.Reconnecting) {
      if (!_destroyed) {
        _cleanup(cancelHeartbeat: true);
        unawaited(reconnect());
      }
    }
  }

  Duration _reconnectDelay() {
    final jitter = Random(token.hashCode).nextInt(500);
    final base = min(500 * pow(2, _reconnectAttempts).toInt(),
        _maxReconnectDelay.inMilliseconds);
    return Duration(milliseconds: base + jitter);
  }

  Future<void> _cleanup({bool cancelHeartbeat = false}) async {
    _messageSub?.cancel();
    _messageSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;

    if (cancelHeartbeat) {
      _heartbeatSub?.cancel();
      _heartbeatSub = null;
      _heartbeatAckTimer?.cancel();
      _heartbeatAckTimer = null;
      _awaitingHeartbeatAck = false;
    }
  }
}
