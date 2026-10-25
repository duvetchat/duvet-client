import 'dart:async';

import 'package:duvet_client/gateway/client.dart';
import 'package:duvet_client/gateway/events.dart';
import 'package:duvet_client/errors.dart';
import 'package:duvet_client/http/rest.dart';
import 'package:duvet_client/http/router.dart';
import 'package:duvet_client/models/types.dart';
import 'package:http/http.dart' as http;

void defaultLog(int shardId, String msg) {
  print('[gateway:shard-$shardId] $msg');
}

class GatewayManager with GatewayEvents {
  final _eventController = StreamController<GatewayEventPayload>.broadcast();
  final _errorController = StreamController<DuvetException>.broadcast();
  final _stateController = StreamController<GatewayConnectionState>.broadcast();
  final _resumeController = StreamController<GatewayResume>.broadcast();
  final _closeController = StreamController<GatewayCloseReason>.broadcast();
  final _failureController =
      StreamController<GatewayConnectFailure>.broadcast();

  @override
  Stream<GatewayEventPayload> get onEvent => _eventController.stream;

  /// Broadcast stream of [DuvetException]s forwarded from all active shards.
  Stream<DuvetException> get onError => _errorController.stream;

  /// Broadcast stream of the shards' connection states as they change:
  /// [GatewayConnectionState.reconnecting] when a socket dropped (READY comes
  /// again once a new one is open, or [onResume] with [resume]),
  /// [GatewayConnectionState.connected] when one opened, and
  /// [GatewayConnectionState.disconnected] once destroyed, or when the gateway
  /// refused a shard's options (4000): that shard opens no other socket, and
  /// a manager with other options takes its place.
  Stream<GatewayConnectionState> get onConnectionState =>
      _stateController.stream;

  /// Broadcast stream that fires when the gateway resumed a shard's session
  /// on a new socket ([resume]; [GatewayClient.onResume]): it's live again,
  /// with the events it missed delivered before, and no READY.
  Stream<GatewayResume> get onResume => _resumeController.stream;

  /// Broadcast stream of the reasons the gateway gives before it closes a
  /// shard's socket ([GatewayClient.onCloseReason]).
  Stream<GatewayCloseReason> get onCloseReason => _closeController.stream;

  /// Broadcast stream of the shards' attempts to open a socket that failed
  /// ([GatewayClient.onConnectFailure]): with the gateway's HTTP status, a
  /// 401 when it doesn't know the token, and how many failed in a row.
  Stream<GatewayConnectFailure> get onConnectFailure =>
      _failureController.stream;

  final RestClient api;
  final void Function(int shardId, String msg) _log;

  /// How long opening a socket may take before the attempt is dropped and
  /// another one starts ([defaultConnectTimeout]).
  final Duration connectTimeout;

  /// Whether a shard's socket that replaces one that dropped resumes its
  /// session ([GatewayClient.resume]). Off, as by default, each socket gets
  /// a READY.
  final bool resume;

  final List<GatewayClient> _shards = List.empty(growable: true);
  final List<StreamSubscription<dynamic>> _shardSubs =
      List.empty(growable: true);

  bool _destroyed = false;

  final ApiRouter router;

  GatewayManager(
    this.api, {
    void Function(int shardId, String msg)? log,
    ApiRouter? router,
    this.connectTimeout = defaultConnectTimeout,
    this.resume = false,
  })  : _log = log ?? defaultLog,
        router = router ?? const ApiRouter();

  /// Creates a manager with a default [RestClient].
  ///
  /// The internal [http.Client] will be closed when [destroy] is called.
  GatewayManager.withDefaultApi({
    void Function(int shardId, String msg)? log,
    ApiRouter? router,
    this.connectTimeout = defaultConnectTimeout,
    this.resume = false,
  })  : api = RestClient(http.Client()),
        _log = log ?? defaultLog,
        router = router ?? const ApiRouter();

  /// Spawns [shardCount] shards and connects each one: it completes once each
  /// has a socket open, trying again while one can't open (each attempt takes
  /// [connectTimeout] at most), and throws a [StateError] if the manager is
  /// destroyed first.
  Future<void> connectAll({int shardCount = 1}) async {
    if (_destroyed) throw StateError('GatewayManager has been destroyed.');
    for (var id = 0; id < shardCount; id++) {
      await _spawnShard(shardId: id, shardCount: shardCount);
    }
  }

