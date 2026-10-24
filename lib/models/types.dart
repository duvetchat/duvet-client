import 'dart:convert' show jsonDecode;

import 'package:duvet_client/utils/util.dart';
part 'gateway_envelope.dart';
part 'rest_types.dart';

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

  /// A room's or conversation's notice that its author pinned the message it
  /// references; no content.
  static const pinNotice = MessageType(2);
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

  /// A video's media type, when known: video/* plays as a file, text/html is
  /// a player page.
  final String? contentType;

  const EmbedMedia(
      {required this.url, this.width, this.height, this.contentType});

  EmbedMedia.fromJson(Map<String, dynamic> j)
      : url = j['url'] as String,
        width = j['width'] as int?,
        height = j['height'] as int?,
        contentType = j['content_type'] as String?;

  Map<String, dynamic> toJson() => {
        'url': url,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (contentType != null) 'content_type': contentType,
      };
}

class EmbedFooter {
  final String text;
  final String? iconUrl;

  const EmbedFooter({required this.text, this.iconUrl});

  EmbedFooter.fromJson(Map<String, dynamic> j)
      : text = j['text'] as String,
        iconUrl = j['icon_url'] as String?;

  Map<String, dynamic> toJson() => {
        'text': text,
        if (iconUrl != null) 'icon_url': iconUrl,
      };
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

  Map<String, dynamic> toJson() => {
        'name': name,
        if (url != null) 'url': url,
        if (iconUrl != null) 'icon_url': iconUrl,
      };
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

  Map<String, dynamic> toJson() =>
      {'name': name, 'value': value, 'inline': inline};
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

  Map<String, dynamic> toJson() => {
        if (colorFrom != null) 'color_from': colorFrom,
        if (colorVia != null) 'color_via': colorVia,
        if (colorTo != null) 'color_to': colorTo,
      };
}

/// The values [Embed.type] takes.
abstract final class EmbedType {
  static const rich = 'rich';
  static const video = 'video';
  static const gifv = 'gifv';
  static const image = 'image';
  static const audio = 'audio';
  static const sticker = 'sticker';
}

class Embed {
  final String? type;
  final String? provider;
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
    this.provider,
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
        provider = j['provider'] as String?,
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

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        if (provider != null) 'provider': provider,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
        if (timestamp != null) 'timestamp': timestamp,
        if (color != null) 'color': color!.toJson(),
        if (footer != null) 'footer': footer!.toJson(),
        if (image != null) 'image': image!.toJson(),
        if (thumbnail != null) 'thumbnail': thumbnail!.toJson(),
        if (video != null) 'video': video!.toJson(),
        if (author != null) 'author': author!.toJson(),
        if (fields != null) 'fields': fields!.map((f) => f.toJson()).toList(),
      };
}

// ---------------------------------------------------------------------------
// Attachment
// ---------------------------------------------------------------------------

/// A file: one sent with a message, or one of a user's or a space's files
/// (their attachment lists).
class Attachment {
  final String id;
  final String? messageId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final bool? deleted;
  final bool? pending;
  final String? url;

  const Attachment({
    required this.id,
    this.messageId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    this.width,
    this.height,
    required this.createdAt,
    this.deletedAt,
    this.deleted,
    this.pending,
    this.url,
  });

