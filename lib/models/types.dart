import 'package:duvet_client/utils/util.dart';
part 'gateway_envelope.dart';

// ---------------------------------------------------------------------------
// Primitive enums
// ---------------------------------------------------------------------------

final class UserStatus extends EnumLike<int, UserStatus> {
  static const offline = UserStatus(0);
  static const online = UserStatus(1);
  static const dnd = UserStatus(2);
  const UserStatus(super.value);

  static UserStatus fromInt(int v) => UserStatus(v);

  String toStringLabel() {
    switch (value) {
      case 1:
        return 'online';
      case 2:
        return 'dnd';
      default:
        return 'offline';
    }
  }
}

final class RoomType extends EnumLike<int, RoomType> {
  static const text = RoomType(1);
  static const voice = RoomType(2);
  static const category = RoomType(3);
  const RoomType(super.value);

  static RoomType fromInt(int v) => RoomType(v);

  String toStringLabel() {
    switch (value) {
      case 2:
        return 'voice';
      case 3:
        return 'category';
      default:
        return 'text';
    }
  }
}

final class MessageType extends EnumLike<int, MessageType> {
  static const text = MessageType(0);
  static const voice = MessageType(1);
  const MessageType(super.value);

  static MessageType fromInt(int v) => MessageType(v);
}

final class MessageReferenceType extends EnumLike<int, MessageReferenceType> {
  static const reply = MessageReferenceType(0);
  const MessageReferenceType(super.value);
}

// ---------------------------------------------------------------------------
// Embed models
// ---------------------------------------------------------------------------

class EmbedMedia {
  final String url;
  final int? width;
  final int? height;

  const EmbedMedia({required this.url, this.width, this.height});

  EmbedMedia.fromJson(Map<String, dynamic> j)
      : url = j['url'] as String,
        width = j['width'] as int?,
        height = j['height'] as int?;

  Map<String, dynamic> toJson() => {
        'url': url,
        if (width != null) 'width': width,
        if (height != null) 'height': height
      };
}

class EmbedFooter {
  final String text;
  final String? iconUrl;

  const EmbedFooter({required this.text, this.iconUrl});

  EmbedFooter.fromJson(Map<String, dynamic> j)
      : text = j['text'] as String,
        iconUrl = j['icon_url'] as String?;
}

class EmbedAuthor {
  final String name;
  final String? url;
  final String? iconUrl;

  const EmbedAuthor({required this.name, this.url, this.iconUrl});

  EmbedAuthor.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
        url = j['url'] as String?,
        iconUrl = j['icon_url'] as String?;
}

class EmbedField {
  final String name;
  final String value;
  final bool inline;

  const EmbedField(
      {required this.name, required this.value, required this.inline});

  EmbedField.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
        value = j['value'] as String,
        inline = j['inline'] as bool? ?? false;
}

class EmbedColor {
  final int? colorFrom;
  final int? colorVia;
  final int? colorTo;

  const EmbedColor({this.colorFrom, this.colorVia, this.colorTo});

  EmbedColor.fromJson(Map<String, dynamic> j)
      : colorFrom = j['color_from'] as int?,
        colorVia = j['color_via'] as int?,
        colorTo = j['color_to'] as int?;
}

class Embed {
  final String? type;
  final String? title;
  final String? description;
  final String? url;
  final String? timestamp;
  final EmbedColor? color;
  final EmbedFooter? footer;
  final EmbedMedia? image;
  final EmbedMedia? thumbnail;
  final EmbedMedia? video;
  final EmbedAuthor? author;
  final List<EmbedField>? fields;

  const Embed({
    this.type,
    this.title,
    this.description,
    this.url,
    this.timestamp,
    this.color,
    this.footer,
    this.image,
    this.thumbnail,
    this.video,
    this.author,
    this.fields,
  });

  Embed.fromJson(Map<String, dynamic> j)
      : type = j['type'] as String?,
        title = j['title'] as String?,
        description = j['description'] as String?,
        url = j['url'] as String?,
        timestamp = j['timestamp'] as String?,
        color = j['color'] != null ? EmbedColor.fromJson(j['color']) : null,
        footer = j['footer'] != null ? EmbedFooter.fromJson(j['footer']) : null,
        image = j['image'] != null ? EmbedMedia.fromJson(j['image']) : null,
        thumbnail =
            j['thumbnail'] != null ? EmbedMedia.fromJson(j['thumbnail']) : null,
        video = j['video'] != null ? EmbedMedia.fromJson(j['video']) : null,
        author = j['author'] != null ? EmbedAuthor.fromJson(j['author']) : null,
        fields = (j['fields'] as List<dynamic>?)
            ?.map((e) => EmbedField.fromJson(e as Map<String, dynamic>))
            .toList();
}

// ---------------------------------------------------------------------------
// Attachment
// ---------------------------------------------------------------------------

class Attachment {
  final String id;
  final String messageId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final bool? deleted;
  final bool? pending;

  const Attachment({
    required this.id,
    required this.messageId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    this.width,
    this.height,
    required this.createdAt,
    this.deleted,
    this.pending,
  });

  Attachment.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        messageId = j['message_id'] as String,
        filename = j['filename'] as String,
        contentType = j['content_type'] as String,
        sizeBytes = j['size_bytes'] as int,
        width = j['width'] as int?,
        height = j['height'] as int?,
        createdAt = DateTime.parse(j['created_at'] as String),
        deleted = j['deleted'] as bool?,
        pending = j['pending'] as bool?;
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

class MessageReference {
  final MessageReferenceType? type;
  final String? messageId;
  final String? roomId;
  final String? spaceId;
  final bool? failIfNotExists;