  /// Permanently shuts down all shards and closes all streams.
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    for (final sub in _shardSubs) {
      sub.cancel();
    }
    for (final shard in _shards) {
      shard.destroy();
    }
    _shardSubs.clear();
    _shards.clear();
    _stateController.add(GatewayConnectionState.disconnected);
    _eventController.close();
    _errorController.close();
    _stateController.close();
    _resumeController.close();
    _closeController.close();
    _failureController.close();
    api.client.close();
    _log(-1, '[GatewayManager] destroyed');
  }

  /// Makes each shard's next identify start a new session, with READY,
  /// rather than resume its own ([GatewayClient.wantFreshSession]).
  void wantFreshSession() {
    for (final shard in _shards) {
      shard.wantFreshSession();
    }
  }

  /// Ends each shard's wait before its next attempt to open a socket, so that
  /// it tries now ([GatewayClient.retryNow]), and answers whether one was
  /// waiting.
  bool retryNow() {
    var waiting = false;
    for (final shard in _shards) {
      if (shard.retryNow()) waiting = true;
    }
    return waiting;
  }

  /// Sends an arbitrary event message through shard 0, and answers whether it
  /// went out on an open socket ([GatewayClient.sendMessage]).
  ///
  /// This is the manager-level equivalent of the TypeScript
  /// `sendEventMessage(type, data)` helper. All WebRTC / voice signalling
  /// messages should go through this method rather than reaching into
  /// individual [GatewayClient] instances; [WebRTCController] types them.
  ///
  /// Throws a [StateError] if no shards have been connected yet.
  bool sendMessage(String type, Map<String, dynamic> data) {
    if (_shards.isEmpty) {
      throw StateError('Cannot send "$type" — no shards are connected. '
          'Call connectAll() first.');
    }
    // Route through shard 0; update to round-robin / hash when sharding lands.
    return _shards[0].sendMessage(type, data);
  }

  /// Shard 0's [GatewayClient.connection]: the number of its open socket, or
  /// null while none is (and before [connectAll]).
  int? get connection => _shards.isEmpty ? null : _shards[0].connection;

  /// Shard 0's [GatewayClient.silenceBeforeReady].
  Duration get silenceBeforeReady =>
      _shards.isEmpty ? Duration.zero : _shards[0].silenceBeforeReady;

  Future<void> _spawnShard(
      {required int shardId, required int shardCount}) async {
    final client = GatewayClient(api,
        shardId: shardId,
        shardCount: shardCount,
        log: (msg) => _log(shardId, msg),
        router: router,
        connectTimeout: connectTimeout,
        resume: resume);

    _shardSubs.addAll([
      client.events.listen(
        (event) {
          if (!_eventController.isClosed) _eventController.add(event);
        },
        onError: (Object err, StackTrace st) {
          _log(shardId,
              '[GatewayManager] shard $shardId event-stream error: $err\n$st');
        },
        cancelOnError: false,
      ),
      client.errors.listen(
        (err) {
          if (!_errorController.isClosed) _errorController.add(err);
        },
        cancelOnError: false,
      ),
      client.onConnectionState.listen((state) {
        if (!_stateController.isClosed) _stateController.add(state);
      }),
      client.onResume.listen((resume) {
        if (!_resumeController.isClosed) _resumeController.add(resume);
      }),
      client.onCloseReason.listen((close) {
        if (!_closeController.isClosed) _closeController.add(close);
      }),
      client.onConnectFailure.listen((failure) {
        if (!_failureController.isClosed) _failureController.add(failure);
      }),
    ]);
    _shards.add(client);

    try {
      await client.connect();
    } catch (e) {
      if (_destroyed) throw StateError('GatewayManager has been destroyed.');
      _log(shardId, '[GatewayManager] shard $shardId could not connect: $e');
      // Until a socket opens, or the manager is destroyed.
      await client.reconnect();
      if (_destroyed) throw StateError('GatewayManager has been destroyed.');
    }
    _log(shardId, '[GatewayManager] shard $shardId online');
  }
}
