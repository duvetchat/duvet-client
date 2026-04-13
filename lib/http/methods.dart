import 'package:http/http.dart' as http;
import 'package:duvet_client/http/router.dart';

import 'dart:io';
import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:duvet_client/errors.dart';
import 'package:duvet_client/models/types.dart';

// ---------------------------------------------------------------------------
// Api responses
// ---------------------------------------------------------------------------

mixin RestMethods {
  http.Client get client;
  ApiRouter get router;
  Map<String, String> get authHeaders;

  String get _baseUrl => router.getCustomApiUrl(protocol: "http");

  // -------------------------------------------------------------------------
  // Spaces
  // -------------------------------------------------------------------------

  Future<GatewaySpace> createSpace(String name, {String? description}) async {
    final url = router.urlFromPath('/api/spaces');
    final response = await client.post(url,
        headers: authHeaders,
        body: jsonEncode({
          'name': name,
          if (description != null) 'description': description,
        }));
    _assertOk(response, 'create space');
    return GatewaySpace.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GatewaySpace> getSpace(String spaceId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get space');
    return GatewaySpace.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteSpace(String spaceId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'delete space');
  }

  Future<void> leaveSpace(String spaceId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/members/@me');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'leave space');
  }

  // -------------------------------------------------------------------------
  // Rooms
  // -------------------------------------------------------------------------

  Future<GatewayRoom> createRoom(
    String spaceId, {
    required String name,
    required RoomType type,
    String? description,
    String? parentId,
    int? position,
    bool nsfw = false,
  }) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/rooms');
    final response = await client.post(url,
        headers: authHeaders,
        body: jsonEncode({
          'name': name,
          'type': type.value,
          'description': description,
          'parent_id': parentId,
          'position': position,
          'nsfw': nsfw,
        }));
    _assertOk(response, 'create room');
    return GatewayRoom.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GatewayRoom> getRoom(String spaceId, String roomId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/rooms/$roomId');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get room');
    return GatewayRoom.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<GatewayRoom>> getRooms(String spaceId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/rooms');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get rooms');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => GatewayRoom.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GatewayRoom> updateRoom(
    String spaceId,
    String roomId, {
    String? name,
    String? description,
    int? position,
    bool? nsfw,
    String? parentId,
  }) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/rooms/$roomId');
    final response = await client.patch(url,
        headers: authHeaders,
        body: jsonEncode({
          'name': name,
          'description': description,
          'position': position,
          'nsfw': nsfw,
          'parent_id': parentId,
        }));
    _assertOk(response, 'update room');
    return GatewayRoom.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteRoom(String spaceId, String roomId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/rooms/$roomId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'delete room');
  }

  // Room permission overwrites
  Future<GatewayRoomOverwrite> updateRoomOverwrite(
    String spaceId,
    String roomId, {
    required String targetId,
    required int targetType,
    required int allowFlags,
    required int denyFlags,
  }) async {
    final url =
        router.urlFromPath('/api/spaces/$spaceId/rooms/$roomId/overwrites');
    final response = await client.put(url,
        headers: authHeaders,
        body: jsonEncode({
          'target_id': targetId,
          'target_type': targetType,
          'allow_flags': allowFlags,
          'deny_flags': denyFlags,
        }));
    _assertOk(response, 'update overwrite');
    return GatewayRoomOverwrite.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteRoomOverwrite(
      String spaceId, String roomId, String targetId) async {
    final url = router
        .urlFromPath('/api/spaces/$spaceId/rooms/$roomId/overwrites/$targetId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'delete overwrite');
  }

  Future<String> createRoomInvite(String spaceId, String roomId) async {
    final url =
        router.urlFromPath('/api/spaces/$spaceId/rooms/$roomId/invites');
    final response = await client.post(url, headers: authHeaders);
    _assertOk(response, 'create room invite');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['code'] as String;
  }

  // -------------------------------------------------------------------------
  // Messages
  // -------------------------------------------------------------------------

  Future<GatewayMessage> getMessageById(String roomId, String messageId) async {
    final url = router.urlFromPath('/api/rooms/$roomId/messages/$messageId');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get message by ID');
    return GatewayMessage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<GatewayMessage>> getMessagesThread(
      String roomId, String messageId) async {
    final url =
        router.urlFromPath('/api/rooms/$roomId/messages/$messageId/thread');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get message thread');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => GatewayMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // replaced all readAsBytesSync() calls with async readAsBytes() to
  // avoid blocking the main thread / causing jank in Flutter UIs.
  Future<GatewayMessage> sendMessageWithFiles(
    String roomId,
    List<File> files, {
    String? content,
    String? nonce,
    MessageReference? reference,
    List<Embed>? embeds,
    String? stickerAttachmentId,
  }) async {
    final url = router.urlFromPath('/api/rooms/$roomId/messages');

    // read all file bytes concurrently with async I/O before building
    // the multipart request, keeping the event loop unblocked.
    final fileBytes = await Future.wait(files.map((f) => f.readAsBytes()));

    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(authHeaders)
      ..fields['content'] = content ?? ''
      ..fields['nonce'] = nonce ?? ''
      ..fields['reference'] = jsonEncode(reference?.toJson() ?? {})
      ..fields['sticker_attachment_id'] = stickerAttachmentId ?? '';

    for (var i = 0; i < files.length; i++) {
      request.files.add(http.MultipartFile.fromBytes(
        'files',
        fileBytes[i],
        filename: files[i].path.split(Platform.pathSeparator).last,
      ));
    }

    if (embeds?.isEmpty == false) {
			request.fields['embeds'] = jsonEncode(embeds ?? []);
		}

		final http.StreamedResponse stream = await request.send();
    final response = await http.Response.fromStream(stream);

    _assertOk(response, 'send message');

    return GatewayMessage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

	// TODO: move to the const Router
  Future<List<Message>> getMessages(
    String roomId, {
    int limit = 50,
    String? before,
  }) async {
    final query = {
      'count': limit.toString(),
      if (before != null) 'before': before,
    };
    final url = Uri.https(_baseUrl, '/api/rooms/$roomId/messages', query);
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get messages');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GatewayMessage> editMessage(
      String roomId, String messageId, String content) async {
    final url = router.urlFromPath('/api/rooms/$roomId/messages/$messageId');
    final response = await client.patch(url,
        headers: authHeaders, body: jsonEncode({'content': content}));
    _assertOk(response, 'edit message');
    return GatewayMessage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> sendRoomTypingIndicator(String roomId) async {
    final url = router.urlFromPath('/api/rooms/$roomId/typing');
    final response = await client.post(url, headers: authHeaders);
    _assertOk(response, 'send room typing indicator');
  }

  Future<void> deleteMessage(String roomId, String messageId) async {
    final url = router.urlFromPath('/api/rooms/$roomId/messages/$messageId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'delete message');
  }

  Future<void> ackRoom(String roomId, String messageId) async {
    final url = router.urlFromPath('/api/rooms/$roomId/ack');
    final response = await client.post(url,
        headers: authHeaders, body: jsonEncode({'message_id': messageId}));
    _assertOk(response, 'ack room');
  }

  Future<Map<String, int>> getUnreadCount() async {
    final url = router.urlFromPath('/api/users/me/mentions/counts');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get unread count');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body.map((key, value) => MapEntry(key, value as int));
  }

  // -------------------------------------------------------------------------
  // Reactions
  // -------------------------------------------------------------------------

  Future<void> addRoomReaction(
      String roomId, String messageId, String emojiName,
      {String? emojiId}) async {
    final url =
        router.urlFromPath('/api/rooms/$roomId/messages/$messageId/reactions');
    final response = await client.put(url,
        headers: authHeaders,
        body: jsonEncode({
          'emoji_name': emojiName,
          'emoji_id': emojiId,
        }));
    _assertOk(response, 'add reaction');
  }

  Future<void> removeReaction(String roomId, String messageId, String emojiName,
      {String? emojiId}) async {
    final url = router.urlFromPath(
        '/api/rooms/$roomId/messages/$messageId/reactions/$emojiName');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'remove reaction');
  }

  // -------------------------------------------------------------------------
  // Roles
  // -------------------------------------------------------------------------

  Future<GatewayRole> createRole(
    String spaceId, {
    required String name,
    int? colorFrom,
    int? colorVia,
    int? colorTo,
    bool hoisted = false,
  }) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/roles');
    final response = await client.post(url,
        headers: authHeaders,
        body: jsonEncode({
          'name': name,
          'color_from': colorFrom,
          'color_via': colorVia,
          'color_to': colorTo,
          'hoisted': hoisted,
        }));
    _assertOk(response, 'create role');
    return GatewayRole.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GatewayRole> updateRole(
    String spaceId,
    String roleId, {
    String? name,
    int? colorFrom,
    int? colorVia,
    int? colorTo,
    int? permissions,
    bool? hoisted,
    int? position,

		/// NOTE:
    /// When true, null color fields explicitly clear those colors in the DB.
    bool? clearColors,
  }) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/roles/$roleId');
    final response = await client.patch(url,
        headers: authHeaders,
        body: jsonEncode({
          'name': name,
          'color_from': colorFrom,
          'color_via': colorVia,
          'color_to': colorTo,
          'permissions': permissions,
          'hoisted': hoisted,
          'position': position,
        }));
    _assertOk(response, 'update role');
    return GatewayRole.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteRole(String spaceId, String roleId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/roles/$roleId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'delete role');
  }

  Future<void> assignRoleToMember(
      String spaceId, String memberId, String roleId) async {
    final url = router
        .urlFromPath('/api/spaces/$spaceId/members/$memberId/roles/$roleId');
    final response = await client.put(url, headers: authHeaders);
    _assertOk(response, 'assign role to member');
  }

  Future<void> unassignRoleFromMember(
      String spaceId, String memberId, String roleId) async {
    final url = router
        .urlFromPath('/api/spaces/$spaceId/members/$memberId/roles/$roleId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'unassign role from member');
  }

  // -------------------------------------------------------------------------
  // Space emojis
  // -------------------------------------------------------------------------

  // use async readAsBytes() instead of readAsBytesSync()
  Future<SpaceEmoji> createEmoji(String spaceId,
      {required String name, required File file}) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/emojis');
    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(authHeaders)
      ..fields['name'] = name
      ..files.add(http.MultipartFile.fromBytes('files', bytes));

    final http.StreamedResponse stream = await request.send();
    final http.Response response = await http.Response.fromStream(stream);
    _assertOk(response, 'create emoji');

    return SpaceEmoji.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SpaceEmoji> updateEmoji(
      String spaceId, String emojiId, String name) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/emojis/$emojiId');
    final response = await client.patch(url,
        headers: authHeaders, body: jsonEncode({'name': name}));
    _assertOk(response, 'update emoji');
    return SpaceEmoji.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteEmoji(String spaceId, String emojiId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/emojis/$emojiId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'delete emoji');
  }

  // -------------------------------------------------------------------------
  // Space stickers
  // -------------------------------------------------------------------------

  // use async readAsBytes() instead of readAsBytesSync()
  Future<SpaceSticker> createSticker(String spaceId,
      {required String name, required File file}) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/stickers');
    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll(authHeaders)
      ..fields['name'] = name
      ..files.add(http.MultipartFile.fromBytes('files', bytes));

    final http.StreamedResponse stream = await request.send();
    final http.Response response = await http.Response.fromStream(stream);
    _assertOk(response, 'create sticker');

    return SpaceSticker.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteSticker(String spaceId, String stickerId) async {
    final url = router.urlFromPath('/api/spaces/$spaceId/stickers/$stickerId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'delete sticker');
  }

  // -------------------------------------------------------------------------
  // Friends
  // -------------------------------------------------------------------------

  Future<FriendRequest> sendFriendRequest(String userId) async {
    final url = router.urlFromPath('/api/users/@me/friends/requests');
    final response = await client.post(url,
        headers: authHeaders, body: jsonEncode({'user_id': userId}));
    _assertOk(response, 'send friend request');
    return FriendRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Friend> acceptFriendRequest(String requestId) async {
    final url = router.urlFromPath('/api/friends/requests/$requestId/accept');
    final response = await client.post(url, headers: authHeaders);
    _assertOk(response, 'accept friend request');
    return Friend.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> rejectFriendRequest(String requestId) async {
    final url = router.urlFromPath('/api/friends/requests/$requestId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'reject friend request');
  }

  Future<void> unfriend(String userId) async {
    final url = router.urlFromPath('/api/users/@me/friends/$userId');
    final response = await client.delete(url, headers: authHeaders);
    _assertOk(response, 'remove friend');
  }

  Future<List<Friend>> getFriends() async {
    final url = router.urlFromPath('/api/users/@me/friends');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get friends');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) => Friend.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FriendRequest>> getPendingFriendRequests() async {
    final url = router.urlFromPath('/api/users/@me/friends/requests');
    final response = await client.get(url, headers: authHeaders);
    _assertOk(response, 'get friend requests');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------------------
  // Users
  // -------------------------------------------------------------------------

  Future<UserMeResult> updateMe({
    String? username,
    String? alias,
    String? avatar,
    String? banner,
  }) async {
    final url = router.urlFromPath('/api/users/@me');
    final response = await client.patch(url,
        headers: authHeaders,
        body: jsonEncode({
          'username': username,
          'alias': alias,
          'avatar': avatar,
          'banner': banner,
        }));
    _assertOk(response, 'update me');
    return UserMeResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// throws a [DuvetAuthException] for 401/403 responses and a
  /// [DuvetApiException] for all other non-2xx responses, giving callers
  /// structured error types instead of a raw string Exception.
  void _assertOk(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw DuvetAuthException(
        action: action,
        statusCode: response.statusCode,
        body: '${response.body}\n${authHeaders.toString()}',
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
