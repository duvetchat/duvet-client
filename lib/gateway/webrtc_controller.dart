// this codebase (this file) is the only one that's not largely made by me
// all copyright goes to the duvet authors (MARCROCK22 and n128)
// I am a mere contributor who cloned the TS codebase

import 'dart:async';

import 'package:duvet_client/gateway/manager.dart';
import 'package:duvet_client/models/types.dart';

/// A user's voice state in a space's voice room, or in a conversation's call
/// (then [roomId] is the conversation's ID).
///
/// Immutable: a new instance comes with every update, so consumers can compare
/// references to tell what changed.
class VoiceParticipant {
  final String userId;
  final String roomId;
  final bool muted;
  final bool deafened;
  final bool screenSharing;

  /// Their camera is on.
  final bool camera;

  /// The state's version: see [VoiceStateEvent.version].
  final int version;

  const VoiceParticipant({
    required this.userId,
    required this.roomId,
    this.muted = false,
    this.deafened = false,
    this.screenSharing = false,
    this.camera = false,
    this.version = 0,
  });

  @override
  String toString() => 'VoiceParticipant(userId=$userId, roomId=$roomId, '
      'muted=$muted, deafened=$deafened, screenSharing=$screenSharing, '
      'camera=$camera, version=$version)';
}

/// Who's in voice in every room and call a session knows of, kept as the
/// gateway reports it: READY's calls, each SPACE_CREATE's voice rooms and
/// each CALL_ONGOING's call, then every VOICE_STATE_UPDATE.
///
/// Updates can arrive out of order. Each carries a version that grows with
/// every change, and one older than what's known is dropped; one as new is
/// the same state again (a call's catch-up when the user joins it).
class VoiceStates {
  final _rooms = <String, Map<String, VoiceParticipant>>{};

  // The newest version seen per room and user, kept after they leave, so a
  // late "joined" can't bring them back.
  final _versions = <String, int>{};

  /// Everyone in voice, by room (or call) ID, then by user ID. Unmodifiable.
  Map<String, Map<String, VoiceParticipant>> get rooms => Map.unmodifiable(
      _rooms.map((roomId, users) => MapEntry(roomId, Map.unmodifiable(users))));

  /// Who's in [roomId]: none when nobody is.
  List<VoiceParticipant> participantsIn(String roomId) =>
      List.unmodifiable(_rooms[roomId]?.values ?? const <VoiceParticipant>[]);

  /// READY: a new session, so what was known is dropped (each space's
  /// SPACE_CREATE brings its voice rooms again), and READY's [calls] are
  /// taken.
  void reset([List<GatewayReadyActiveCall> calls = const []]) {
    _rooms.clear();
    _versions.clear();
    for (final call in calls) {
      _call(call.conversationId, call.voiceStates);
    }
  }

  /// SPACE_CREATE: the space's voice rooms as the gateway has them now replace
  /// what was known of them; an entry older than an update already applied
  /// is left out.
  void space(GatewaySpaceCreatePayload space) {
    for (final roomId in space.rooms.keys) {
      _rooms.remove(roomId);
    }
    for (final s in space.voiceStates ?? const <GatewayVoiceState>[]) {
      _snapshot(VoiceParticipant(
        userId: s.userId,
        roomId: s.roomId,
        muted: s.muted,
        deafened: s.deafened,
        screenSharing: s.screenSharing,
        camera: s.camera,
        version: s.version,
      ));
    }
  }

  /// CALL_ONGOING: who is in the call's voice as the gateway has it now
  /// replaces what was known of it; an entry older than an update already
  /// applied is left out.
  void ongoing(CallOngoingEvent call) =>
      _call(call.conversationId, call.voiceStates);

  void _call(String conversationId, List<CallVoiceState>? states) {
    _rooms.remove(conversationId);
    for (final s in states ?? const <CallVoiceState>[]) {
      _snapshot(VoiceParticipant(
        userId: s.userId,
        roomId: conversationId,
        muted: s.muted,
        deafened: s.deafened,
        screenSharing: s.screenSharing,
        camera: s.camera,
        version: s.version,
      ));
    }
  }