  const MessageReference(
      {this.type,
      this.messageId,
      this.roomId,
      this.spaceId,
      this.failIfNotExists});

  MessageReference.fromJson(Map<String, dynamic> j)
      : type = MessageReferenceType(j['type'] as int? ?? 0),
        messageId = j['message_id'] as String?,
        roomId = j['room_id'] as String?,
        spaceId = j['space_id'] as String?,
        failIfNotExists = j['fail_if_not_exists'] as bool?;

  MessageReference.fromMessage(GatewayMessage m)
      : type = MessageReferenceType.reply,
        messageId = m.id,
        roomId = m.roomId,
        spaceId = null,
        failIfNotExists = true;

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type!.value,
        if (messageId != null) 'message_id': messageId,
        if (roomId != null) 'room_id': roomId,
        if (spaceId != null) 'space_id': spaceId,
        if (failIfNotExists != null) 'fail_if_not_exists': failIfNotExists,
      };
}

class ReferencedMessage {
  final String id;
  final int? type;
  final String? messageId;
  final String? roomId;
  final String? spaceId;
  final String? content;
  final String? authorId;
  final String? authorName;
  final String? authorAvatar;
  final DateTime? createdAt;

  const ReferencedMessage({
    required this.id,
    this.type,
    this.messageId,
    this.roomId,
    this.spaceId,
    this.content,
    this.authorId,
    this.authorName,
    this.authorAvatar,
    this.createdAt,
  });

  ReferencedMessage.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        type = j['type'] as int?,
        messageId = j['message_id'] as String?,
        roomId = j['room_id'] as String?,
        spaceId = j['space_id'] as String?,
        content = j['content'] as String?,
        authorId = j['author_id'] as String?,
        authorName = j['author_name'] as String?,
        authorAvatar = j['author_avatar'] as String?,
        createdAt = j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : null;
}

class MessageReaction {
  final String emojiName;
  final String? emojiId;
  final int count;
  final List<String> users;

  const MessageReaction(
      {required this.emojiName,
      this.emojiId,
      required this.count,
      required this.users});

  MessageReaction.fromJson(Map<String, dynamic> j)
      : emojiName = j['emoji_name'] as String,
        emojiId = j['emoji_id'] as String?,
        count = j['count'] as int,
        users = (j['users'] as List<dynamic>).map((e) => e as String).toList();
}

class GatewayMessage {
  final String id;
  final String roomId;
  final String authorId;
  final String? content;
  final MessageType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? nonce;
  final GatewayUser? user;
  final String? memberAlias;
  final ReferencedMessage? referencedMessage;
  final String? refMessageId;
  final List<Embed>? embeds;
  final List<Attachment>? attachments;
  final List<MessageReaction>? reactions;
  final String? stickerAttachmentId;

  const GatewayMessage({
    required this.id,
    required this.roomId,
    required this.authorId,
    this.content,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.nonce,
    this.user,
    this.memberAlias,
    this.referencedMessage,
    this.refMessageId,
    this.embeds,
    this.attachments,
    this.reactions,
    this.stickerAttachmentId,
  });

  GatewayMessage.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        roomId = j['room_id'] as String,
        authorId = j['author_id'] as String,
        content = j['content'] as String?,
        type = MessageType.fromInt(j['type'] as int? ?? 0),
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null,
        nonce = j['nonce'] as String?,
        user = j['user'] != null
            ? GatewayUser.fromJson(j['user'] as Map<String, dynamic>)
            : null,
        memberAlias = j['member_alias'] as String?,
        referencedMessage = j['referenced_message'] != null
            ? ReferencedMessage.fromJson(
                j['referenced_message'] as Map<String, dynamic>)
            : null,
        refMessageId = j['ref_message_id'] as String?,
        embeds = (j['embeds'] as List<dynamic>?)
            ?.map((e) => Embed.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments = (j['attachments'] as List<dynamic>?)
            ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactions = (j['reactions'] as List<dynamic>?)
            ?.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        stickerAttachmentId = j['sticker_attachment_id'] as String?;
}

class Message {
  final String id;
  final String content;
  final MessageType type;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nonce;
  final ReferencedMessage? referencedMessage;
  final String? refMessageId;
  final List<Embed>? embeds;
  final List<Attachment>? attachments;
  final List<MessageReaction>? reactions;
  final String? stickerAttachmentId;

  const Message({
    required this.id,
    required this.content,
    required this.type,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.nonce,
    this.referencedMessage,
    this.refMessageId,
    this.embeds,
    this.attachments,
    this.reactions,
    this.stickerAttachmentId,
  });

