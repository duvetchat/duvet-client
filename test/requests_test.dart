// What each method sends: its method, path, query and body, as the desktop
// app's API layer (desktop-electrobun/src/mainview/src/lib/api/) sends them,
// and how the client renews its session.
import 'dart:convert';
import 'dart:io';

import 'package:duvet_client/duvet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _time = '2026-10-22T10:00:00.123456Z';

final _message = {
  'id': 'm1',
  'room_id': 'r1',
  'author_id': 'u1',
  'content': 'hi',
  'type': 0,
  'created_at': _time,
  'updated_at': _time,
};

final _room = {
  'id': 'r1',
  'space_id': 's1',
  'parent_id': null,
  'type': 1,
  'name': 'general',
  'description': null,
  'position': 0,
  'nsfw': false,
  'created_at': _time,
  'updated_at': _time,
};

final _role = {
  'id': 'ro1',
  'space_id': 's1',
  'name': 'mod',
  'color_from': null,
  'color_via': null,
  'color_to': null,
  'flags': 0,
  'permissions': 8,
  'hoisted': false,
  'position': 1,
  'created_at': _time,
  'updated_at': _time,
};

final _asset = {
  'id': 'e1',
  'name': 'cat',
  'space_id': 's1',
  'attachment_id': 'a1',
  'created_at': _time,
  'updated_at': _time,
};

/// A request as the mock server got it.
class Sent {
  final http.Request request;
  Sent(this.request);

  String get method => request.method;
  String get path => request.url.path;
  Map<String, List<String>> get query => request.url.queryParametersAll;
  String? get contentType => request.headers['content-type'];
  Map<String, dynamic> get json =>
      jsonDecode(request.body) as Map<String, dynamic>;
}

