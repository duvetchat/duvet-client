part of 'types.dart';

// ---------------------------------------------------------------------------
// Spaces
// ---------------------------------------------------------------------------

/// What creating a space answers: the space, and the rooms the API makes with
/// it (a text and a voice room). The gateway's SPACE_CREATE, with its roles
/// and members, follows.
class CreatedSpace {
  final GatewaySpace space;

  /// Its text room, then its voice room.
  final List<GatewayRoom> rooms;

  const CreatedSpace({required this.space, required this.rooms});

  CreatedSpace.fromJson(Map<String, dynamic> j)
      : space = GatewaySpace.fromJson(j['space'] as Map<String, dynamic>),
        rooms = [
          for (final key in const ['text_room', 'voice_room'])
            if (j[key] != null)
              GatewayRoom.fromJson(j[key] as Map<String, dynamic>),
        ];

  /// The space's ID.
  String get id => space.id;
}

// ---------------------------------------------------------------------------
// Space members
// ---------------------------------------------------------------------------

class SpaceMemberWithUser extends GatewayMember {
  final GatewayUser user;

  /// The position of the member's highest role: the members list's cursor,
  /// with the member's ID.
  final int? maxPos;

  const SpaceMemberWithUser({
    required super.id,
    required super.spaceId,
    required super.userId,
    super.alias,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
    required this.user,
    this.maxPos,
  });

  SpaceMemberWithUser.fromJson(super.j)
      : user = GatewayUser.fromJson(j['user'] as Map<String, dynamic>),
        maxPos = j['max_pos'] as int?,
        super.fromJson();
}

// ---------------------------------------------------------------------------
// Message search
// ---------------------------------------------------------------------------

/// A message search. The values of each list are alternatives; different
/// filters must all match. The API rejects (400) a search with neither text
/// nor a filter.
class MessageSearch {
  final String? query;
  final List<String> authorIds;
  final List<String> mentions;
  final List<String> roomIds;
  final List<String> has;

  /// Only the pinned messages (true) or only the others (false).
  final bool? pinned;
  final DateTime? before;
  final DateTime? after;

  /// The ID of the previous page's last message.
  final String? cursor;

  const MessageSearch({
    this.query,
    this.authorIds = const [],
    this.mentions = const [],
    this.roomIds = const [],
    this.has = const [],
    this.pinned,
    this.before,
    this.after,
    this.cursor,
  });

  /// The search's query parameters: each list's values repeat its key.
  Map<String, dynamic> toQueryParameters() => {
        if (query != null && query!.isNotEmpty) 'query': query,
        if (authorIds.isNotEmpty) 'author_id': authorIds,
        if (mentions.isNotEmpty) 'mentions': mentions,
        if (roomIds.isNotEmpty) 'room_id': roomIds,
        if (has.isNotEmpty) 'has': has,
        if (pinned != null) 'pinned': pinned.toString(),
        if (before != null) 'before': before!.toUtc().toIso8601String(),
        if (after != null) 'after': after!.toUtc().toIso8601String(),
        if (cursor != null && cursor!.isNotEmpty) 'cursor': cursor,
      };
}

class MessageSearchResponse<T> {
  /// All the pages' messages, counted up to 1000.
  final int totalResults;

  /// This page, newest first.
  final List<T> messages;

  const MessageSearchResponse(
      {required this.totalResults, required this.messages});

