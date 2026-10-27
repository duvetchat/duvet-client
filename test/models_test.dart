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
      // An API from before mention_author.
      expect(m.referencedMessage!.mentionAuthor, isFalse);
    });

    test('a reply says whether it mentions the author it replies to', () {
      for (final name in ['message_create', 'message_response']) {
        final mentions = GatewayMessage.fromJson(_load(name, 'full'));
        expect(mentions.referencedMessage!.mentionAuthor, isTrue);
        final silent = GatewayMessage.fromJson(
            {..._load(name, 'partial'), 'room_id': 'r1'});
        expect(silent.referencedMessage!.mentionAuthor, isFalse);
      }
    });

    test('flags and interaction metadata, from the gateway and REST', () {
      for (final name in [
        'message_create',
        'message_update',
        'message_response'
      ]) {
        final m = GatewayMessage.fromJson(_load(name, 'full'));
        expect(m.flags, 2, reason: name);
        final meta = m.interactionMetadata!;
        expect((
          meta.type,
          meta.user.username,
          meta.name
        ), (
          2,
          's-string',
          's-string'
        ), reason: name);
        final none =
            GatewayMessage.fromJson({..._load(name, 'nulls'), 'room_id': 'r1'});
        expect(none.interactionMetadata, isNull, reason: name);
      }
    });

    test('an ephemeral message, and a deferred one loading', () {
      expect((MessageFlag.ephemeral, MessageFlag.loading), (64, 128));
      final m = GatewayMessage.fromJson(
          {...full, 'flags': MessageFlag.ephemeral | MessageFlag.loading});
      expect(m.flags & MessageFlag.ephemeral, isNonZero);
      expect(m.flags & MessageFlag.loading, isNonZero);
      expect(m.flags & MessageFlag.isComponentsV2, isZero);
      expect(GatewayMessage.fromJson(_without(full, 'flags')).flags, 0);
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
    _parses('friend', Friend.fromJson,
        check: (f, _) => expect(f.statusId, UserStatus.dnd));
    test('a friend\'s status: none from an older API', () {
      expect(
          Friend.fromJson(_without(_load('friend', 'full'), 'status_id'))
              .statusId,
          isNull);
    });
    _parses('friend_request_row', FriendRequest.fromJson);
    _parses('friend_request', FriendRequest.fromJson);

    test('a conversation\'s members can be null', () {
      final c = Conversation.fromJson(
          _withNull(_load('conversation', 'full'), 'members'));
      expect(c.members, isEmpty);
    });

    test('a member\'s and a DM\'s user: the whole public user, bio included',
        () {
      for (final user in [
        ConversationMember.fromJson(_load('conversation_member_row', 'full'))
            .user!,
        DirectMessage.fromJson(_load('dm_message_create', 'full')).user!,
      ]) {
        expect((user.custom, user.flags, user.emailVerified),
            ('s-string', 2, true));
        final at = DateTime.utc(2026, 10, 22, 10, 0, 0, 123, 456);
        expect((user.createdAt, user.updatedAt, user.deletedAt), (at, at, at));
      }
      final alive =
          ConversationMember.fromJson(_load('conversation_member_row', 'nulls'))
              .user!;
      expect((alive.deletedAt, alive.emailVerified), (null, false));
      // Without them: their defaults.
      final bare = ConversationUser.fromJson({'id': 'u1', 'username': 'maya'});
      expect((bare.custom, bare.flags, bare.createdAt), ('', 0, null));
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
      'CALL_OUTGOING': ('call_outgoing_event', []),
      'CALL_ONGOING': ('call_ongoing_event', []),
      'CALL_ACCEPTED': ('call_member_event', []),
      'CALL_DECLINED': ('call_member_event', []),
      'CALL_ENDED': ('call_ended_event', []),
      'MESSAGE_PIN_UPDATE': ('message_pin_update_event', []),
      'DM_MESSAGE_PIN_UPDATE': ('dm_message_pin_update_event', []),
      // The API's Recording and DMRecording are Typing and DMTyping.
      'RECORDING': ('typing_event', []),
      'DM_RECORDING': ('dm_typing_event', []),
      'ROOM_REORDER': ('room_reorder_event', []),
      'USER_ACTIVITY_UPDATE': ('user_activity_update_event', []),
      'TEAM_INVITE_CREATE': ('team_invite_create_event', []),
      'VOICE_VIDEO_REFUSED': ('voice_video_refused_event', []),
      'STORAGE_TRANSFER_UPDATE': ('storage_transfer_update_event', []),
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

    test('the events added after 1.0.1 are their own, no UnknownEvents', () {
      // A breaking change: they came as UnknownEvents, and a switch over
      // GatewayEventPayload with no default case has to handle them now.
      const added = <String, (String, Type)>{
        'MESSAGE_PIN_UPDATE': (
          'message_pin_update_event',
          MessagePinUpdatedEvent
        ),
        'DM_MESSAGE_PIN_UPDATE': (
          'dm_message_pin_update_event',
          DMMessagePinUpdatedEvent
        ),
        'RECORDING': ('typing_event', RecordingStartedEvent),
        'DM_RECORDING': ('dm_typing_event', DMRecordingStartedEvent),
        'ROOM_REORDER': ('room_reorder_event', RoomReorderedEvent),
        'USER_ACTIVITY_UPDATE': (
          'user_activity_update_event',
          UserActivityUpdatedEvent
        ),
        'TEAM_INVITE_CREATE': (
          'team_invite_create_event',
          TeamInviteCreatedEvent
        ),
        'VOICE_VIDEO_REFUSED': (
          'voice_video_refused_event',
          VoiceVideoRefusedPayloadEvent
        ),
        'STORAGE_TRANSFER_UPDATE': (
          'storage_transfer_update_event',
          StorageTransferUpdatedEvent
        ),
        'CALL_OUTGOING': ('call_outgoing_event', CallOutgoingPayloadEvent),
        'CALL_ONGOING': ('call_ongoing_event', CallOngoingPayloadEvent),
      };
      for (final MapEntry(key: type, value: (name, event)) in added.entries) {
        final e = dispatch(type, _load(name, 'full'));
        expect(e.runtimeType, event, reason: type);
        expect(e, isNot(isA<UnknownEvent>()), reason: type);
      }
    });

    test('MESSAGE_PIN_UPDATE: the message, and when it was pinned', () {
      final json = _load('message_pin_update_event', 'full');
      final pinned =
          dispatch('MESSAGE_PIN_UPDATE', json) as MessagePinUpdatedEvent;
      expect(
          (pinned.data.id, pinned.data.roomId), (json['id'], json['room_id']));
      expect(
          pinned.data.pinnedAt, DateTime.utc(2026, 10, 22, 10, 0, 0, 123, 456));
      final unpinned = dispatch(
              'MESSAGE_PIN_UPDATE', _load('message_pin_update_event', 'nulls'))
          as MessagePinUpdatedEvent;
      expect(unpinned.data.pinnedAt, isNull);
    });

    test('DM_MESSAGE_PIN_UPDATE: the message, and when it was pinned', () {
      final json = _load('dm_message_pin_update_event', 'full');
      final pinned =
          dispatch('DM_MESSAGE_PIN_UPDATE', json) as DMMessagePinUpdatedEvent;
      expect((pinned.data.id, pinned.data.conversationId),
          (json['id'], json['conversation_id']));
      expect(pinned.data.pinnedAt, isNotNull);
      final unpinned = dispatch('DM_MESSAGE_PIN_UPDATE',
              _load('dm_message_pin_update_event', 'nulls'))
          as DMMessagePinUpdatedEvent;
      expect(unpinned.data.pinnedAt, isNull);
    });

    test('RECORDING and DM_RECORDING: who records where, not typing', () {
      final room = dispatch('RECORDING', {
        'user_id': 'u2',
        'username': 'maya',
        'alias': 'Maya',
        'avatar': null,
        'room_id': 'r1',
      });
      expect(room, isA<RecordingStartedEvent>());
      expect(room, isNot(isA<TypingStartedEvent>()));
      final r = (room as RecordingStartedEvent).data;
      expect((r.userId, r.username, r.alias, r.roomId),
          ('u2', 'maya', 'Maya', 'r1'));

      final dm = dispatch('DM_RECORDING', _load('dm_typing_event', 'nulls'))
          as DMRecordingStartedEvent;
      expect((dm.data.conversationId, dm.data.alias), ('s-string', null));
      expect(dispatch('TYPING', _load('typing_event', 'full')),
          isNot(isA<RecordingStartedEvent>()));
    });

    test('ROOM_REORDER: every room, with its position and parent', () {
      final json = _load('room_reorder_event', 'full');
      final e = dispatch('ROOM_REORDER', json) as RoomReorderedEvent;
      final room = e.data.rooms.single;
      final sent = (json['rooms'] as List).single as Map<String, dynamic>;
      expect((room.id, room.spaceId, room.parentId, room.position),
          (sent['id'], sent['space_id'], sent['parent_id'], 2));
      final none =
          dispatch('ROOM_REORDER', _load('room_reorder_event', 'nulls'))
              as RoomReorderedEvent;
      expect(none.data.rooms, isEmpty);
    });

    test('USER_ACTIVITY_UPDATE: the activities, none when cleared', () {
      final e = dispatch('USER_ACTIVITY_UPDATE',
              _load('user_activity_update_event', 'full'))
          as UserActivityUpdatedEvent;
      expect(e.data.userId, 's-string');
      final a = e.data.activities.single;
      expect(a.type, ActivityType.listening);
      expect(
          (a.name, a.details, a.state), ('s-string', 's-string', 's-string'));
      expect((a.timestamps!.start, a.timestamps!.end), (2, 2));
      expect((
        a.assets!.largeImage,
        a.assets!.largeText,
        a.assets!.smallImage,
        a.assets!.smallText,
      ), (
        's-string',
        's-string',
        's-string',
        's-string'
      ));

      // Cleared: an empty list, or null.
      final json = _load('user_activity_update_event', 'nulls');
      for (final cleared in [json, _withNull(json, 'activities')]) {
        final e = dispatch('USER_ACTIVITY_UPDATE', cleared)
            as UserActivityUpdatedEvent;
        expect(e.data.activities, isEmpty);
      }
    });

    test('an activity as the gateway leaves it: playing, with a name alone',
        () {
      final a = Activity.fromJson({'name': 'Visual Studio Code'});
      expect((a.type, a.name), (ActivityType.playing, 'Visual Studio Code'));
      expect((a.details, a.state, a.timestamps, a.assets),
          (null, null, null, null));
    });

    test('TEAM_INVITE_CREATE: the invite, as the list of them has it', () {
      final json = _load('team_invite_create_event', 'full');
      final e = dispatch('TEAM_INVITE_CREATE', json) as TeamInviteCreatedEvent;
      expect((e.data.id, e.data.teamName, e.data.invitedByUsername),
          (json['id'], json['team_name'], json['invited_by_username']));
      expect(e.data.createdAt, DateTime.utc(2026, 10, 22, 10, 0, 0, 123, 456));
    });

    test('SPACE_CREATE: the members\' activities, none when left out', () {
      final full = dispatch('SPACE_CREATE', _load('space_create_event', 'full'))
          as SpaceCreateEvent;
      final activity = full.data.activities['s-string']!.single;
      expect(
          (activity.type, activity.name), (ActivityType.listening, 's-string'));
      // A bot's leaves them out.
      final nulls =
          dispatch('SPACE_CREATE', _load('space_create_event', 'nulls'))
              as SpaceCreateEvent;
      expect(nulls.data.activities, isEmpty);
    });

    test('SPACE_MEMBER_ADD: who joined, with their status and user', () {
      final json = _load('space_member_add_event', 'full');
      final added = dispatch('SPACE_MEMBER_ADD', json) as SpaceMemberAddedEvent;
      expect((added.data.userId, added.data.memberId, added.data.spaceId),
          (json['user_id'], json['member_id'], json['space_id']));
      expect(added.data.statusId, UserStatus.dnd);
      expect(added.data.user?.id, (json['user'] as Map)['id']);
      // omitempty: the user when the API has it.
      final bare =
          dispatch('SPACE_MEMBER_ADD', _load('space_member_add_event', 'nulls'))
              as SpaceMemberAddedEvent;
      expect((bare.data.statusId, bare.data.user), (UserStatus.dnd, null));

      final removed = dispatch(
              'SPACE_MEMBER_REMOVE', _load('space_member_remove_event', 'full'))
          as SpaceMemberRemovedEvent;
      expect(removed.data.userId, isNotNull);
      expect((removed.data.statusId, removed.data.user), (null, null));
    });

    test('USER_STATUS_UPDATE: a bot\'s carries its space; a person\'s none',
        () {
      final json = _load('user_status_update_event', 'full');
      final bot =
          dispatch('USER_STATUS_UPDATE', json) as UserStatusUpdatedEvent;
      expect(bot.data.spaceId, json['space_id']);
      final person = dispatch(
              'USER_STATUS_UPDATE', _load('user_status_update_event', 'nulls'))
          as UserStatusUpdatedEvent;
      expect(
          (person.data.spaceId, person.data.statusId), (null, UserStatus.dnd));
    });

    test('READY: active_calls can be null; the session token is camelCase', () {
      final e = dispatch(
              'READY', _withNull(_load('ready_event', 'full'), 'active_calls'))
          as ReadyEvent;
      expect(e.data.activeCalls, isNull);
      expect(e.data.sessionToken, isNotEmpty);
    });

    test('READY: whether each call rings and was answered, and who calls', () {
      final call =
          (dispatch('READY', _load('ready_event', 'full')) as ReadyEvent)
              .data
              .activeCalls!
              .single;
      expect((
        call.initiatorName,
        call.initiatorAvatar,
        call.ringing,
        call.answered
      ), (
        's-string',
        's-string',
        true,
        true
      ));

      // A gateway from before them leaves them out.
      final json = _load('ready_event', 'full');
      final listed =
          (json['active_calls'] as List).single as Map<String, dynamic>;
      for (final key in [
        'initiator_name',
        'initiator_avatar',
        'ringing',
        'answered'
      ]) {
        listed.remove(key);
      }
      final old =
          (dispatch('READY', json) as ReadyEvent).data.activeCalls!.single;
      expect(
          (old.initiatorName, old.initiatorAvatar, old.ringing, old.answered),
          (null, null, null, null));
    });

    test('a bot\'s READY', () {
      for (final json in _variants('bot_ready_event').values) {
        expect(dispatch('READY', json), isA<ReadyEvent>());
      }
    });

    test('READY: the spaces whose SPACE_CREATE follows', () {
      for (final name in ['ready_event', 'bot_ready_event']) {
        final full = dispatch('READY', _load(name, 'full')) as ReadyEvent;
        expect(full.data.guildIds, ['s-string'], reason: name);
        final none = dispatch('READY', _load(name, 'nulls')) as ReadyEvent;
        expect(none.data.guildIds, isEmpty, reason: name);
      }
      final older =
          dispatch('READY', _without(_load('ready_event', 'full'), 'guild_ids'))
              as ReadyEvent;
      expect(older.data.guildIds, isEmpty);
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

    test(
        'READY: each conversation\'s read position; none from an older '
        'gateway, nor for a bot', () {
      final json = _load('ready_event', 'full');
      final e = dispatch('READY', json) as ReadyEvent;
      expect(e.data.lastReadConvs, json['last_read_convs']);
      final read = dispatch('READY', {
        ...json,
        'last_read_convs': {'conversation-1': 'message-9'},
      }) as ReadyEvent;
      expect(read.data.lastReadConvs, {'conversation-1': 'message-9'});
      // None read yet: empty, not null.
      final none =
          dispatch('READY', _load('ready_event', 'nulls')) as ReadyEvent;
      expect(none.data.lastReadConvs, isEmpty);
      // A gateway before it leaves it out.
      final older =
          dispatch('READY', _without(json, 'last_read_convs')) as ReadyEvent;
      expect(older.data.lastReadConvs, isNull);
      final bot =
          dispatch('READY', _load('bot_ready_event', 'full')) as ReadyEvent;
      expect(bot.data.lastReadConvs, isNull);
    });

    test('USER_UPDATE carries the bio; an older API leaves it out', () {
      final json = _load('user_update_event', 'full');
      final e = dispatch('USER_UPDATE', json) as UserUpdatedEvent;
      expect(e.data.custom, json['custom']);
      final older =
          dispatch('USER_UPDATE', _without(json, 'custom')) as UserUpdatedEvent;
      expect(older.data.custom, isNull);
    });

    test('USER_UPDATE carries the flags and badges; an older API not', () {
      final json = _load('user_update_event', 'full');
      final e = dispatch('USER_UPDATE', json) as UserUpdatedEvent;
      expect((e.data.flags, e.data.badges), (2, 2));
      final older =
          dispatch('USER_UPDATE', _without(_without(json, 'flags'), 'badges'))
              as UserUpdatedEvent;
      expect((older.data.flags, older.data.badges), (null, null));
    });

    test('CONVERSATION_UPDATE: the name and the owner', () {
      final json = _load('conversation_update_event', 'full');
      final e =
          dispatch('CONVERSATION_UPDATE', json) as ConversationUpdatedEvent;
      expect((e.data.id, e.data.name, e.data.ownerId),
          (json['id'], json['name'], json['owner_id']));
      final older = dispatch('CONVERSATION_UPDATE', _without(json, 'owner_id'))
          as ConversationUpdatedEvent;
      expect(older.data.ownerId, isNull);
    });

    test('FRIEND_REQUEST_ACCEPT: the new friend\'s status', () {
      final json = _load('friend_request_accept_event', 'full');
      final e =
          dispatch('FRIEND_REQUEST_ACCEPT', json) as FriendRequestAcceptedEvent;
      expect(e.data.statusId, UserStatus.dnd);
      final older =
          dispatch('FRIEND_REQUEST_ACCEPT', _without(json, 'status_id'))
              as FriendRequestAcceptedEvent;
      expect(older.data.statusId, isNull);
    });

    test('STORAGE_TRANSFER_UPDATE: the transfer as it is now', () {
      final at = DateTime.utc(2026, 10, 22, 10, 0, 0, 123, 456);
      final full = (dispatch('STORAGE_TRANSFER_UPDATE',
                  _load('storage_transfer_update_event', 'full'))
              as StorageTransferUpdatedEvent)
          .data;
      expect(full.status, StorageTransferStatus.done);
      expect((full.keepSource, full.sameBucket, full.error),
          (true, true, 's-string'));
      expect((
        full.totalFiles,
        full.totalBytes,
        full.movedFiles,
        full.movedBytes,
        full.skippedFiles,
        full.failedFiles,
      ), (
        2,
        2,
        2,
        2,
        2,
        2
      ));
      expect((full.createdAt, full.startedAt, full.finishedAt, full.updatedAt),
          (at, at, at, at));
      expect(full.sourceBucketId, isNotNull);
      expect(full.targetBucketId, isNotNull);

      // Null buckets, the default storage, and not started yet.
      final queued = (dispatch('STORAGE_TRANSFER_UPDATE',
                  _load('storage_transfer_update_event', 'nulls'))
              as StorageTransferUpdatedEvent)
          .data;
      expect((queued.sourceBucketId, queued.targetBucketId), (null, null));
      expect((queued.error, queued.startedAt, queued.finishedAt),
          (null, null, null));
      expect((
        StorageTransferStatus.queued,
        StorageTransferStatus.moving,
        StorageTransferStatus.failed,
        StorageTransferStatus.cancelled,
      ), (
        0,
        1,
        3,
        4
      ));
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

    test('the reason the gateway closes a socket with', () {
      // What session.go's SendCloseReason writes.
      final close = GatewayCloseReason.fromJson({
        'event': 'close-with-reason',
        'code': 4004,
        'reason': 'session ended'
      });
      expect((close.code, close.reason, close.shardId),
          (GatewayCloseCode.invalidCredentials, 'session ended', 0));
      // The client says which shard's socket it was.
      expect(
          GatewayCloseReason.fromJson({'code': 4000}, shardId: 3).shardId, 3);
      expect((
        GatewayCloseCode.invalidShard,
        GatewayCloseCode.notIdentified,
        GatewayCloseCode.alreadyIdentified,
      ), (
        4000,
        4003,
        4005
      ));
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

    test('VOICE_VIDEO_REFUSED: which video, why, and the room\'s limit', () {
      // As webrtc.go writes it when the room has its cameras on already.
      final limit = dispatch('VOICE_VIDEO_REFUSED', {
        'room_id': 'r1',
        'kind': 'camera',
        'reason': 'limit',
        'limit': 8,
      }) as VoiceVideoRefusedPayloadEvent;
      expect((limit.data.roomId, limit.data.kind, limit.data.reason),
          ('r1', 'camera', 'limit'));
      expect(limit.data.limit, 8);
      // omitempty: no limit for another reason.
      final screen = dispatch('VOICE_VIDEO_REFUSED',
              _load('voice_video_refused_event', 'nulls'))
          as VoiceVideoRefusedPayloadEvent;
      expect(screen.data.limit, isNull);
    });

    test('calls: incoming, outgoing, ongoing, accepted, declined, ended', () {
      final incoming =
          dispatch('CALL_INCOMING', _load('call_incoming_event', 'nulls'))
              as CallIncomingPayloadEvent;
      expect(incoming.data.initiatorAvatar, isNull);
      final outgoing =
          dispatch('CALL_OUTGOING', _load('call_outgoing_event', 'full'))
              as CallOutgoingPayloadEvent;
      expect(outgoing.data.conversationId, 's-string');
      final ongoing =
          dispatch('CALL_ONGOING', _load('call_ongoing_event', 'full'))
              as CallOngoingPayloadEvent;
      expect(
          (ongoing.data.initiatorId, ongoing.data.voiceStates?.single.camera),
          ('s-string', true));
      // Null while nobody is in the call's voice.
      final empty = dispatch('CALL_ONGOING',
              _withNull(_load('call_ongoing_event', 'full'), 'voice_states'))
          as CallOngoingPayloadEvent;
      expect(empty.data.voiceStates, isNull);
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