  Attachment.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        messageId = j['message_id'] as String?,
        filename = j['filename'] as String,
        contentType = j['content_type'] as String,
        sizeBytes = j['size_bytes'] as int,
        width = j['width'] as int?,
        height = j['height'] as int?,
        createdAt = DateTime.parse(j['created_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null,
        deleted = j['deleted'] as bool?,
        pending = j['pending'] as bool?,
        url = j['url'] as String?;
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

/// What a new message says about the mentions it makes beyond the users its
/// text names (`allowed_mentions`).
class AllowedMentions {
  /// Whether a reply mentions the author of the message it replies to. A
  /// reply sent without [AllowedMentions] does; false sends it without
  /// notifying them. The API ignores it for a message that isn't a reply.
  final bool repliedUser;

  const AllowedMentions({required this.repliedUser});

  Map<String, dynamic> toJson() => {'replied_user': repliedUser};
}

class ReferencedMessage {
  final int? type;
  final String? messageId;
  final String? roomId;
  final String? spaceId;
  final String? content;
  final String? authorId;
  final String? authorName;
  final String? authorAvatar;
  final DateTime? createdAt;

  /// Whether the reply mentions the author of the message it replies to: it
  /// was sent without [AllowedMentions] or with [AllowedMentions.repliedUser],
  /// that message is someone else's (not a webhook's, nor a pin notice), and
  /// they could see the reply then. It stays once that message is deleted.
  /// False from an API from before it.
  final bool mentionAuthor;

  const ReferencedMessage({
    this.type,
    this.messageId,
    this.roomId,
    this.spaceId,
    this.content,
    this.authorId,
    this.authorName,
    this.authorAvatar,
    this.createdAt,
    this.mentionAuthor = false,
  });

  ReferencedMessage.fromJson(Map<String, dynamic> j)
      : type = j['type'] as int?,
        messageId = j['message_id'] as String?,
        roomId = j['room_id'] as String?,
        spaceId = j['space_id'] as String?,
        content = j['content'] as String?,
        authorId = j['author_id'] as String?,
        authorName = j['author_name'] as String?,
        authorAvatar = j['author_avatar'] as String?,
        createdAt = j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String)
            : null,
        mentionAuthor = j['mention_author'] as bool? ?? false;
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

/// The bits of [GatewayMessage.flags].
abstract final class MessageFlag {
  /// A bot's response to an interaction, or a follow-up, that only the person
  /// who used the interaction sees: it reaches their sessions alone, as
  /// MESSAGE_CREATE, MESSAGE_UPDATE and MESSAGE_DELETE, and isn't one of the
  /// room's messages (no history, search, pins, reactions or replies). The
  /// API keeps it while an interaction's token can reach it (15 minutes), and
  /// only that token edits or deletes it.
  static const ephemeral = 1 << 6;

  /// A bot's deferred response to an interaction, which it completes by
  /// editing the message.
  static const loading = 1 << 7;

  /// The components are the whole message: it has no content, embeds or
  /// files of its own.
  static const isComponentsV2 = 1 << 15;
}

/// What a message a bot sends for an interaction says about it.
class InteractionMetadata {
  final String id;

  /// 2 for a command, 3 for a component.
  final int type;

  /// Who used it, as they were when the message was made.
  final InteractionUser user;

  /// The message whose component was used, for a component's interaction.
  final String? interactedMessageId;

  /// The interaction's first response, on its follow-ups.
  final String? originalResponseMessageId;

  /// The command's name, for a command's interaction.
  final String? name;

  const InteractionMetadata({
    required this.id,
    required this.type,
    required this.user,
    this.interactedMessageId,
    this.originalResponseMessageId,
    this.name,
  });

  InteractionMetadata.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        type = j['type'] as int,
        user = InteractionUser.fromJson(j['user'] as Map<String, dynamic>),
        interactedMessageId = j['interacted_message_id'] as String?,
        originalResponseMessageId =
            j['original_response_message_id'] as String?,
        name = j['name'] as String?;
}

/// The short form of a user that interactions and command lists carry.
class InteractionUser {
  final String id;
  final String username;
  final String? alias;
  final String? avatar;

  const InteractionUser(
      {required this.id, required this.username, this.alias, this.avatar});

  InteractionUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?;
}

class GatewayMessage {
  final String id;
  final String roomId;

  /// Null for webhook messages, which carry [webhookId] instead.
  final String? authorId;
  final String? webhookId;
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

  /// When it was pinned; null while it isn't. Events that create or edit a
  /// message leave it out.
  final DateTime? pinnedAt;

  /// [MessageFlag] bits.
  final int flags;

  /// The message's components, as the API sends them.
  final List<Map<String, dynamic>>? components;

  /// Set on the messages a bot sends for an interaction.
  final InteractionMetadata? interactionMetadata;

  const GatewayMessage({
    required this.id,
    required this.roomId,
    this.authorId,
    this.webhookId,
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
    this.pinnedAt,
    this.flags = 0,
    this.components,
    this.interactionMetadata,
  });

  GatewayMessage.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        roomId = j['room_id'] as String,
        authorId = j['author_id'] as String?,
        webhookId = j['webhook_id'] as String?,
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
        stickerAttachmentId = j['sticker_attachment_id'] as String?,
        pinnedAt = _parseDate(j['pinned_at']),
        flags = j['flags'] as int? ?? 0,
        components = (j['components'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList(),
        interactionMetadata = j['interaction_metadata'] != null
            ? InteractionMetadata.fromJson(
                j['interaction_metadata'] as Map<String, dynamic>)
            : null;
}

DateTime? _parseDate(Object? v) =>
    v != null ? DateTime.parse(v as String) : null;

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
  final int flags;
  final int badges;
  final bool isBot;
  final UserStatus statusId;

  /// The status the user chose ([UserStatus.online] or [UserStatus.dnd]):
  /// only on their own user, in READY. Null elsewhere, for a bot, and from a
  /// gateway from before statuses.
  final UserStatus? status;
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
    this.flags = 0,
    this.badges = 0,
    this.isBot = false,
    required this.statusId,
    this.status,
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
        flags = j['flags'] as int? ?? 0,
        badges = j['badges'] as int? ?? 0,
        isBot = j['is_bot'] as bool? ?? false,
        statusId = UserStatus.fromInt(j['status_id'] as int? ?? 0),
        status = switch (j['status'] as int?) {
          final s? => UserStatus.fromInt(s),
          null => null,
        },
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = j['deleted_at'] != null
            ? DateTime.parse(j['deleted_at'] as String)
            : null;
}

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

/// Someone in a space's voice room, as SPACE_CREATE lists them.
class GatewayVoiceState {
  final String roomId;
  final String userId;
  final bool muted;
  final bool deafened;
  final bool screenSharing;

  /// Their camera is on.
  final bool camera;

  /// Orders this state among VOICE_STATE_UPDATEs: see [VoiceStateEvent].
  final int version;

  const GatewayVoiceState({
    required this.roomId,
    required this.userId,
    this.muted = false,
    this.deafened = false,
    this.screenSharing = false,
    this.camera = false,
    this.version = 0,
  });

  GatewayVoiceState.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        userId = j['user_id'] as String,
        muted = j['muted'] as bool? ?? false,
        deafened = j['deafened'] as bool? ?? false,
        screenSharing = j['screen_sharing'] as bool? ?? false,
        camera = j['camera'] as bool? ?? false,
        version = j['version'] as int? ?? 0;
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
  final String? spaceId;
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
    this.spaceId,
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
        spaceId = j['space_id'] as String?,
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
  final String? icon;
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
    this.icon,
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
        icon = j['icon'] as String?,
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

/// The values of [Conversation.type].
final class ConversationType extends EnumLike<int, ConversationType> {
  static const dm = ConversationType(1);
  static const group = ConversationType(2);
  const ConversationType(super.value);
}

/// The user that conversation members and DMs carry: the API's public user.
class ConversationUser {
  final String id;
  final String username;
  final String? alias;
  final String? avatar;
  final String? banner;
  final int? badges;
  final bool isBot;

  /// The bio, empty when there's none.
  final String custom;
  final int flags;
  final bool? emailVerified;

  /// When the account was made and last changed: null only in a user built
  /// without them, as the API always sends them.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// When the account was deleted; null while it isn't.
  final DateTime? deletedAt;

  const ConversationUser({
    required this.id,
    required this.username,
    this.alias,
    this.avatar,
    this.banner,
    this.badges,
    this.isBot = false,
    this.custom = '',
    this.flags = 0,
    this.emailVerified,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  ConversationUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?,
        badges = j['badges'] as int?,
        isBot = j['is_bot'] as bool? ?? false,
        custom = j['custom'] as String? ?? '',
        flags = j['flags'] as int? ?? 0,
        emailVerified = j['email_verified'] as bool?,
        createdAt = _parseDate(j['created_at']),
        updatedAt = _parseDate(j['updated_at']),
        deletedAt = _parseDate(j['deleted_at']);
}

class ConversationMember {
  final String id;
  final String conversationId;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null in the member that adding one answers when the conversation's list
  /// doesn't have them yet.
  final ConversationUser? user;

  const ConversationMember({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });

  ConversationMember.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        conversationId = j['conversation_id'] as String,
        userId = j['user_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        user = j['user'] != null
            ? ConversationUser.fromJson(j['user'] as Map<String, dynamic>)
            : null;
}

class Conversation {
  final String id;
  final ConversationType type;
  final String? name;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<ConversationMember> members;

  const Conversation({
    required this.id,
    required this.type,
    this.name,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.members,
  });

  Conversation.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        type = ConversationType(j['type'] as int),
        name = j['name'] as String?,
        ownerId = j['owner_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        deletedAt = _parseDate(j['deleted_at']),
        members = (j['members'] as List<dynamic>? ?? [])
            .map((e) => ConversationMember.fromJson(e as Map<String, dynamic>))
            .toList();
}

class DirectMessage {
  final String id;
  final String? conversationId;

  /// Always set for a DM: the API's type allows null only because webhook
  /// room messages share the table.
  final String authorId;
  final String? content;
  final MessageType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? nonce;
  final ConversationUser? user;
  final ReferencedMessage? referencedMessage;
  final List<Embed>? embeds;
  final List<Attachment>? attachments;
  final List<MessageReaction>? reactions;
  final String? stickerAttachmentId;

  /// When it was pinned; null while it isn't. Events that create or edit a
  /// message leave it out.
  final DateTime? pinnedAt;

  const DirectMessage({
    required this.id,
    this.conversationId,
    required this.authorId,
    this.content,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.nonce,
    this.user,
    this.referencedMessage,
    this.embeds,
    this.attachments,
    this.reactions,
    this.stickerAttachmentId,
    this.pinnedAt,
  });

  DirectMessage.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        conversationId = j['conversation_id'] as String?,
        authorId = j['author_id'] as String,
        content = j['content'] as String?,
        type = MessageType.fromInt(j['type'] as int? ?? 0),
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        nonce = j['nonce'] as String?,
        user = j['user'] != null
            ? ConversationUser.fromJson(j['user'] as Map<String, dynamic>)
            : null,
        referencedMessage = j['referenced_message'] != null
            ? ReferencedMessage.fromJson(
                j['referenced_message'] as Map<String, dynamic>)
            : null,
        embeds = (j['embeds'] as List<dynamic>?)
            ?.map((e) => Embed.fromJson(e as Map<String, dynamic>))
            .toList(),
        attachments = (j['attachments'] as List<dynamic>?)
            ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactions = (j['reactions'] as List<dynamic>?)
            ?.map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        stickerAttachmentId = j['sticker_attachment_id'] as String?,
        pinnedAt = _parseDate(j['pinned_at']);
}

// ---------------------------------------------------------------------------
// Friends
// ---------------------------------------------------------------------------

/// A friend request, with the other user's details. The request that
/// `sendFriendRequest` answers is the bare request, without them.
class FriendRequest {
  final String id;
  final String senderId;
  final String recipientId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userUsername;
  final String? userAlias;
  final String? userAvatar;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    required this.updatedAt,
    this.userUsername,
    this.userAlias,
    this.userAvatar,
  });

  FriendRequest.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        senderId = j['sender_id'] as String,
        recipientId = j['recipient_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        userUsername = j['user_username'] as String?,
        userAlias = j['user_alias'] as String?,
        userAvatar = j['user_avatar'] as String?;
}

class Friend {
  final String id;
  final String requestId;
  final String senderId;
  final String recipientId;
  final String userUsername;
  final String? userAlias;
  final String? userAvatar;

  /// The friend's status as the list was read, whether or not a space is
  /// shared with them; USER_STATUS_UPDATE carries its changes. Null from an
  /// API before friends' statuses.
  final UserStatus? statusId;

  const Friend({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.recipientId,
    required this.userUsername,
    this.userAlias,
    this.userAvatar,
    this.statusId,
  });

  Friend.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        requestId = j['request_id'] as String,
        senderId = j['sender_id'] as String,
        recipientId = j['recipient_id'] as String,
        userUsername = j['user_username'] as String,
        userAlias = j['user_alias'] as String?,
        userAvatar = j['user_avatar'] as String?,
        statusId = switch (j['status_id'] as int?) {
          final s? => UserStatus.fromInt(s),
          null => null,
        };
}

/// FRIEND_REQUEST_CREATE: the request, with its sender's details.
class FriendRequestCreateEvent {
  final String id;
  final String senderId;
  final String username;
  final String? alias;
  final String? avatar;

  const FriendRequestCreateEvent({
    required this.id,
    required this.senderId,
    required this.username,
    this.alias,
    this.avatar,
  });

  FriendRequestCreateEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        senderId = j['sender_id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?;
}

/// FRIEND_REQUEST_ACCEPT: the friendship the request made.
class FriendRequestAcceptEvent {
  final String id;
  final String requestId;
  final String senderId;
  final String recipientId;
  final GatewayUser? user;

  const FriendRequestAcceptEvent({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.recipientId,
    this.user,
  });

  FriendRequestAcceptEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        requestId = j['request_id'] as String,
        senderId = j['sender_id'] as String,
        recipientId = j['recipient_id'] as String,
        user = j['user'] != null
            ? GatewayUser.fromJson(j['user'] as Map<String, dynamic>)
            : null;
}

// ---------------------------------------------------------------------------
// Gateway ready payload
// ---------------------------------------------------------------------------

/// A voice state in a conversation's call: it has no room.
class CallVoiceState {
  final String userId;
  final bool muted;
  final bool deafened;
  final bool screenSharing;

  /// Their camera is on.
  final bool camera;
  final int version;

  const CallVoiceState({
    required this.userId,
    this.muted = false,
    this.deafened = false,
    this.screenSharing = false,
    this.camera = false,
    this.version = 0,
  });

  CallVoiceState.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] as String,
        muted = j['muted'] as bool? ?? false,
        deafened = j['deafened'] as bool? ?? false,
        screenSharing = j['screen_sharing'] as bool? ?? false,
        camera = j['camera'] as bool? ?? false,
        version = j['version'] as int? ?? 0;
}

/// A STUN or TURN server for a peer connection, as READY hands them out: the
/// STUN server, and the TURN relay with credentials of the user's own (the
/// TURN REST API's: a username `<expiry>:<user_id>` and its password).
class IceServer {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServer({required this.urls, this.username, this.credential});

  /// `urls` may be one URL or a list; a credential that isn't a password
  /// (an OAuth one) is left out.
  IceServer.fromJson(Map<String, dynamic> j)
      : urls = switch (j['urls']) {
          final String url => [url],
          final List<dynamic> list => [for (final u in list) u as String],
          _ => const [],
        },
        username = j['username'] as String?,
        credential =
            j['credential'] is String ? j['credential'] as String : null;

  /// As a peer connection's configuration takes it.
  Map<String, dynamic> toJson() => {
        'urls': urls,
        if (username != null) 'username': username,
        if (credential != null) 'credential': credential,
      };
}

class GatewayReadyActiveCall {
  final String conversationId;
  final String initiatorId;
  final List<CallVoiceState>? voiceStates;

  const GatewayReadyActiveCall({
    required this.conversationId,
    required this.initiatorId,
    this.voiceStates,
  });

  GatewayReadyActiveCall.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        initiatorId = j['initiator_id'] as String,
        voiceStates = (j['voice_states'] as List<dynamic>?)
            ?.map((e) => CallVoiceState.fromJson(e as Map<String, dynamic>))
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

  /// The STUN and TURN servers for voice and calls; none in a bot's READY.
  final List<IceServer> iceServers;

  const GatewayReadyData({
    required this.user,
    required this.sessionToken,
    this.unreadRooms,
    this.lastReadRooms,
    this.lastMsgRooms,
    this.unreadConvs,
    this.activeCalls,
    this.spaces,
    this.iceServers = const [],
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
            .toList(),
        iceServers = [
          for (final s in j['ice_servers'] as List<dynamic>? ?? const [])
            IceServer.fromJson(s as Map<String, dynamic>),
        ];
}

// ---------------------------------------------------------------------------
// Activities
// ---------------------------------------------------------------------------

/// The values [Activity.type] takes.
abstract final class ActivityType {
  /// A game or another app: the gateway leaves the type out.
  static const playing = 0;

  /// Music. Spotify's, as the desktop app shares it, has the song in
  /// [Activity.details], the artist in [Activity.state], the album in
  /// [ActivityAssets.largeText], and the song's start and end.
  static const listening = 2;
}

/// When an activity started and when it ends, in Unix milliseconds.
class ActivityTimestamps {
  final int? start;
  final int? end;

  const ActivityTimestamps({this.start, this.end});

  ActivityTimestamps.fromJson(Map<String, dynamic> j)
      : start = j['start'] as int?,
        end = j['end'] as int?;
}

/// An activity's images (a URL, or a small data URI) and their texts.
class ActivityAssets {
  final String? largeImage;
  final String? largeText;
  final String? smallImage;
  final String? smallText;

  const ActivityAssets(
      {this.largeImage, this.largeText, this.smallImage, this.smallText});

  ActivityAssets.fromJson(Map<String, dynamic> j)
      : largeImage = j['large_image'] as String?,
        largeText = j['large_text'] as String?,
        smallImage = j['small_image'] as String?,
        smallText = j['small_text'] as String?;
}

/// What a user is doing, as an app of theirs tells the gateway
/// (ACTIVITY_UPDATE): a game, or the song Spotify plays.
class Activity {
  /// An [ActivityType].
  final int type;
  final String name;
  final String? details;
  final String? state;
  final ActivityTimestamps? timestamps;
  final ActivityAssets? assets;

  const Activity({
    this.type = ActivityType.playing,
    required this.name,
    this.details,
    this.state,
    this.timestamps,
    this.assets,
  });

  Activity.fromJson(Map<String, dynamic> j)
      : type = j['type'] as int? ?? ActivityType.playing,
        name = j['name'] as String,
        details = j['details'] as String?,
        state = j['state'] as String?,
        timestamps = j['timestamps'] != null
            ? ActivityTimestamps.fromJson(
                j['timestamps'] as Map<String, dynamic>)
            : null,
        assets = j['assets'] != null
            ? ActivityAssets.fromJson(j['assets'] as Map<String, dynamic>)
            : null;
}

List<Activity> _activities(Object? list) => [
      for (final a in list as List<dynamic>? ?? const [])
        Activity.fromJson(a as Map<String, dynamic>),
    ];

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

  /// The members who aren't offline as the event is sent, by user ID: the
  /// presence to start from, which USER_STATUS_UPDATE keeps current.
  final Map<String, UserStatus> memberStatuses;

  /// What the space's members connected now are doing, by user ID: the
  /// activities to start from, which USER_ACTIVITY_UPDATE keeps current.
  /// None in a bot's.
  final Map<String, List<Activity>> activities;

  const GatewaySpaceCreatePayload({
    required this.space,
    required this.rooms,
    required this.rolesPermissions,
    required this.memberRoles,
    this.overwrites,
    required this.ownerId,
    this.voiceStates,
    this.memberStatuses = const {},
    this.activities = const {},
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
            .toList(),
        memberStatuses = (j['member_statuses'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, UserStatus.fromInt(v as int))),
        activities = (j['activities'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, _activities(v)));
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

  /// The space this status is for: a bot also has one per space, online
  /// while the shard that holds the space is connected, which comes first in
  /// that space (as the desktop app reads them). Null for a status that holds
  /// everywhere: a person's, or a bot's overall one.
  final String? spaceId;
  const GatewayUserStatusUpdate(
      {required this.userId, required this.statusId, this.spaceId});

  GatewayUserStatusUpdate.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] as String,
        statusId = UserStatus.fromInt(j['status_id'] as int),
        spaceId = j['space_id'] as String?;
}

/// MESSAGE_PIN_UPDATE: a message of a room was pinned or unpinned. A pin also
/// posts the room's pin notice, which comes as a MESSAGE_CREATE of type
/// [MessageType.pinNotice].
class MessagePinUpdateEvent {
  final String id;
  final String roomId;

  /// When it was pinned; null once it's unpinned.
  final DateTime? pinnedAt;
  const MessagePinUpdateEvent(
      {required this.id, required this.roomId, this.pinnedAt});
  MessagePinUpdateEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        roomId = j['room_id'] as String,
        pinnedAt = _parseDate(j['pinned_at']);
}

/// DM_MESSAGE_PIN_UPDATE: a message of a conversation was pinned or unpinned.
/// A pin also posts the conversation's pin notice, which comes as a
/// DM_MESSAGE_CREATE of type [MessageType.pinNotice].
class DMMessagePinUpdateEvent {
  final String id;
  final String conversationId;

  /// When it was pinned; null once it's unpinned.
  final DateTime? pinnedAt;
  const DMMessagePinUpdateEvent(
      {required this.id, required this.conversationId, this.pinnedAt});
  DMMessagePinUpdateEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        conversationId = j['conversation_id'] as String,
        pinnedAt = _parseDate(j['pinned_at']);
}

/// ROOM_REORDER: every room of a space, with its position and parent, after
/// one of them moved.
class RoomReorderEvent {
  final List<GatewayRoom> rooms;
  const RoomReorderEvent({required this.rooms});
  RoomReorderEvent.fromJson(Map<String, dynamic> j)
      : rooms = [
          for (final r in j['rooms'] as List<dynamic>? ?? const [])
            GatewayRoom.fromJson(r as Map<String, dynamic>),
        ];
}

/// USER_ACTIVITY_UPDATE: a user's activities changed. It comes once for each
/// space shared with them. A user who goes offline loses theirs without one:
/// their USER_STATUS_UPDATE to [UserStatus.offline] says so.
class UserActivityUpdateEvent {
  final String userId;

  /// Empty when they cleared them.
  final List<Activity> activities;
  const UserActivityUpdateEvent(
      {required this.userId, this.activities = const []});
  UserActivityUpdateEvent.fromJson(Map<String, dynamic> j)
      : userId = j['user_id'] as String,
        activities = _activities(j['activities']);
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

/// MENTION_CREATE: the user was mentioned in a message of a room.
class MentionCreateEvent {
  final String messageId;
  final String roomId;

  /// Who wrote the message.
  final String authorId;

  /// Never set by the API: a conversation's mentions come as
  /// DM_MENTION_CREATE ([DMMentionCreateEvent]).
  final String? conversationId;

  const MentionCreateEvent({
    required this.messageId,
    required this.roomId,
    required this.authorId,
    this.conversationId,
  });
  MentionCreateEvent.fromJson(Map<String, dynamic> j)
      : messageId = j['message_id'] as String,
        roomId = j['room_id'] as String,
        authorId = j['author_id'] as String,
        conversationId = j['conversation_id'] as String?;
}

/// DM_MENTION_CREATE: the user was mentioned in a message of a conversation.
class DMMentionCreateEvent {
  final String messageId;
  final String conversationId;

  /// Who wrote the message.
  final String authorId;

  const DMMentionCreateEvent({
    required this.messageId,
    required this.conversationId,
    required this.authorId,
  });
  DMMentionCreateEvent.fromJson(Map<String, dynamic> j)
      : messageId = j['message_id'] as String,
        conversationId = j['conversation_id'] as String,
        authorId = j['author_id'] as String;
}

class UserUpdateEvent {
  final String id;
  final String username;
  final String? alias;
  final String? avatar;
  final String? banner;

  /// The bio, empty when there's none. Null from an API from before bios,
  /// which leaves it out: the one known then stays.
  final String? custom;
  const UserUpdateEvent(
      {required this.id,
      required this.username,
      this.alias,
      this.avatar,
      this.banner,
      this.custom});
  UserUpdateEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?,
        custom = j['custom'] as String?;
}

/// VOICE_STATE_UPDATE: a user's whole voice state in a space's voice room or
/// a conversation's call (then [roomId] is the conversation's ID), or that
/// they left it ([joined] false).
///
/// [version] grows with every change in any room, and survives the gateway's
/// restarts: an update older than one already applied came late, and is
/// dropped ([VoiceStates] does).
class VoiceStateEvent {
  final String roomId;
  final String userId;
  final bool joined;
  final bool muted;
  final bool deafened;
  final bool screenSharing;

  /// Their camera is on.
  final bool camera;
  final int version;
  const VoiceStateEvent({
    required this.roomId,
    required this.userId,
    required this.joined,
    this.muted = false,
    this.deafened = false,
    this.screenSharing = false,
    this.camera = false,
    this.version = 0,
  });
  VoiceStateEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        userId = j['user_id'] as String,
        joined = j['joined'] as bool? ?? false,
        muted = j['muted'] as bool? ?? false,
        deafened = j['deafened'] as bool? ?? false,
        screenSharing = j['screen_sharing'] as bool? ?? false,
        camera = j['camera'] as bool? ?? false,
        version = j['version'] as int? ?? 0;
}

/// A WebRTC session description: an offer or an answer.
class SessionDescription {
  /// "offer", "pranswer", "answer" or "rollback".
  final String type;
  final String sdp;
  const SessionDescription({required this.type, required this.sdp});
  SessionDescription.fromJson(Map<String, dynamic> j)
      : type = j['type'] as String,
        sdp = j['sdp'] as String;

  Map<String, dynamic> toJson() => {'type': type, 'sdp': sdp};
}

/// An ICE candidate, as `RTCIceCandidateInit` (and pion's `ICECandidateInit`)
/// write it.
class IceCandidateInit {
  /// The `candidate:` attribute line.
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final String? usernameFragment;

  const IceCandidateInit({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    this.usernameFragment,
  });

  IceCandidateInit.fromJson(Map<String, dynamic> j)
      : candidate = j['candidate'] as String? ?? '',
        sdpMid = j['sdpMid'] as String?,
        sdpMLineIndex = j['sdpMLineIndex'] as int?,
        usernameFragment = j['usernameFragment'] as String?;

  Map<String, dynamic> toJson() => {
        'candidate': candidate,
        if (sdpMid != null) 'sdpMid': sdpMid,
        if (sdpMLineIndex != null) 'sdpMLineIndex': sdpMLineIndex,
        if (usernameFragment != null) 'usernameFragment': usernameFragment,
      };
}

/// VOICE_JOINED: the gateway's answer to joining a voice room or a call.
class VoiceJoinedEvent {
  final String roomId;
  final SessionDescription? answer;
  const VoiceJoinedEvent({required this.roomId, this.answer});
  VoiceJoinedEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        answer = j['answer'] != null
            ? SessionDescription.fromJson(j['answer'] as Map<String, dynamic>)
            : null;
}

/// WEBRTC_ICE_CANDIDATE: one of the gateway's ICE candidates for the peer
/// connection of a room or call.
class IceCandidateEvent {
  final String roomId;
  final IceCandidateInit candidate;
  const IceCandidateEvent({required this.roomId, required this.candidate});

  /// The gateway sends the candidate as a JSON string of its
  /// `ICECandidateInit`; an object, or a bare `candidate:` line, is taken too.
  IceCandidateEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        candidate = _candidate(j['candidate']);

  static IceCandidateInit _candidate(Object? raw) {
    if (raw is Map<String, dynamic>) return IceCandidateInit.fromJson(raw);
    final text = raw as String? ?? '';
    if (text.trimLeft().startsWith('{')) {
      try {
        return IceCandidateInit.fromJson(
            jsonDecode(text) as Map<String, dynamic>);
      } on FormatException {
        // Not JSON after all: the line itself.
      }
    }
    return IceCandidateInit(candidate: text);
  }
}

/// WEBRTC_RENEGOTIATE: the gateway's offer for a room's or call's peer
/// connection (other people's tracks come and go, or an ICE restart): the
/// client answers it with WEBRTC_ANSWER.
class RenegotiateOfferEvent {
  final String roomId;
  final SessionDescription offer;
  const RenegotiateOfferEvent({required this.roomId, required this.offer});
  RenegotiateOfferEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        offer = SessionDescription.fromJson(j['offer'] as Map<String, dynamic>);
}

/// WEBRTC_RENEGOTIATE_ANSWER: the gateway's answer to the client's own
/// renegotiation (WEBRTC_RENEGOTIATE_OFFER).
class RenegotiateAnswerEvent {
  final String roomId;
  final SessionDescription? answer;
  const RenegotiateAnswerEvent({required this.roomId, this.answer});
  RenegotiateAnswerEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        answer = j['answer'] != null
            ? SessionDescription.fromJson(j['answer'] as Map<String, dynamic>)
            : null;
}

/// VOICE_SESSION_REPLACED: this session is no longer in a room or call's
/// voice. Another device of the user's joined it ([reason] null), or the user
/// lost the right to be there ([reason] "permissions").
class VoiceSessionReplacedEvent {
  final String roomId;
  final String? reason;
  const VoiceSessionReplacedEvent({required this.roomId, this.reason});
  VoiceSessionReplacedEvent.fromJson(Map<String, dynamic> j)
      : roomId = j['room_id'] as String,
        reason = j['reason'] as String?;
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

  /// Null in MEMBER_ROLE_REMOVE, which doesn't carry it.
  final String? spaceId;
  const MemberRoleEvent(
      {required this.memberId, required this.roleId, this.spaceId});
  MemberRoleEvent.fromJson(Map<String, dynamic> j)
      : memberId = j['member_id'] as String,
        roleId = j['role_id'] as String,
        spaceId = j['space_id'] as String?;
}

/// SPACE_MEMBER_ADD and SPACE_MEMBER_REMOVE: someone joined or left a space.
class SpaceMemberEvent {
  final String memberId;
  final String spaceId;

  /// Who joined or left: both events carry it.
  final String? userId;

  /// SPACE_MEMBER_ADD's: the new member's status, as USER_STATUS_UPDATE would
  /// give it, which carries its changes from now on. Null in
  /// SPACE_MEMBER_REMOVE.
  final UserStatus? statusId;

  /// SPACE_MEMBER_ADD's: the new member's user, when the API has it.
  final GatewayUser? user;
  const SpaceMemberEvent({
    required this.memberId,
    required this.spaceId,
    this.userId,
    this.statusId,
    this.user,
  });
  SpaceMemberEvent.fromJson(Map<String, dynamic> j)
      : memberId = j['member_id'] as String,
        spaceId = j['space_id'] as String,
        userId = j['user_id'] as String?,
        statusId = switch (j['status_id'] as int?) {
          final s? => UserStatus.fromInt(s),
          null => null,
        },
        user = j['user'] != null
            ? GatewayUser.fromJson(j['user'] as Map<String, dynamic>)
            : null;
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
  const CallIncomingEvent({
    required this.conversationId,
    required this.initiatorId,
    required this.initiatorName,
    this.initiatorAvatar,
  });
  CallIncomingEvent.fromJson(Map<String, dynamic> j)
      : conversationId = j['conversation_id'] as String,
        initiatorId = j['initiator_id'] as String,
        initiatorName = j['initiator_name'] as String,
        initiatorAvatar = j['initiator_avatar'] as String?;
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

/// FRIEND_REQUEST_REJECT: the request, rejected by its recipient or cancelled
/// by its sender.
class FriendRequestRejectEvent {
  final String id;
  const FriendRequestRejectEvent({required this.id});
  FriendRequestRejectEvent.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String;
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

/// The user's own profile: the public user plus the fields hidden from
/// everyone else. The API doesn't send the email.
class UserMeResult {
  final String id;
  final String username;
  final bool emailVerified;
  final String? alias;
  final DateTime? birthdate;
  final String? phone;
  final String? avatar;
  final String? banner;
  final String custom;
  final int flags;
  final int badges;
  final bool isBot;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The status the user chose: [UserStatus.online] or [UserStatus.dnd]. Null
  /// for a bot, and from an API from before statuses.
  final UserStatus? status;

  const UserMeResult({
    required this.id,
    required this.username,
    required this.emailVerified,
    this.alias,
    this.birthdate,
    this.phone,
    this.avatar,
    this.banner,
    required this.custom,
    this.flags = 0,
    this.badges = 0,
    this.isBot = false,
    required this.createdAt,
    required this.updatedAt,
    this.status,
  });

  UserMeResult.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        username = j['username'] as String,
        emailVerified = j['email_verified'] as bool? ?? false,
        alias = j['alias'] as String?,
        birthdate = _parseDate(j['birthdate']),
        phone = j['phone'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?,
        custom = j['custom'] as String? ?? '',
        flags = j['flags'] as int? ?? 0,
        badges = j['badges'] as int? ?? 0,
        isBot = j['is_bot'] as bool? ?? false,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        status = switch (j['status'] as int?) {
          final s? => UserStatus.fromInt(s),
          null => null,
        };
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

class DMMentionCreatedEvent extends GatewayEventPayload {
  final DMMentionCreateEvent data;
  const DMMentionCreatedEvent(this.data);
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
  final IceCandidateEvent data;
  const WebRTCIceCandidateEvent(this.data);
}

class WebRTCRenegotiateEvent extends GatewayEventPayload {
  final RenegotiateOfferEvent data;
  const WebRTCRenegotiateEvent(this.data);
}

class WebRTCRenegotiateAnswerEvent extends GatewayEventPayload {
  final RenegotiateAnswerEvent data;
  const WebRTCRenegotiateAnswerEvent(this.data);
}

class VoiceSessionReplacedPayloadEvent extends GatewayEventPayload {
  final VoiceSessionReplacedEvent data;
  const VoiceSessionReplacedPayloadEvent(this.data);
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
  final FriendRequestCreateEvent data;
  const FriendRequestCreatedEvent(this.data);
}

class FriendRequestAcceptedEvent extends GatewayEventPayload {
  final FriendRequestAcceptEvent data;
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

class MessagePinUpdatedEvent extends GatewayEventPayload {
  final MessagePinUpdateEvent data;
  const MessagePinUpdatedEvent(this.data);
}

class DMMessagePinUpdatedEvent extends GatewayEventPayload {
  final DMMessagePinUpdateEvent data;
  const DMMessagePinUpdatedEvent(this.data);
}

/// RECORDING: someone is recording a voice message in a room, with what
/// TYPING carries. Like TYPING, it takes no sequence number, and a resume
/// doesn't replay it.
class RecordingStartedEvent extends GatewayEventPayload {
  final TypingEvent data;
  const RecordingStartedEvent(this.data);
}

/// DM_RECORDING: [RecordingStartedEvent] for a conversation.
class DMRecordingStartedEvent extends GatewayEventPayload {
  final DMTypingEvent data;
  const DMRecordingStartedEvent(this.data);
}

class RoomReorderedEvent extends GatewayEventPayload {
  final RoomReorderEvent data;
  const RoomReorderedEvent(this.data);
}

class UserActivityUpdatedEvent extends GatewayEventPayload {
  final UserActivityUpdateEvent data;
  const UserActivityUpdatedEvent(this.data);
}

/// TEAM_INVITE_CREATE: the user was invited to a developer team. The invite
/// is the one `listMyTeamInvites` lists, until it's accepted or declined.
class TeamInviteCreatedEvent extends GatewayEventPayload {
  final TeamInvite data;
  const TeamInviteCreatedEvent(this.data);
}

/// An event this package doesn't parse: its [type] and data as they came.
class UnknownEvent extends GatewayEventPayload {
  final String type;
  final Map<String, dynamic>? rawData;
  const UnknownEvent(this.type, this.rawData);
}
