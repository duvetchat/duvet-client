import 'dart:async';
import 'dart:io';
import 'dart:convert' show jsonEncode, jsonDecode;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:duvet_client/http/ack.dart';
import 'package:duvet_client/http/router.dart';
import 'package:duvet_client/http/send.dart';
import 'package:duvet_client/errors.dart';
import 'package:duvet_client/models/types.dart';

// A voice note goes as the file voice-note.<format>, with the media type of its
// format: WebM/Opus as the desktop app records it, Ogg/Opus, or AAC in MP4.
const _voiceNote = 'voice-note';
const _voiceNoteTypes = {
  'webm': 'audio/webm',
  'ogg': 'audio/ogg',
  'm4a': 'audio/mp4',
};

/// How many members a page of [RestMethods.getSpaceMembers] has.
const membersPageSize = 50;

/// A file part of a multipart request.
typedef FilePart = ({String field, List<int> bytes, String filename});

// The media types of the files the API takes, by extension: it keeps the type
// a file part declares.
const _mediaTypes = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'avif': 'image/avif',
  'svg': 'image/svg+xml',
  'mp4': 'video/mp4',
  'webm': 'video/webm',
  'mov': 'video/quicktime',
  'mp3': 'audio/mpeg',
  'm4a': 'audio/mp4',
  'ogg': 'audio/ogg',
  'wav': 'audio/wav',
  'flac': 'audio/flac',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'json': 'application/json',
  'zip': 'application/zip',
};

MediaType _mediaTypeOf(String filename) {
  final dot = filename.lastIndexOf('.');
  final ext = dot < 0 ? '' : filename.substring(dot + 1).toLowerCase();
  // A voice note's WebM is audio, where any other WebM is a video.
  final voiceNote = dot >= 0 && filename.substring(0, dot) == _voiceNote
      ? _voiceNoteTypes[ext]
      : null;
  return MediaType.parse(
      voiceNote ?? _mediaTypes[ext] ?? 'application/octet-stream');
}

// A file's name without its folders: on Windows a path may separate them with
// either slash.
String _basename(String path) =>
    path.split(Platform.isWindows ? RegExp(r'[/\\]') : RegExp('/')).last;

// ---------------------------------------------------------------------------
// Api responses
// ---------------------------------------------------------------------------

