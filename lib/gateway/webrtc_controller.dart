// this codebase (this file) is the only one that's not largely made by me
// all copyright goes to the duvet authors (MARCROCK22 and n128)
// I am a mere contributor who cloned the TS codebase

import 'dart:async';

import 'package:duvet_client/gateway/manager.dart';
import 'package:duvet_client/models/types.dart';

/// Snapshot of a single participant's voice state inside a room.
///
/// Immutable - a new instance is produced on every update so consumers can
/// compare references for change detection.
class VoiceParticipant {
  final String userId;
  final String roomId;
  final bool muted;
  final bool deafened;
  final bool screenSharing;

  const VoiceParticipant({
    required this.userId,
    required this.roomId,
    this.muted = false,
    this.deafened = false,
    this.screenSharing = false,
  });

  VoiceParticipant copyWith({
    bool? muted,
    bool? deafened,
    bool? screenSharing,
  }) =>
      VoiceParticipant(
        userId: userId,
        roomId: roomId,
        muted: muted ?? this.muted,
        deafened: deafened ?? this.deafened,
        screenSharing: screenSharing ?? this.screenSharing,
      );

  @override
  String toString() => 'VoiceParticipant(userId=$userId, roomId=$roomId, '
      'muted=$muted, deafened=$deafened, screenSharing=$screenSharing)';
}

/// Handles all WebRTC / voice signalling events received from the gateway
/// and provides typed send-methods for the outbound signalling messages.
///
/// This is the Dart equivalent of the TypeScript `webrtcListeners` registry
/// + the voice-state management inside `handleEvent`.
///
/// ### Usage
/// ```dart
/// final rtc = WebRTCController(manager);
///
/// // Subscribe to signalling events
/// rtc.onVoiceJoined.listen((e) {
///   // server confirms we joined; start WebRTC handshake here
///   startPeerConnection(e.data.sdp);
/// });
///
/// rtc.onIceCandidate.listen((e) {
///   peerConnection.addIceCandidate(e.data.candidate);
/// });
///
/// // Join a voice room
/// rtc.joinVoiceRoom('room-id');
///
/// // … later, send ICE candidates back to the server
/// rtc.sendIceCandidate(
///   candidate: candidate.candidate,
///   sdpMLineIndex: candidate.sdpMLineIndex,
///   sdpMid: candidate.sdpMid,
/// );
///
/// // Clean up
/// rtc.dispose();
/// ```
class WebRTCController {
  final GatewayManager _manager;
  final List<StreamSubscription<dynamic>> _subs = [];

  // Local voice-state cache
  // Updated on every VOICE_STATE_UPDATE before the event is forwarded to
  // the public stream so listeners always see consistent state.

  final Map<String, Map<String, VoiceParticipant>> _voiceStates = {};

  /// The room this client has actively joined, or `null` when not in voice.
  String? _activeRoomId;
  String? get activeRoomId => _activeRoomId;

  final _voiceStateCtrl = StreamController<VoiceStateUpdatedEvent>.broadcast();
  final _voiceJoinedCtrl =
      StreamController<VoiceJoinedPayloadEvent>.broadcast();
  final _iceCandidateCtrl =
      StreamController<WebRTCIceCandidateEvent>.broadcast();
  final _renegotiateCtrl = StreamController<WebRTCRenegotiateEvent>.broadcast();
  final _renegotiateAnswerCtrl =
      StreamController<WebRTCRenegotiateAnswerEvent>.broadcast();

  /// Fires whenever a participant joins, leaves, or changes state in any
  /// voice room.  The local [voiceStates] cache is updated *before* this
  /// stream emits, so [participantsIn] will already reflect the new state.
  Stream<VoiceStateUpdatedEvent> get onVoiceStateUpdate =>
      _voiceStateCtrl.stream;

  /// Fires when the server confirms the client has joined a voice room and
  /// includes the initial SDP needed to start the WebRTC handshake.
  Stream<VoiceJoinedPayloadEvent> get onVoiceJoined => _voiceJoinedCtrl.stream;

  /// Fires when the server forwards an ICE candidate from a remote peer.
  Stream<WebRTCIceCandidateEvent> get onIceCandidate =>
      _iceCandidateCtrl.stream;

  /// Fires when the server requests a WebRTC renegotiation (sends an SDP
  /// offer that the client must answer).
  Stream<WebRTCRenegotiateEvent> get onRenegotiate => _renegotiateCtrl.stream;

  /// Fires when the server sends back a renegotiation SDP answer.
  Stream<WebRTCRenegotiateAnswerEvent> get onRenegotiateAnswer =>
      _renegotiateAnswerCtrl.stream;

  WebRTCController(this._manager) {
    _subs.add(
      _manager.onVoiceStateUpdate.listen(_handleVoiceStateUpdate),
    );
    _subs.add(
      _manager.onVoiceJoin.listen(_voiceJoinedCtrl.add),
    );
    _subs.add(
      _manager.onIceCandidate.listen(_iceCandidateCtrl.add),
    );
    _subs.add(
      _manager.onRenegotiate.listen(_renegotiateCtrl.add),
    );
    _subs.add(
      _manager.onRenegotiateAnswer.listen(_renegotiateAnswerCtrl.add),
    );
  }