  MessageSearchResponse.fromJson(
      Map<String, dynamic> j, T Function(Map<String, dynamic>) fromJson)
      : totalResults = j['total_results'] as int? ?? 0,
        messages = (j['messages'] as List<dynamic>? ?? [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
}

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

class StorageStatus {
  final int usedBytes;
  final int maxBytes;
  final int uploadLimitBytes;
  final num percentageUsed;

  const StorageStatus({
    required this.usedBytes,
    required this.maxBytes,
    required this.uploadLimitBytes,
    required this.percentageUsed,
  });

  StorageStatus.fromJson(Map<String, dynamic> j)
      : usedBytes = j['used_bytes'] as int,
        maxBytes = j['max_bytes'] as int,
        uploadLimitBytes = j['upload_limit_bytes'] as int,
        percentageUsed = j['percentage_used'] as num;
}

/// An S3-compatible bucket a user or a space keeps its files in.
class StorageBucket {
  final String id;
  final String ownerId;
  final String name;
  final String endpoint;
  final String region;
  final String bucketName;
  final String accessKeyId;
  final bool isActive;
  final bool isDefault;
  final bool usePathStyle;
  final int? maxBytes;
  final int? uploadLimitBytes;
  final int usedBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StorageBucket({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.endpoint,
    required this.region,
    required this.bucketName,
    required this.accessKeyId,
    required this.isActive,
    required this.isDefault,
    required this.usePathStyle,
    this.maxBytes,
    this.uploadLimitBytes,
    required this.usedBytes,
    required this.createdAt,
    required this.updatedAt,
  });

  StorageBucket.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        ownerId = j['owner_id'] as String,
        name = j['name'] as String,
        endpoint = j['endpoint'] as String,
        region = j['region'] as String? ?? '',
        bucketName = j['bucket_name'] as String,
        accessKeyId = j['access_key_id'] as String,
        isActive = j['is_active'] as bool? ?? false,
        isDefault = j['is_default'] as bool? ?? false,
        usePathStyle = j['use_path_style'] as bool? ?? false,
        maxBytes = j['max_bytes'] as int?,
        uploadLimitBytes = j['upload_limit_bytes'] as int?,
        usedBytes = j['used_bytes'] as int? ?? 0,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String);
}

/// What creating or updating a [StorageBucket] takes.
class BucketPayload {
  final String name;
  final String endpoint;
  final String? region;
  final String bucketName;
  final String accessKeyId;
  final String secretAccessKey;
  final bool? usePathStyle;
  final int? maxBytes;
  final int? uploadLimitBytes;