  /// A room that's gone, or a call that ended: the gateway sends no update
  /// for the people who were in it.
  void forget(String roomId) => _rooms.remove(roomId);

  /// VOICE_STATE_UPDATE: answers whether it applied, false for one that came
  /// after a newer one.
  bool apply(VoiceStateEvent e) {
    final key = '${e.roomId}:${e.userId}';
    final last = _versions[key];
    if (last != null && e.version < last) return false;
    _versions[key] = e.version;
    if (e.joined) {
      (_rooms[e.roomId] ??= {})[e.userId] = VoiceParticipant(
        userId: e.userId,
        roomId: e.roomId,
        muted: e.muted,
        deafened: e.deafened,
        screenSharing: e.screenSharing,
        camera: e.camera,
        version: e.version,
      );
    } else {
      final room = _rooms[e.roomId];
      room?.remove(e.userId);
      if (room != null && room.isEmpty) _rooms.remove(e.roomId);
    }
    return true;
  }

  void _snapshot(VoiceParticipant p) {
    final key = '${p.roomId}:${p.userId}';
    final last = _versions[key];
    if (last != null && p.version < last) return;
    _versions[key] = p.version;
    (_rooms[p.roomId] ??= {})[p.userId] = p;
  }
}

/// Voice and call signalling over the gateway: the typed messages a client
/// sends to be in a space's voice room or a conversation's call, and to
/// negotiate its peer connection with the gateway, which forwards everyone's
/// audio and video; and [voiceStates], kept from the gateway's events.
///
/// Each send answers whether the message went out: false while no socket is
/// open (see [connection]), when it would be lost.
///
/// ### Joining a voice room
/// ```dart
/// final rtc = WebRTCController(manager);
/// rtc.onVoiceJoined.listen((e) => pc.setRemoteDescription(e.data.answer));
/// rtc.onRenegotiate.listen((e) async {
///   // set e.data.offer, then answer it
///   rtc.sendAnswer(e.data.roomId, answer);
/// });
/// rtc.joinVoice(roomId, offer, videoOff: true);
/// rtc.syncVoice(roomId, muted: false, deafened: false, screenSharing: false,
///     camera: false, videoOff: true);
/// ```
///
/// ### Calls
/// A call's voice is joined like a room's, with the conversation's ID as the
/// room: after [initiateCall] once someone accepts (CALL_ACCEPTED), or after
/// [acceptCall]. A call rings none of its caller's devices, which get
/// CALL_OUTGOING instead ([onCallOutgoing]), and one that goes on without
/// ringing the user comes as CALL_ONGOING ([onCallOngoing]); they join it
/// with [acceptCall], or with [initiateCall]. A CALL_ACCEPTED with the user's
/// own ID means they answered on another device, or rejoined a call they
/// started.
class WebRTCController {
  final GatewayManager _manager;
  final List<StreamSubscription<dynamic>> _subs = [];
  final _updates = StreamController<VoiceStateUpdatedEvent>.broadcast();

  /// Who's in voice where, as the gateway reports it.
  final voiceStates = VoiceStates();

  WebRTCController(this._manager) {
    _subs.add(_manager.onEvent.listen(_handle));
  }

  void _handle(GatewayEventPayload event) {
    switch (event) {
      case ReadyEvent(:final data):
        voiceStates.reset(data.activeCalls ?? const []);
      case SpaceCreateEvent(:final data):
        voiceStates.space(data);
      case VoiceStateUpdatedEvent(:final data):
        if (voiceStates.apply(data) && !_updates.isClosed) _updates.add(event);
      case CallOngoingPayloadEvent(:final data):
        voiceStates.ongoing(data);
      case CallEndedPayloadEvent(:final data):
        voiceStates.forget(data.conversationId);
      case RoomDeletedEvent(:final data):
        voiceStates.forget(data.id);
      default:
    }
  }

