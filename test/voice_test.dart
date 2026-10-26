// Voice and call signalling: the voice states kept in version order, and the
// messages WebRTCController sends, as the gateway reads them
// (internal/adapters/connection/payload.go), against a fake gateway on
// 127.0.0.1.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duvet_client/duvet.dart';
import 'package:duvet_client/http/router.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

VoiceStateEvent _state(String room, String user, int version,
        {bool joined = true, bool muted = false}) =>
    VoiceStateEvent(
        roomId: room,
        userId: user,
        joined: joined,
        muted: muted,
        version: version);

/// A SPACE_CREATE as the gateway sends it (through JSON, as the client gets
/// it) with voice [rooms] and their [voiceStates].
GatewaySpaceCreatePayload _space(
        List<String> rooms, List<GatewayVoiceState> voiceStates) =>
    GatewaySpaceCreatePayload.fromJson(jsonDecode(jsonEncode({
      'space': {
        'id': 's1',
        'name': 'Guild',
        'owner_id': 'u1',
        'created_at': '2026-10-23T09:00:00Z',
        'updated_at': '2026-10-23T09:00:00Z',
      },
      'rooms': {
        for (final id in rooms)
          id: {
            'id': id,
            'space_id': 's1',
            'name': id,
            'type': 2,
            'position': 0,
            'created_at': '2026-10-23T09:00:00Z',
            'updated_at': '2026-10-23T09:00:00Z',
          },
      },
      'roles_permissions': {},
      'owner_id': 'u1',
      'voice_states': [
        for (final s in voiceStates)
          {
            'room_id': s.roomId,
            'user_id': s.userId,
            'muted': s.muted,
            'deafened': s.deafened,
            'screen_sharing': s.screenSharing,
            'camera': s.camera,
            'version': s.version,
          },
      ],
    })) as Map<String, dynamic>);

/// A gateway on 127.0.0.1 that answers identify with READY and keeps every
/// other message, and can push events.
class _FakeGateway {
  _FakeGateway._(this._server) {
    _server.listen(_handle);
  }

  static Future<_FakeGateway> start() async =>
      _FakeGateway._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final open = <WebSocket>[];
  final messages = <Map<String, dynamic>>[];
  final _received = StreamController<void>.broadcast();
  int _seq = 0;

  ApiRouter get router => ApiRouter(
      api: '127.0.0.1:${_server.port}',
      ws: '127.0.0.1:${_server.port}',
      secure: false);

  /// Completes once [count] messages other than identify and heartbeat came.
  Future<void> received(int count) async {
    while (messages.length < count) {
      await _received.stream.first.timeout(const Duration(seconds: 10));
    }
  }

  void push(String type, Map<String, dynamic> data) {
    for (final socket in open) {
      socket.add(jsonEncode({
        'event': 'payload',
        'op': 1,
        's': ++_seq,
        'd': {'type': type, 'data': data},
      }));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    open.add(socket);
    socket.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (message['type']) {
        case 'identify':
          push('READY', {
            'user': {
              'id': 'u1',
              'username': 'gaby',
              'created_at': '2026-10-23T09:00:00Z',
              'updated_at': '2026-10-23T09:00:00Z',
            },
            'sessionToken': 'session-1',
          });
        case 'heartbeat':
          socket.add(jsonEncode({'event': 'heartbeat_ack'}));
        default:
          messages.add(message);
          _received.add(null);
      }
    }, onDone: () => open.remove(socket));
  }

  Future<void> close() async {
    for (final socket in [...open]) {
      await socket.close();
    }
    await _server.close(force: true);
    await _received.close();
  }
}