/// A client whose server answers [reply] (200, JSON) and records what it got.
({RestClient api, List<Sent> sent}) _client(Object? Function(Sent) reply,
    {String token = 'tok', String sessionToken = 'sess'}) {
  final sent = <Sent>[];
  final mock = MockClient((request) async {
    final s = Sent(request);
    sent.add(s);
    final body = reply(s);
    if (body is http.Response) return body;
    return http.Response(body == null ? '' : jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
  return (
    api: RestClient(mock, token: token, sessionToken: sessionToken),
    sent: sent
  );
}

void main() {
  group('headers', () {
    test('sends the access and session tokens', () async {
      final c = _client((_) => null);
      await c.api.leaveSpace('s1');
      final h = c.sent.single.request.headers;
      expect(h['Authorization'], 'Bearer tok');
      expect(h['X-Session-Token'], 'sess');
    });

    test('sends no auth headers without a session', () async {
      final c = _client(
          (_) => {
                'code': 'abc',
                'space_id': 's1',
                'space_name': 'S',
                'description': '',
                'member_count': 3,
              },
          token: '',
          sessionToken: '');
      await c.api.getInvite('abc');
      final h = c.sent.single.request.headers;
      expect(h.containsKey('Authorization'), isFalse);
      expect(h.containsKey('X-Session-Token'), isFalse);
    });

    test('JSON bodies say so; bodiless requests carry no content type',
        () async {
      final c = _client((_) => null);
      await c.api.pinRoomMessage('r1', 'm1');
      await c.api.inviteToTeam('t1', 'a@b.c');
      expect(c.sent[0].contentType, isNull);
      expect(c.sent[1].contentType, startsWith('application/json'));
    });
  });

  group('auth', () {
    test('logIn keeps the tokens of the body', () async {
      final c = _client((_) => {'token': 'A', 'session_token': 'S'},
          token: '', sessionToken: '');
      final signIn = await c.api.logIn('a@b.c', 'pw');
      expect(signIn.token, 'A');
      expect(c.api.token, 'A');
      expect(c.api.sessionToken, 'S');
      expect(c.sent.single.path, '/api/auth/login');
      expect(c.sent.single.json, {'email': 'a@b.c', 'password': 'pw'});
    });

    test('a failed logIn throws DuvetAuthException without refreshing',
        () async {
      final c = _client((_) => http.Response('{"error":"bad"}', 401));
      await expectLater(
          c.api.logIn('a@b.c', 'pw'), throwsA(isA<DuvetAuthException>()));
      expect(c.sent, hasLength(1));
    });

    test('signIn sends the account', () async {
      final c = _client((_) => null);
      await c.api.signIn(username: 'u', password: 'p', email: 'e@x.y');
      expect(c.sent.single.path, '/api/auth/signin');
      expect(c.sent.single.json,
          {'username': 'u', 'alias': null, 'password': 'p', 'email': 'e@x.y'});
    });

    test('logout forgets the tokens even when it fails', () async {
      final c = _client((_) => http.Response('', 500));
      await c.api.logout();
      expect(c.api.token, isEmpty);
      expect(c.api.sessionToken, isEmpty);
    });

    test('a 401 refreshes once for concurrent requests and retries them',
        () async {
      var refreshes = 0;
      final c = _client((s) {
        if (s.path == '/api/auth/refresh') {
          refreshes++;
          return {'token': 'new', 'session_token': 'sess2'};
        }
        if (s.request.headers['Authorization'] != 'Bearer new') {
          return http.Response('{"error":"expired"}', 401);
        }
        return [_message];
      });
      final pages = await Future.wait(
          [c.api.getMessages('r1'), c.api.getMessages('r1', before: 'm9')]);
      expect(pages.map((p) => p.single.id), ['m1', 'm1']);
      expect(refreshes, 1);
      final refresh = c.sent.firstWhere((s) => s.path == '/api/auth/refresh');
      expect(refresh.request.headers['X-Session-Token'], 'sess');
      expect(c.api.sessionToken, 'sess2');
    });

    test('a request is retried only once', () async {
      final c = _client((s) => s.path == '/api/auth/refresh'
          ? {'token': 'new'}
          : http.Response('', 401));
      await expectLater(c.api.getFriends(), throwsA(isA<DuvetAuthException>()));
      expect(c.sent.map((s) => s.path), [
        '/api/users/@me/friends',
        '/api/auth/refresh',
        '/api/users/@me/friends'
      ]);
    });

    test('a rejected refresh forgets the tokens', () async {
      final c = _client((s) => http.Response('', 401));
      await expectLater(c.api.getFriends(), throwsA(isA<DuvetAuthException>()));
      expect(c.api.token, isEmpty);
      expect(c.api.sessionToken, isEmpty);
    });

    test('a rate-limited refresh waits and tries again', () async {
      var refreshes = 0;
      final c = _client((s) {
        if (s.path == '/api/auth/refresh') {
          return ++refreshes == 1
              ? http.Response('', 429, headers: {'retry-after': '1'})
              : {'token': 'new'};
        }
        return s.request.headers['Authorization'] == 'Bearer new'
            ? <Object>[]
            : http.Response('', 401);
      });
      expect(await c.api.getFriends(), isEmpty);
      expect(refreshes, 2);
      expect(c.api.sessionToken, 'sess', reason: 'kept when none comes back');
    });

    test('without a session token a 401 just throws', () async {
      final c = _client((_) => http.Response('', 401), sessionToken: '');
      await expectLater(c.api.getFriends(), throwsA(isA<DuvetAuthException>()));
      expect(c.sent, hasLength(1));
    });

    test('other failures throw DuvetApiException with the status', () async {
      final c = _client((_) => http.Response('{"error":"nope"}', 404));
      await expectLater(
          c.api.getRoomPins('r1'),
          throwsA(isA<DuvetApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.body, 'body', contains('nope'))));
    });
  });

  group('messages', () {
    test('getMessages pages back by 100', () async {
      final c = _client((_) => [_message]);
      await c.api.getMessages('r1', before: 'm5');
      expect(c.sent.single.path, '/api/rooms/r1/messages');
      expect(c.sent.single.query, {
        'count': ['100'],
        'before': ['m5'],
      });
    });

    test('getMessagesAfter asks in ascending order', () async {
      final c = _client((_) => [_message]);
      await c.api.getMessagesAfter('r1', 'm5');
      expect(c.sent.single.query, {
        'count': ['100'],
        'after': ['m5'],
        'order': ['asc'],
      });
    });

    test('sendMessage without files sends JSON', () async {
      final c = _client((_) => _message);
      await c.api.sendMessage('r1', 'hello',
          nonce: 'n1',
          messageReference: const MessageReference(
              type: MessageReferenceType.reply, messageId: 'm0'),
          embeds: [
            const Embed(
                title: 'T',
                color: EmbedColor(colorFrom: 0xff0000),
                fields: [EmbedField(name: 'a', value: 'b', inline: true)])
          ],
          stickerAttachmentId: 'st1');
      final s = c.sent.single;
      expect(s.method, 'POST');
      expect(s.path, '/api/rooms/r1/messages');
      expect(s.json, {
        'content': 'hello',
        'nonce': 'n1',
        'message_reference': {'type': 0, 'message_id': 'm0'},
        'embeds': [
          {
            'title': 'T',
            'color': {'color_from': 0xff0000},
            'fields': [
              {'name': 'a', 'value': 'b', 'inline': true}
            ],
          }
        ],
        'sticker_attachment_id': 'st1',
      });
    });

    test('sendMessage with files sends a multipart form', () async {
      final dir = Directory.systemTemp.createTempSync('duvet_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/cat.png')..writeAsBytesSync([1, 2, 3]);

      final c = _client((_) => _message);
      await c.api.sendMessage('r1', 'look',
          nonce: 'n1',
          messageReference: const MessageReference(messageId: 'm0'),
          files: [file]);
      final s = c.sent.single;
      expect(s.contentType, startsWith('multipart/form-data; boundary='));
      final body = s.request.body;
      expect(body, contains('name="content"\r\n\r\nlook'));
      expect(body, contains('name="nonce"\r\n\r\nn1'));
      expect(body,
          contains('name="message_reference"\r\n\r\n{"message_id":"m0"}'));
      expect(body, contains('name="files"; filename="cat.png"'));
      expect(body, contains('content-type: image/png'));
      expect(body, isNot(contains('name="reference"')));
    });

    test('sendVoiceNote sends a WebM file of type 1', () async {
      final c = _client((_) => {..._message, 'type': 1});
      final m = await c.api.sendVoiceNote('r1', [1, 2, 3], nonce: 'n');
      expect(m.type, MessageType.voice);
      final body = c.sent.single.request.body;
      expect(body, contains('name="type"\r\n\r\n1'));
      expect(body, contains('filename="voice-note.webm"'));
      expect(body, contains('content-type: audio/webm'));
    });

    test('updateMessage and deleteMessage', () async {
      final c = _client((_) => _message);
      await c.api.updateMessage('m1', 'edited', 'r1');
      await c.api.deleteMessage('m1', 'r1');
      expect(c.sent[0].method, 'PATCH');
      expect(c.sent[0].path, '/api/rooms/r1/messages/m1');
      expect(c.sent[0].json, {'content': 'edited'});
      expect(c.sent[1].method, 'DELETE');
      expect(c.sent[1].path, '/api/rooms/r1/messages/m1');
    });

    test('pins and threads', () async {
      final c = _client((s) => s.method == 'GET' ? [_message] : null);
      await c.api.getRoomPins('r1');
      await c.api.pinRoomMessage('r1', 'm1');
      await c.api.unpinRoomMessage('r1', 'm1');
      await c.api.getMessageThread('r1', 'm1');
      expect(c.sent.map((s) => '${s.method} ${s.path}'), [
        'GET /api/rooms/r1/pins',
        'PUT /api/rooms/r1/pins/m1',
        'DELETE /api/rooms/r1/pins/m1',
        'GET /api/rooms/r1/messages/m1/thread',
      ]);
    });

    test('search repeats each list\'s key', () async {
      final c = _client((_) => {
            'total_results': 1,
            'messages': [_message],
          });
      final r = await c.api.searchSpaceMessages(
          's1',
          MessageSearch(
            query: 'a b',
            authorIds: ['u1', 'u2'],
            has: ['link'],
            pinned: false,
            before: DateTime.utc(2026, 1, 2),
            cursor: 'm7',
          ));
      expect(r.totalResults, 1);
      expect(r.messages.single.id, 'm1');
      expect(c.sent.single.path, '/api/spaces/s1/messages/search');
      expect(c.sent.single.query, {
        'query': ['a b'],
        'author_id': ['u1', 'u2'],
        'has': ['link'],
        'pinned': ['false'],
        'before': ['2026-01-02T00:00:00.000Z'],
        'cursor': ['m7'],
      });
    });

    test('typing indicators swallow failures', () async {
      final c = _client((_) => http.Response('', 500));
      await c.api.sendTypingIndicator('r1');
      await c.api.sendRecordingIndicator('r1');
      expect(c.sent.map((s) => s.path),
          ['/api/rooms/r1/typing', '/api/rooms/r1/recording']);
    });

    test('mention counts are read, and empty on failure', () async {
      final ok = _client((_) => {'r1': 2, 'c1': 1});
      expect(await ok.api.getMentionCounts(), {'r1': 2, 'c1': 1});
      expect(ok.sent.single.path, '/api/users/@me/mentions/counts');

      final failing = _client((_) => http.Response('', 500));
      expect(await failing.api.getMentionCounts(), isEmpty);
    });
  });

  group('reactions', () {
    test('room reactions encode the emoji once', () async {
      final c = _client((_) => null);
      await c.api.addRoomReaction('r1', 'm1', '👍');
      await c.api.removeRoomReaction('r1', 'm1', '👍');
      await c.api.removeRoomReaction('r1', 'm1', 'a/b#c');
      expect(c.sent[0].method, 'PUT');
      expect(c.sent[0].path, '/api/rooms/r1/messages/m1/reactions');
      expect(c.sent[0].json, {'emoji_name': '👍', 'emoji_id': null});
      expect(c.sent[1].request.url.toString(),
          endsWith('/api/rooms/r1/messages/m1/reactions/%F0%9F%91%8D'));
      expect(
          c.sent[2].request.url.toString(), endsWith('/reactions/a%2Fb%23c'));
    });

    test('conversation reactions', () async {
      final c = _client((_) => null);
      await c.api.addConversationReaction('c1', 'm1', 'cat', emojiId: 'e1');
      await c.api.removeConversationReaction('c1', 'm1', 'cat');
      expect(c.sent[0].path,
          '/api/users/@me/conversations/c1/messages/m1/reactions');
      expect(c.sent[0].json, {'emoji_name': 'cat', 'emoji_id': 'e1'});
      expect(c.sent[1].path,
          '/api/users/@me/conversations/c1/messages/m1/reactions/cat');
    });
  });

  group('rooms', () {
    test('createRoom sends the parent only when there is one', () async {
      final c = _client((_) => _room);
      await c.api.createRoom('s1', 'general', RoomType.text);
      await c.api.createRoom('s1', 'voice', RoomType.voice, parentId: 'cat1');
      expect(c.sent[0].json, {'name': 'general', 'type': 1});
      expect(c.sent[1].json, {'name': 'voice', 'type': 2, 'parent_id': 'cat1'});
    });

    test('updateRoom sends only what is given', () async {
      final c = _client((_) => _room);
      await c.api.updateRoom('s1', 'r1', name: 'x');
      await c.api.updateRoom('s1', 'r1',
          clearDescription: true, clearParent: true, position: 3);
      expect(c.sent[0].method, 'PATCH');
      expect(c.sent[0].path, '/api/spaces/s1/rooms/r1');
      expect(c.sent[0].json, {'name': 'x'});
      expect(c.sent[1].json,
          {'description': null, 'parent_id': null, 'position': 3});
    });

    test('overwrites and invites', () async {
      final c = _client((s) => switch (s.path) {
            '/api/spaces/s1/rooms/r1/overwrites' => {
                'id': 'o1',
                'room_id': 'r1',
                'target_id': 'ro1',
                'target_type': 0,
                'allow_flags': 1,
                'deny_flags': 2,
                'created_at': _time,
                'updated_at': _time,
              },
            '/api/spaces/s1/rooms/r1/invites' => {'code': 'abc'},
            _ => null,
          });
      final o = await c.api.upsertRoomOverwrite('s1', 'r1', 'ro1', 0, 1, 2);
      expect(o.allowFlags, 1);
      expect(c.sent[0].method, 'PUT');
      expect(c.sent[0].json, {
        'target_id': 'ro1',
        'target_type': 0,
        'allow_flags': 1,
        'deny_flags': 2,
      });
      await c.api.deleteRoomOverwrite('s1', 'r1', 'ro1');
      expect(c.sent[1].path, '/api/spaces/s1/rooms/r1/overwrites/ro1');
      expect(await c.api.createRoomInvite('s1', 'r1', 3600), 'abc');
      expect(c.sent[2].json, {'max_age': 3600});
    });
  });

  group('roles', () {
    test('createRole sends what is given', () async {
      final c = _client((_) => _role);
      await c.api.createRole('s1', 'mod', permissions: 8, hoisted: true);
      expect(c.sent.single.json,
          {'name': 'mod', 'permissions': 8, 'hoisted': true});
    });

    test('updateRole clears colors only when asked', () async {
      final c = _client((_) => _role);
      await c.api.updateRole('s1', 'ro1', colorFrom: 5);
      await c.api.updateRole('s1', 'ro1', clearColors: true);
      expect(c.sent[0].json, {'color_from': 5});
      expect(c.sent[1].json, {
        'color_from': null,
        'color_via': null,
        'color_to': null,
        'clear_colors': true,
      });
    });

    test('member roles take (space, role, member)', () async {
      final c = _client((_) => null);
      await c.api.assignRoleToMember('s1', 'ro1', 'mem1');
      await c.api.removeRoleFromMember('s1', 'ro1', 'mem1');
      expect(c.sent.map((s) => '${s.method} ${s.path}'), [
        'PUT /api/spaces/s1/members/mem1/roles/ro1',
        'DELETE /api/spaces/s1/members/mem1/roles/ro1',
      ]);
    });
  });

  group('emojis and stickers', () {
    test('create sends the file as "file" with its media type', () async {
      final dir = Directory.systemTemp.createTempSync('duvet_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/cat.webp')..writeAsBytesSync([1]);

      final c = _client((_) => _asset);
      await c.api.createEmoji('s1', 'cat', file);
      await c.api.createSticker('s1', 'cat', file);
      for (final s in c.sent) {
        expect(s.contentType, startsWith('multipart/form-data'));
        expect(s.request.body, contains('name="name"\r\n\r\ncat'));
        expect(s.request.body, contains('name="file"; filename="cat.webp"'));
        expect(s.request.body, contains('content-type: image/webp'));
      }
      expect(c.sent.map((s) => s.path),
          ['/api/spaces/s1/emojis', '/api/spaces/s1/stickers']);
    });

    test('list, update, delete', () async {
      final c = _client((s) => switch (s.method) {
            'GET' => [_asset],
            'PATCH' => _asset,
            _ => null,
          });
      expect(await c.api.listEmojis('s1'), hasLength(1));
      await c.api.updateSticker('s1', 'st1', 'dog');
      await c.api.deleteSticker('s1', 'st1');
      expect(c.sent[1].json, {'name': 'dog'});
      expect(c.sent.map((s) => '${s.method} ${s.path}'), [
        'GET /api/spaces/s1/emojis',
        'PATCH /api/spaces/s1/stickers/st1',
        'DELETE /api/spaces/s1/stickers/st1',
      ]);
    });
  });

  group('spaces', () {
    test('createSpace', () async {
      final c = _client((_) => null);
      await c.api.createSpace('S');
      await c.api.createSpace('S', description: 'd');
      expect(c.sent[0].json, {'name': 'S'});
      expect(c.sent[1].json, {'name': 'S', 'description': 'd'});
    });

    test('updateSpace sends JSON, or a form for images', () async {
      final c = _client((_) => {'id': 's1'});
      await c.api.updateSpace('s1', name: 'N');
      await c.api.updateSpace('s1', removeIcon: true);
      expect(c.sent[0].json, {'name': 'N'});
      expect(c.sent[1].contentType, startsWith('multipart/form-data'));
      expect(
          c.sent[1].request.body, contains('name="remove_icon"\r\n\r\ntrue'));
    });

    test('members are paged by highest role and ID', () async {
      final c = _client((_) => <Object>[]);
      await c.api.getSpaceMembers('s1');
      await c.api.getSpaceMembers('s1', afterId: 'mem9', afterPos: 2);
      expect(c.sent[0].query, {
        'count': ['50']
      });
      expect(c.sent[1].query, {
        'count': ['50'],
        'after_id': ['mem9'],
        'after_pos': ['2'],
      });
    });
  });

  group('friends', () {
    test('paths', () async {
      final c = _client((s) => switch ((s.method, s.path)) {
            ('POST', '/api/users/@me/friends/requests') => {
                'id': 'fr1',
                'sender_id': 'u1',
                'recipient_id': 'u2',
                'created_at': _time,
                'updated_at': _time,
              },
            ('POST', _) => {
                'id': 'f1',
                'request_id': 'fr1',
                'sender_id': 'u1',
                'recipient_id': 'u2',
                'user_username': 'bob',
                'user_alias': null,
                'user_avatar': null,
              },
            ('GET', _) => <Object>[],
            _ => null,
          });
      final request = await c.api.sendFriendRequest('u2');
      expect(request.userUsername, isNull);
      await c.api.getPendingRequests();
      await c.api.getSentRequests();
      final friend = await c.api.acceptFriendRequest('fr1');
      expect(friend.userUsername, 'bob');
      await c.api.rejectFriendRequest('fr1');
      await c.api.getFriends();
      await c.api.unfriend('u2');
      expect(c.sent.first.json, {'user_id': 'u2'});
      expect(c.sent.map((s) => '${s.method} ${s.path}'), [
        'POST /api/users/@me/friends/requests',
        'GET /api/users/@me/friends/requests',
        'GET /api/users/@me/friends/requests/sent',
        'POST /api/users/@me/friends/requests/fr1/accept',
        'DELETE /api/users/@me/friends/requests/fr1',
        'GET /api/users/@me/friends',
        'DELETE /api/users/@me/friends/u2',
      ]);
    });
  });

  group('conversations', () {
    final conversation = {
      'id': 'c1',
      'type': 1,
      'name': null,
      'owner_id': 'u1',
      'created_at': _time,
      'updated_at': _time,
      'deleted_at': null,
      'members': <Object>[],
    };
    final dm = {
      'id': 'd1',
      'conversation_id': 'c1',
      'author_id': 'u1',
      'content': 'yo',
      'type': 0,
      'created_at': _time,
      'updated_at': _time,
    };

    test('create DMs and groups', () async {
      final c = _client((_) => conversation);
      await c.api.createDM('u2');
      await c.api.createGroup('G', ['u2', 'u3']);
      expect(c.sent[0].json, {'type': 1, 'user_id': 'u2'});
      expect(c.sent[1].json, {
        'type': 2,
        'name': 'G',
        'user_ids': ['u2', 'u3'],
      });
    });

    test('messages', () async {
      final c = _client((s) => s.method == 'GET' ? [dm] : dm);
      await c.api.getDirectMessages('c1', before: 'd0');
      await c.api.getDirectMessagesAfter('c1', 'd0');
      await c.api.sendDirectMessage('c1', 'yo', nonce: 'n');
      await c.api.updateDirectMessage('c1', 'd1', 'edit');
      expect(c.sent[0].path, '/api/users/@me/conversations/c1/messages');
      expect(c.sent[0].query, {
        'count': ['100'],
        'before': ['d0'],
      });
      expect(c.sent[1].path, '/api/users/@me/conversations/c1/messages/after');
      expect(c.sent[1].query, {
        'count': ['100'],
        'after': ['d0'],
      });
      expect(c.sent[2].json, {'content': 'yo', 'nonce': 'n'});
      expect(c.sent[3].json, {'content': 'edit'});
    });

    test('members, pins, typing', () async {
      final c = _client((_) => null);
      await c.api.removeConversationMember('c1', 'u2');
      await c.api.leaveConversation('c1');
      await c.api.pinConversationMessage('c1', 'd1');
      await c.api.sendConversationTyping('c1');
      await c.api.sendConversationRecording('c1');
      expect(c.sent.map((s) => '${s.method} ${s.path}'), [
        'DELETE /api/users/@me/conversations/c1/members/u2',
        'DELETE /api/users/@me/conversations/c1/members/@me',
        'PUT /api/users/@me/conversations/c1/pins/d1',
        'POST /api/users/@me/conversations/c1/typing',
        'POST /api/users/@me/conversations/c1/recording',
      ]);
    });
  });

  group('interactions', () {
    test('component and command uses', () async {
      final c = _client((_) => {'type': 4});
      expect(
          await c.api.sendComponentInteraction(
              'r1', 'm1', const ComponentUse(customId: 'b', componentType: 2)),
          4);
      await c.api.sendCommandInteraction(
          'r1',
          'app1',
          const CommandUse(id: 'cmd1', name: 'roll', options: [
            UsedOption(name: 'sides', type: CommandOptionType.integer, value: 6)
          ]));
      expect(c.sent[0].path, '/api/interactions');
      expect(c.sent[0].json, {
        'type': 3,
        'room_id': 'r1',
        'message_id': 'm1',
        'data': {'custom_id': 'b', 'component_type': 2},
      });
      expect(c.sent[1].json, {
        'type': 2,
        'room_id': 'r1',
        'application_id': 'app1',
        'data': {
          'id': 'cmd1',
          'name': 'roll',
          'type': 1,
          'options': [
            {'name': 'sides', 'type': 4, 'value': 6}
          ],
        },
      });
    });

    test('space commands are cached, and a failed list is not', () async {
      var fail = true;
      final c = _client((_) => fail
          ? http.Response('', 500)
          : {'applications': <Object>[], 'commands': <Object>[]});
      await expectLater(
          c.api.getSpaceCommands('s1'), throwsA(isA<DuvetApiException>()));
      fail = false;
      await c.api.getSpaceCommands('s1');
      await c.api.getSpaceCommands('s1');
      expect(c.sent, hasLength(2));
      c.api.forgetSpaceCommands('s1');
      await c.api.getSpaceCommands('s1');
      expect(c.sent, hasLength(3));
    });
  });

  group('users', () {
    test('updateUser sends only what is given', () async {
      final c = _client((_) => {
            'id': 'u1',
            'username': 'me',
            'email': 'a@b.c',
            'email_verified': true,
            'alias': null,
            'birthdate': null,
            'phone': null,
            'avatar': null,
            'banner': null,
            'custom': '',
            'created_at': _time,
            'updated_at': _time,
          });
      await c.api.updateUser(username: 'me');
      await c.api.updateUser(clearAlias: true);
      expect(c.sent[0].json, {'username': 'me'});
      expect(c.sent[1].json, {'alias': null});
    });

    test('uploadProfileImage sends the crop', () async {
      final c = _client((_) => http.Response('', 500));
      await expectLater(
          c.api.uploadProfileImage(ProfileImageKind.avatar, [1], 'me.jpg',
              (x: 1.4, y: 2.6, w: 100, h: 100)),
          throwsA(isA<DuvetApiException>()));
      final body = c.sent.single.request.body;
      expect(body, contains('name="avatar_crop_x"\r\n\r\n1\r\n'));
      expect(body, contains('name="avatar_crop_y"\r\n\r\n3\r\n'));
      expect(body, contains('name="avatar"; filename="me.jpg"'));
      expect(body, contains('content-type: image/jpeg'));
    });
  });

  group('acks', () {
    test('at most one per room every interval, with the newest ID', () async {
      final c = _client((_) => null);
      await c.api.ackRoom('r1', '01');
      await c.api.ackRoom('r1', '03');
      await c.api.ackRoom('r1', '02');
      await c.api.ackConversation('c1', '01');
      expect(c.sent.map((s) => s.json['message_id']), ['01', '01']);
      await Future<void>.delayed(
          ackInterval + const Duration(milliseconds: 200));
      expect(c.sent.map((s) => '${s.path} ${s.json['message_id']}'), [
        '/api/rooms/r1/ack 01',
        '/api/users/@me/conversations/c1/ack 01',
        '/api/rooms/r1/ack 03',
      ]);
    });

    test('failures are swallowed', () async {
      final c = _client((_) => http.Response('', 500));
      await c.api.ackRoom('r1', '01');
      expect(c.sent, hasLength(1));
    });
  });
}