  const BucketPayload({
    required this.name,
    required this.endpoint,
    this.region,
    required this.bucketName,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.usePathStyle,
    this.maxBytes,
    this.uploadLimitBytes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'endpoint': endpoint,
        if (region != null) 'region': region,
        'bucket_name': bucketName,
        'access_key_id': accessKeyId,
        'secret_access_key': secretAccessKey,
        if (usePathStyle != null) 'use_path_style': usePathStyle,
        'max_bytes': maxBytes,
        'upload_limit_bytes': uploadLimitBytes,
      };
}

// ---------------------------------------------------------------------------
// Developer: teams, applications, bots
// ---------------------------------------------------------------------------

class Team {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Team({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  Team.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        ownerId = j['owner_id'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String);
}

/// The values of [TeamMember.role].
abstract final class TeamRole {
  static const admin = 0;
  static const member = 1;
}

class TeamMember {
  final String teamId;
  final String userId;

  /// A [TeamRole].
  final int role;
  final String username;
  final String? avatar;

  const TeamMember({
    required this.teamId,
    required this.userId,
    required this.role,
    required this.username,
    this.avatar,
  });

  TeamMember.fromJson(Map<String, dynamic> j)
      : teamId = j['team_id'] as String,
        userId = j['user_id'] as String,
        role = j['role'] as int,
        username = j['username'] as String,
        avatar = j['avatar'] as String?;
}

class TeamInvite {
  final String id;
  final String teamId;
  final String userId;
  final String invitedBy;
  final DateTime createdAt;
  final String teamName;
  final String invitedByUsername;

  const TeamInvite({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.invitedBy,
    required this.createdAt,
    required this.teamName,
    required this.invitedByUsername,
  });

  TeamInvite.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        teamId = j['team_id'] as String,
        userId = j['user_id'] as String,
        invitedBy = j['invited_by'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        teamName = j['team_name'] as String,
        invitedByUsername = j['invited_by_username'] as String;
}

class Application {
  final String id;
  final String teamId;
  final String name;
  final String? description;
  final String? icon;
  final bool public;
  final String? botUserId;
  final String? botTokenHash;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Application({
    required this.id,
    required this.teamId,
    required this.name,
    this.description,
    this.icon,
    required this.public,
    this.botUserId,
    this.botTokenHash,
    required this.createdAt,
    required this.updatedAt,
  });

  Application.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        teamId = j['team_id'] as String,
        name = j['name'] as String,
        description = j['description'] as String?,
        icon = j['icon'] as String?,
        public = j['public'] as bool? ?? false,
        botUserId = j['bot_user_id'] as String?,
        botTokenHash = j['bot_token_hash'] as String?,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String);
}

class BotUser {
  final String id;
  final String username;
  final String? alias;
  final String? avatar;
  final String? banner;
  final bool isBot;

  const BotUser({
    required this.id,
    required this.username,
    this.alias,
    this.avatar,
    this.banner,
    required this.isBot,
  });

  BotUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        username = j['username'] as String,
        alias = j['alias'] as String?,
        avatar = j['avatar'] as String?,
        banner = j['banner'] as String?,
        isBot = j['is_bot'] as bool? ?? false;
}

// ---------------------------------------------------------------------------
// Invites
// ---------------------------------------------------------------------------

class InviteInfo {
  final String code;
  final String spaceId;
  final String spaceName;
  final String description;
  final int memberCount;

  const InviteInfo({
    required this.code,
    required this.spaceId,
    required this.spaceName,
    required this.description,
    required this.memberCount,
  });

  InviteInfo.fromJson(Map<String, dynamic> j)
      : code = j['code'] as String,
        spaceId = j['space_id'] as String,
        spaceName = j['space_name'] as String,
        description = j['description'] as String? ?? '',
        memberCount = j['member_count'] as int? ?? 0;
}

class InviteLink {
  final String id;
  final String code;
  final String roomId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When it stops working; null for one that works until it is revoked.
  final DateTime? expiresAt;

  const InviteLink({
    required this.id,
    required this.code,
    required this.roomId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  InviteLink.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        code = j['code'] as String,
        roomId = j['room_id'] as String,
        createdBy = j['created_by'] as String,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String),
        expiresAt = _parseDate(j['expires_at']);
}

// ---------------------------------------------------------------------------
// Webhooks
// ---------------------------------------------------------------------------

class Webhook {
  final String id;
  final String roomId;
  final String username;
  final String? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Webhook({
    required this.id,
    required this.roomId,
    required this.username,
    this.avatar,
    required this.createdAt,
    required this.updatedAt,
  });

  Webhook.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        roomId = j['room_id'] as String,
        username = j['username'] as String,
        avatar = j['avatar'] as String?,
        createdAt = DateTime.parse(j['created_at'] as String),
        updatedAt = DateTime.parse(j['updated_at'] as String);
}

class WebhookCreateResponse {
  final Webhook webhook;
  final String token;

  const WebhookCreateResponse({required this.webhook, required this.token});

  WebhookCreateResponse.fromJson(Map<String, dynamic> j)
      : webhook = Webhook.fromJson(j['webhook'] as Map<String, dynamic>),
        token = j['token'] as String;
}

// ---------------------------------------------------------------------------
// Commands & interactions
// ---------------------------------------------------------------------------

/// The option types of an application's command.
abstract final class CommandOptionType {
  static const string = 3;
  static const integer = 4;
  static const boolean = 5;
  static const user = 6;
  static const room = 7;
  static const role = 8;
  static const mentionable = 9;
  static const number = 10;
}

class CommandChoice {
  final String name;

  /// A string or a number.
  final Object value;

  const CommandChoice({required this.name, required this.value});

  CommandChoice.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
        value = j['value'] as Object;
}

/// What a command takes; the required ones come first.
class CommandOption {
  /// A [CommandOptionType].
  final int type;
  final String name;
  final String description;
  final bool required;

  /// The only values it takes, for string, integer and number options.
  final List<CommandChoice>? choices;
  final num? minValue;
  final num? maxValue;
  final int? minLength;
  final int? maxLength;
  final List<RoomType>? roomTypes;

  const CommandOption({
    required this.type,
    required this.name,
    required this.description,
    this.required = false,
    this.choices,
    this.minValue,
    this.maxValue,
    this.minLength,
    this.maxLength,
    this.roomTypes,
  });

  CommandOption.fromJson(Map<String, dynamic> j)
      : type = j['type'] as int,
        name = j['name'] as String,
        description = j['description'] as String? ?? '',
        required = j['required'] as bool? ?? false,
        choices = (j['choices'] as List<dynamic>?)
            ?.map((e) => CommandChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        minValue = j['min_value'] as num?,
        maxValue = j['max_value'] as num?,
        minLength = j['min_length'] as int?,
        maxLength = j['max_length'] as int?,
        roomTypes = (j['room_types'] as List<dynamic>?)
            ?.map((e) => RoomType.fromInt(e as int))
            .toList();
}

/// A chat command an application registers.
class ApplicationCommand {
  final String id;

  /// 1, a chat command.
  final int type;
  final String applicationId;
  final String name;
  final String description;
  final List<CommandOption> options;
  final String version;

  const ApplicationCommand({
    required this.id,
    required this.type,
    required this.applicationId,
    required this.name,
    required this.description,
    required this.options,
    required this.version,
  });

  ApplicationCommand.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        type = j['type'] as int? ?? 1,
        applicationId = j['application_id'] as String,
        name = j['name'] as String,
        description = j['description'] as String? ?? '',
        options = (j['options'] as List<dynamic>? ?? [])
            .map((e) => CommandOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        version = j['version'] as String? ?? '';
}

class SpaceCommandApplication {
  final String id;
  final String name;
  final InteractionUser bot;

  const SpaceCommandApplication(
      {required this.id, required this.name, required this.bot});

  SpaceCommandApplication.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        bot = InteractionUser.fromJson(j['bot'] as Map<String, dynamic>);
}

/// The commands a member can use in a space: those of the applications whose
/// bots are in it.
class SpaceCommands {
  final List<SpaceCommandApplication> applications;
  final List<ApplicationCommand> commands;

  const SpaceCommands({required this.applications, required this.commands});

  SpaceCommands.fromJson(Map<String, dynamic> j)
      : applications = (j['applications'] as List<dynamic>? ?? [])
            .map((e) =>
                SpaceCommandApplication.fromJson(e as Map<String, dynamic>))
            .toList(),
        commands = (j['commands'] as List<dynamic>? ?? [])
            .map((e) => ApplicationCommand.fromJson(e as Map<String, dynamic>))
            .toList();
}

/// The types of a bot's first response to an interaction
/// ([InteractionReply.type]).
abstract final class InteractionCallbackType {
  /// A message in the interaction's room.
  static const channelMessageWithSource = 4;

  /// A LOADING message, which the bot completes by editing it.
  static const deferredChannelMessageWithSource = 5;

  /// Nothing yet: the bot edits the component's message later.
  static const deferredUpdateMessage = 6;

  /// The component's message, edited at once.
  static const updateMessage = 7;

  /// A modal for the person who used the component or the command.
  static const modal = 9;
}

/// What a person's interaction answers: the type of the bot's first response
/// and, when the bot opened a modal, the modal and the application its submit
/// goes to.
class InteractionReply {
  /// An [InteractionCallbackType].
  final int type;

  /// The modal, as the API sends it: its `custom_id`, `title` and
  /// `components`.
  final Map<String, dynamic>? modal;

  /// The application whose bot opened the modal.
  final String? applicationId;

  const InteractionReply({required this.type, this.modal, this.applicationId});

  InteractionReply.fromJson(Map<String, dynamic> j)
      : type = j['type'] as int,
        modal = j['data'] as Map<String, dynamic>?,
        applicationId = j['application_id'] as String?;

  /// Whether the bot opened a modal: then [modal] and [applicationId] are
  /// set.
  bool get isModal =>
      type == InteractionCallbackType.modal &&
      modal != null &&
      applicationId != null;
}

/// What a person sends about the component of a bot's message they used.
class ComponentUse {
  final String customId;
  final int componentType;

  /// What a select's choice was: its options' values, or the IDs of the
  /// members, roles or rooms.
  final List<String>? values;

  const ComponentUse(
      {required this.customId, required this.componentType, this.values});

  Map<String, dynamic> toJson() => {
        'custom_id': customId,
        'component_type': componentType,
        if (values != null) 'values': values,
      };
}

/// A command option's value, as it is sent.
class UsedOption {
  final String name;

  /// A [CommandOptionType].
  final int type;

  /// A string, a number or a bool.
  final Object value;

  const UsedOption(
      {required this.name, required this.type, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'value': value};
}

/// What a person sends about the command they used: the command, as the
/// space's list has it, and its options.
class CommandUse {
  final String id;
  final String name;
  final List<UsedOption> options;

  const CommandUse(
      {required this.id, required this.name, this.options = const []});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': 1,
        'options': options.map((o) => o.toJson()).toList(),
      };
}
