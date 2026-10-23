import 'dart:async';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// How long a request may go without progress before it fails with a
/// [TimeoutException]: connecting, each piece of its body sent and each piece
/// of the answer received count as progress, so an upload that keeps moving
/// isn't cut short.
const defaultRequestTimeout = Duration(seconds: 20);

// Bodies go out in pieces this big, so that progress, and the timeout, follow
// what the socket takes.
const _piece = 64 * 1024;

/// Sends [request] on [client] and reads the whole answer.
///
/// It fails with a [TimeoutException] when [timeout] passes without progress,
/// and with an [http.RequestAbortedException] when [abortTrigger] completes
/// first; either way the request is aborted where [client] supports it (the
/// default one does). [onProgress] gets the bytes of the body sent so far, and
/// their total.
Future<http.Response> sendWithin(
  http.Client client,
  http.BaseRequest request, {
  required Duration timeout,
  Future<void>? abortTrigger,
  void Function(int sent, int total)? onProgress,
}) async {
  // Completes with the reason the request stops early.
  final stop = Completer<Object>();
  void stopWith(Object reason) {
    if (!stop.isCompleted) stop.complete(reason);
  }

  Timer? idle;
  var finished = false;
  void alive() {
    if (finished) return;
    idle?.cancel();
    idle = Timer(
        timeout,
        () => stopWith(TimeoutException(
            'No progress on ${request.method} ${request.url.path} '
            'for ${timeout.inMilliseconds} ms',
            timeout)));
  }

  abortTrigger?.then((_) => stopWith(http.RequestAbortedException(request.url)),
      onError: (Object _) =>
          stopWith(http.RequestAbortedException(request.url)));

  final body = request.finalize();
  final total = request.contentLength ?? -1;
  var sent = 0;
  final sending = _Sending(
      request,
      _inPieces(body, (bytes) {
        sent += bytes;
        alive();
        onProgress?.call(sent, total);
      }),
      stop.future);

  alive();
  try {
    return await Future.any([
      _exchange(client, sending, alive),
      stop.future.then<http.Response>((reason) => throw reason),
    ]);
  } on http.RequestAbortedException {
    // The client's own error for the abort: the reason is ours.
    if (stop.isCompleted) throw await stop.future;
    rethrow;
  } finally {
    finished = true;
    idle?.cancel();
  }
}

Future<http.Response> _exchange(
    http.Client client, http.BaseRequest request, void Function() alive) async {
  final response = await client.send(request);
  alive();
  final bytes = await http.ByteStream(response.stream.map((chunk) {
    alive();
    return chunk;
  })).toBytes();
  return http.Response.bytes(bytes, response.statusCode,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase);
}

// [body] in pieces of at most [_piece] bytes, telling [sent] the size of each
// as it goes out. A piece is counted when the client takes it: while the socket
// is full the client pauses, and the pieces left wait.
Stream<List<int>> _inPieces(
        Stream<List<int>> body, void Function(int bytes) sent) =>
    body.transform(StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
      for (var start = 0; start < chunk.length; start += _piece) {
        final end = min(start + _piece, chunk.length);
        sink.add(chunk is Uint8List
            ? Uint8List.sublistView(chunk, start, end)
            : chunk.sublist(start, end));
      }
    })).map((piece) {
      sent(piece.length);
      return piece;
    });

// A finalized request as it goes out: its body in pieces, and abortable.
final class _Sending extends http.BaseRequest with http.Abortable {
  _Sending(http.BaseRequest inner, this._body, this.abortTrigger)
      : super(inner.method, inner.url) {
    headers.addAll(inner.headers);
    contentLength = inner.contentLength;
    followRedirects = inner.followRedirects;
    maxRedirects = inner.maxRedirects;
    persistentConnection = inner.persistentConnection;
  }

  final Stream<List<int>> _body;

  @override
  final Future<void>? abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_body);
  }
}
