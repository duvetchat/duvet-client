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

  @override
  Stream<GatewayEventPayload> get onEvent => _eventController.stream;

  /// Broadcast stream of [DuvetException]s forwarded from all active shards.
  Stream<DuvetException> get onError => _errorController.stream;

  final RestClient api;
  final void Function(int shardId, String msg) _log;

  final List<GatewayClient> _shards = List.empty(growable: true);
  final List<StreamSubscription<dynamic>> _shardSubs =
      List.empty(growable: true);
  final List<StreamSubscription<dynamic>> _shardErrorSubs =
      List.empty(growable: true);

  bool _destroyed = false;

  final ApiRouter router;

  GatewayManager(
    this.api, {
    void Function(int shardId, String msg)? log,
    ApiRouter? router,
  })  : _log = log ?? defaultLog,
        router = router ?? const ApiRouter();

  /// Creates a manager with a default [RestClient].
  ///
  /// The internal [http.Client] will be closed when [destroy] is called.
  GatewayManager.withDefaultApi({
    void Function(int shardId, String msg)? log,
    ApiRouter? router,
  })  : api = RestClient(http.Client()),
        _log = log ?? defaultLog,
        router = router ?? const ApiRouter();

  /// Spawns [shardCount] shards and connects each one.
  Future<void> connectAll({int shardCount = 1}) async {
    if (_destroyed) throw StateError('GatewayManager has been destroyed.');
    for (var id = 0; id < shardCount; id++) {
      await _spawnShard(shardId: id, shardCount: shardCount);
    }
  }

  /// Permanently shuts down all shards and closes all streams.
  void destroy() {
    _destroyed = true;
    for (final sub in _shardSubs) sub.cancel();
    for (final sub in _shardErrorSubs) sub.cancel();
    for (final shard in _shards) shard.destroy();
    _shardSubs.clear();
    _shardErrorSubs.clear();
    _shards.clear();
    _eventController.close();
    _errorController.close();
    api.client.close();
    _log(-1, '[GatewayManager] destroyed');
  }

  /// Sends an arbitrary event message through shard 0.
  ///
  /// This is the manager-level equivalent of the TypeScript
  /// `sendEventMessage(type, data)` helper. All WebRTC / voice signalling
  /// messages should go through this method rather than reaching into
  /// individual [GatewayClient] instances.
  ///
  /// Throws a [StateError] if no shards have been connected yet.
  void sendMessage(String type, Map<String, dynamic> data) {
    if (_shards.isEmpty) {
      throw StateError('Cannot send "$type" — no shards are connected. '
          'Call connectAll() first.');
    }
    // Route through shard 0; update to round-robin / hash when sharding lands.
    _shards[0].sendMessage(type, data);
  }

  Future<void> _spawnShard(
      {required int shardId, required int shardCount}) async {
    final client = GatewayClient(api,
        shardId: shardId,
        shardCount: shardCount,
        log: (msg) => _log(shardId, msg),
        router: router);

    final StreamSubscription<GatewayEventPayload> sub = client.events.listen(
      (event) {
        if (!_eventController.isClosed) _eventController.add(event);
      },
      onError: (Object err, StackTrace st) {
        _log(shardId,
            '[GatewayManager] shard $shardId event-stream error: $err\n$st');
      },
      cancelOnError: false,
    );

    final StreamSubscription<DuvetException> errorSub = client.errors.listen(
      (err) {
        if (!_errorController.isClosed) _errorController.add(err);
      },
      cancelOnError: false,
    );

    _shards.add(client);
    _shardSubs.add(sub);
    _shardErrorSubs.add(errorSub);

    await client.connect();
    _log(shardId, '[GatewayManager] shard $shardId online');
  }
}
