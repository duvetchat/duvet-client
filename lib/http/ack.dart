import 'dart:async';

// Read acks go out at most once per room or conversation every ackInterval:
// reading a busy room would otherwise send one per message. The first goes out
// at once; later ones within the interval merge into one trailing ack with the
// newest message ID. IDs are UUIDv7, so they compare by time as strings.
const ackInterval = Duration(seconds: 3);

class _AckState {
  String? sentId;
  DateTime sentAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? pendingId;
  Timer? timer;
}

/// Wraps a send so each key gets at most one ack per interval, never one
/// older than what was sent.
class AckThrottle {
  final Future<void> Function(String key, String messageId) _send;
  final _states = <String, _AckState>{};

  AckThrottle(this._send);

  Future<void> call(String key, String messageId) {
    final state = _states.putIfAbsent(key, _AckState.new);
    final pending = state.pendingId;
    if (pending == null || messageId.compareTo(pending) > 0) {
      state.pendingId = messageId;
    }
    if (state.timer != null) return Future.value();
    final wait = state.sentAt.add(ackInterval).difference(DateTime.now());
    if (wait <= Duration.zero) return _flush(key, state);
    state.timer = Timer(wait, () => _flush(key, state));
    return Future.value();
  }

  Future<void> _flush(String key, _AckState state) {
    state.timer = null;
    final id = state.pendingId;
    state.pendingId = null;
    final sent = state.sentId;
    if (id == null || (sent != null && id.compareTo(sent) <= 0)) {
      return Future.value();
    }
    state.sentId = id;
    state.sentAt = DateTime.now();
    return _send(key, id);
  }

  /// Cancels the trailing acks still waiting.
  void dispose() {
    for (final state in _states.values) {
      state.timer?.cancel();
    }
    _states.clear();
  }
}