  /// The VOICE_STATE_UPDATEs that changed [voiceStates], which is up to date
  /// when they arrive; late ones are left out.
  Stream<VoiceStateUpdatedEvent> get onVoiceStateUpdate => _updates.stream;

  /// The gateway's answer to [joinVoice]: apply it before any renegotiation.
  Stream<VoiceJoinedPayloadEvent> get onVoiceJoined => _manager.onVoiceJoin;

  /// The gateway's ICE candidates.
  Stream<WebRTCIceCandidateEvent> get onIceCandidate => _manager.onIceCandidate;

  /// The gateway's offers, to answer with [sendAnswer].
  Stream<WebRTCRenegotiateEvent> get onRenegotiate => _manager.onRenegotiate;

  /// The gateway's answers to [sendRenegotiateOffer].
  Stream<WebRTCRenegotiateAnswerEvent> get onRenegotiateAnswer =>
      _manager.onRenegotiateAnswer;

  /// This session's voice in a room or call ended: another device took it,
  /// or the user lost access.
  Stream<VoiceSessionReplacedPayloadEvent> get onVoiceSessionReplaced =>
      _manager.onVoiceSessionReplaced;

  /// The gateway refused or stopped this session's camera or screen: turn it
  /// off, and say why.
  Stream<VoiceVideoRefusedPayloadEvent> get onVoiceVideoRefused =>
      _manager.onVoiceVideoRefused;

  Stream<CallIncomingPayloadEvent> get onCallIncoming =>
      _manager.onCallIncoming;

  /// A call the user started, on each of their sessions: it rings none of
  /// them.
  Stream<CallOutgoingPayloadEvent> get onCallOutgoing =>
      _manager.onCallOutgoing;

  /// A call that goes on without ringing the user, which they can join with
  /// [acceptCall]; [voiceStates] has who is in it by then.
  Stream<CallOngoingPayloadEvent> get onCallOngoing => _manager.onCallOngoing;
  Stream<CallAcceptedEvent> get onCallAccepted => _manager.onCallAccept;
  Stream<CallDeclinedEvent> get onCallDeclined => _manager.onCallDecline;
  Stream<CallEndedPayloadEvent> get onCallEnded => _manager.onCallEnd;

  /// The number of the gateway socket open now, or null while none is:
  /// [GatewayManager.connection].
  int? get connection => _manager.connection;

  /// How long the gateway had been silent before the last READY:
  /// [GatewayManager.silenceBeforeReady]. A client back from a long silence
  /// (the device slept) may rather not rejoin voice by surprise.
  Duration get silenceBeforeReady => _manager.silenceBeforeReady;

  // Voice --------------------------------------------------------------------

  /// VOICE_JOIN: joins [roomId] (a voice room, or a call's conversation) with
  /// the peer connection's [offer]. [tracks] tags the transceivers that send
  /// a camera, by mid (`{"1": "camera"}`); [videoOff] receives no video at
  /// all. The gateway answers with VOICE_JOINED, or with nothing when it
  /// refuses.
  bool joinVoice(String roomId, SessionDescription offer,
          {Map<String, String> tracks = const {}, bool videoOff = false}) =>
      _send('VOICE_JOIN', {
        'room_id': roomId,
        'offer': offer.toJson(),
        if (tracks.isNotEmpty) 'tracks': tracks,
        'video_off': videoOff,
      });

  /// VOICE_LEAVE: leaves [roomId]'s voice. The gateway ignores it when the
  /// user's voice there is another device's.
  bool leaveVoice(String roomId) => _send('VOICE_LEAVE', {'room_id': roomId});

  /// VOICE_SYNC: the client's whole voice state in [roomId]. The gateway
  /// replaces its state with each one, so every field is required: one left
  /// out would turn that off.
  bool syncVoice(
    String roomId, {
    required bool muted,
    required bool deafened,
    required bool screenSharing,
    required bool camera,
    required bool videoOff,
  }) =>
      _send('VOICE_SYNC', {
        'room_id': roomId,
        'muted': muted,
        'deafened': deafened,
        'screen_sharing': screenSharing,
        'camera': camera,
        'video_off': videoOff,
      });