mixin RestMethods {
  http.Client get client;
  ApiRouter get router;
  Map<String, String> get authHeaders;

  /// Renews the session's tokens after a request got a 401, and answers
  /// whether it did: the request is then sent once more.
  Future<bool> renewSession() async => false;

  /// How long a request may go without progress before it fails with a
  /// [TimeoutException] ([defaultRequestTimeout]: connecting, sending its body
  /// and receiving the answer count as progress).
  Duration get requestTimeout => defaultRequestTimeout;

  // -------------------------------------------------------------------------
  // Auth (logging in and out is [RestClient]'s, which keeps the tokens)
  // -------------------------------------------------------------------------

  /// Makes an account; it is verified by the link the API emails.
  Future<void> signIn({
    required String username,
    String? alias,
    required String password,
    required String email,
  }) async {
    await request('POST', '/api/auth/signin', 'sign in',
        json: {
          'username': username,
          'alias': alias,
          'password': password,
          'email': email,
        },
        renew: false);
  }

  Future<void> verifyEmail(String token) async {
    await request('POST', '/api/auth/verify', 'verify email',
        json: {'token': token}, renew: false);
  }

  Future<void> sendVerificationEmail() async {
    await request('POST', '/api/auth/verify/send', 'send verification email');
  }

  Future<void> resetPassword(String token, String password) async {
    await request('POST', '/api/auth/reset-password', 'reset password',
        json: {'token': token, 'password': password}, renew: false);
  }

  Future<void> forgotPassword(String email) async {
    await request('POST', '/api/auth/forgot-password', 'send reset email',
        json: {'email': email}, renew: false);
  }

  Future<void> sendResetPasswordEmail() async {
    await request(
        'POST', '/api/auth/reset-password/send', 'send reset password email');
  }

  Future<void> changeEmail(String token, String email) async {
    await request('POST', '/api/auth/change-email', 'change email',
        json: {'token': token, 'email': email}, renew: false);
  }

  Future<void> sendChangeEmail(String email) async {
    await request(
        'POST', '/api/auth/change-email/send', 'send email change request',
        json: {'email': email});
  }

  // -------------------------------------------------------------------------
  // Spaces
  // -------------------------------------------------------------------------

  /// Makes a space, with a text and a voice room; answers it with its rooms.
  Future<CreatedSpace> createSpace(String name, {String? description}) async {
    final response =
        await request('POST', '/api/spaces', 'create space', json: {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    return CreatedSpace.fromJson(_decodeMap(response));
  }

  /// Deletes the space, which only its owner may do (anyone else gets a 403;
  /// a space already gone, a 404). Its members get SPACE_DELETE.
  Future<void> deleteSpace(String spaceId) async {
    await request('DELETE', '/api/spaces/$spaceId', 'delete space');
  }

  /// A page of the space's members, by their highest role and then their ID;
  /// the next page starts after the last one's ID and [SpaceMemberWithUser.maxPos].
  Future<List<SpaceMemberWithUser>> getSpaceMembers(String spaceId,
      {String? afterId, int? afterPos}) async {
    final response = await request(
        'GET', '/api/spaces/$spaceId/members', 'get space members',
        query: {
          'count': membersPageSize,
          'after_id': afterId,
          'after_pos': afterPos,
        });
    return _decodeList(response, SpaceMemberWithUser.fromJson);
  }

  Future<void> leaveSpace(String spaceId) async {
    await request('DELETE', '/api/spaces/$spaceId/members/@me', 'leave space');
  }

  /// Updates the space. A new [banner] or [icon], or [removeBanner] or
  /// [removeIcon], sends a multipart form; anything else, JSON.
  Future<Map<String, dynamic>> updateSpace(
    String spaceId, {
    String? name,
    String? description,
    String? locale,
    File? banner,
    File? icon,
    bool removeBanner = false,
    bool removeIcon = false,
  }) async {
    final path = '/api/spaces/$spaceId';
    final http.Response response;
    if (banner != null || icon != null || removeBanner || removeIcon) {
      response = await request('PATCH', path, 'update space', fields: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (description != null) 'description': description,
        if (locale != null) 'locale': locale,
        if (removeBanner) 'remove_banner': 'true',
        if (removeIcon) 'remove_icon': 'true',
      }, files: [
        if (banner != null) await _filePart('banner', banner),
        if (icon != null) await _filePart('icon', icon),
      ]);
    } else {
      response = await request('PATCH', path, 'update space', json: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (locale != null) 'locale': locale,
      });
    }
    return _decodeMap(response);
  }

  // Space attachments

  Future<List<Attachment>> getSpaceAttachments(String spaceId) async {
    final response = await request(
        'GET', '/api/spaces/$spaceId/attachments', 'get space attachments');
    return _decodeList(response, Attachment.fromJson);
  }

  /// The bytes the space's files take.
  Future<int> getSpaceStorageUsed(String spaceId) async {
    final response = await request('GET',
        '/api/spaces/$spaceId/attachments/storage', 'get space storage used');
    return _decodeMap(response)['total_size'] as int;
  }

  Future<void> deleteSpaceAttachment(
      String spaceId, String attachmentId) async {
    await request('DELETE', '/api/spaces/$spaceId/attachments/$attachmentId',
        'delete space attachment');
  }

  Future<void> deleteAllSpaceAttachments(String spaceId) async {
    await request('DELETE', '/api/spaces/$spaceId/attachments',
        'delete all space attachments');
  }

  // Space buckets

  Future<List<StorageBucket>> getSpaceBuckets(String spaceId) async {
    final response = await request(
        'GET', '/api/spaces/$spaceId/buckets', 'get space buckets');
    return _decodeList(response, StorageBucket.fromJson);
  }

  Future<StorageBucket> createSpaceBucket(
      String spaceId, BucketPayload data) async {
    final response = await request(
        'POST', '/api/spaces/$spaceId/buckets', 'create space bucket',
        json: data.toJson());
    return StorageBucket.fromJson(_decodeMap(response));
  }

  Future<StorageBucket> updateSpaceBucket(
      String spaceId, String bucketId, BucketPayload data) async {
    final response = await request('PATCH',
        '/api/spaces/$spaceId/buckets/$bucketId', 'update space bucket',
        json: data.toJson());
    return StorageBucket.fromJson(_decodeMap(response));
  }

  Future<void> deleteSpaceBucket(String spaceId, String bucketId) async {
    await request('DELETE', '/api/spaces/$spaceId/buckets/$bucketId',
        'delete space bucket');
  }

  Future<void> activateSpaceBucket(String spaceId, String bucketId) async {
    await request('POST', '/api/spaces/$spaceId/buckets/$bucketId/activate',
        'activate space bucket');
  }

  Future<void> deactivateSpaceBucket(String spaceId, String bucketId) async {
    await request('POST', '/api/spaces/$spaceId/buckets/$bucketId/deactivate',
        'deactivate space bucket');
  }

  // -------------------------------------------------------------------------
  // Rooms
  // -------------------------------------------------------------------------

  Future<GatewayRoom> createRoom(String spaceId, String name, RoomType type,
      {String? parentId}) async {
    final response = await request(
        'POST', '/api/spaces/$spaceId/rooms', 'create room',
        json: {
          'name': name,
          'type': type.value,
          if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
        });
    return GatewayRoom.fromJson(_decodeMap(response));
  }

  Future<void> deleteRoom(String spaceId, String roomId) async {
    await request(
        'DELETE', '/api/spaces/$spaceId/rooms/$roomId', 'delete room');
  }

  /// Updates the room. Only the arguments given are sent; [clearDescription]
  /// and [clearParent] send null for the description and the parent.
  Future<GatewayRoom> updateRoom(
    String spaceId,
    String roomId, {
    String? name,
    String? description,
    bool clearDescription = false,
    String? parentId,
    bool clearParent = false,
    int? position,
  }) async {
    final response = await request(
        'PATCH', '/api/spaces/$spaceId/rooms/$roomId', 'update room',
        json: {
          if (name != null) 'name': name,
          if (description != null || clearDescription)
            'description': description,
          if (parentId != null || clearParent) 'parent_id': parentId,
          if (position != null) 'position': position,
        });
    return GatewayRoom.fromJson(_decodeMap(response));
  }

  Future<GatewayRoomOverwrite> upsertRoomOverwrite(
    String spaceId,
    String roomId,
    String targetId,
    int targetType,
    int allowFlags,
    int denyFlags,
  ) async {
    final response = await request('PUT',
        '/api/spaces/$spaceId/rooms/$roomId/overwrites', 'upsert overwrite',
        json: {
          'target_id': targetId,
          'target_type': targetType,
          'allow_flags': allowFlags,
          'deny_flags': denyFlags,
        });
    return GatewayRoomOverwrite.fromJson(_decodeMap(response));
  }

  Future<void> deleteRoomOverwrite(
      String spaceId, String roomId, String targetId) async {
    await request(
        'DELETE',
        '/api/spaces/$spaceId/rooms/$roomId/overwrites/$targetId',
        'delete overwrite');
  }

  /// Makes an invite to the room that works for [maxAge] seconds (0: until it
  /// is revoked); answers its code.
  Future<String> createRoomInvite(
      String spaceId, String roomId, int maxAge) async {
    final response = await request('POST',
        '/api/spaces/$spaceId/rooms/$roomId/invites', 'create room invite',
        json: {'max_age': maxAge});
    return _decodeMap(response)['code'] as String;
  }

  // -------------------------------------------------------------------------
  // Messages
  // -------------------------------------------------------------------------

  /// A page of the room's messages before [before] (the newest without it),
  /// newest first: [count] of them, 1 to 100.
  Future<List<GatewayMessage>> getMessages(String roomId,
      {String? before, int count = 100}) async {
    final response = await request(
        'GET', '/api/rooms/$roomId/messages', 'get messages',
        query: {'count': count, 'before': before});
    return _decodeList(response, GatewayMessage.fromJson);
  }

  Future<List<GatewayMessage>> getMessagesAfter(
      String roomId, String after) async {
    final response = await request(
        'GET', '/api/rooms/$roomId/messages', 'get messages after',
        query: {'count': 100, 'after': after, 'order': 'asc'});
    return _decodeList(response, GatewayMessage.fromJson);
  }

  Future<GatewayMessage> getMessageById(String roomId, String messageId) async {
    final response = await request(
        'GET', '/api/rooms/$roomId/messages/$messageId', 'get message by ID');
    return GatewayMessage.fromJson(_decodeMap(response));
  }

  Future<MessageSearchResponse<GatewayMessage>> searchSpaceMessages(
      String spaceId, MessageSearch search) async {
    final response = await request(
        'GET', '/api/spaces/$spaceId/messages/search', 'search space messages',
        query: search.toQueryParameters());
    return MessageSearchResponse.fromJson(
        _decodeMap(response), GatewayMessage.fromJson);
  }

  /// A room's pinned messages, the last pinned first.
  Future<List<GatewayMessage>> getRoomPins(String roomId) async {
    final response =
        await request('GET', '/api/rooms/$roomId/pins', 'get room pins');
    return _decodeList(response, GatewayMessage.fromJson);
  }

  /// Pins a message of a room, which posts the room's pin notice.
  Future<void> pinRoomMessage(String roomId, String messageId) async {
    await request('PUT', '/api/rooms/$roomId/pins/$messageId', 'pin message');
  }

  Future<void> unpinRoomMessage(String roomId, String messageId) async {
    await request(
        'DELETE', '/api/rooms/$roomId/pins/$messageId', 'unpin message');
  }

  Future<List<GatewayMessage>> getMessageThread(
      String roomId, String messageId) async {
    final response = await request('GET',
        '/api/rooms/$roomId/messages/$messageId/thread', 'get message thread');
    return _decodeList(response, GatewayMessage.fromJson);
  }

  /// Sends a message to the room. With [files], it goes as a multipart form,
  /// which carries no [embeds] or sticker.
  ///
  /// [onProgress] gets the bytes of the request sent so far, and their total.
  /// Completing [abortTrigger] cancels the request: it then fails with an
  /// [http.RequestAbortedException].
  Future<GatewayMessage> sendMessage(
    String roomId,
    String content, {
    String? nonce,
    MessageReference? messageReference,
    List<File>? files,
    List<Embed>? embeds,
    String? stickerAttachmentId,
    void Function(int sent, int total)? onProgress,
    Future<void>? abortTrigger,
  }) async {
    final response = await _sendMessage('/api/rooms/$roomId/messages', content,
        nonce: nonce,
        messageReference: messageReference,
        files: files,
        embeds: embeds,
        stickerAttachmentId: stickerAttachmentId,
        onProgress: onProgress,
        abortTrigger: abortTrigger);
    return GatewayMessage.fromJson(_decodeMap(response));
  }

  /// Sends a voice message to the room: [audio] is a recording in [format],
  /// `webm` (WebM/Opus, as the desktop app records), `ogg` (Ogg/Opus) or `m4a`
  /// (AAC in MP4).
  Future<GatewayMessage> sendVoiceNote(String roomId, List<int> audio,
      {String? nonce, String format = 'webm'}) async {
    final response = await _sendVoiceNote('/api/rooms/$roomId/messages', audio,
        nonce: nonce, format: format);
    return GatewayMessage.fromJson(_decodeMap(response));
  }

  Future<GatewayMessage> updateMessage(
      String messageId, String content, String roomId) async {
    final response = await request(
        'PATCH', '/api/rooms/$roomId/messages/$messageId', 'update message',
        json: {'content': content});
    return GatewayMessage.fromJson(_decodeMap(response));
  }

  /// Tells the room the user is typing. Failures are ignored.
  Future<void> sendTypingIndicator(String roomId) async {
    await request('POST', '/api/rooms/$roomId/typing', 'send typing indicator')
        .then((_) {}, onError: (_) {});
  }

  /// Tells the room the user is recording a voice message. Failures are
  /// ignored.
  Future<void> sendRecordingIndicator(String roomId) async {
    await request(
            'POST', '/api/rooms/$roomId/recording', 'send recording indicator')
        .then((_) {}, onError: (_) {});
  }

  Future<void> deleteMessage(String messageId, String roomId) async {
    await request(
        'DELETE', '/api/rooms/$roomId/messages/$messageId', 'delete message');
  }

  /// Marks the room read up to [messageId]. Acks go out at most once per room
  /// every [ackInterval], with the newest message ID; failures are ignored.
  Future<void> ackRoom(String roomId, String messageId) =>
      _roomAcks(roomId, messageId);

  late final _roomAcks = AckThrottle((roomId, messageId) => request(
      'POST', '/api/rooms/$roomId/ack', 'ack room',
      json: {'message_id': messageId}).then((_) {}, onError: (_) {}));

  /// The unread mentions of each room and conversation, by its ID. Answers
  /// none when the request fails.
  Future<Map<String, int>> getMentionCounts() async {
    try {
      final response = await request(
          'GET', '/api/users/@me/mentions/counts', 'get mention counts');
      return _decodeMap(response)
          .map((key, value) => MapEntry(key, value as int));
    } on Exception {
      return {};
    }
  }

  // -------------------------------------------------------------------------
  // Reactions
  // -------------------------------------------------------------------------

  Future<void> addRoomReaction(
      String roomId, String messageId, String emojiName,
      {String? emojiId}) async {
    await request('PUT', '/api/rooms/$roomId/messages/$messageId/reactions',
        'add reaction',
        json: {'emoji_name': emojiName, 'emoji_id': emojiId});
  }

  Future<void> removeRoomReaction(
      String roomId, String messageId, String emojiName) async {
    await request(
        'DELETE',
        '/api/rooms/$roomId/messages/$messageId/reactions/'
            '${Uri.encodeComponent(emojiName)}',
        'remove reaction');
  }

  Future<void> addConversationReaction(
      String convId, String messageId, String emojiName,
      {String? emojiId}) async {
    await request(
        'PUT',
        '/api/users/@me/conversations/$convId/messages/$messageId/reactions',
        'add conversation reaction',
        json: {'emoji_name': emojiName, 'emoji_id': emojiId});
  }

  Future<void> removeConversationReaction(
      String convId, String messageId, String emojiName) async {
    await request(
        'DELETE',
        '/api/users/@me/conversations/$convId/messages/$messageId/reactions/'
            '${Uri.encodeComponent(emojiName)}',
        'remove conversation reaction');
  }

  // -------------------------------------------------------------------------
  // Roles
  // -------------------------------------------------------------------------

  Future<GatewayRole> createRole(
    String spaceId,
    String name, {
    int? permissions,
    int? colorFrom,
    int? colorVia,
    int? colorTo,
    bool? hoisted,
  }) async {
    final response = await request(
        'POST', '/api/spaces/$spaceId/roles', 'create role',
        json: {
          'name': name,
          if (permissions != null) 'permissions': permissions,
          if (colorFrom != null) 'color_from': colorFrom,
          if (colorVia != null) 'color_via': colorVia,
          if (colorTo != null) 'color_to': colorTo,
          if (hoisted != null) 'hoisted': hoisted,
        });
    return GatewayRole.fromJson(_decodeMap(response));
  }

  /// Updates the role. Only the arguments given are sent; with [clearColors],
  /// the null colors clear those of the role.
  Future<GatewayRole> updateRole(
    String spaceId,
    String roleId, {
    String? name,
    int? permissions,
    int? colorFrom,
    int? colorVia,
    int? colorTo,
    bool? hoisted,
    int? position,
    bool clearColors = false,
  }) async {
    final response = await request(
        'PATCH', '/api/spaces/$spaceId/roles/$roleId', 'update role',
        json: {
          if (name != null) 'name': name,
          if (permissions != null) 'permissions': permissions,
          if (colorFrom != null || clearColors) 'color_from': colorFrom,
          if (colorVia != null || clearColors) 'color_via': colorVia,
          if (colorTo != null || clearColors) 'color_to': colorTo,
          if (hoisted != null) 'hoisted': hoisted,
          if (position != null) 'position': position,
          if (clearColors) 'clear_colors': true,
        });
    return GatewayRole.fromJson(_decodeMap(response));
  }

  Future<void> deleteRole(String spaceId, String roleId) async {
    await request(
        'DELETE', '/api/spaces/$spaceId/roles/$roleId', 'delete role');
  }

  Future<void> assignRoleToMember(
      String spaceId, String roleId, String memberId) async {
    await request('PUT', '/api/spaces/$spaceId/members/$memberId/roles/$roleId',
        'assign role to member');
  }

  Future<void> removeRoleFromMember(
      String spaceId, String roleId, String memberId) async {
    await request(
        'DELETE',
        '/api/spaces/$spaceId/members/$memberId/roles/$roleId',
        'remove role from member');
  }

  // -------------------------------------------------------------------------
  // Space emojis
  // -------------------------------------------------------------------------

  Future<List<SpaceEmoji>> listEmojis(String spaceId) async {
    final response =
        await request('GET', '/api/spaces/$spaceId/emojis', 'list emojis');
    return _decodeList(response, SpaceEmoji.fromJson);
  }

  Future<SpaceEmoji> createEmoji(String spaceId, String name, File file) async {
    final response = await request(
        'POST', '/api/spaces/$spaceId/emojis', 'create emoji',
        fields: {'name': name}, files: [await _filePart('file', file)]);
    return SpaceEmoji.fromJson(_decodeMap(response));
  }

  Future<SpaceEmoji> updateEmoji(
      String spaceId, String emojiId, String name) async {
    final response = await request(
        'PATCH', '/api/spaces/$spaceId/emojis/$emojiId', 'update emoji',
        json: {'name': name});
    return SpaceEmoji.fromJson(_decodeMap(response));
  }

  Future<void> deleteEmoji(String spaceId, String emojiId) async {
    await request(
        'DELETE', '/api/spaces/$spaceId/emojis/$emojiId', 'delete emoji');
  }

  // -------------------------------------------------------------------------
  // Space stickers
  // -------------------------------------------------------------------------

  Future<List<SpaceSticker>> listStickers(String spaceId) async {
    final response =
        await request('GET', '/api/spaces/$spaceId/stickers', 'list stickers');
    return _decodeList(response, SpaceSticker.fromJson);
  }

  Future<SpaceSticker> createSticker(
      String spaceId, String name, File file) async {
    final response = await request(
        'POST', '/api/spaces/$spaceId/stickers', 'create sticker',
        fields: {'name': name}, files: [await _filePart('file', file)]);
    return SpaceSticker.fromJson(_decodeMap(response));
  }

  Future<SpaceSticker> updateSticker(
      String spaceId, String stickerId, String name) async {
    final response = await request(
        'PATCH', '/api/spaces/$spaceId/stickers/$stickerId', 'update sticker',
        json: {'name': name});
    return SpaceSticker.fromJson(_decodeMap(response));
  }

  Future<void> deleteSticker(String spaceId, String stickerId) async {
    await request(
        'DELETE', '/api/spaces/$spaceId/stickers/$stickerId', 'delete sticker');
  }

  // -------------------------------------------------------------------------
  // Invites
  // -------------------------------------------------------------------------

  Future<InviteInfo> getInvite(String code) async {
    final response = await request(
        'GET', '/api/invites/${Uri.encodeComponent(code)}', 'get invite');
    return InviteInfo.fromJson(_decodeMap(response));
  }

  Future<InviteInfo> joinInvite(String code) async {
    final response = await request('POST',
        '/api/invites/${Uri.encodeComponent(code)}/join', 'join invite');
    return InviteInfo.fromJson(_decodeMap(response));
  }

  /// The space's invites that still work (needs Manage Invites).
  Future<List<InviteLink>> listSpaceInvites(String spaceId) async {
    final response =
        await request('GET', '/api/spaces/$spaceId/invites', 'list invites');
    return _decodeList(response, InviteLink.fromJson);
  }

  Future<void> revokeInvite(String spaceId, String inviteId) async {
    await request(
        'DELETE', '/api/spaces/$spaceId/invites/$inviteId', 'revoke invite');
  }

  // -------------------------------------------------------------------------
  // Webhooks
  // -------------------------------------------------------------------------

  Future<List<Webhook>> listWebhooks(String spaceId, String roomId) async {
    final response = await request(
        'GET', '/api/spaces/$spaceId/rooms/$roomId/webhooks', 'list webhooks');
    return _decodeList(response, Webhook.fromJson);
  }

  Future<WebhookCreateResponse> createWebhook(
      String spaceId, String roomId, String username,
      {File? avatar}) async {
    final response = await request(
        'POST', '/api/spaces/$spaceId/rooms/$roomId/webhooks', 'create webhook',
        fields: {'username': username},
        files: [if (avatar != null) await _filePart('avatar', avatar)]);
    return WebhookCreateResponse.fromJson(_decodeMap(response));
  }

  Future<Webhook> updateWebhook(
    String spaceId,
    String roomId,
    String webhookId, {
    String? username,
    File? avatar,
    bool removeAvatar = false,
  }) async {
    final response = await request(
        'PATCH',
        '/api/spaces/$spaceId/rooms/$roomId/webhooks/$webhookId',
        'update webhook',
        fields: {
          if (username != null && username.isNotEmpty) 'username': username,
          if (removeAvatar) 'remove_avatar': 'true',
        },
        files: [
          if (avatar != null) await _filePart('avatar', avatar)
        ]);
    return Webhook.fromJson(_decodeMap(response));
  }

  Future<void> deleteWebhook(
      String spaceId, String roomId, String webhookId) async {
    await request(
        'DELETE',
        '/api/spaces/$spaceId/rooms/$roomId/webhooks/$webhookId',
        'delete webhook');
  }

  /// Answers the webhook's new token.
  Future<String> resetWebhookToken(
      String spaceId, String roomId, String webhookId) async {
    final response = await request(
        'POST',
        '/api/spaces/$spaceId/rooms/$roomId/webhooks/$webhookId/reset-token',
        'reset webhook token');
    return _decodeMap(response)['token'] as String;
  }

  // -------------------------------------------------------------------------
  // Interactions & commands
  // -------------------------------------------------------------------------

  /// Uses a component of a bot's message in a room. The API waits up to 3
  /// seconds for the bot's first response and answers it: its type, and the
  /// modal when the bot opened one ([InteractionReply.isModal]); without a
  /// response, 504.
  Future<InteractionReply> useComponent(
          String roomId, String messageId, ComponentUse data) =>
      _component('use component', roomId, messageId, data);

  /// [useComponent], answering only the type of the bot's first response.
  Future<int> sendComponentInteraction(
          String roomId, String messageId, ComponentUse data) =>
      _component('send component interaction', roomId, messageId, data)
          .then((reply) => reply.type);

  /// Uses an application's command in a room, and answers the bot's first
  /// response, as [useComponent] does.
  Future<InteractionReply> useCommand(
          String roomId, String applicationId, CommandUse data) =>
      _command('use command', roomId, applicationId, data);

  /// [useCommand], answering only the type of the bot's first response.
  Future<int> sendCommandInteraction(
          String roomId, String applicationId, CommandUse data) =>
      _command('send command interaction', roomId, applicationId, data)
          .then((reply) => reply.type);

  /// Submits a modal the application's bot opened in a room: [customId] is the
  /// modal's, and [components] its labels with what was entered in their
  /// inputs, as the API takes them. [messageId] is the message whose component
  /// opened it, if one did. A modal is submitted once; answers the bot's first
  /// response, as [useComponent] does.
  Future<InteractionReply> submitModal(String roomId, String applicationId,
          String customId, List<Map<String, dynamic>> components,
          {String? messageId}) =>
      _interact('submit modal', {
        'type': 5,
        'room_id': roomId,
        'application_id': applicationId,
        if (messageId != null) 'message_id': messageId,
        'data': {'custom_id': customId, 'components': components},
      });

  Future<InteractionReply> _component(
          String action, String roomId, String messageId, ComponentUse data) =>
      _interact(action, {
        'type': 3,
        'room_id': roomId,
        'message_id': messageId,
        'data': data.toJson(),
      });

  Future<InteractionReply> _command(String action, String roomId,
      String applicationId, CommandUse data) async {
    try {
      return await _interact(action, {
        'type': 2,
        'room_id': roomId,
        'application_id': applicationId,
        'data': data.toJson(),
      });
    } catch (_) {
      // The command may have changed or gone: the next use asks for the
      // lists again.
      _spaceCommands.clear();
      rethrow;
    }
  }

  Future<InteractionReply> _interact(
      String action, Map<String, dynamic> json) async {
    final response =
        await request('POST', '/api/interactions', action, json: json);
    return InteractionReply.fromJson(_decodeMap(response));
  }

  /// The space's commands, kept for a few minutes, or until
  /// [forgetSpaceCommands] (the space's members changed: a bot came or
  /// went). A failed request isn't kept.
  Future<SpaceCommands> getSpaceCommands(String spaceId) {
    final cached = _spaceCommands[spaceId];
    if (cached != null && DateTime.now().difference(cached.at) < _commandsTTL) {
      return cached.list;
    }
    final list =
        request('GET', '/api/spaces/$spaceId/commands', 'get space commands')
            .then((response) => SpaceCommands.fromJson(_decodeMap(response)));
    _spaceCommands[spaceId] = (at: DateTime.now(), list: list);
    list.catchError((Object _) {
      if (identical(_spaceCommands[spaceId]?.list, list)) {
        _spaceCommands.remove(spaceId);
      }
      return const SpaceCommands(applications: [], commands: []);
    }).ignore();
    return list;
  }

  void forgetSpaceCommands(String spaceId) {
    _spaceCommands.remove(spaceId);
  }

  static const _commandsTTL = Duration(minutes: 5);
  final _spaceCommands =
      <String, ({DateTime at, Future<SpaceCommands> list})>{};

  // -------------------------------------------------------------------------
  // Friends
  // -------------------------------------------------------------------------

  /// Answers the bare request, without the other user's details.
  Future<FriendRequest> sendFriendRequest(String userId) async {
    final response = await request(
        'POST', '/api/users/@me/friends/requests', 'send friend request',
        json: {'user_id': userId});
    return FriendRequest.fromJson(_decodeMap(response));
  }

  Future<List<FriendRequest>> getPendingRequests() async {
    final response = await request(
        'GET', '/api/users/@me/friends/requests', 'get pending requests');
    return _decodeList(response, FriendRequest.fromJson);
  }

  Future<List<FriendRequest>> getSentRequests() async {
    final response = await request(
        'GET', '/api/users/@me/friends/requests/sent', 'get sent requests');
    return _decodeList(response, FriendRequest.fromJson);
  }

  Future<Friend> acceptFriendRequest(String requestId) async {
    final response = await request(
        'POST',
        '/api/users/@me/friends/requests/$requestId/accept',
        'accept friend request');
    return Friend.fromJson(_decodeMap(response));
  }

  Future<void> rejectFriendRequest(String requestId) async {
    await request('DELETE', '/api/users/@me/friends/requests/$requestId',
        'reject friend request');
  }

  Future<List<Friend>> getFriends() async {
    final response =
        await request('GET', '/api/users/@me/friends', 'get friends');
    return _decodeList(response, Friend.fromJson);
  }

  Future<void> unfriend(String userId) async {
    await request('DELETE', '/api/users/@me/friends/$userId', 'unfriend');
  }

  // -------------------------------------------------------------------------
  // Conversations
  // -------------------------------------------------------------------------

  Future<List<Conversation>> getConversations() async {
    final response = await request(
        'GET', '/api/users/@me/conversations', 'get conversations');
    return _decodeList(response, Conversation.fromJson);
  }

  Future<Conversation> createDM(String userId) async {
    final response = await request(
        'POST', '/api/users/@me/conversations', 'create DM',
        json: {'type': ConversationType.dm.value, 'user_id': userId});
    return Conversation.fromJson(_decodeMap(response));
  }

  Future<Conversation> createGroup(String name, List<String> userIds) async {
    final response = await request(
        'POST', '/api/users/@me/conversations', 'create group',
        json: {
          'type': ConversationType.group.value,
          'name': name,
          'user_ids': userIds,
        });
    return Conversation.fromJson(_decodeMap(response));
  }

  Future<Conversation> updateConversation(
      String conversationId, String name) async {
    final response = await request('PATCH',
        '/api/users/@me/conversations/$conversationId', 'update conversation',
        json: {'name': name});
    return Conversation.fromJson(_decodeMap(response));
  }

  Future<ConversationMember> addConversationMember(
      String conversationId, String userId) async {
    final response = await request(
        'POST',
        '/api/users/@me/conversations/$conversationId/members',
        'add conversation member',
        json: {'user_id': userId});
    return ConversationMember.fromJson(_decodeMap(response));
  }

  Future<void> removeConversationMember(
      String conversationId, String userId) async {
    await request(
        'DELETE',
        '/api/users/@me/conversations/$conversationId/members/$userId',
        'remove conversation member');
  }

  Future<void> leaveConversation(String conversationId) async {
    await request(
        'DELETE',
        '/api/users/@me/conversations/$conversationId/members/@me',
        'leave conversation');
  }

  /// A page of the conversation's messages before [before] (the newest
  /// without it), newest first: [count] of them, 1 to 100.
  Future<List<DirectMessage>> getDirectMessages(String conversationId,
      {String? before, int count = 100}) async {
    final response = await request(
        'GET',
        '/api/users/@me/conversations/$conversationId/messages',
        'get direct messages',
        query: {'count': count, 'before': before});
    return _decodeList(response, DirectMessage.fromJson);
  }

  Future<DirectMessage> getDirectMessageById(
      String conversationId, String messageId) async {
    final response = await request(
        'GET',
        '/api/users/@me/conversations/$conversationId/messages/$messageId',
        'get direct message by ID');
    return DirectMessage.fromJson(_decodeMap(response));
  }

  /// A conversation message's reply thread, oldest first, as a room's thread
  /// is.
  Future<List<DirectMessage>> getConversationMessageThread(
      String conversationId, String messageId) async {
    final response = await request(
        'GET',
        '/api/users/@me/conversations/$conversationId/messages/$messageId/thread',
        'get conversation message thread');
    return _decodeList(response, DirectMessage.fromJson);
  }

  /// A conversation's pinned messages, the last pinned first.
  Future<List<DirectMessage>> getConversationPins(String conversationId) async {
    final response = await request(
        'GET',
        '/api/users/@me/conversations/$conversationId/pins',
        'get conversation pins');
    return _decodeList(response, DirectMessage.fromJson);
  }

  /// Pins a message of a conversation, which posts the conversation's pin
  /// notice.
  Future<void> pinConversationMessage(
      String conversationId, String messageId) async {
    await request(
        'PUT',
        '/api/users/@me/conversations/$conversationId/pins/$messageId',
        'pin conversation message');
  }

  Future<void> unpinConversationMessage(
      String conversationId, String messageId) async {
    await request(
        'DELETE',
        '/api/users/@me/conversations/$conversationId/pins/$messageId',
        'unpin conversation message');
  }

  Future<MessageSearchResponse<DirectMessage>> searchConversationMessages(
      String conversationId, MessageSearch search) async {
    final response = await request(
        'GET',
        '/api/users/@me/conversations/$conversationId/messages/search',
        'search conversation messages',
        query: search.toQueryParameters());
    return MessageSearchResponse.fromJson(
        _decodeMap(response), DirectMessage.fromJson);
  }

  Future<List<DirectMessage>> getDirectMessagesAfter(
      String conversationId, String after) async {
    final response = await request(
        'GET',
        '/api/users/@me/conversations/$conversationId/messages/after',
        'get direct messages after',
        query: {'count': 100, 'after': after});
    return _decodeList(response, DirectMessage.fromJson);
  }

  /// Sends a message to the conversation. With [files], it goes as a
  /// multipart form, which carries no [embeds] or sticker. [onProgress] and
  /// [abortTrigger] work as [sendMessage]'s.
  Future<DirectMessage> sendDirectMessage(
    String conversationId,
    String content, {
    String? nonce,
    MessageReference? messageReference,
    List<File>? files,
    List<Embed>? embeds,
    String? stickerAttachmentId,
    void Function(int sent, int total)? onProgress,
    Future<void>? abortTrigger,
  }) async {
    final response = await _sendMessage(
        '/api/users/@me/conversations/$conversationId/messages', content,
        nonce: nonce,
        messageReference: messageReference,
        files: files,
        embeds: embeds,
        stickerAttachmentId: stickerAttachmentId,
        onProgress: onProgress,
        abortTrigger: abortTrigger);
    return DirectMessage.fromJson(_decodeMap(response));
  }

  /// Sends a voice message to the conversation: [audio] is a recording in
  /// [format], as [sendVoiceNote] takes it.
  Future<DirectMessage> sendDMVoiceNote(String conversationId, List<int> audio,
      {String? nonce, String format = 'webm'}) async {
    final response = await _sendVoiceNote(
        '/api/users/@me/conversations/$conversationId/messages', audio,
        nonce: nonce, format: format);
    return DirectMessage.fromJson(_decodeMap(response));
  }

  Future<DirectMessage> updateDirectMessage(
      String conversationId, String messageId, String content) async {
    final response = await request(
        'PATCH',
        '/api/users/@me/conversations/$conversationId/messages/$messageId',
        'update direct message',
        json: {'content': content});
    return DirectMessage.fromJson(_decodeMap(response));
  }

  /// Tells the conversation the user is typing.
  Future<void> sendConversationTyping(String conversationId) async {
    await request('POST', '/api/users/@me/conversations/$conversationId/typing',
        'send conversation typing');
  }

  /// Tells the conversation the user is recording a voice message.
  Future<void> sendConversationRecording(String conversationId) async {
    await request(
        'POST',
        '/api/users/@me/conversations/$conversationId/recording',
        'send conversation recording');
  }

  Future<void> deleteDirectMessage(
      String conversationId, String messageId) async {
    await request(
        'DELETE',
        '/api/users/@me/conversations/$conversationId/messages/$messageId',
        'delete direct message');
  }

  /// Marks the conversation read up to [messageId]. Acks go out at most once
  /// per conversation every [ackInterval], with the newest message ID;
  /// failures are ignored.
  Future<void> ackConversation(String conversationId, String messageId) =>
      _conversationAcks(conversationId, messageId);

  late final _conversationAcks = AckThrottle((conversationId, messageId) =>
      request('POST', '/api/users/@me/conversations/$conversationId/ack',
              'ack conversation', json: {'message_id': messageId})
          .then((_) {}, onError: (_) {}));

  // -------------------------------------------------------------------------
  // Users
  // -------------------------------------------------------------------------

  Future<UserMeResult> me() async {
    final response = await request('GET', '/api/users/@me', 'get me');
    return UserMeResult.fromJson(_decodeMap(response));
  }

  /// Updates the user. Only the arguments given are sent; [clearAlias] sends
  /// null for the alias.
  Future<UserMeResult> updateUser({
    String? username,
    String? alias,
    bool clearAlias = false,
    String? avatar,
    String? banner,
  }) async {
    final response =
        await request('PATCH', '/api/users/@me', 'update user', json: {
      if (username != null) 'username': username,
      if (alias != null || clearAlias) 'alias': alias,
      if (avatar != null) 'avatar': avatar,
      if (banner != null) 'banner': banner,
    });
    return UserMeResult.fromJson(_decodeMap(response));
  }

  /// Sets the user's avatar or banner ([kind]) to the [crop] of an image.
  Future<UserMeResult> uploadProfileImage(
    ProfileImageKind kind,
    List<int> bytes,
    String filename,
    ({num x, num y, num w, num h}) crop,
  ) async {
    final name = kind.name;
    final response = await request(
        'PATCH', '/api/users/@me', 'upload profile image',
        fields: {
          '${name}_crop_x': crop.x.round().toString(),
          '${name}_crop_y': crop.y.round().toString(),
          '${name}_crop_w': crop.w.round().toString(),
          '${name}_crop_h': crop.h.round().toString(),
        },
        files: [
          (field: name, bytes: bytes, filename: filename)
        ]);
    return UserMeResult.fromJson(_decodeMap(response));
  }

  Future<StorageStatus> getMyStorageStatus() async {
    final response =
        await request('GET', '/api/users/@me/storage', 'get storage status');
    return StorageStatus.fromJson(_decodeMap(response));
  }

  Future<List<Attachment>> getMyAttachments() async {
    final response =
        await request('GET', '/api/users/@me/attachments', 'get attachments');
    return _decodeList(response, Attachment.fromJson);
  }

  Future<void> deleteMyAttachment(String id) async {
    await request(
        'DELETE', '/api/users/@me/attachments/$id', 'delete attachment');
  }

  Future<void> deleteAllMyAttachments() async {
    await request(
        'DELETE', '/api/users/@me/attachments', 'delete all attachments');
  }

  // Storage buckets

  Future<List<StorageBucket>> getMyBuckets() async {
    final response =
        await request('GET', '/api/users/@me/buckets', 'get buckets');
    return _decodeList(response, StorageBucket.fromJson);
  }

  Future<StorageBucket> createMyBucket(BucketPayload data) async {
    final response = await request(
        'POST', '/api/users/@me/buckets', 'create bucket',
        json: data.toJson());
    return StorageBucket.fromJson(_decodeMap(response));
  }

  Future<StorageBucket> updateMyBucket(String id, BucketPayload data) async {
    final response = await request(
        'PATCH', '/api/users/@me/buckets/$id', 'update bucket',
        json: data.toJson());
    return StorageBucket.fromJson(_decodeMap(response));
  }

  Future<void> deleteMyBucket(String id) async {
    await request('DELETE', '/api/users/@me/buckets/$id', 'delete bucket');
  }

  Future<void> activateMyBucket(String id) async {
    await request(
        'POST', '/api/users/@me/buckets/$id/activate', 'activate bucket');
  }

  Future<void> deactivateMyBucket(String id) async {
    await request(
        'POST', '/api/users/@me/buckets/$id/deactivate', 'deactivate bucket');
  }

  // Internal (staff only)

  Future<Map<String, dynamic>> updateUserFlagsBadges(String userId,
      {int? flags, int? badges}) async {
    final response = await request('PATCH',
        '/api/internal/users/$userId/flags-badges', 'update flags and badges',
        json: {
          if (flags != null) 'flags': flags,
          if (badges != null) 'badges': badges,
        });
    return _decodeMap(response);
  }

  // -------------------------------------------------------------------------
  // Developer: teams
  // -------------------------------------------------------------------------

  Future<Team> createTeam(String name) async {
    final response = await request(
        'POST', '/api/users/@me/teams', 'create team',
        json: {'name': name});
    return Team.fromJson(_decodeMap(response));
  }

  Future<List<Team>> listTeams() async {
    final response = await request('GET', '/api/users/@me/teams', 'list teams');
    return _decodeList(response, Team.fromJson);
  }

  Future<Team> updateTeam(String teamId, String name) async {
    final response = await request(
        'PATCH', '/api/users/@me/teams/$teamId', 'update team',
        json: {'name': name});
    return Team.fromJson(_decodeMap(response));
  }

  Future<void> deleteTeam(String teamId) async {
    await request('DELETE', '/api/users/@me/teams/$teamId', 'delete team');
  }

  Future<List<TeamMember>> listTeamMembers(String teamId) async {
    final response = await request(
        'GET', '/api/users/@me/teams/$teamId/members', 'list team members');
    return _decodeList(response, TeamMember.fromJson);
  }

  Future<void> inviteToTeam(String teamId, String email) async {
    await request(
        'POST', '/api/users/@me/teams/$teamId/invites', 'invite to team',
        json: {'email': email});
  }

  Future<void> removeTeamMember(String teamId, String userId) async {
    await request('DELETE', '/api/users/@me/teams/$teamId/members/$userId',
        'remove team member');
  }

  // Team invites

  Future<List<TeamInvite>> listMyTeamInvites() async {
    final response = await request(
        'GET', '/api/users/@me/team-invites', 'list team invites');
    return _decodeList(response, TeamInvite.fromJson);
  }

  Future<void> acceptTeamInvite(String inviteId) async {
    await request('POST', '/api/users/@me/team-invites/$inviteId/accept',
        'accept team invite');
  }

  Future<void> declineTeamInvite(String inviteId) async {
    await request('POST', '/api/users/@me/team-invites/$inviteId/decline',
        'decline team invite');
  }

  // Applications

  Future<Application> createApplication(String teamId, String name,
      {String? description}) async {
    final response = await request('POST',
        '/api/users/@me/teams/$teamId/applications', 'create application',
        json: {
          'name': name,
          if (description != null) 'description': description,
        });
    return Application.fromJson(_decodeMap(response));
  }

  Future<List<Application>> listApplications(String teamId) async {
    final response = await request('GET',
        '/api/users/@me/teams/$teamId/applications', 'list applications');
    return _decodeList(response, Application.fromJson);
  }

  Future<Application> updateApplication(String teamId, String appId,
      {String? name, String? description, bool? public}) async {
    final response = await request(
        'PATCH',
        '/api/users/@me/teams/$teamId/applications/$appId',
        'update application',
        json: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (public != null) 'public': public,
        });
    return Application.fromJson(_decodeMap(response));
  }

  Future<void> deleteApplication(String teamId, String appId) async {
    await request('DELETE', '/api/users/@me/teams/$teamId/applications/$appId',
        'delete application');
  }

  // Bot

  /// Makes the application's bot; answers its token.
  Future<String> createBot(String teamId, String appId) async {
    final response = await request('POST',
        '/api/users/@me/teams/$teamId/applications/$appId/bot', 'create bot');
    return _decodeMap(response)['token'] as String;
  }

  /// Answers the bot's new token.
  Future<String> resetBotToken(String teamId, String appId) async {
    final response = await request(
        'POST',
        '/api/users/@me/teams/$teamId/applications/$appId/bot/reset-token',
        'reset bot token');
    return _decodeMap(response)['token'] as String;
  }

  Future<void> deleteBot(String teamId, String appId) async {
    await request('DELETE',
        '/api/users/@me/teams/$teamId/applications/$appId/bot', 'delete bot');
  }

  /// Updates the application's bot. [clearAlias] removes its alias.
  Future<Map<String, dynamic>> updateBot(
    String teamId,
    String appId, {
    String? username,
    String? alias,
    bool clearAlias = false,
    File? avatar,
    File? banner,
    bool removeAvatar = false,
    bool removeBanner = false,
  }) async {
    final response = await request('PATCH',
        '/api/users/@me/teams/$teamId/applications/$appId/bot', 'update bot',
        fields: {
          if (username != null && username.isNotEmpty) 'username': username,
          if (alias != null && alias.isNotEmpty)
            'alias': alias
          else if (clearAlias)
            'alias': '',
          if (removeAvatar) 'remove_avatar': 'true',
          if (removeBanner) 'remove_banner': 'true',
        },
        files: [
          if (avatar != null) await _filePart('avatar', avatar),
          if (banner != null) await _filePart('banner', banner),
        ]);
    return _decodeMap(response);
  }

  // Bot → space

  Future<BotUser> getBotUser(String userId) async {
    final response = await request('GET', '/api/users/$userId', 'get bot user');
    return BotUser.fromJson(_decodeMap(response));
  }

  Future<void> addBotToSpace(String spaceId, String botUserId) async {
    await request(
        'POST', '/api/spaces/$spaceId/bots/$botUserId', 'add bot to space');
  }

  Future<void> removeBotFromSpace(String spaceId, String botUserId) async {
    await request('DELETE', '/api/spaces/$spaceId/bots/$botUserId',
        'remove bot from space');
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Sends a request to the API with the session's headers: [json] as its
  /// body, or [fields] and [files] as a multipart form, and throws a
  /// [DuvetApiException] unless it succeeds. Unless [renew] is false, a 401
  /// renews the session and sends it once more, as does a 401 to a request
  /// sent before a renewal that has finished since. [action] names it in
  /// errors.
  ///
  /// It fails with a [TimeoutException] when [timeout] ([requestTimeout]
  /// unless given) passes without progress. [onProgress] gets the bytes of the
  /// body sent so far, and their total; completing [abortTrigger] cancels the
  /// request, which then fails with an [http.RequestAbortedException].
  Future<http.Response> request(
    String method,
    String path,
    String action, {
    Map<String, dynamic>? query,
    Object? json,
    Map<String, String>? fields,
    List<FilePart>? files,
    bool renew = true,
    Duration? timeout,
    void Function(int sent, int total)? onProgress,
    Future<void>? abortTrigger,
  }) async {
    final url = router.urlFromPath(path, query: query);

    http.BaseRequest build() {
      if (fields != null || files != null) {
        return http.MultipartRequest(method, url)
          ..headers.addAll(authHeaders)
          ..fields.addAll(fields ?? const {})
          ..files.addAll([
            for (final f in files ?? const <FilePart>[])
              http.MultipartFile.fromBytes(f.field, f.bytes,
                  filename: f.filename, contentType: _mediaTypeOf(f.filename)),
          ]);
      }
      final request = http.Request(method, url)..headers.addAll(authHeaders);
      if (json != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(json);
      }
      return request;
    }

    Future<http.Response> sendOnce() => sendWithin(client, build(),
        timeout: timeout ?? requestTimeout,
        abortTrigger: abortTrigger,
        onProgress: onProgress);

    final sentWith = authHeaders['Authorization'];
    var response = await sendOnce();
    if (renew &&
        response.statusCode == 401 &&
        (authHeaders['Authorization'] != sentWith || await renewSession())) {
      response = await sendOnce();
    }
    _assertOk(response, action);
    return response;
  }

  Future<http.Response> _sendMessage(
    String path,
    String content, {
    String? nonce,
    MessageReference? messageReference,
    List<File>? files,
    List<Embed>? embeds,
    String? stickerAttachmentId,
    void Function(int sent, int total)? onProgress,
    Future<void>? abortTrigger,
  }) async {
    if (files != null && files.isNotEmpty) {
      return request('POST', path, 'send message',
          fields: {
            'content': content,
            if (nonce != null && nonce.isNotEmpty) 'nonce': nonce,
            if (messageReference != null)
              'message_reference': jsonEncode(messageReference.toJson()),
          },
          files: [
            for (final f in files) await _filePart('files', f),
          ],
          onProgress: onProgress,
          abortTrigger: abortTrigger);
    }
    return request('POST', path, 'send message',
        json: {
          'content': content,
          if (nonce != null) 'nonce': nonce,
          if (messageReference != null)
            'message_reference': messageReference.toJson(),
          if (embeds != null && embeds.isNotEmpty)
            'embeds': embeds.map((e) => e.toJson()).toList(),
          if (stickerAttachmentId != null && stickerAttachmentId.isNotEmpty)
            'sticker_attachment_id': stickerAttachmentId,
        },
        onProgress: onProgress,
        abortTrigger: abortTrigger);
  }

  Future<http.Response> _sendVoiceNote(String path, List<int> audio,
      {String? nonce, required String format}) async {
    if (!_voiceNoteTypes.containsKey(format)) {
      throw ArgumentError.value(format, 'format',
          'a voice note is ${_voiceNoteTypes.keys.join(', ')}');
    }
    return request('POST', path, 'send voice note', fields: {
      'type': '${MessageType.voice.value}',
      if (nonce != null && nonce.isNotEmpty) 'nonce': nonce,
    }, files: [
      (field: 'files', bytes: audio, filename: '$_voiceNote.$format'),
    ]);
  }

  // Reads the file with async I/O so the event loop isn't blocked.
  Future<FilePart> _filePart(String field, File file) async => (
        field: field,
        bytes: await file.readAsBytes(),
        filename: _basename(file.path),
      );

  Map<String, dynamic> _decodeMap(http.Response response) =>
      jsonDecode(response.body) as Map<String, dynamic>;

  List<T> _decodeList<T>(
          http.Response response, T Function(Map<String, dynamic>) fromJson) =>
      (jsonDecode(response.body) as List<dynamic>? ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();

  /// throws a [DuvetAuthException] for 401/403 responses and a
  /// [DuvetApiException] for all other non-2xx responses, giving callers
  /// structured error types instead of a raw string Exception.
  void _assertOk(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw DuvetAuthException(
        action: action,
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    throw DuvetApiException(
      action: action,
      statusCode: response.statusCode,
      reasonPhrase: response.reasonPhrase,
      body: response.body,
    );
  }
}

/// Which of the user's profile images [RestMethods.uploadProfileImage] sets.
enum ProfileImageKind { avatar, banner }