  Message.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        content = j['content'] as String? ?? '',
        type = MessageType.fromInt(j['type'] as int? ?? 0),
        authorId = j['author_id'] as String,
        authorName = j['author_name'] as String,
        authorAvatarUrl = j['author_avatar_url'] as String?,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        nonce = j['nonce'] as String?,
        referencedMessage = j['referenced_message'] != null
            ? ReferencedMessage.fromJson(
                j['referenced_message'] as Map<String, dynamic>)
            : null,
        refMessageId = j['ref_message_id'] as String?,
        embeds = (j['embeds'] as List<dynamic>?)
            ?.map((e) => Embed.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments = (j['attachments'] as List<dynamic>?)
            ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactions = (j['reactions'] as List<dynamic>?)
            ?.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        stickerAttachmentId = j['sticker_attachment_id'] as String?;
}

// ---------------------------------------------------------------------------
// User
// ---------------------------------------------------------------------------

class GatewayUser {
  final String id;
  final String username;
  final bool? emailVerified;
  final String? alias;
  final String? avatar;
  final String? banner;
  final String custom;
  final UserStatus statusId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const GatewayUser({
    required this.id,
    required this.username,
    this.emailVerified,
    this.alias,
    this.avatar,
    this.banner,
    required this.custom,
    required this.statusId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  GatewayUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        username = j['username'] as String,
        emailVerified = j['email_verified'] as bool?,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?,
        custom = j['custom'] as String? ?? '',
        statusId = UserStatus.fromInt(j['status_id'] as int? ?? 0),
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

class GatewayVoiceState {
  final String roomId;
  final String userId;
  final bool? muted;
  final bool? deafened;
  final bool? screenSharing;

  const GatewayVoiceState({
    required this.roomId,
    required this.userId,
    this.muted,
    this.deafened,
    this.screenSharing,
  });

  GatewayVoiceState.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        userId = j['user_id'] as String,
        muted = j['muted'] as bool?,
        deafened = j['deafened'] as bool?,
        screenSharing = j['screen_sharing'] as bool?;
}

// ---------------------------------------------------------------------------
// Rooms
// ---------------------------------------------------------------------------

class GatewayRoomOverwrite {
  final String id;
  final String roomId;
  final String targetId;
  final int targetType;
  final int denyFlags;
  final int allowFlags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const GatewayRoomOverwrite({
    required this.id,
    required this.roomId,
    required this.targetId,
    required this.targetType,
    required this.denyFlags,
    required this.allowFlags,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  GatewayRoomOverwrite.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        roomId = j['room_id'] as String,
        targetId = j['target_id'] as String,
        targetType = j['target_type'] as int,
        denyFlags = j['deny_flags'] as int,
        allowFlags = j['allow_flags'] as int,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

class GatewayRoom {
  final String id;
  final String spaceId;
  final String? parentId;
  final RoomType type;
  final String name;
  final String? description;
  final int position;
  final bool nsfw;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const GatewayRoom({
    required this.id,
    required this.spaceId,
    this.parentId,
    required this.type,
    required this.name,
    this.description,
    required this.position,
    required this.nsfw,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  GatewayRoom.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        spaceId = j['space_id'] as String,
        parentId = j['parent_id'] as String?,
        type = RoomType.fromInt(j['type'] as int),
        name = j['name'] as String,
        description = j['description'] as String?,
        position = j['position'] as int,
        nsfw = j['nsfw'] as bool? ?? false,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

// ---------------------------------------------------------------------------
// Members & Roles
// ---------------------------------------------------------------------------

class GatewayMember {
  final String id;
  final String spaceId;
  final String userId;
  final String? alias;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const GatewayMember({
    required this.id,
    required this.spaceId,
    required this.userId,
    this.alias,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  GatewayMember.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        spaceId = j['space_id'] as String,
        userId = j['user_id'] as String,
        alias = j['alias'] as String?,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

class GatewayRole {
  final String id;
  final String spaceId;
  final String name;
  final int? colorFrom;
  final int? colorVia;
  final int? colorTo;
  final int flags;
  final int permissions;
  final bool hoisted;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const GatewayRole({
    required this.id,
    required this.spaceId,
    required this.name,
    this.colorFrom,
    this.colorVia,
    this.colorTo,
    required this.flags,
    required this.permissions,
    required this.hoisted,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  GatewayRole.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        spaceId = j['space_id'] as String,
        name = j['name'] as String,
        colorFrom = j['color_from'] as int?,
        colorVia = j['color_via'] as int?,
        colorTo = j['color_to'] as int?,
        flags = j['flags'] as int? ?? 0,
        permissions = j['permissions'] as int? ?? 0,
        hoisted = j['hoisted'] as bool? ?? false,
        position = j['position'] as int? ?? 0,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

// ---------------------------------------------------------------------------
// Spaces
// ---------------------------------------------------------------------------

class GatewaySpace {
  final String id;
  final String name;
  final String? description;
  final String? banner;
  final String ownerId;
  final String? locale;
  final GatewayMember? member;
  final Map<String, List<String>> memberRoles;
  final List<GatewayRoomOverwrite> roomOverwrites;
  final List<GatewayRoom> rooms;
  final List<GatewayMember> members;
  final List<GatewayRole> roles;
  final List<GatewayUser> users;
  final List<GatewayVoiceState>? voiceStates;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const GatewaySpace({
    required this.id,
    required this.name,
    this.description,
    this.banner,
    required this.ownerId,
    this.locale,
    this.member,
    required this.memberRoles,
    required this.roomOverwrites,
    required this.rooms,
    required this.members,
    required this.roles,
    required this.users,
    this.voiceStates,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  GatewaySpace.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        description = j['description'] as String?,
        banner = j['banner'] as String?,
        ownerId = j['owner_id'] as String,
        locale = j['locale'] as String?,
        member = j['member'] != null
            ? GatewayMember.fromJson(j['member'] as Map<String, dynamic>)
            : null,
        memberRoles = (j['member_roles'] as Map<String, dynamic>? ?? {}).map((k,
                v) =>
            MapEntry(k, (v as List<dynamic>).map((e) => e as String).toList())),
        roomOverwrites = (j['room_overwrites'] as List<dynamic>? ?? [])
            .map(
                (e) => GatewayRoomOverwrite.fromJson(e as Map<String, dynamic>))
            .toList(),
        rooms = (j['rooms'] as List<dynamic>? ?? [])
            .map((e) => GatewayRoom.fromJson(e as Map<String, dynamic>))
            .toList(),
        members = (j['members'] as List<dynamic>? ?? [])
            .map((e) => GatewayMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        roles = (j['roles'] as List<dynamic>? ?? [])
            .map((e) => GatewayRole.fromJson(e as Map<String, dynamic>))
            .toList(),
        users = (j['users'] as List<dynamic>? ?? [])
            .map((e) => GatewayUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        voiceStates = (j['voice_states'] as List<dynamic>?)
            ?.map((e) => GatewayVoiceState.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

// ---------------------------------------------------------------------------
// Space assets (emoji / sticker)
// ---------------------------------------------------------------------------

class SpaceEmoji {
  final String id;
  final String name;
  final String spaceId;
  final String attachmentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const SpaceEmoji({
    required this.id,
    required this.name,
    required this.spaceId,
    required this.attachmentId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  SpaceEmoji.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        spaceId = j['space_id'] as String,
        attachmentId = j['attachment_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

class SpaceSticker {
  final String id;
  final String name;
  final String spaceId;
  final String attachmentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const SpaceSticker({
    required this.id,
    required this.name,
    required this.spaceId,
    required this.attachmentId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  SpaceSticker.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        spaceId = j['space_id'] as String,
        attachmentId = j['attachment_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

// ---------------------------------------------------------------------------
// Conversations / DMs
// ---------------------------------------------------------------------------

class Conversation {
  final String id;
  final String? name;
  final List<String> memberIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    this.name,
    required this.memberIds,
    required this.createdAt,
    required this.updatedAt,
  });

  Conversation.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String?,
        memberIds = (j['member_ids'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String);
}

class DirectMessage {
  final String id;
  final String conversationId;
  final String authorId;
  final String? content;
  final MessageType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? nonce;
  final GatewayUser? user;
  final ReferencedMessage? referencedMessage;
  final String? refMessageId;
  final List<Embed>? embeds;
  final List<Attachment>? attachments;
  final List<MessageReaction>? reactions;
  final String? stickerAttachmentId;

  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.authorId,
    this.content,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.nonce,
    this.user,
    this.referencedMessage,
    this.refMessageId,
    this.embeds,
    this.attachments,
    this.reactions,
    this.stickerAttachmentId,
  });

  DirectMessage.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        conversationId = j['conversation_id'] as String,
        authorId = j['author_id'] as String,
        content = j['content'] as String?,
        type = MessageType.fromInt(j['type'] as int? ?? 0),
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null,
        nonce = j['nonce'] as String?,
        user = j['user'] != null
            ? GatewayUser.fromJson(j['user'] as Map<String, dynamic>)
            : null,
        referencedMessage = j['referenced_message'] != null
            ? ReferencedMessage.fromJson(
                j['referenced_message'] as Map<String, dynamic>)
            : null,
        refMessageId = j['ref_message_id'] as String?,
        embeds = (j['embeds'] as List<dynamic>?)
            ?.map((e) => Embed.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments = (j['attachments'] as List<dynamic>?)
            ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactions = (j['reactions'] as List<dynamic>?)
            ?.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        stickerAttachmentId = j['sticker_attachment_id'] as String?;
}

// ---------------------------------------------------------------------------
// Friends
// ---------------------------------------------------------------------------

class FriendRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final DateTime createdAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.createdAt,
  });

  FriendRequest.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        senderId = j['sender_id'] as String,
        receiverId = j['receiver_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String);
}

class Friend {
  final String id;
  final String userId;
  final String friendId;
  final DateTime createdAt;

  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.createdAt,
  });

  Friend.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        userId = j['user_id'] as String,
        friendId = j['friend_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String);
}

// ---------------------------------------------------------------------------
// Gateway ready payload
// ---------------------------------------------------------------------------

class GatewayReadyActiveCall {
  final String conversationId;
  final String initiatorId;
  final List<GatewayVoiceState>? voiceStates;

  const GatewayReadyActiveCall({
    required this.conversationId,
    required this.initiatorId,
    this.voiceStates,
  });

  GatewayReadyActiveCall.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        initiatorId = j['initiator_id'] as String,
        voiceStates = (j['voice_states'] as List<dynamic>?)
            ?.map((e) => GatewayVoiceState.fromJson(e as Map<String, dynamic>))
            .toList();
}

class GatewayReadyData {
  final GatewayUser user;
  final String sessionToken;
  final List<String>? unreadRooms;
  final Map<String, String>? lastReadRooms;
  final Map<String, String>? lastMsgRooms;
  final List<String>? unreadConvs;
  final List<GatewayReadyActiveCall>? activeCalls;
  final List<GatewaySpace>? spaces;

  const GatewayReadyData({
    required this.user,
    required this.sessionToken,
    this.unreadRooms,
    this.lastReadRooms,
    this.lastMsgRooms,
    this.unreadConvs,
    this.activeCalls,
    this.spaces,
  });

  GatewayReadyData.fromJson(Map<String, dynamic> j)
      : user = GatewayUser.fromJson(j['user'] as Map<String, dynamic>),
        sessionToken = j['sessionToken'] as String,
        unreadRooms = (j['unread_rooms'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        lastReadRooms = (j['last_read_rooms'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String)),
        lastMsgRooms = (j['last_msg_rooms'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as String)),
        unreadConvs = (j['unread_convs'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        activeCalls = (j['active_calls'] as List<dynamic>?)
            ?.map((e) =>
                GatewayReadyActiveCall.fromJson(e as Map<String, dynamic>))
            .toList(),
        spaces = (j['spaces'] as List<dynamic>?)
            ?.map((e) => GatewaySpace.fromJson(e as Map<String, dynamic>))
            .toList();
}

// ---------------------------------------------------------------------------
// Gateway event payloads (non-ready)
// ---------------------------------------------------------------------------

class GatewaySpaceCreatePayload {
  final GatewaySpace space;
  final Map<String, GatewayRoom> rooms;
  final Map<String, GatewayRole> rolesPermissions;
  final Map<String, List<String>> memberRoles;
  final Map<String, List<GatewayRoomOverwrite>>? overwrites;
  final String ownerId;
  final List<GatewayVoiceState>? voiceStates;

  const GatewaySpaceCreatePayload({
    required this.space,
    required this.rooms,
    required this.rolesPermissions,
    required this.memberRoles,
    this.overwrites,
    required this.ownerId,
    this.voiceStates,
  });

  GatewaySpaceCreatePayload.fromJson(Map<String, dynamic> j)
      : space = GatewaySpace.fromJson(j['space'] as Map<String, dynamic>),
        rooms = (j['rooms'] as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, GatewayRoom.fromJson(v as Map<String, dynamic>))),
        rolesPermissions = (j['roles_permissions'] as Map<String, dynamic>).map(
            (k, v) =>
                MapEntry(k, GatewayRole.fromJson(v as Map<String, dynamic>))),
        memberRoles = (j['member_roles'] as Map<String, dynamic>? ?? {}).map((k,
                v) =>
            MapEntry(k, (v as List<dynamic>).map((e) => e as String).toList())),
        overwrites = (j['overwrites'] as Map<String, dynamic>?)?.map((k, v) =>
            MapEntry(
                k,
                (v as List<dynamic>)
                    .map((e) => GatewayRoomOverwrite.fromJson(
                        e as Map<String, dynamic>))
                    .toList())),
        ownerId = j['owner_id'] as String,
        voiceStates = (j['voice_states'] as List<dynamic>?)
            ?.map((e) => GatewayVoiceState.fromJson(e as Map<String, dynamic>))
            .toList();
}

// ---------------------------------------------------------------------------
// Delete / simple event payloads
// ---------------------------------------------------------------------------

class GatewayMessageDelete {
  final String id;
  final String roomId;
  const GatewayMessageDelete({required this.id, required this.roomId});

  GatewayMessageDelete.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        roomId = j['room_id'] as String;
}

class GatewayUserStatusUpdate {
  final String userId;
  final UserStatus statusId;
  const GatewayUserStatusUpdate({required this.userId, required this.statusId});

  GatewayUserStatusUpdate.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] as String,
        statusId = UserStatus.fromInt(j['status_id'] as int);
}

class SpaceDeleteEvent {
  final String id;
  const SpaceDeleteEvent({required this.id});
  SpaceDeleteEvent.fromJson(Map<String, dynamic> j) : id = j['id'] as String;
}

class RoomDeleteEvent {
  final String id;
  final String spaceId;
  const RoomDeleteEvent({required this.id, required this.spaceId});
  RoomDeleteEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        spaceId = j['space_id'] as String;
}

class OverwriteDeleteEvent {
  final String roomId;
  final String targetId;
  const OverwriteDeleteEvent({required this.roomId, required this.targetId});
  OverwriteDeleteEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        targetId = j['target_id'] as String;
}

class MentionCreateEvent {
  final String roomId;
  final String? conversationId;
  const MentionCreateEvent({required this.roomId, this.conversationId});
  MentionCreateEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        conversationId = j['conversation_id'] as String?;
}

class UserUpdateEvent {
  final String id;
  final String username;
  final String? alias;
  final String? avatar;
  final String? banner;
  const UserUpdateEvent(
      {required this.id,
      required this.username,
      this.alias,
      this.avatar,
      this.banner});
  UserUpdateEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?;
}

class VoiceStateEvent {
  final String roomId;
  final String userId;
  final bool joined;
  final bool? muted;
  final bool? deafened;
  final bool? screenSharing;
  const VoiceStateEvent({
    required this.roomId,
    required this.userId,
    required this.joined,
    this.muted,
    this.deafened,
    this.screenSharing,
  });
  VoiceStateEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        userId = j['user_id'] as String,
        joined = j['joined'] as bool,
        muted = j['muted'] as bool?,
        deafened = j['deafened'] as bool?,
        screenSharing = j['screen_sharing'] as bool?;
}

class VoiceJoinedEvent {
  final String userId;
  final String sdp;
  const VoiceJoinedEvent({required this.userId, required this.sdp});
  VoiceJoinedEvent.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] as String,
        sdp = j['sdp'] as String;
}

class WebRTCEvent {
  final String? candidate;
  final int? sdpMLineIndex;
  final String? sdpMid;
  final String? sdp;
  const WebRTCEvent(
      {this.candidate, this.sdpMLineIndex, this.sdpMid, this.sdp});
  WebRTCEvent.fromJson(Map<String, dynamic> j)
      : candidate = j['candidate'] as String?,
        sdpMLineIndex = j['sdpMLineIndex'] as int?,
        sdpMid = j['sdpMid'] as String?,
        sdp = j['sdp'] as String?;
}

class RoleDeleteEvent {
  final String id;
  final String spaceId;
  const RoleDeleteEvent({required this.id, required this.spaceId});
  RoleDeleteEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        spaceId = j['space_id'] as String;
}

class MemberRoleEvent {
  final String memberId;
  final String roleId;
  final String spaceId;
  const MemberRoleEvent(
      {required this.memberId, required this.roleId, required this.spaceId});
  MemberRoleEvent.fromJson(Map<String, dynamic> j)
      : memberId = j['member_id'] as String,
        roleId = j['role_id'] as String,
        spaceId = j['space_id'] as String;
}

class SpaceMemberEvent {
  final String memberId;
  final String spaceId;
  const SpaceMemberEvent({required this.memberId, required this.spaceId});
  SpaceMemberEvent.fromJson(Map<String, dynamic> j)
      : memberId = j['member_id'] as String,
        spaceId = j['space_id'] as String;
}

class GuildMemberAddEvent {
  final String spaceId;
  final String userId;
  final String memberId;
  final GatewayUser? user;
  const GuildMemberAddEvent({
    required this.spaceId,
    required this.userId,
    required this.memberId,
    this.user,
  });
  GuildMemberAddEvent.fromJson(Map<String, dynamic> j)
      : spaceId = j['space_id'] as String,
        userId = j['user_id'] as String,
        memberId = j['member_id'] as String,
        user = j['user'] != null
            ? GatewayUser.fromJson(j['user'] as Map<String, dynamic>)
            : null;
}

class GuildMemberRemoveEvent {
  final String spaceId;
  final String userId;
  final String memberId;
  const GuildMemberRemoveEvent(
      {required this.spaceId, required this.userId, required this.memberId});
  GuildMemberRemoveEvent.fromJson(Map<String, dynamic> j)
      : spaceId = j['space_id'] as String,
        userId = j['user_id'] as String,
        memberId = j['member_id'] as String;
}

class SpaceAssetDeleteEvent {
  final String id;
  final String spaceId;
  const SpaceAssetDeleteEvent({required this.id, required this.spaceId});
  SpaceAssetDeleteEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        spaceId = j['space_id'] as String;
}

class ReactionEvent {
  final String messageId;
  final String userId;
  final String emojiName;
  final String? emojiId;
  const ReactionEvent(
      {required this.messageId,
      required this.userId,
      required this.emojiName,
      this.emojiId});
  ReactionEvent.fromJson(Map<String, dynamic> j)
      : messageId = j['message_id'] as String,
        userId = j['user_id'] as String,
        emojiName = j['emoji_name'] as String,
        emojiId = j['emoji_id'] as String?;
}

class ReactionRemoveEvent {
  final String messageId;
  final String userId;
  final String emojiName;
  const ReactionRemoveEvent(
      {required this.messageId, required this.userId, required this.emojiName});
  ReactionRemoveEvent.fromJson(Map<String, dynamic> j)
      : messageId = j['message_id'] as String,
        userId = j['user_id'] as String,
        emojiName = j['emoji_name'] as String;
}

class TypingEvent {
  final String userId;
  final String username;
  final String? alias;
  final String? avatar;
  final String roomId;
  const TypingEvent(
      {required this.userId,
      required this.username,
      this.alias,
      this.avatar,
      required this.roomId});
  TypingEvent.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        roomId = j['room_id'] as String;
}

class DMTypingEvent {
  final String conversationId;
  final String userId;
  final String username;
  final String? alias;
  final String? avatar;
  const DMTypingEvent(
      {required this.conversationId,
      required this.userId,
      required this.username,
      this.alias,
      this.avatar});
  DMTypingEvent.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        userId = j['user_id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?;
}

class CallIncomingEvent {
  final String conversationId;
  final String initiatorId;
  final String initiatorName;
  final String? initiatorAvatar;
  final List<String> memberIds;
  const CallIncomingEvent({
    required this.conversationId,
    required this.initiatorId,
    required this.initiatorName,
    this.initiatorAvatar,
    required this.memberIds,
  });
  CallIncomingEvent.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        initiatorId = j['initiator_id'] as String,
        initiatorName = j['initiator_name'] as String,
        initiatorAvatar = j['initiator_avatar'] as String?,
        memberIds =
            (j['member_ids'] as List<dynamic>).map((e) => e as String).toList();
}

class CallResponseEvent {
  final String conversationId;
  final String userId;
  const CallResponseEvent({required this.conversationId, required this.userId});
  CallResponseEvent.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        userId = j['user_id'] as String;
}

class CallEndedEvent {
  final String conversationId;
  const CallEndedEvent({required this.conversationId});
  CallEndedEvent.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String;
}

class FriendRequestRejectEvent {
  final String requestId;
  const FriendRequestRejectEvent({required this.requestId});
  FriendRequestRejectEvent.fromJson(Map<String, dynamic> j)
      : requestId = j['request_id'] as String;
}

class FriendRemoveEvent {
  final String userId;
  const FriendRemoveEvent({required this.userId});
  FriendRemoveEvent.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] as String;
}

class ConversationUpdateEvent {
  final String id;
  final String? name;
  const ConversationUpdateEvent({required this.id, this.name});
  ConversationUpdateEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String?;
}

class ConversationDeleteEvent {
  final String id;
  const ConversationDeleteEvent({required this.id});
  ConversationDeleteEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String;
}

class ConversationMemberAddEvent {
  final String conversationId;
  final String userId;
  final String memberId;
  final String? username;
  final String? alias;
  final String? avatar;
  final String? banner;
  final int? statusId;
  final GatewayUser? user;
  const ConversationMemberAddEvent({
    required this.conversationId,
    required this.userId,
    required this.memberId,
    this.username,
    this.alias,
    this.avatar,
    this.banner,
    this.statusId,
    this.user,
  });
  ConversationMemberAddEvent.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        userId = j['user_id'] as String,
        memberId = j['member_id'] as String,
        username = j['username'] as String?,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?,
        statusId = j['status_id'] as int?,
        user = j['user'] != null
            ? GatewayUser.fromJson(j['user'] as Map<String, dynamic>)
            : null;
}

class ConversationMemberRemoveEvent {
  final String conversationId;
  final String userId;
  const ConversationMemberRemoveEvent(
      {required this.conversationId, required this.userId});
  ConversationMemberRemoveEvent.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        userId = j['user_id'] as String;
}

class DMMessageDeleteEvent {
  final String id;
  final String conversationId;
  const DMMessageDeleteEvent({required this.id, required this.conversationId});
  DMMessageDeleteEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        conversationId = j['conversation_id'] as String;
}

class UserMeResult {
  final String id;
  final String username;
  final String email;
  final String password;
  final String? phone;

  final bool? emailVerified;
  final String? alias;
  final String? avatar;
  final String? banner;
  final String custom;
  final UserStatus statusId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const UserMeResult({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.phone,
    this.emailVerified,
    this.alias,
    this.avatar,
    this.banner,
    required this.custom,
    required this.statusId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  UserMeResult.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        email = j['email'] as String,
        password = j['password'] as String,
        phone = j['phone'] as String?,
        username = j['username'] as String,
        emailVerified = j['email_verified'] as bool?,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?,
        custom = j['custom'] as String? ?? '',
        statusId = UserStatus.fromInt(j['status_id'] as int? ?? 0),
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

// ---------------------------------------------------------------------------
// Sealed GatewayEventPayload union
// ---------------------------------------------------------------------------

sealed class GatewayEventPayload {
  const GatewayEventPayload();
}

class ReadyEvent extends GatewayEventPayload {
  final GatewayReadyData data;
  const ReadyEvent(this.data);
}

class SpaceCreateEvent extends GatewayEventPayload {
  final GatewaySpaceCreatePayload data;
  const SpaceCreateEvent(this.data);
}

class SpaceUpdateEvent extends GatewayEventPayload {
  final GatewaySpace data;
  const SpaceUpdateEvent(this.data);
}

class SpaceDeletedEvent extends GatewayEventPayload {
  final SpaceDeleteEvent data;
  const SpaceDeletedEvent(this.data);
}

class RoomCreateEvent extends GatewayEventPayload {
  final GatewayRoom data;
  const RoomCreateEvent(this.data);
}

class RoomUpdateEvent extends GatewayEventPayload {
  final GatewayRoom data;
  const RoomUpdateEvent(this.data);
}

class RoomDeletedEvent extends GatewayEventPayload {
  final RoomDeleteEvent data;
  const RoomDeletedEvent(this.data);
}

class RoomOverwriteUpdateEvent extends GatewayEventPayload {
  final GatewayRoomOverwrite data;
  const RoomOverwriteUpdateEvent(this.data);
}

class RoomOverwriteDeletedEvent extends GatewayEventPayload {
  final OverwriteDeleteEvent data;
  const RoomOverwriteDeletedEvent(this.data);
}

class MessageCreateEvent extends GatewayEventPayload {
  final GatewayMessage data;
  const MessageCreateEvent(this.data);
}

class MessageUpdateEvent extends GatewayEventPayload {
  final GatewayMessage data;
  const MessageUpdateEvent(this.data);
}

class MessageDeletedEvent extends GatewayEventPayload {
  final GatewayMessageDelete data;
  const MessageDeletedEvent(this.data);
}

class MentionCreatedEvent extends GatewayEventPayload {
  final MentionCreateEvent data;
  const MentionCreatedEvent(this.data);
}

class UserUpdatedEvent extends GatewayEventPayload {
  final UserUpdateEvent data;
  const UserUpdatedEvent(this.data);
}

class UserStatusUpdatedEvent extends GatewayEventPayload {
  final GatewayUserStatusUpdate data;
  const UserStatusUpdatedEvent(this.data);
}

class VoiceStateUpdatedEvent extends GatewayEventPayload {
  final VoiceStateEvent data;
  const VoiceStateUpdatedEvent(this.data);
}

class VoiceJoinedPayloadEvent extends GatewayEventPayload {
  final VoiceJoinedEvent data;
  const VoiceJoinedPayloadEvent(this.data);
}

class WebRTCIceCandidateEvent extends GatewayEventPayload {
  final WebRTCEvent data;
  const WebRTCIceCandidateEvent(this.data);
}

class WebRTCRenegotiateEvent extends GatewayEventPayload {
  final WebRTCEvent data;
  const WebRTCRenegotiateEvent(this.data);
}

class WebRTCRenegotiateAnswerEvent extends GatewayEventPayload {
  final WebRTCEvent data;
  const WebRTCRenegotiateAnswerEvent(this.data);
}

class RoleCreatedEvent extends GatewayEventPayload {
  final GatewayRole data;
  const RoleCreatedEvent(this.data);
}

class RoleUpdatedEvent extends GatewayEventPayload {
  final GatewayRole data;
  const RoleUpdatedEvent(this.data);
}

class RoleDeletedEvent extends GatewayEventPayload {
  final RoleDeleteEvent data;
  const RoleDeletedEvent(this.data);
}

class MemberRoleAddedEvent extends GatewayEventPayload {
  final MemberRoleEvent data;
  const MemberRoleAddedEvent(this.data);
}

class MemberRoleRemovedEvent extends GatewayEventPayload {
  final MemberRoleEvent data;
  const MemberRoleRemovedEvent(this.data);
}

class SpaceMemberAddedEvent extends GatewayEventPayload {
  final SpaceMemberEvent data;
  const SpaceMemberAddedEvent(this.data);
}

class SpaceMemberRemovedEvent extends GatewayEventPayload {
  final SpaceMemberEvent data;
  const SpaceMemberRemovedEvent(this.data);
}

class GuildMemberAddedEvent extends GatewayEventPayload {
  final GuildMemberAddEvent data;
  const GuildMemberAddedEvent(this.data);
}

class GuildMemberRemovedEvent extends GatewayEventPayload {
  final GuildMemberRemoveEvent data;
  const GuildMemberRemovedEvent(this.data);
}

class SpaceEmojiCreatedEvent extends GatewayEventPayload {
  final SpaceEmoji data;
  const SpaceEmojiCreatedEvent(this.data);
}

class SpaceEmojiUpdatedEvent extends GatewayEventPayload {
  final SpaceEmoji data;
  const SpaceEmojiUpdatedEvent(this.data);
}

class SpaceEmojiDeletedEvent extends GatewayEventPayload {
  final SpaceAssetDeleteEvent data;
  const SpaceEmojiDeletedEvent(this.data);
}

class SpaceStickerCreatedEvent extends GatewayEventPayload {
  final SpaceSticker data;
  const SpaceStickerCreatedEvent(this.data);
}

class SpaceStickerUpdatedEvent extends GatewayEventPayload {
  final SpaceSticker data;
  const SpaceStickerUpdatedEvent(this.data);
}

class SpaceStickerDeletedEvent extends GatewayEventPayload {
  final SpaceAssetDeleteEvent data;
  const SpaceStickerDeletedEvent(this.data);
}

class ReactionAddedEvent extends GatewayEventPayload {
  final ReactionEvent data;
  const ReactionAddedEvent(this.data);
}

class ReactionRemovedEvent extends GatewayEventPayload {
  final ReactionRemoveEvent data;
  const ReactionRemovedEvent(this.data);
}

class FriendRequestCreatedEvent extends GatewayEventPayload {
  final FriendRequest data;
  const FriendRequestCreatedEvent(this.data);
}

class FriendRequestAcceptedEvent extends GatewayEventPayload {
  final Friend data;
  const FriendRequestAcceptedEvent(this.data);
}

class FriendRequestRejectedEvent extends GatewayEventPayload {
  final FriendRequestRejectEvent data;
  const FriendRequestRejectedEvent(this.data);
}

class FriendRemovedEvent extends GatewayEventPayload {
  final FriendRemoveEvent data;
  const FriendRemovedEvent(this.data);
}

class ConversationCreatedEvent extends GatewayEventPayload {
  final Conversation data;
  const ConversationCreatedEvent(this.data);
}

class ConversationUpdatedEvent extends GatewayEventPayload {
  final ConversationUpdateEvent data;
  const ConversationUpdatedEvent(this.data);
}

class ConversationDeletedEvent extends GatewayEventPayload {
  final ConversationDeleteEvent data;
  const ConversationDeletedEvent(this.data);
}

class ConversationMemberAddedEvent extends GatewayEventPayload {
  final ConversationMemberAddEvent data;
  const ConversationMemberAddedEvent(this.data);
}

class ConversationMemberRemovedEvent extends GatewayEventPayload {
  final ConversationMemberRemoveEvent data;
  const ConversationMemberRemovedEvent(this.data);
}

class DMMessageCreatedEvent extends GatewayEventPayload {
  final DirectMessage data;
  const DMMessageCreatedEvent(this.data);
}

class DMMessageUpdatedEvent extends GatewayEventPayload {
  final DirectMessage data;
  const DMMessageUpdatedEvent(this.data);
}

class DMMessageDeletedEvent extends GatewayEventPayload {
  final DMMessageDeleteEvent data;
  const DMMessageDeletedEvent(this.data);
}

class DMReactionAddedEvent extends GatewayEventPayload {
  final ReactionEvent data;
  const DMReactionAddedEvent(this.data);
}

class DMReactionRemovedEvent extends GatewayEventPayload {
  final ReactionRemoveEvent data;
  const DMReactionRemovedEvent(this.data);
}

class TypingStartedEvent extends GatewayEventPayload {
  final TypingEvent data;
  const TypingStartedEvent(this.data);
}

class DMTypingStartedEvent extends GatewayEventPayload {
  final DMTypingEvent data;
  const DMTypingStartedEvent(this.data);
}

class CallIncomingPayloadEvent extends GatewayEventPayload {
  final CallIncomingEvent data;
  const CallIncomingPayloadEvent(this.data);
}

class CallAcceptedEvent extends GatewayEventPayload {
  final CallResponseEvent data;
  const CallAcceptedEvent(this.data);
}

class CallDeclinedEvent extends GatewayEventPayload {
  final CallResponseEvent data;
  const CallDeclinedEvent(this.data);
}

class CallEndedPayloadEvent extends GatewayEventPayload {
  final CallEndedEvent data;
  const CallEndedPayloadEvent(this.data);
}

class UnknownEvent extends GatewayEventPayload {
  final String type;
  final Map<String, dynamic>? rawData;
  const UnknownEvent(this.type, this.rawData);
}
