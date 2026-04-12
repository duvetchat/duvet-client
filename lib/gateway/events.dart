// this was also largely inspired by Nyxx

import 'dart:async';
import 'package:duvet_client/models/types.dart';
import 'package:duvet_client/utils/extensions.dart';

mixin GatewayEvents {
  /// Unified broadcast stream of every [GatewayEventPayload] received across
  /// all shards. Never completes until [destroy] is called.
  Stream<GatewayEventPayload> get onEvent;

  /// Returns a [StreamSubscription] filtered to payloads of type [T].
  ///
  /// ```dart
  /// manager.on<MessageCreateEvent>((e) => print(e.data.content));
  /// ```
  StreamSubscription<T> on<T extends GatewayEventPayload>(
          void Function(T event) handler) =>
      onEvent.whereType<T>().listen(handler);

  /// Completes with the [GatewayReadyData] from the first [ReadyEvent]
  /// received by shard 0.  Await this to ensure the session is established
  /// before acting on other events.
  Future<GatewayReadyData> get ready =>
      onEvent.whereType<ReadyEvent>().first.then((e) => e.data);

  Stream<ReadyEvent> get onReady => onEvent.whereType<ReadyEvent>();

  Stream<SpaceCreateEvent> get onSpaceCreate =>
      onEvent.whereType<SpaceCreateEvent>();
  Stream<SpaceUpdateEvent> get onSpaceUpdate =>
      onEvent.whereType<SpaceUpdateEvent>();
  Stream<SpaceDeletedEvent> get onSpaceDelete =>
      onEvent.whereType<SpaceDeletedEvent>();

  Stream<RoomCreateEvent> get onRoomCreate =>
      onEvent.whereType<RoomCreateEvent>();
  Stream<RoomUpdateEvent> get onRoomUpdate =>
      onEvent.whereType<RoomUpdateEvent>();
  Stream<RoomDeletedEvent> get onRoomDelete =>
      onEvent.whereType<RoomDeletedEvent>();

  Stream<RoomOverwriteUpdateEvent> get onOverwriteUpdate =>
      onEvent.whereType<RoomOverwriteUpdateEvent>();
  Stream<RoomOverwriteDeletedEvent> get onOverwriteDelete =>
      onEvent.whereType<RoomOverwriteDeletedEvent>();

  Stream<MessageCreateEvent> get onMessageCreate =>
      onEvent.whereType<MessageCreateEvent>();
  Stream<MessageUpdateEvent> get onMessageUpdate =>
      onEvent.whereType<MessageUpdateEvent>();
  Stream<MessageDeletedEvent> get onMessageDelete =>
      onEvent.whereType<MessageDeletedEvent>();
  Stream<MentionCreatedEvent> get onMentionCreate =>
      onEvent.whereType<MentionCreatedEvent>();

  Stream<ReactionAddedEvent> get onReactionAdd =>
      onEvent.whereType<ReactionAddedEvent>();
  Stream<ReactionRemovedEvent> get onReactionRemove =>
      onEvent.whereType<ReactionRemovedEvent>();

  Stream<TypingStartedEvent> get onTyping =>
      onEvent.whereType<TypingStartedEvent>();

  Stream<UserUpdatedEvent> get onUserUpdate =>
      onEvent.whereType<UserUpdatedEvent>();
  Stream<UserStatusUpdatedEvent> get onUserStatusUpdate =>
      onEvent.whereType<UserStatusUpdatedEvent>();

  Stream<GuildMemberAddedEvent> get onMemberAdd =>
      onEvent.whereType<GuildMemberAddedEvent>();
  Stream<GuildMemberRemovedEvent> get onMemberRemove =>
      onEvent.whereType<GuildMemberRemovedEvent>();
  Stream<SpaceMemberAddedEvent> get onSpaceMemberAdd =>
      onEvent.whereType<SpaceMemberAddedEvent>();
  Stream<SpaceMemberRemovedEvent> get onSpaceMemberRemove =>
      onEvent.whereType<SpaceMemberRemovedEvent>();

  Stream<RoleCreatedEvent> get onRoleCreate =>
      onEvent.whereType<RoleCreatedEvent>();
  Stream<RoleUpdatedEvent> get onRoleUpdate =>
      onEvent.whereType<RoleUpdatedEvent>();
  Stream<RoleDeletedEvent> get onRoleDelete =>
      onEvent.whereType<RoleDeletedEvent>();
  Stream<MemberRoleAddedEvent> get onMemberRoleAdd =>
      onEvent.whereType<MemberRoleAddedEvent>();
  Stream<MemberRoleRemovedEvent> get onMemberRoleRemove =>
      onEvent.whereType<MemberRoleRemovedEvent>();

  Stream<SpaceEmojiCreatedEvent> get onEmojiCreate =>
      onEvent.whereType<SpaceEmojiCreatedEvent>();
  Stream<SpaceEmojiUpdatedEvent> get onEmojiUpdate =>
      onEvent.whereType<SpaceEmojiUpdatedEvent>();
  Stream<SpaceEmojiDeletedEvent> get onEmojiDelete =>
      onEvent.whereType<SpaceEmojiDeletedEvent>();
  Stream<SpaceStickerCreatedEvent> get onStickerCreate =>
      onEvent.whereType<SpaceStickerCreatedEvent>();
  Stream<SpaceStickerUpdatedEvent> get onStickerUpdate =>
      onEvent.whereType<SpaceStickerUpdatedEvent>();
  Stream<SpaceStickerDeletedEvent> get onStickerDelete =>
      onEvent.whereType<SpaceStickerDeletedEvent>();

  Stream<DMMessageCreatedEvent> get onDMCreate =>
      onEvent.whereType<DMMessageCreatedEvent>();
  Stream<DMMessageUpdatedEvent> get onDMUpdate =>
      onEvent.whereType<DMMessageUpdatedEvent>();
  Stream<DMMessageDeletedEvent> get onDMDelete =>
      onEvent.whereType<DMMessageDeletedEvent>();
  Stream<DMReactionAddedEvent> get onDMReactionAdd =>
      onEvent.whereType<DMReactionAddedEvent>();
  Stream<DMReactionRemovedEvent> get onDMReactionRemove =>
      onEvent.whereType<DMReactionRemovedEvent>();
  Stream<DMTypingStartedEvent> get onDMTyping =>
      onEvent.whereType<DMTypingStartedEvent>();

  Stream<ConversationCreatedEvent> get onConversationCreate =>
      onEvent.whereType<ConversationCreatedEvent>();
  Stream<ConversationUpdatedEvent> get onConversationUpdate =>
      onEvent.whereType<ConversationUpdatedEvent>();
  Stream<ConversationDeletedEvent> get onConversationDelete =>
      onEvent.whereType<ConversationDeletedEvent>();
  Stream<ConversationMemberAddedEvent> get onConversationMemberAdd =>
      onEvent.whereType<ConversationMemberAddedEvent>();
  Stream<ConversationMemberRemovedEvent> get onConversationMemberRemove =>
      onEvent.whereType<ConversationMemberRemovedEvent>();

  Stream<FriendRequestCreatedEvent> get onFriendRequestCreate =>
      onEvent.whereType<FriendRequestCreatedEvent>();
  Stream<FriendRequestAcceptedEvent> get onFriendRequestAccept =>
      onEvent.whereType<FriendRequestAcceptedEvent>();
  Stream<FriendRequestRejectedEvent> get onFriendRequestReject =>
      onEvent.whereType<FriendRequestRejectedEvent>();
  Stream<FriendRemovedEvent> get onFriendRemove =>
      onEvent.whereType<FriendRemovedEvent>();

  Stream<VoiceStateUpdatedEvent> get onVoiceStateUpdate =>
      onEvent.whereType<VoiceStateUpdatedEvent>();
  Stream<VoiceJoinedPayloadEvent> get onVoiceJoin =>
      onEvent.whereType<VoiceJoinedPayloadEvent>();

  Stream<CallIncomingPayloadEvent> get onCallIncoming =>
      onEvent.whereType<CallIncomingPayloadEvent>();
  Stream<CallAcceptedEvent> get onCallAccept =>
      onEvent.whereType<CallAcceptedEvent>();
  Stream<CallDeclinedEvent> get onCallDecline =>
      onEvent.whereType<CallDeclinedEvent>();
  Stream<CallEndedPayloadEvent> get onCallEnd =>
      onEvent.whereType<CallEndedPayloadEvent>();

  Stream<WebRTCIceCandidateEvent> get onIceCandidate =>
      onEvent.whereType<WebRTCIceCandidateEvent>();
  Stream<WebRTCRenegotiateEvent> get onRenegotiate =>
      onEvent.whereType<WebRTCRenegotiateEvent>();
  Stream<WebRTCRenegotiateAnswerEvent> get onRenegotiateAnswer =>
      onEvent.whereType<WebRTCRenegotiateAnswerEvent>();

  Stream<UnknownEvent> get onUnknown => onEvent.whereType<UnknownEvent>();
}