  void _handleVoiceStateUpdate(VoiceStateUpdatedEvent event) {
    final d = event.data;
    final roomMap = _voiceStates.putIfAbsent(d.roomId, () => {});

    if (d.joined) {
      final existing = roomMap[d.userId];
      if (existing != null) {
        // Participant already present — update mute/deafen/screen-share flags
        // without touching userId / roomId (mirrors the TS existingIdx branch).
        roomMap[d.userId] = existing.copyWith(
          muted: d.muted ?? existing.muted,
          deafened: d.deafened ?? existing.deafened,
          screenSharing: d.screenSharing ?? existing.screenSharing,
        );
      } else {
        // New participant joined
        roomMap[d.userId] = VoiceParticipant(
          userId: d.userId,
          roomId: d.roomId,
          muted: d.muted ?? false,
          deafened: d.deafened ?? false,
          screenSharing: d.screenSharing ?? false,
        );
      }
    } else {
      // Participant left
      roomMap.remove(d.userId);
      if (roomMap.isEmpty) _voiceStates.remove(d.roomId);
    }

    // Forward to public stream after state is already consistent.
    if (!_voiceStateCtrl.isClosed) _voiceStateCtrl.add(event);
  }

  /// Returns all currently-tracked voice states, keyed by room ID.
  ///
  /// The inner map is keyed by user ID.  Both maps are unmodifiable copies.
  Map<String, Map<String, VoiceParticipant>> get voiceStates =>
      Map.unmodifiable(_voiceStates.map(
        (roomId, users) => MapEntry(roomId, Map.unmodifiable(users)),
      ));

  /// Returns the list of participants currently in [roomId].
  /// Returns an empty list when nobody is in that room.
  List<VoiceParticipant> participantsIn(String roomId) =>
      List.unmodifiable(_voiceStates[roomId]?.values as Iterable<dynamic>);

  // Outbound send methods
  //
  // These mirror the TypeScript sendEventMessage() call-sites that appear
  // inside VOICE_STATE_UPDATE, VOICE_JOINED, and the WebRTC cases.

  /// Sends a `join_voice` event to enter [roomId].
  ///
  /// The server responds with a [VoiceJoinedPayloadEvent] containing the
  /// initial SDP needed to open the peer connection.
  void joinVoiceRoom(String roomId) {
    _activeRoomId = roomId;
    _manager.sendMessage('join_voice', {'room_id': roomId});
  }

  /// Sends a `leave_voice` event to exit the current voice room.
  /// Does nothing if the client is not currently in a voice room.
  void leaveVoiceRoom() {
    final roomId = _activeRoomId;
    if (roomId == null) return;
    _manager.sendMessage('leave_voice', {'room_id': roomId});
    _activeRoomId = null;
  }

  /// Sends a `VOICE_STATE_UPDATE` event to change the local client's
  /// mute / deafen / screen-sharing state on the server.
  ///
  /// Only the provided fields are included in the payload; omitted fields
  /// are left unchanged server-side.
  void updateVoiceState({
    bool? muted,
    bool? deafened,
    bool? screenSharing,
  }) {
    _manager.sendMessage('VOICE_STATE_UPDATE', {
      if (muted != null) 'muted': muted,
      if (deafened != null) 'deafened': deafened,
      if (screenSharing != null) 'screen_sharing': screenSharing,
    });
  }

  /// Sends a `WEBRTC_ICE_CANDIDATE` event to the server.
  ///
  /// Call this for every ICE candidate produced by the local
  /// `RTCPeerConnection.onIceCandidate` callback.
  void sendIceCandidate({
    required String candidate,
    required int sdpMLineIndex,
    required String sdpMid,
  }) {
    _manager.sendMessage('WEBRTC_ICE_CANDIDATE', {
      'candidate': candidate,
      'sdpMLineIndex': sdpMLineIndex,
      'sdpMid': sdpMid,
    });
  }

  /// Sends a `WEBRTC_RENEGOTIATE` event containing the local SDP offer.
  ///
  /// Use this when the local peer connection needs to renegotiate
  /// (e.g. after adding a screen-share track).
  void sendRenegotiate(String sdp) {
    _manager.sendMessage('WEBRTC_RENEGOTIATE', {'sdp': sdp});
  }

  /// Sends a `WEBRTC_RENEGOTIATE_ANSWER` event containing the local SDP
  /// answer in response to a [WebRTCRenegotiateEvent] from the server.
  void sendRenegotiateAnswer(String sdp) {
    _manager.sendMessage('WEBRTC_RENEGOTIATE_ANSWER', {'sdp': sdp});
  }

  // Incoming call helpers
  //
  // The TypeScript `activeCall` / `callVoiceStates` stores are app-level
  // concerns; the library just exposes the raw events and the send helpers
  // so Flutter / CLI consumers can build their own state on top.

  /// Sends a `call_accept` event for [conversationId].
  void acceptCall(String conversationId) {
    _manager.sendMessage('call_accept', {
      'conversation_id': conversationId,
    });
  }

  /// Sends a `call_decline` event for [conversationId].
  void declineCall(String conversationId) {
    _manager.sendMessage('call_decline', {
      'conversation_id': conversationId,
    });
  }

  /// Sends a `call_end` event for [conversationId].
  void endCall(String conversationId) {
    _manager.sendMessage('call_end', {
      'conversation_id': conversationId,
    });
  }

  /// Cancels all gateway subscriptions and closes the internal broadcast
  /// streams.  After calling this the controller must not be reused.
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _voiceStates.clear();
    _activeRoomId = null;
    _voiceStateCtrl.close();
    _voiceJoinedCtrl.close();
    _iceCandidateCtrl.close();
    _renegotiateCtrl.close();
    _renegotiateAnswerCtrl.close();
  }
}