  /// WEBRTC_ICE_CANDIDATE: one of the peer connection's ICE candidates.
  bool sendIceCandidate(String roomId, IceCandidateInit candidate) =>
      _send('WEBRTC_ICE_CANDIDATE', {
        'room_id': roomId,
        'candidate': candidate.toJson(),
      });

  /// WEBRTC_ANSWER: the answer to the gateway's offer (WEBRTC_RENEGOTIATE).
  bool sendAnswer(String roomId, SessionDescription answer) =>
      _send('WEBRTC_ANSWER', {'room_id': roomId, 'answer': answer.toJson()});

  /// WEBRTC_RENEGOTIATE_OFFER: the client's own renegotiation (it added or
  /// removed a track); the gateway answers with WEBRTC_RENEGOTIATE_ANSWER.
  /// [tracks] tags new camera transceivers, as in [joinVoice].
  bool sendRenegotiateOffer(String roomId, SessionDescription offer,
          {Map<String, String> tracks = const {}}) =>
      _send('WEBRTC_RENEGOTIATE_OFFER', {
        'room_id': roomId,
        'offer': offer.toJson(),
        if (tracks.isNotEmpty) 'tracks': tracks,
      });

  // Calls --------------------------------------------------------------------

  /// CALL_INITIATE: rings [memberIds] (the conversation's members; the caller
  /// is left out of the ringing) with CALL_INCOMING, and the caller's sessions
  /// get CALL_OUTGOING.
  ///
  /// Into a call going on, it starts none: it joins the call for one of its
  /// members who isn't in its voice. From anyone but its caller, that counts
  /// as accepting it (calls that crossed, or one that no longer rings them):
  /// everyone gets CALL_ACCEPTED, and their app joins its voice. Its caller
  /// who hung up rejoins the same way once someone has answered it, with a
  /// CALL_ACCEPTED of their own ID that isn't an answer; before that, their
  /// app joins at the first answer. From someone in its voice, it changes
  /// nothing.
  bool initiateCall(String conversationId, List<String> memberIds) =>
      _send('CALL_INITIATE', {
        'conversation_id': conversationId,
        'member_ids': memberIds,
      });

  /// CALL_ACCEPT: answers a call; everyone in it gets CALL_ACCEPTED. It joins
  /// one that no longer rings the user the same way (CALL_ONGOING). The
  /// caller's own answers nothing.
  bool acceptCall(String conversationId) =>
      _send('CALL_ACCEPT', {'conversation_id': conversationId});

  /// CALL_DECLINE: turns a call down on all of the user's devices: its caller
  /// and each of the user's sessions get CALL_DECLINED, and the call ends
  /// (CALL_ENDED) once every member but its caller declined.
  bool declineCall(String conversationId) =>
      _send('CALL_DECLINE', {'conversation_id': conversationId});

  /// CALL_CANCEL: ends the call for everyone (CALL_ENDED). Its caller can, and
  /// so can a member whose [initiateCall] answered it (calls that crossed)
  /// while nobody else has accepted it; after that, theirs only takes their
  /// voice out, as [leaveCall] does.
  bool cancelCall(String conversationId) =>
      _send('CALL_CANCEL', {'conversation_id': conversationId});

  /// CALL_LEAVE: leaves a call's voice; the call ends when nobody's left.
  bool leaveCall(String conversationId) =>
      _send('CALL_LEAVE', {'conversation_id': conversationId});

  bool _send(String type, Map<String, dynamic> data) {
    try {
      return _manager.sendMessage(type, data);
    } on StateError {
      // No shard yet: nothing could go out.
      return false;
    }
  }

  /// Cancels the gateway subscriptions and closes [onVoiceStateUpdate]. After
  /// this the controller must not be reused.
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _updates.close();
  }
}