void main() {
  group('VoiceStates', () {
    test('an update older than one applied is dropped; as new is kept', () {
      final states = VoiceStates();
      expect(states.apply(_state('r1', 'maya', 5)), isTrue);
      expect(states.apply(_state('r1', 'maya', 7, muted: true)), isTrue);
      // A late one, from before the mute.
      expect(states.apply(_state('r1', 'maya', 6)), isFalse);
      expect(states.participantsIn('r1').single.muted, isTrue);
      // The same state again (a call's catch-up when joining it).
      expect(states.apply(_state('r1', 'maya', 7, muted: true)), isTrue);

      expect(states.apply(_state('r1', 'maya', 9, joined: false)), isTrue);
      expect(states.participantsIn('r1'), isEmpty);
      expect(states.rooms, isEmpty);
      // A "joined" that came after the leave doesn't bring her back.
      expect(states.apply(_state('r1', 'maya', 8)), isFalse);
      expect(states.participantsIn('r1'), isEmpty);
    });

    test('READY starts over, with its calls', () {
      final states = VoiceStates()..apply(_state('r1', 'maya', 9));
      states.reset([
        GatewayReadyActiveCall.fromJson({
          'conversation_id': 'c1',
          'initiator_id': 'leo',
          'voice_states': [
            {'user_id': 'leo', 'muted': true, 'version': 3},
          ],
        }),
      ]);
      expect(states.participantsIn('r1'), isEmpty);
      final leo = states.participantsIn('c1').single;
      expect((leo.userId, leo.muted, leo.version), ('leo', true, 3));
      // The new session's versions start from what READY said.
      expect(states.apply(_state('r1', 'maya', 1)), isTrue);
      expect(states.apply(_state('c1', 'leo', 2)), isFalse);
    });

    test('SPACE_CREATE replaces its rooms, but not with older states', () {
      final states = VoiceStates()
        ..apply(_state('r1', 'gone', 1))
        ..apply(_state('r2', 'maya', 20, joined: false))
        ..apply(_state('other', 'leo', 1));
      states.space(_space([
        'r1',
        'r2'
      ], [
        const GatewayVoiceState(roomId: 'r1', userId: 'ana', version: 4),
        // Older than the leave already applied.
        const GatewayVoiceState(roomId: 'r2', userId: 'maya', version: 10),
      ]));
      expect(states.participantsIn('r1').map((p) => p.userId), ['ana']);
      expect(states.participantsIn('r2'), isEmpty);
      // Another space's room is left alone.
      expect(states.participantsIn('other').single.userId, 'leo');
    });

    test('CALL_ONGOING replaces its call, but not with older states', () {
      final states = VoiceStates()
        ..apply(_state('c1', 'gone', 1))
        ..apply(_state('c1', 'maya', 20, joined: false))
        ..apply(_state('other', 'leo', 1));
      states.ongoing(CallOngoingEvent.fromJson({
        'conversation_id': 'c1',
        'initiator_id': 'leo',
        'voice_states': [
          {'user_id': 'ana', 'version': 4},
          // Older than the leave already applied.
          {'user_id': 'maya', 'version': 10},
        ],
      }));
      expect(states.participantsIn('c1').map((p) => p.userId), ['ana']);
      // Another room is left alone.
      expect(states.participantsIn('other').single.userId, 'leo');
      // Nobody in its voice any more.
      states.ongoing(
          const CallOngoingEvent(conversationId: 'c1', initiatorId: 'leo'));
      expect(states.participantsIn('c1'), isEmpty);
    });

    test('a forgotten room is empty', () {
      final states = VoiceStates()..apply(_state('c1', 'maya', 1));
      states.forget('c1');
      expect(states.participantsIn('c1'), isEmpty);
    });
  });

  group('WebRTCController', () {
    late _FakeGateway gateway;
    late GatewayManager manager;
    late WebRTCController rtc;

    setUp(() async {
      gateway = await _FakeGateway.start();
      manager = GatewayManager(
          RestClient(http.Client(), token: 'token', router: gateway.router),
          router: gateway.router,
          log: (_, __) {});
      rtc = WebRTCController(manager);
      addTearDown(() async {
        rtc.dispose();
        manager.destroy();
        await gateway.close();
      });
    });

    test('nothing goes out before a socket is open', () {
      expect(rtc.connection, isNull);
      expect(rtc.leaveVoice('r1'), isFalse);
      expect(rtc.acceptCall('c1'), isFalse);
    });

    test('sends each message as the gateway reads it', () async {
      final ready = manager.ready;
      await manager.connectAll();
      await ready;
      expect(rtc.connection, 1);

      const offer = SessionDescription(type: 'offer', sdp: 'v=0 offer');
      const answer = SessionDescription(type: 'answer', sdp: 'v=0 answer');
      expect(rtc.joinVoice('r1', offer, videoOff: true), isTrue);
      rtc.syncVoice('r1',
          muted: true,
          deafened: false,
          screenSharing: false,
          camera: false,
          videoOff: true);
      rtc.sendIceCandidate(
          'r1',
          const IceCandidateInit(
              candidate: 'candidate:1 1 udp 1 10.0.0.2 5000 typ host',
              sdpMid: '0',
              sdpMLineIndex: 0));
      rtc.sendAnswer('r1', answer);
      rtc.sendRenegotiateOffer('r1', offer, tracks: {'1': 'camera'});
      rtc.leaveVoice('r1');
      rtc.initiateCall('c1', ['u1', 'maya']);
      rtc.acceptCall('c1');
      rtc.declineCall('c1');
      rtc.cancelCall('c1');
      rtc.leaveCall('c1');
      await gateway.received(11);

      expect(gateway.messages, [
        {
          'type': 'VOICE_JOIN',
          'data': {
            'room_id': 'r1',
            'offer': {'type': 'offer', 'sdp': 'v=0 offer'},
            'video_off': true,
          },
        },
        {
          // The whole state, every field.
          'type': 'VOICE_SYNC',
          'data': {
            'room_id': 'r1',
            'muted': true,
            'deafened': false,
            'screen_sharing': false,
            'camera': false,
            'video_off': true,
          },
        },
        {
          'type': 'WEBRTC_ICE_CANDIDATE',
          'data': {
            'room_id': 'r1',
            'candidate': {
              'candidate': 'candidate:1 1 udp 1 10.0.0.2 5000 typ host',
              'sdpMid': '0',
              'sdpMLineIndex': 0,
            },
          },
        },
        {
          'type': 'WEBRTC_ANSWER',
          'data': {
            'room_id': 'r1',
            'answer': {'type': 'answer', 'sdp': 'v=0 answer'},
          },
        },
        {
          'type': 'WEBRTC_RENEGOTIATE_OFFER',
          'data': {
            'room_id': 'r1',
            'offer': {'type': 'offer', 'sdp': 'v=0 offer'},
            'tracks': {'1': 'camera'},
          },
        },
        {
          'type': 'VOICE_LEAVE',
          'data': {'room_id': 'r1'},
        },
        {
          'type': 'CALL_INITIATE',
          'data': {
            'conversation_id': 'c1',
            'member_ids': ['u1', 'maya'],
          },
        },
        for (final type in [
          'CALL_ACCEPT',
          'CALL_DECLINE',
          'CALL_CANCEL',
          'CALL_LEAVE'
        ])
          {
            'type': type,
            'data': {'conversation_id': 'c1'},
          },
      ]);
    });

    test('keeps the voice states, and passes on only the fresh updates',
        () async {
      final updates = <VoiceStateEvent>[];
      rtc.onVoiceStateUpdate.listen((e) => updates.add(e.data));
      final ready = manager.ready;
      await manager.connectAll();
      await ready;

      Map<String, dynamic> update(int version, {bool joined = true}) => {
            'room_id': 'r1',
            'user_id': 'maya',
            'joined': joined,
            'muted': false,
            'deafened': false,
            'screen_sharing': false,
            'camera': false,
            'version': version,
          };
      gateway.push('VOICE_STATE_UPDATE', update(5));
      gateway.push('VOICE_STATE_UPDATE', update(4, joined: false));
      gateway.push('CALL_INCOMING', {
        'conversation_id': 'c1',
        'initiator_id': 'maya',
        'initiator_name': 'Maya',
        'initiator_avatar': null,
      });
      final incoming = await rtc.onCallIncoming.first;
      expect(incoming.data.initiatorName, 'Maya');
      // The late leave was dropped.
      expect(updates.map((u) => u.version), [5]);
      expect(rtc.voiceStates.participantsIn('r1').single.userId, 'maya');

      gateway.push('VOICE_STATE_UPDATE', {
        ...update(1),
        'room_id': 'c1',
      });
      gateway.push('CALL_ENDED', {'conversation_id': 'c1'});
      await rtc.onCallEnded.first;
      // The gateway sends no leave for a call that ended.
      expect(rtc.voiceStates.participantsIn('c1'), isEmpty);
    });

    test('passes on calls placed and calls going on, with who is in them',
        () async {
      final ready = manager.ready;
      await manager.connectAll();
      await ready;

      gateway.push('CALL_OUTGOING', {'conversation_id': 'c1'});
      expect((await rtc.onCallOutgoing.first).data.conversationId, 'c1');

      gateway.push('CALL_ONGOING', {
        'conversation_id': 'c2',
        'initiator_id': 'maya',
        'voice_states': [
          {'user_id': 'maya', 'muted': true, 'version': 3},
        ],
      });
      expect((await rtc.onCallOngoing.first).data.initiatorId, 'maya');
      final maya = rtc.voiceStates.participantsIn('c2').single;
      expect((maya.userId, maya.muted, maya.version), ('maya', true, 3));
    });

    test('silenceBeforeReady is the gap before READY, whatever follows it',
        () async {
      final ready = manager.ready;
      await manager.connectAll();
      await ready;
      // The first thing heard: no silence before it.
      expect(rtc.silenceBeforeReady, Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      final again = manager.onReady.first;
      final ended = rtc.onCallEnded.first;
      gateway.push('READY', {
        'user': {
          'id': 'u1',
          'username': 'gaby',
          'created_at': '2026-10-23T09:00:00Z',
          'updated_at': '2026-10-23T09:00:00Z',
        },
        'sessionToken': 'session-2',
      });
      // What the gateway sends right after READY doesn't change it.
      gateway.push('CALL_ENDED', {'conversation_id': 'c9'});
      await again;
      await ended;
      expect(rtc.silenceBeforeReady,
          greaterThanOrEqualTo(const Duration(milliseconds: 300)));
    });

    test('passes on the camera or screen the gateway refused', () async {
      final ready = manager.ready;
      await manager.connectAll();
      await ready;

      final refused = rtc.onVoiceVideoRefused.first;
      gateway.push('VOICE_VIDEO_REFUSED',
          {'room_id': 'r1', 'kind': 'camera', 'reason': 'limit', 'limit': 8});
      final e = await refused;
      expect((e.data.roomId, e.data.kind, e.data.reason, e.data.limit),
          ('r1', 'camera', 'limit', 8));
    });

    test('a new socket has a new number, and gets READY', () async {
      final ready = manager.ready;
      await manager.connectAll();
      await ready;
      expect(rtc.connection, 1);

      final again = manager.onReady.first;
      await gateway.open.single.close(); // the gateway drops it
      await again;
      expect(rtc.connection, 2);
    });
  });
}
