// Parses the JSON the API and the gateway send. The fixtures in fixtures/
// are the server's own response types (Go structs) marshalled with every field
// set ("full"), with every nullable field null and every list empty
// ("nulls"), and with nested objects but null leaves ("partial", as a history
// message's partial user), so a field the server can leave out or send as null breaks a
// test here rather than an app.
//
// To make them again from the api and gateway checkouts:
// tool/fixtures/generate.sh.
import 'dart:convert';
import 'dart:io';

import 'package:duvet_client/duvet.dart';
import 'package:test/test.dart';

Map<String, dynamic> _load(String name, String variant) =>
    jsonDecode(File('test/fixtures/$name.$variant.json').readAsStringSync())
        as Map<String, dynamic>;

/// The fixture's variants. [always] are the keys the server always sets
/// although its type allows null (e.g. a room message's room_id): the nulls
/// variant takes them from the full one.
Map<String, Map<String, dynamic>> _variants(String name,
    {List<String> always = const []}) {
  final full = _load(name, 'full');
  final variants = {
    'full': full,
    'nulls': _load(name, 'nulls'),
    'partial': _load(name, 'partial'),
  };
  for (final json in variants.values) {
    for (final key in always) {
      json[key] = full[key];
    }
  }
  return variants;
}

/// A test per variant of [name] that [parse] parses it, then [check]s it.
void _parses<T>(String name, T Function(Map<String, dynamic>) parse,
    {List<String> always = const [], void Function(T, String)? check}) {
  for (final MapEntry(key: variant, value: json)
      in _variants(name, always: always).entries) {
    test('$name ($variant) → $T', () {
      final parsed = parse(json);
      check?.call(parsed, variant);
    });
  }
}

/// [json] with [key] set to null, as the server sends it in some cases.
Map<String, dynamic> _withNull(Map<String, dynamic> json, String key) =>
    {...json, key: null};

/// [json] without [key], as an omitempty field leaves it.
Map<String, dynamic> _without(Map<String, dynamic> json, String key) =>
    {...json}..remove(key);

