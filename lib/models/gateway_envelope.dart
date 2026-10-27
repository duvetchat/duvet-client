part of 'types.dart';

class GatewayEnvelope {
  final int op;
  final GatewayEventPayload? d;
  final int s;
  final String event;

  const GatewayEnvelope(
      {required this.op, this.d, required this.s, required this.event});

  GatewayEnvelope.fromJson(Map<String, dynamic> j)
      : op = j['op'] as int? ?? 0,
        s = j['s'] as int? ?? 0,
        event = j['event'] as String? ?? '',
        d = _parsePayload(
          j['d']?['type'] as String?,
          j['d']?['data'] as Map<String, dynamic>?,
        );

  static GatewayEventPayload? _parsePayload(
      String? type, Map<String, dynamic>? data) {
    if (type == null || type.isEmpty) return null;

    final d = data ?? <String, dynamic>{};

    switch (type.toUpperCase()) {
      case 'READY':
        return ReadyEvent(GatewayReadyData.fromJson(d));
      case 'SPACE_CREATE':
        return SpaceCreateEvent(GatewaySpaceCreatePayload.fromJson(d));
      case 'SPACE_UPDATE':
        return SpaceUpdateEvent(GatewaySpace.fromJson(d));
      case 'SPACE_DELETE':
        return SpaceDeletedEvent(SpaceDeleteEvent.fromJson(d));
      case 'ROOM_CREATE':
        return RoomCreateEvent(GatewayRoom.fromJson(d));
      case 'ROOM_UPDATE':
        return RoomUpdateEvent(GatewayRoom.fromJson(d));
      case 'ROOM_DELETE':
        return RoomDeletedEvent(RoomDeleteEvent.fromJson(d));
      case 'ROOM_REORDER':
        return RoomReorderedEvent(RoomReorderEvent.fromJson(d));
      case 'ROOM_OVERWRITE_UPDATE':
        return RoomOverwriteUpdateEvent(GatewayRoomOverwrite.fromJson(d));
      case 'ROOM_OVERWRITE_DELETE':
        return RoomOverwriteDeletedEvent(OverwriteDeleteEvent.fromJson(d));
      case 'MESSAGE_CREATE':
        return MessageCreateEvent(GatewayMessage.fromJson(d));
      case 'MESSAGE_UPDATE':
        return MessageUpdateEvent(GatewayMessage.fromJson(d));
      case 'MESSAGE_DELETE':
        return MessageDeletedEvent(GatewayMessageDelete.fromJson(d));
      case 'MESSAGE_PIN_UPDATE':
        return MessagePinUpdatedEvent(MessagePinUpdateEvent.fromJson(d));
      case 'MENTION_CREATE':
        return MentionCreatedEvent(MentionCreateEvent.fromJson(d));
      case 'DM_MENTION_CREATE':
        return DMMentionCreatedEvent(DMMentionCreateEvent.fromJson(d));
      case 'USER_UPDATE':
        return UserUpdatedEvent(UserUpdateEvent.fromJson(d));
      case 'USER_STATUS_UPDATE':
        return UserStatusUpdatedEvent(GatewayUserStatusUpdate.fromJson(d));
      case 'USER_ACTIVITY_UPDATE':
        return UserActivityUpdatedEvent(UserActivityUpdateEvent.fromJson(d));
      case 'VOICE_STATE_UPDATE':
        return VoiceStateUpdatedEvent(VoiceStateEvent.fromJson(d));
      case 'VOICE_JOINED':
        return VoiceJoinedPayloadEvent(VoiceJoinedEvent.fromJson(d));
      case 'VOICE_SESSION_REPLACED':
        return VoiceSessionReplacedPayloadEvent(
            VoiceSessionReplacedEvent.fromJson(d));
      case 'VOICE_VIDEO_REFUSED':
        return VoiceVideoRefusedPayloadEvent(
            VoiceVideoRefusedEvent.fromJson(d));
      case 'WEBRTC_ICE_CANDIDATE':
        return WebRTCIceCandidateEvent(IceCandidateEvent.fromJson(d));
      case 'WEBRTC_RENEGOTIATE':
        return WebRTCRenegotiateEvent(RenegotiateOfferEvent.fromJson(d));
      case 'WEBRTC_RENEGOTIATE_ANSWER':
        return WebRTCRenegotiateAnswerEvent(RenegotiateAnswerEvent.fromJson(d));
      case 'ROLE_CREATE':
        return RoleCreatedEvent(GatewayRole.fromJson(d));
      case 'ROLE_UPDATE':
        return RoleUpdatedEvent(GatewayRole.fromJson(d));
      case 'ROLE_DELETE':
        return RoleDeletedEvent(RoleDeleteEvent.fromJson(d));
      case 'MEMBER_ROLE_ADD':
        return MemberRoleAddedEvent(MemberRoleEvent.fromJson(d));
      case 'MEMBER_ROLE_REMOVE':
        return MemberRoleRemovedEvent(MemberRoleEvent.fromJson(d));
      case 'SPACE_MEMBER_ADD':
        return SpaceMemberAddedEvent(SpaceMemberEvent.fromJson(d));
      case 'SPACE_MEMBER_REMOVE':
        return SpaceMemberRemovedEvent(SpaceMemberEvent.fromJson(d));
      case 'GUILD_MEMBER_ADD':
        return GuildMemberAddedEvent(GuildMemberAddEvent.fromJson(d));
      case 'GUILD_MEMBER_REMOVE':
        return GuildMemberRemovedEvent(GuildMemberRemoveEvent.fromJson(d));
      case 'SPACE_EMOJI_CREATE':
        return SpaceEmojiCreatedEvent(SpaceEmoji.fromJson(d));
      case 'SPACE_EMOJI_UPDATE':
        return SpaceEmojiUpdatedEvent(SpaceEmoji.fromJson(d));
      case 'SPACE_EMOJI_DELETE':
        return SpaceEmojiDeletedEvent(SpaceAssetDeleteEvent.fromJson(d));
      case 'SPACE_STICKER_CREATE':
        return SpaceStickerCreatedEvent(SpaceSticker.fromJson(d));
      case 'SPACE_STICKER_UPDATE':
        return SpaceStickerUpdatedEvent(SpaceSticker.fromJson(d));
      case 'SPACE_STICKER_DELETE':
        return SpaceStickerDeletedEvent(SpaceAssetDeleteEvent.fromJson(d));
      case 'REACTION_ADD':
        return ReactionAddedEvent(ReactionEvent.fromJson(d));
      case 'REACTION_REMOVE':
        return ReactionRemovedEvent(ReactionRemoveEvent.fromJson(d));
      case 'FRIEND_REQUEST_CREATE':
        return FriendRequestCreatedEvent(FriendRequestCreateEvent.fromJson(d));
      case 'FRIEND_REQUEST_ACCEPT':
        return FriendRequestAcceptedEvent(FriendRequestAcceptEvent.fromJson(d));
      case 'FRIEND_REQUEST_REJECT':
        return FriendRequestRejectedEvent(FriendRequestRejectEvent.fromJson(d));
      case 'FRIEND_REMOVE':
        return FriendRemovedEvent(FriendRemoveEvent.fromJson(d));
      case 'CONVERSATION_CREATE':
        return ConversationCreatedEvent(Conversation.fromJson(d));
      case 'CONVERSATION_UPDATE':
        return ConversationUpdatedEvent(ConversationUpdateEvent.fromJson(d));
      case 'CONVERSATION_DELETE':
        return ConversationDeletedEvent(ConversationDeleteEvent.fromJson(d));
      case 'CONVERSATION_MEMBER_ADD':
        return ConversationMemberAddedEvent(
            ConversationMemberAddEvent.fromJson(d));
      case 'CONVERSATION_MEMBER_REMOVE':
        return ConversationMemberRemovedEvent(
            ConversationMemberRemoveEvent.fromJson(d));
      case 'DM_MESSAGE_CREATE':
        return DMMessageCreatedEvent(DirectMessage.fromJson(d));
      case 'DM_MESSAGE_UPDATE':
        return DMMessageUpdatedEvent(DirectMessage.fromJson(d));
      case 'DM_MESSAGE_DELETE':
        return DMMessageDeletedEvent(DMMessageDeleteEvent.fromJson(d));
      case 'DM_MESSAGE_PIN_UPDATE':
        return DMMessagePinUpdatedEvent(DMMessagePinUpdateEvent.fromJson(d));
      case 'DM_REACTION_ADD':
        return DMReactionAddedEvent(ReactionEvent.fromJson(d));
      case 'DM_REACTION_REMOVE':
        return DMReactionRemovedEvent(ReactionRemoveEvent.fromJson(d));
      case 'TYPING':
        return TypingStartedEvent(TypingEvent.fromJson(d));
      case 'DM_TYPING':
        return DMTypingStartedEvent(DMTypingEvent.fromJson(d));
      case 'RECORDING':
        return RecordingStartedEvent(TypingEvent.fromJson(d));
      case 'DM_RECORDING':
        return DMRecordingStartedEvent(DMTypingEvent.fromJson(d));
      case 'CALL_INCOMING':
        return CallIncomingPayloadEvent(CallIncomingEvent.fromJson(d));
      case 'CALL_OUTGOING':
        return CallOutgoingPayloadEvent(CallOutgoingEvent.fromJson(d));
      case 'CALL_ONGOING':
        return CallOngoingPayloadEvent(CallOngoingEvent.fromJson(d));
      case 'CALL_ACCEPTED':
        return CallAcceptedEvent(CallResponseEvent.fromJson(d));
      case 'CALL_DECLINED':
        return CallDeclinedEvent(CallResponseEvent.fromJson(d));
      case 'CALL_ENDED':
        return CallEndedPayloadEvent(CallEndedEvent.fromJson(d));
      case 'TEAM_INVITE_CREATE':
        return TeamInviteCreatedEvent(TeamInvite.fromJson(d));
      case 'STORAGE_TRANSFER_UPDATE':
        return StorageTransferUpdatedEvent(StorageTransfer.fromJson(d));
      default:
        return UnknownEvent(type, d);
    }
  }
}

