// Parses what the live instance (api.duvet.chat, ws.duvet.chat) really sends.
// Read-only: it changes nothing on the account.
//
//   DUVET_LIVE=1 dart test -t live                # the checks needing no account
//   DUVET_LIVE=1 DUVET_EMAIL=… DUVET_PASSWORD=… dart test -t live
//
// A response a model can't parse fails its test with the JSON that broke it.
@Tags(['live'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duvet_client/duvet.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Keeps the last body each URL answered, to show the JSON a model choked on.
class _Recorder extends http.BaseClient {
  final _inner = http.Client();
  final bodies = <String, String>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    final bytes = await response.stream.toBytes();
    bodies['${request.method} ${request.url.path}'] = utf8.decode(bytes);
    return http.StreamedResponse(Stream.value(bytes), response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: request);
  }

  @override
  void close() => _inner.close();
}

final _email = Platform.environment['DUVET_EMAIL'];
final _password = Platform.environment['DUVET_PASSWORD'];
final _noAccount = _email == null || _password == null
    ? 'set DUVET_EMAIL and DUVET_PASSWORD to check the account\'s data'
    : null;

String _trim(String s) => s.length > 2000 ? '${s.substring(0, 2000)}…' : s;

void main() {
  if (Platform.environment['DUVET_LIVE'] != '1') {
    test('live instance', () {}, skip: 'set DUVET_LIVE=1 to check it');
    return;
  }

  final recorder = _Recorder();
  final api = RestClient(recorder);
  tearDownAll(recorder.close);

  /// Runs [call]; when it throws anything but an API error, fails with the
  /// JSON of [key] (the request's "METHOD /path").
  Future<T> parsed<T>(String key, Future<T> Function() call) async {
    try {
      return await call();
    } on DuvetApiException {
      rethrow;
    } catch (e, st) {
      fail('$key: $e\n$st\nJSON:\n${_trim(recorder.bodies[key] ?? '(none)')}');
    }
  }

  group('without an account', () {
    test('an unknown invite is a DuvetApiException', () async {
      await expectLater(
          api.getInvite('no-such-invite-code'),
          throwsA(isA<DuvetApiException>().having(
              (e) => e.statusCode, 'statusCode', inInclusiveRange(400, 499))));
    });

    test('wrong credentials are a DuvetApiException', () async {
      final anon = RestClient(http.Client());
      await expectLater(anon.logIn('nobody@example.invalid', 'wrong-password'),
          throwsA(isA<DuvetApiException>()));
    });
  });

  group('with an account', skip: _noAccount, () {
    late GatewayReadyData ready;
    late List<GatewaySpaceCreatePayload> spaces;

    setUpAll(() async {
      await api.logIn(_email!, _password!);
      final identified = await _identify(api);
      ready = identified.ready;
      spaces = identified.spaces;
      print('gateway events: ${identified.events}');
    });

    tearDownAll(() {
      final checked = recorder.bodies.keys.toList()..sort();
      print('${checked.length} responses parsed:\n  ${checked.join('\n  ')}');
    });

    test('READY parsed', () {
      expect(ready.user.id, isNotEmpty);
    });

    test('me', () async {
      final me = await parsed('GET /api/users/@me', api.me);
      expect(me.id, ready.user.id);
    });

    test('user lists', () async {
      await parsed('GET /api/users/@me/mentions/counts', api.getMentionCounts);
      await parsed('GET /api/users/@me/storage', api.getMyStorageStatus);
      await parsed('GET /api/users/@me/attachments', api.getMyAttachments);
      await parsed('GET /api/users/@me/buckets', api.getMyBuckets);
      await parsed('GET /api/users/@me/friends', api.getFriends);
      await parsed(
          'GET /api/users/@me/friends/requests', api.getPendingRequests);
      await parsed(
          'GET /api/users/@me/friends/requests/sent', api.getSentRequests);
      await parsed('GET /api/users/@me/team-invites', api.listMyTeamInvites);
    });

    test('teams and applications', () async {
      final teams = await parsed('GET /api/users/@me/teams', api.listTeams);
      for (final team in teams.take(3)) {
        await parsed('GET /api/users/@me/teams/${team.id}/members',
            () => api.listTeamMembers(team.id));
        final apps = await parsed(
            'GET /api/users/@me/teams/${team.id}/applications',
            () => api.listApplications(team.id));
        for (final app in apps.where((a) => a.botUserId != null).take(3)) {
          await parsed('GET /api/users/${app.botUserId}',
              () => api.getBotUser(app.botUserId!));
        }
      }
    });

    test('conversations and their messages', () async {
      final conversations = await parsed(
          'GET /api/users/@me/conversations', api.getConversations);
      for (final c in conversations.take(5)) {
        final base = 'GET /api/users/@me/conversations/${c.id}';
        final messages =
            await parsed('$base/messages', () => api.getDirectMessages(c.id));
        await parsed('$base/pins', () => api.getConversationPins(c.id));
        await parsed(
            '$base/messages/search',
            () => api.searchConversationMessages(
                c.id, MessageSearch(before: DateTime.now())));
        if (messages.isNotEmpty) {
          final last = messages.last;
          await parsed('$base/messages/${last.id}',
              () => api.getDirectMessageById(c.id, last.id));
          await parsed('$base/messages/after',
              () => api.getDirectMessagesAfter(c.id, last.id));
        }
      }
    });

    test('spaces and their rooms', () async {
      for (final created in spaces.take(5)) {
        final space = created.space;
        final rooms = created.rooms.values;
        final base = 'GET /api/spaces/${space.id}';
        await parsed('$base/members', () => api.getSpaceMembers(space.id));
        await parsed('$base/emojis', () => api.listEmojis(space.id));
        await parsed('$base/stickers', () => api.listStickers(space.id));
        await parsed('$base/commands', () => api.getSpaceCommands(space.id));
        await parsed(
            '$base/messages/search',
            () => api.searchSpaceMessages(
                space.id, MessageSearch(before: DateTime.now())));
        // These need permissions the account may not have in the space.
        for (final (key, call) in <(String, Future<Object?> Function())>[
          ('$base/invites', () => api.listSpaceInvites(space.id)),
          ('$base/attachments', () => api.getSpaceAttachments(space.id)),
          (
            '$base/attachments/storage',
            () => api.getSpaceStorageUsed(space.id)
          ),
          ('$base/buckets', () => api.getSpaceBuckets(space.id)),
        ]) {
          try {
            await parsed(key, call);
          } on DuvetApiException catch (e) {
            if (e.statusCode != 403) rethrow;
          }
        }

        for (final room
            in rooms.where((r) => r.type == RoomType.text).take(3)) {
          final roomBase = 'GET /api/rooms/${room.id}';
          final messages = await parsed(
              '$roomBase/messages', () => api.getMessages(room.id));
          await parsed('$roomBase/pins', () => api.getRoomPins(room.id));
          try {
            await parsed(
                'GET /api/spaces/${space.id}/rooms/${room.id}/webhooks',
                () => api.listWebhooks(space.id, room.id));
          } on DuvetApiException catch (e) {
            if (e.statusCode != 403) rethrow;
          }
          if (messages.isNotEmpty) {
            final oldest = messages.last;
            await parsed('$roomBase/messages/${oldest.id}',
                () => api.getMessageById(room.id, oldest.id));
            await parsed('$roomBase/messages/${oldest.id}/thread',
                () => api.getMessageThread(room.id, oldest.id));
            await parsed('$roomBase/messages',
                () => api.getMessagesAfter(room.id, oldest.id));
          }
        }
      }
    });
  });
}

/// What the gateway sent on identifying: READY and the spaces' SPACE_CREATE.
typedef _Identified = ({
  GatewayReadyData ready,
  List<GatewaySpaceCreatePayload> spaces,
  Map<String, int> events,
});

/// Connects to the gateway as [api]'s session, identifies, and parses every
/// event until READY and then until it goes quiet for a few seconds.
Future<_Identified> _identify(RestClient api) async {
  final ws = api.router.getCustomApiUrl(protocol: 'ws');
  final socket =
      await WebSocket.connect('wss://$ws/gateway?token=${api.token}');
  final incoming = StreamIterator(socket);
  GatewayReadyData? ready;
  final spaces = <GatewaySpaceCreatePayload>[];
  final events = <String, int>{};
  try {
    socket.add(jsonEncode({
      'type': 'identify',
      'data': {'token': api.token},
    }));
    // Up to 20s for READY; the spaces come after it, until it goes quiet.
    while (await incoming.moveNext().timeout(
        Duration(seconds: ready == null ? 20 : 3),
        onTimeout: () => false)) {
      final raw = incoming.current as String;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = '${json['d']?['type'] ?? json['event']}';
      events[type] = (events[type] ?? 0) + 1;
      final GatewayEnvelope envelope;
      try {
        envelope = GatewayEnvelope.fromJson(json);
      } catch (e, st) {
        fail('gateway $type: $e\n$st\nJSON:\n${_trim(raw)}');
      }
      switch (envelope.d) {
        case ReadyEvent(:final data):
          ready = data;
        case SpaceCreateEvent(:final data):
          spaces.add(data);
        default:
      }
    }
  } finally {
    await socket.close();
    await incoming.cancel();
  }
  if (ready == null) throw StateError('no READY from the gateway');
  return (ready: ready, spaces: spaces, events: events);
}