void main() {
  group('users', () {
    _parses('user_me', UserMeResult.fromJson, check: (u, variant) {
      expect(u.createdAt, DateTime.utc(2026, 10, 22, 10, 0, 0, 123, 456));
      // The status the user chose: left out for a bot, and by an older API.
      expect(u.status, variant == 'full' ? UserStatus.dnd : isNull);
    });
    _parses('user', GatewayUser.fromJson);
    _parses('user', BotUser.fromJson);
    _parses('storage_status', StorageStatus.fromJson);
    _parses('attachment', Attachment.fromJson);
    _parses('bucket_list_row', StorageBucket.fromJson);
    _parses('bucket_create_row', StorageBucket.fromJson);
    _parses('team', Team.fromJson);
    _parses('team_member', TeamMember.fromJson);
    _parses('team_invite', TeamInvite.fromJson);
    _parses('application', Application.fromJson);
  });

  group('room messages', () {
    // A room message always has its room.
    const room = ['room_id'];
    _parses('message_response', GatewayMessage.fromJson, always: room);
    _parses('thread_message', GatewayMessage.fromJson, always: room);
    _parses('message_create', GatewayMessage.fromJson, always: room);
    _parses('message_update', GatewayMessage.fromJson, always: room);
    _parses('message_model', GatewayMessage.fromJson, always: room);

    final full = _load('message_response', 'full');

    test('embeds and components can be null', () {
      final m = GatewayMessage.fromJson(
          _withNull(_withNull(full, 'embeds'), 'components'));
      expect(m.embeds, isNull);
      expect(m.components, isNull);
    });

    test('a webhook message has no author', () {
      final m = GatewayMessage.fromJson(_withNull(full, 'author_id'));
      expect(m.authorId, isNull);
      expect(m.webhookId, isNotNull);
    });

    test('the user of a history message has zero times', () {
      final user = {
        ...(full['user'] as Map<String, dynamic>),
        'created_at': '0001-01-01T00:00:00Z',
        'updated_at': '0001-01-01T00:00:00Z',
      };
      final m = GatewayMessage.fromJson({...full, 'user': user});
      expect(m.user!.createdAt.year, 1);
    });

    test('omitempty fields can be missing', () {
      var json = full;
      for (final key in [
        'webhook_id',
        'user',
        'referenced_message',
        'interaction_metadata',
        'nonce',
      ]) {
        json = _without(json, key);
      }
      GatewayMessage.fromJson(json);
    });

    test('a referenced message can carry only its ids', () {
      final ref = {
        'type': 0,
        'message_id': 'm',
        'room_id': 'r',
        'space_id': null,
      };
      final m = GatewayMessage.fromJson({...full, 'referenced_message': ref});
      expect(m.referencedMessage!.messageId, 'm');
    });

    test('search', () {
      for (final json in _variants('message_search').values) {
        final r = MessageSearchResponse.fromJson(json, (m) {
          return GatewayMessage.fromJson(
              {...m, 'room_id': m['room_id'] ?? 'r1'});
        });
        expect(r.totalResults, isNonNegative);
      }
    });
  });

  group('direct messages', () {
    // A DM always has its author.
    const author = ['author_id'];
    _parses('message_response', DirectMessage.fromJson, always: author);
    _parses('dm_message_create', DirectMessage.fromJson, always: author);
    _parses('dm_message_update', DirectMessage.fromJson, always: author);
    // A conversation's thread has a room's thread's shape.
    _parses('thread_message', DirectMessage.fromJson, always: author);

    test('search', () {
      for (final json in _variants('message_search').values) {
        MessageSearchResponse.fromJson(
            json, (m) => DirectMessage.fromJson({...m, 'author_id': 'u1'}));
      }
    });
  });

  group('spaces', () {
    _parses('space', GatewaySpace.fromJson);
    _parses('room', GatewayRoom.fromJson);
    _parses('role', GatewayRole.fromJson);
    _parses('room_overwrite', GatewayRoomOverwrite.fromJson);
    _parses('invite_link', InviteLink.fromJson);
    _parses('invite_info', InviteInfo.fromJson);
    _parses('space_emoji', SpaceEmoji.fromJson);
    _parses('space_sticker', SpaceSticker.fromJson);
    _parses('webhook', Webhook.fromJson);
    _parses('webhook_create', WebhookCreateResponse.fromJson);
    _parses('space_member', SpaceMemberWithUser.fromJson);
    _parses('space_commands', SpaceCommands.fromJson);
    _parses('create_space_result', CreatedSpace.fromJson, check: (s, _) {
      expect(s.id, s.space.id);
      expect(s.rooms, hasLength(2));
    });

    test('a created space needs only the space and its rooms', () {
      final full = _load('create_space_result', 'full');
      final s = CreatedSpace.fromJson({
        for (final key in ['space', 'text_room', 'voice_room']) key: full[key],
      });
      expect(s.rooms.map((r) => r.id), [
        (full['text_room'] as Map)['id'],
        (full['voice_room'] as Map)['id'],
      ]);
    });
  });

  group('interactions', () {
    _parses('interaction_created', InteractionReply.fromJson,
        check: (r, variant) {
      expect(r.type, 2);
      expect(r.isModal, isFalse);
    });

    test('a modal: its data and application', () {
      final r = InteractionReply.fromJson(
          {..._load('interaction_created', 'full'), 'type': 9});
      expect(r.isModal, isTrue);
      expect(r.modal!['custom_id'], 's-string');
      expect(r.modal!['components'], isNotEmpty);
      expect(r.applicationId, isNotNull);
    });

    test('a modal without its application is not one to open', () {
      final r = InteractionReply.fromJson(
          {..._load('interaction_created', 'partial'), 'type': 9});
      expect(r.modal, isNotNull);
      expect(r.isModal, isFalse);
    });
  });

  group('conversations and friends', () {
    _parses('conversation', Conversation.fromJson);
    _parses('conversation_member_row', ConversationMember.fromJson);
    // Answered by adding a member when the list doesn't have them yet.
    _parses('conversation_member', ConversationMember.fromJson);
    _parses('friend', Friend.fromJson);
    _parses('friend_request_row', FriendRequest.fromJson);
    _parses('friend_request', FriendRequest.fromJson);

    test('a conversation\'s members can be null', () {
      final c = Conversation.fromJson(
          _withNull(_load('conversation', 'full'), 'members'));
      expect(c.members, isEmpty);
    });
  });

  group('gateway events', () {
    GatewayEventPayload? dispatch(String type, Map<String, dynamic> data) =>
        GatewayEnvelope.fromJson({
          'event': 'payload',
          'op': 1,
          'd': {'type': type, 'data': data},
          's': 7,
        }).d;

    // Each event the client handles: the fixture of its data, and the keys
    // the server always sets although its type allows null.
    const events = <String, (String, List<String>)>{
      'READY': ('ready_event', []),
      'SPACE_CREATE': ('space_create_event', []),
      'SPACE_UPDATE': ('space', []),
      'SPACE_DELETE': ('space_delete_event', []),
      'ROOM_CREATE': ('room', []),
      'ROOM_UPDATE': ('room', []),
      'ROOM_DELETE': ('room_delete_event', []),
      'ROOM_OVERWRITE_UPDATE': ('room_overwrite', []),
      'ROOM_OVERWRITE_DELETE': ('room_overwrite_delete_event', []),
      'MESSAGE_CREATE': ('message_create', ['room_id']),
      'MESSAGE_UPDATE': ('message_update', ['room_id']),
      'MESSAGE_DELETE': ('message_delete', []),
      'MENTION_CREATE': ('mention_create_event', []),
      'DM_MENTION_CREATE': ('dm_mention_create_event', []),
      'USER_UPDATE': ('user_update_event', []),
      'USER_STATUS_UPDATE': ('user_status_update_event', []),
      'VOICE_STATE_UPDATE': ('voice_state_update_event', []),
      'VOICE_JOINED': ('voice_joined_event', []),
      'VOICE_SESSION_REPLACED': ('voice_session_replaced_event', []),
      'WEBRTC_ICE_CANDIDATE': ('webrtc_ice_candidate_event', []),
      'WEBRTC_RENEGOTIATE': ('webrtc_renegotiate_event', []),
      'WEBRTC_RENEGOTIATE_ANSWER': ('webrtc_renegotiate_answer_event', []),
      'ROLE_CREATE': ('role', []),
      'ROLE_UPDATE': ('role', []),
      'ROLE_DELETE': ('role_delete_event', []),
      'MEMBER_ROLE_ADD': ('member_role_add_event', []),
      'MEMBER_ROLE_REMOVE': ('member_role_remove_event', []),
      'SPACE_MEMBER_ADD': ('space_member_add_event', []),
      'SPACE_MEMBER_REMOVE': ('space_member_remove_event', []),
      'SPACE_EMOJI_CREATE': ('space_emoji', []),
      'SPACE_EMOJI_UPDATE': ('space_emoji', []),
      'SPACE_EMOJI_DELETE': ('space_emoji', []),
      'SPACE_STICKER_CREATE': ('space_sticker', []),
      'SPACE_STICKER_UPDATE': ('space_sticker', []),
      'SPACE_STICKER_DELETE': ('space_sticker', []),
      'REACTION_ADD': ('reaction_add_event', []),
      'REACTION_REMOVE': ('reaction_remove_event', []),
      'FRIEND_REQUEST_CREATE': ('friend_request_create_event', []),
      'FRIEND_REQUEST_ACCEPT': ('friend_request_accept_event', []),
      'FRIEND_REQUEST_REJECT': ('friend_request_reject_event', []),
      'FRIEND_REMOVE': ('friend_remove_event', []),
      'CONVERSATION_CREATE': ('conversation', []),
      'CONVERSATION_UPDATE': ('conversation_update_event', []),
      'CONVERSATION_MEMBER_ADD': ('conversation_member_add_event', []),
      'CONVERSATION_MEMBER_REMOVE': ('conversation_member_remove_event', []),
      'DM_MESSAGE_CREATE': ('dm_message_create', ['author_id']),
      'DM_MESSAGE_UPDATE': ('dm_message_update', ['author_id']),
      'DM_MESSAGE_DELETE': ('dm_message_delete_event', []),
      'DM_REACTION_ADD': ('dm_reaction_add_event', []),
      'DM_REACTION_REMOVE': ('dm_reaction_remove_event', []),
      'TYPING': ('typing_event', []),
      'DM_TYPING': ('dm_typing_event', []),
      'CALL_INCOMING': ('call_incoming_event', []),
      'CALL_ACCEPTED': ('call_member_event', []),
      'CALL_DECLINED': ('call_member_event', []),
      'CALL_ENDED': ('call_ended_event', []),
    };

    // Handled by the client, but neither the API nor the gateway sends them.
    const unpublished = {
      'CONVERSATION_DELETE',
      'GUILD_MEMBER_ADD',
      'GUILD_MEMBER_REMOVE',
    };

    test('every event the client handles has a fixture', () {
      final source =
          File('lib/models/gateway_envelope.dart').readAsStringSync();
      final handled = RegExp(r"case '([A-Z_]+)'")
          .allMatches(source)
          .map((m) => m[1]!)
          .toSet();
      expect(handled.difference(unpublished).difference(events.keys.toSet()),
          isEmpty,
          reason: 'add the event\'s Go type to tool/fixtures and to `events`');
    });

    for (final MapEntry(key: type, value: (name, always)) in events.entries) {
      for (final MapEntry(key: variant, value: json)
          in _variants(name, always: always).entries) {
        test('$type ($variant)', () {
          final payload = dispatch(type, json);
          expect(payload, isNotNull);
          expect(payload, isNot(isA<UnknownEvent>()));
        });
      }
    }

    test('READY: active_calls can be null; the session token is camelCase', () {
      final e = dispatch(
              'READY', _withNull(_load('ready_event', 'full'), 'active_calls'))
          as ReadyEvent;
      expect(e.data.activeCalls, isNull);
      expect(e.data.sessionToken, isNotEmpty);
    });

    test('a bot\'s READY', () {
      for (final json in _variants('bot_ready_event').values) {
        expect(dispatch('READY', json), isA<ReadyEvent>());
      }
    });

    test('READY: the status the user chose; none from an older gateway', () {
      for (final json in _variants('ready_event').values) {
        final e = dispatch('READY', json) as ReadyEvent;
        expect(e.data.user.status, UserStatus.dnd);
      }
      final json = _load('ready_event', 'full');
      final user = _without(json['user'] as Map<String, dynamic>, 'status');
      final older = dispatch('READY', {...json, 'user': user}) as ReadyEvent;
      expect(older.data.user.status, isNull);
    });

    test('USER_UPDATE carries the bio; an older API leaves it out', () {
      final json = _load('user_update_event', 'full');
      final e = dispatch('USER_UPDATE', json) as UserUpdatedEvent;
      expect(e.data.custom, json['custom']);
      final older =
          dispatch('USER_UPDATE', _without(json, 'custom')) as UserUpdatedEvent;
      expect(older.data.custom, isNull);
    });

    test('SPACE_CREATE: rooms and roles are maps by ID', () {
      final e = dispatch('SPACE_CREATE', _load('space_create_event', 'full'))
          as SpaceCreateEvent;
      expect(e.data.rooms, isNotEmpty);
      expect(e.data.rolesPermissions, isNotEmpty);
    });

    test('SPACE_CREATE: the members\' statuses, none when left out', () {
      final full = dispatch('SPACE_CREATE', _load('space_create_event', 'full'))
          as SpaceCreateEvent;
      expect(full.data.memberStatuses, {'s-string': UserStatus.dnd});
      final nulls =
          dispatch('SPACE_CREATE', _load('space_create_event', 'nulls'))
              as SpaceCreateEvent;
      expect(nulls.data.memberStatuses, isEmpty);
    });

    test('mentions carry their message and author', () {
      final room =
          dispatch('MENTION_CREATE', _load('mention_create_event', 'full'))
              as MentionCreatedEvent;
      expect((room.data.messageId, room.data.roomId, room.data.authorId),
          ('s-string', 's-string', 's-string'));
      expect(room.data.conversationId, isNull);

      final json = _load('dm_mention_create_event', 'full');
      final dm = dispatch('DM_MENTION_CREATE', json) as DMMentionCreatedEvent;
      expect((dm.data.messageId, dm.data.conversationId, dm.data.authorId),
          (json['message_id'], json['conversation_id'], json['author_id']));
    });

    test('an event the client doesn\'t know', () {
      expect(dispatch('SOMETHING_NEW', {'a': 1}), isA<UnknownEvent>());
    });
  });

  group('voice and calls', () {
    GatewayEventPayload? dispatch(String type, Map<String, dynamic> data) =>
        GatewayEnvelope.fromJson({
          'event': 'payload',
          'op': 1,
          'd': {'type': type, 'data': data},
          's': 7,
        }).d;

    test('READY: the ICE servers, STUN and TURN with its credentials', () {
      final full =
          dispatch('READY', _load('ready_event', 'full')) as ReadyEvent;
      final server = full.data.iceServers.single;
      expect(server.urls, ['s-string']);
      expect(server.username, 's-string');
      // pion's credential is `any`: the fixture leaves it out.
      expect(server.credential, isNull);

      // As the gateway sends them: the STUN server, then the relay.
      final json = {
        ..._load('ready_event', 'nulls'),
        'ice_servers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
            'credentialType': 'password',
          },
          {
            'urls': [
              'turn:turn.duvet.chat:3478?transport=udp',
              'turns:turn.duvet.chat:5349?transport=tcp',
            ],
            'username': '1761300000:u1',
            'credential': 'c2VjcmV0',
            'credentialType': 'password',
          },
        ],
      };
      final ready = dispatch('READY', json) as ReadyEvent;
      expect(ready.data.iceServers.map((s) => s.toJson()), [
        {
          'urls': ['stun:stun.l.google.com:19302'],
        },
        {
          'urls': [
            'turn:turn.duvet.chat:3478?transport=udp',
            'turns:turn.duvet.chat:5349?transport=tcp',
          ],
          'username': '1761300000:u1',
          'credential': 'c2VjcmV0',
        },
      ]);

      final nulls =
          dispatch('READY', _load('ready_event', 'nulls')) as ReadyEvent;
      expect(nulls.data.iceServers, isEmpty);
      final bot =
          dispatch('READY', _load('bot_ready_event', 'full')) as ReadyEvent;
      expect(bot.data.iceServers, isEmpty);
    });

    test('an ICE server with one URL, or an OAuth credential', () {
      final s = IceServer.fromJson({
        'urls': 'stun:example.invalid',
        'credential': {'macKey': 'k', 'accessToken': 't'},
      });
      expect(s.urls, ['stun:example.invalid']);
      expect(s.credential, isNull);
    });

    test('READY: a call\'s voice states have their camera and version', () {
      final e = dispatch('READY', _load('ready_event', 'full')) as ReadyEvent;
      final state = e.data.activeCalls!.single.voiceStates!.single;
      expect((state.camera, state.version), (true, 2));
    });

    test('SPACE_CREATE: the voice rooms\' states', () {
      final e = dispatch('SPACE_CREATE', _load('space_create_event', 'full'))
          as SpaceCreateEvent;
      final state = e.data.voiceStates!.single;
      expect((state.muted, state.camera, state.version), (true, true, 2));
      final nulls =
          dispatch('SPACE_CREATE', _load('space_create_event', 'nulls'))
              as SpaceCreateEvent;
      expect(nulls.data.voiceStates, isEmpty);
    });

    test('VOICE_STATE_UPDATE: the whole state, with its version', () {
      final joined = dispatch(
              'VOICE_STATE_UPDATE', _load('voice_state_update_event', 'full'))
          as VoiceStateUpdatedEvent;
      expect((
        joined.data.joined,
        joined.data.muted,
        joined.data.deafened,
        joined.data.screenSharing,
        joined.data.camera,
        joined.data.version,
      ), (
        true,
        true,
        true,
        true,
        true,
        2
      ));
      final left = dispatch(
              'VOICE_STATE_UPDATE', _load('voice_state_update_event', 'nulls'))
          as VoiceStateUpdatedEvent;
      expect((left.data.joined, left.data.muted), (false, false));
    });

    test('VOICE_JOINED and the renegotiations carry their descriptions', () {
      final joined =
          dispatch('VOICE_JOINED', _load('voice_joined_event', 'full'))
              as VoiceJoinedPayloadEvent;
      expect(joined.data.answer?.sdp, 's-string');
      final offer = dispatch(
              'WEBRTC_RENEGOTIATE', _load('webrtc_renegotiate_event', 'full'))
          as WebRTCRenegotiateEvent;
      expect(
          (offer.data.roomId, offer.data.offer.sdp), ('s-string', 's-string'));
      final answer = dispatch('WEBRTC_RENEGOTIATE_ANSWER',
              _load('webrtc_renegotiate_answer_event', 'nulls'))
          as WebRTCRenegotiateAnswerEvent;
      expect(answer.data.answer, isNull);
    });

    test('WEBRTC_ICE_CANDIDATE: the candidate is a JSON string', () {
      // What webrtc.go sends: json.Marshal(candidate.ToJSON()) as a string.
      const init = '{"candidate":"candidate:1 1 udp 2130706431 45.77.6.83 '
          '50000 typ host","sdpMid":"0","sdpMLineIndex":0,'
          '"usernameFragment":null}';
      final e = dispatch('WEBRTC_ICE_CANDIDATE', {
        'candidate': init,
        'room_id': 'r1',
      }) as WebRTCIceCandidateEvent;
      expect(e.data.roomId, 'r1');
      expect(e.data.candidate.candidate,
          'candidate:1 1 udp 2130706431 45.77.6.83 50000 typ host');
      expect(
          (e.data.candidate.sdpMid, e.data.candidate.sdpMLineIndex), ('0', 0));
      expect(e.data.candidate.toJson(), {
        'candidate': 'candidate:1 1 udp 2130706431 45.77.6.83 50000 typ host',
        'sdpMid': '0',
        'sdpMLineIndex': 0,
      });
    });

    test('WEBRTC_ICE_CANDIDATE: an object, or a bare line', () {
      final object = dispatch('WEBRTC_ICE_CANDIDATE', {
        'candidate': {'candidate': 'candidate:x', 'sdpMLineIndex': 1},
        'room_id': 'r1',
      }) as WebRTCIceCandidateEvent;
      expect((object.data.candidate.candidate, object.data.candidate.sdpMid),
          ('candidate:x', null));
      // The fixture's string isn't JSON: the line itself.
      final line = dispatch('WEBRTC_ICE_CANDIDATE',
              _load('webrtc_ice_candidate_event', 'full'))
          as WebRTCIceCandidateEvent;
      expect(line.data.candidate.candidate, 's-string');
      final broken = dispatch('WEBRTC_ICE_CANDIDATE', {
        'candidate': '{not json',
        'room_id': 'r1',
      }) as WebRTCIceCandidateEvent;
      expect(broken.data.candidate.candidate, '{not json');
    });

    test('VOICE_SESSION_REPLACED: another device, or lost access', () {
      final json = _load('voice_session_replaced_event', 'full');
      final lost = dispatch('VOICE_SESSION_REPLACED', json)
          as VoiceSessionReplacedPayloadEvent;
      expect(lost.data.reason, 's-string');
      // omitempty: no reason when another device took the voice.
      final moved = dispatch('VOICE_SESSION_REPLACED', _without(json, 'reason'))
          as VoiceSessionReplacedPayloadEvent;
      expect((moved.data.roomId, moved.data.reason), ('s-string', null));
    });

    test('calls: incoming, accepted, declined, ended', () {
      final incoming =
          dispatch('CALL_INCOMING', _load('call_incoming_event', 'nulls'))
              as CallIncomingPayloadEvent;
      expect(incoming.data.initiatorAvatar, isNull);
      final accepted =
          dispatch('CALL_ACCEPTED', _load('call_member_event', 'full'))
              as CallAcceptedEvent;
      final declined =
          dispatch('CALL_DECLINED', _load('call_member_event', 'full'))
              as CallDeclinedEvent;
      expect((accepted.data.userId, declined.data.userId),
          ('s-string', 's-string'));
      expect(dispatch('CALL_ENDED', _load('call_ended_event', 'full')),
          isA<CallEndedPayloadEvent>());
    });
  });
}
