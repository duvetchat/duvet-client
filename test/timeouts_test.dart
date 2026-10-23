// How requests end when the server is slow or silent, against servers on
// 127.0.0.1: a request without progress for requestTimeout fails with a
// TimeoutException and drops its connection, a cancelled upload stops mid-way,
// and an upload that keeps moving isn't cut short.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:duvet_client/duvet.dart';
import 'package:duvet_client/http/router.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

const _time = '2026-10-23T09:00:00.123456Z';

final _message = {
  'id': 'm1',
  'room_id': 'r1',
  'author_id': 'u1',
  'content': 'look',
  'type': 0,
  'created_at': _time,
  'updated_at': _time,
};

/// A TCP server on 127.0.0.1 that takes connections and never answers. While
/// [reading] is false it doesn't read either, so what's sent to it backs up.
class _Silent {
  _Silent._(this._server, this.reading) {
    _server.listen((socket) {
      final sub = socket.listen((_) {}, onDone: () {
        _dropped.add(null);
        socket.destroy();
      }, onError: (Object _) {
        _dropped.add(null);
        socket.destroy();
      });
      if (!reading) sub.pause();
      _subs.add(sub);
    });
  }

  static Future<_Silent> start({bool reading = true}) async => _Silent._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), reading);

  final ServerSocket _server;
  final bool reading;
  final _subs = <StreamSubscription<Uint8List>>[];
  final _dropped = StreamController<void>.broadcast();

  /// An event each time a client closes its connection (seen once reading).
  Stream<void> get dropped => _dropped.stream;

  ApiRouter get router =>
      ApiRouter(api: '127.0.0.1:${_server.port}', secure: false);

  /// Reads again what's waiting.
  void resume() {
    for (final sub in _subs) {
      sub.resume();
    }
  }

  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _server.close();
    await _dropped.close();
  }
}

/// A client that takes each piece of a request's body after [pause] (by the
/// piece's number), then answers [_message].
class _SlowClient extends http.BaseClient {
  _SlowClient(this.pause);

  final Duration Function(int piece) pause;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var piece = 0;
    await for (final _ in request.finalize()) {
      await Future<void>.delayed(pause(piece++));
    }
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(_message))), 200,
        headers: {'content-type': 'application/json'});
  }
}

void main() {
  test('a request with no answer times out and drops its connection', () async {
    final server = await _Silent.start();
    addTearDown(server.close);
    final dropped = server.dropped.first;
    final api = RestClient(http.Client(),
        token: 'tok',
        router: server.router,
        requestTimeout: const Duration(milliseconds: 300));
    addTearDown(api.client.close);

    final watch = Stopwatch()..start();
    await expectLater(api.getFriends(), throwsA(isA<TimeoutException>()));
    expect(
        watch.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 300)));
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    await dropped.timeout(const Duration(seconds: 5));
  });

  test('a session refresh with no answer times out, keeping the tokens',
      () async {
    final server = await _Silent.start();
    addTearDown(server.close);
    final api = RestClient(http.Client(),
        token: 'tok',
        sessionToken: 'sess',
        router: server.router,
        requestTimeout: const Duration(milliseconds: 300));
    addTearDown(api.client.close);

    await expectLater(api.refreshSession(), throwsA(isA<TimeoutException>()));
    expect((api.token, api.sessionToken), ('tok', 'sess'));
  });

  test('a cancelled upload stops mid-way and drops its connection', () async {
    final dir = Directory.systemTemp.createTempSync('duvet_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/big.bin')
      ..writeAsBytesSync(Uint8List(8 << 20));

    // It reads nothing: the upload backs up, as on a stalled network.
    final server = await _Silent.start(reading: false);
    addTearDown(server.close);
    final dropped = server.dropped.first;
    final api = RestClient(http.Client(), token: 'tok', router: server.router);
    addTearDown(api.client.close);

    var sent = 0;
    var total = 0;
    final cancel = Completer<void>();
    final upload = api.sendMessage('r1', 'look',
        files: [file],
        onProgress: (s, t) => (sent, total) = (s, t),
        abortTrigger: cancel.future);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    cancel.complete();

    await expectLater(upload, throwsA(isA<http.RequestAbortedException>()));
    expect(sent, greaterThan(0));
    expect(sent, lessThan(total));
    server.resume();
    await dropped.timeout(const Duration(seconds: 5));
  });

  test('an upload to a slow server reports its progress and finishes',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var received = 0;
    server.listen((request) async {
      await for (final chunk in request) {
        received += chunk.length;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_message));
      await request.response.close();
    });
    final dir = Directory.systemTemp.createTempSync('duvet_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/big.bin')
      ..writeAsBytesSync(Uint8List(4 << 20));
    final api = RestClient(http.Client(),
        token: 'tok',
        router: ApiRouter(api: '127.0.0.1:${server.port}', secure: false));
    addTearDown(api.client.close);

    final progress = <int>[];
    var total = 0;
    final message = await api.sendMessage('r1', 'look', files: [file],
        onProgress: (sent, t) {
      progress.add(sent);
      total = t;
    });

    expect(message.id, 'm1');
    expect(received, total);
    expect(progress.length, greaterThan(10));
    expect(progress.last, total);
    for (var i = 1; i < progress.length; i++) {
      expect(progress[i], greaterThan(progress[i - 1]));
    }
  });

  group('the timeout counts from the last progress', () {
    final files = [
      (field: 'files', bytes: Uint8List(10 * 64 * 1024), filename: 'a.bin'),
    ];

    test('so an upload longer than it goes through', () async {
      final api = RestClient(
          _SlowClient((_) => const Duration(milliseconds: 100)),
          token: 'tok',
          requestTimeout: const Duration(milliseconds: 400));
      final watch = Stopwatch()..start();
      await api.request('POST', '/api/rooms/r1/messages', 'upload',
          files: files);
      expect(watch.elapsed, greaterThan(const Duration(milliseconds: 800)));
    });

    test('and an upload that stalls for longer fails', () async {
      final api = RestClient(
          _SlowClient((piece) => Duration(milliseconds: piece == 3 ? 900 : 50)),
          token: 'tok',
          requestTimeout: const Duration(milliseconds: 400));
      await expectLater(
          api.request('POST', '/api/rooms/r1/messages', 'upload', files: files),
          throwsA(isA<TimeoutException>()));
    });
  });
}