/// The codes of [GatewayCloseReason.code].
abstract final class GatewayCloseCode {
  /// Bad shard options in identify: a bot's, or a person's who sent any. The
  /// client stops, as the same options would be refused again: it opens no
  /// other socket until the app connects again.
  static const invalidShard = 4000;

  /// Something other than identify or a heartbeat before identify, or a
  /// message the gateway can't read before identify (`invalid identify`): one
  /// that isn't JSON, or an identify whose data isn't one.
  static const notIdentified = 4003;

  /// The token isn't valid: unknown or expired at identify, revoked since (a
  /// bot deleted or its token reset, the account's password reset), or its
  /// session ended (logged out, expired, or 30 days after the login). A
  /// socket opened with the same token fails again: ask the API about the
  /// session, as the desktop app does. A request that gets a 401 renews the
  /// tokens, or forgets them when the session is gone.
  static const invalidCredentials = 4004;

  /// A second identify on a socket that had identified.
  static const alreadyIdentified = 4005;

  /// A newer socket of this client took its session over (`superseded`): it
  /// resumed the session while the gateway still held this socket open, as
  /// when a phone changes networks, or asked to and got a new session. The
  /// client has moved to that socket already, so this one's close needs
  /// nothing done.
  static const superseded = 4006;
}

/// Why the gateway closes a socket, which it says just before it does
/// (`{"event": "close-with-reason", "code": …, "reason": …}`).
class GatewayCloseReason {
  /// A [GatewayCloseCode].
  final int code;
  final String reason;

  /// The shard whose socket it is: 0 without sharding.
  final int shardId;

  const GatewayCloseReason(
      {required this.code, required this.reason, this.shardId = 0});

  GatewayCloseReason.fromJson(Map<String, dynamic> j, {this.shardId = 0})
      : code = j['code'] as int? ?? 0,
        reason = j['reason'] as String? ?? '';

  @override
  String toString() => 'GatewayCloseReason(shard $shardId: $code $reason)';
}
