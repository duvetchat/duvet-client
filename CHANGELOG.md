## Unreleased

Bios and the do-not-disturb status, for the API and gateway versions that bring
them (not deployed yet). Nothing breaks: an older server leaves the new fields
out, and they read as null.

Calls that follow a user across their devices, for the gateway version that
brings them (not deployed yet): CALL_OUTGOING, CALL_ONGOING, and whether
READY's calls ring. An older gateway sends none of it, and the new fields read
as null.

Then what the desktop app has and this package lacked: the gateway events it
dropped, resuming a dropped gateway session, the gateway's close reasons, the
attempts to connect that fail, `allowed_mentions`, a bot's shards in identify,
and the desktop app's wait between attempts to reconnect. **Breaking changes:**
the events it dropped join the sealed `GatewayEventPayload`, and the package
needs Dart 3.6 (see "Breaking changes"). Resuming is off unless asked for, and
the new parameters and fields are optional.

### Breaking changes

- New events join the sealed `GatewayEventPayload`: `MessagePinUpdatedEvent`,
  `DMMessagePinUpdatedEvent`, `RecordingStartedEvent`,
  `DMRecordingStartedEvent`, `RoomReorderedEvent`, `UserActivityUpdatedEvent`,
  `TeamInviteCreatedEvent`, `VoiceVideoRefusedPayloadEvent`,
  `StorageTransferUpdatedEvent`, `CallOutgoingPayloadEvent` and
  `CallOngoingPayloadEvent` (see "Added"). A `switch` over it without a
  default case has to handle them, and they no longer come as `UnknownEvent`s:
  code that read them by `type` and `rawData` has to match their own types.
- **The package needs Dart 3.6** (it took 3.0): it reads the HTTP status of a
  refused upgrade from `WebSocketException.httpStatusCode`, which dart:io has
  since 3.6.
- **`uploadProfileImage` takes no crop:** it sent the crop as
  `<kind>_crop_x`, `_y`, `_w` and `_h` fields, which the API ignores, storing
  the image whole. It now uploads the image as given, so crop it before: drop
  the fourth argument.

### Added

- **Upload progress beyond messages:** `uploadProfileImage`, `updateSpace`,
  `createEmoji` and `createSticker` take an `onProgress` callback, as
  `sendMessage` does, called with the bytes of the request sent so far and
  their total.

- **Bios:** `updateUser(custom:)` sets the bio. The API trims it and takes
  `maxBioLength` (190) characters at most, counted as code points (`runes`),
  so an emoji is one. An empty one clears it, and left out it stays.
  `UserUpdateEvent.custom` is USER_UPDATE's bio, null when an older API leaves
  it out.
- **Status:** `setStatus(UserStatus.online | UserStatus.dnd)`
  (`PUT /api/users/@me/status`) chooses the status others see while the user
  is connected, and answers the user. Offline isn't a choice (an
  `ArgumentError`), and bots get a 403. The status the user chose is
  `UserMeResult.status`, and READY's `GatewayUser.status`. Both are null for a
  bot. USER_STATUS_UPDATE and SPACE_CREATE's `member_statuses` already parsed
  2 as `UserStatus.dnd`.
- **Friends' statuses:** `Friend.statusId`, the status the friends list gives
  each friend (`status_id`), whether or not a space is shared with them, so an
  app can show it before USER_STATUS_UPDATE brings a change. Null from an API
  before it.
- **Calls across devices** (duvetchat/gateway#25):
  - CALL_OUTGOING (`CallOutgoingPayloadEvent`, a `CallOutgoingEvent`): a call
    the user started, on each of their sessions, which rings none of them;
  - CALL_ONGOING (`CallOngoingPayloadEvent`, a `CallOngoingEvent`): a call
    that goes on without ringing the user, because its ring window ended
    before they answered or they were added during it, with who is in its
    voice (`voiceStates`, null while nobody is). They can join it with
    `acceptCall`;
  - READY's `GatewayReadyActiveCall` gains `ringing`, `answered`,
    `initiatorName` and `initiatorAvatar`, null from an older gateway;
  - `onCallOutgoing` and `onCallOngoing`, on `GatewayEvents` and
    `WebRTCController`, whose `voiceStates` takes CALL_ONGOING's
    (`VoiceStates.ongoing`);
  - the docs of `initiateCall`, `acceptCall`, `declineCall` and `cancelCall`
    say what the gateway does now: a CALL_INITIATE into a call going on joins
    it, a decline reaches every session of whoever declined, and a cancel from
    someone whose CALL_INITIATE answered the call ends it only while nobody
    else has accepted it. The caller's own cancel, once they came back to the
    call by calling it, only takes their voice out.
- **Gateway events it dropped** (they came as `UnknownEvent`s):
  - MESSAGE_PIN_UPDATE (`MessagePinUpdatedEvent`, a `MessagePinUpdateEvent`:
    the message, its room, and `pinnedAt`, null once unpinned) and
    DM_MESSAGE_PIN_UPDATE (`DMMessagePinUpdatedEvent`);
  - RECORDING and DM_RECORDING (`RecordingStartedEvent` and
    `DMRecordingStartedEvent`, with TYPING's and DM_TYPING's data);
  - ROOM_REORDER (`RoomReorderedEvent`: every room of the space, with its
    position and parent);
  - USER_ACTIVITY_UPDATE (`UserActivityUpdatedEvent`: a user's activities,
    none once cleared);
  - TEAM_INVITE_CREATE (`TeamInviteCreatedEvent`, a `TeamInvite`).

  `GatewayEvents` has `onMessagePinUpdate`, `onDMPinUpdate`, `onRecording`,
  `onDMRecording`, `onRoomReorder`, `onUserActivityUpdate` and
  `onTeamInviteCreate`. They're no longer `UnknownEvent`s: see "Breaking
  changes".
- **Activities:** `Activity` (`type`, `ActivityType.playing` or `listening`;
  `name`, `details`, `state`, `timestamps` in Unix milliseconds, `assets`),
  and SPACE_CREATE's `activities` (`GatewaySpaceCreatePayload.activities`):
  what the members connected then are doing, by user ID, which
  USER_ACTIVITY_UPDATE keeps current.
- **Resuming the gateway session,** as the desktop app does:
  `GatewayManager(resume: true)` (`GatewayClient` takes it too). A socket that
  replaces one that dropped identifies with READY's `sessionToken`, as
  `session_token`, and the last sequence number. The gateway keeps a dropped
  session for 30 seconds from when it notices the drop, with its last 500
  events:
  - when it resumes it, it replays the events after that number, then sends
    the new ones, and no READY: `onResume` (on the manager and the client)
    gives a `GatewayResume`, with its `shardId`, after the replay. The gateway
    gives no word of it, so the client sends a heartbeat with the identify:
    its ack comes after the replay, or after READY when the gateway starts a
    new session instead. (Not when the gateway's identify fails after it took
    the socket, a Redis error: it then answers the heartbeat alone, which
    reads as a resume. The gateway is to close such a socket.)
  - when it can't, READY comes, as without `resume`.

  The last sequence number comes only from events that carry one, as the
  desktop app takes it. `wantFreshSession()` makes the next identify start a
  new session, until a READY comes: the desktop app asks for one when voice
  has to join while no socket is open, since it joins on READY. A socket that
  closes before the gateway said whether it resumed is followed by a new
  session when something on it moved the sequence number, as it may have been
  a new session's, and by the same resume when nothing did. Off by default:
  without it each socket gets a READY, which apps may wait for (the mobile
  app's online state and voice do).
- **The gateway's close reasons:** `onCloseReason`, on the manager and the
  client, gets a `GatewayCloseReason` (`code`, `reason`, and the `shardId` of
  its socket) for each `close-with-reason`, before the socket closes and
  another one opens. `GatewayCloseCode` names the codes: `invalidShard`
  (4000), `notIdentified` (4003, also for a message the gateway can't read
  before identify), `invalidCredentials` (4004), `alreadyIdentified` (4005),
  and `superseded` (4006: a newer socket of the client took its session
  over, so nothing needs doing). After 4000 no other socket opens, as the same
  shard options would be refused again: the client stays
  `GatewayConnectionState.disconnected` until the app calls `connect()`. On
  4004 the desktop app asks the API about the session at once: a dead one
  gets a 401, which signs out; a live one renews the token, which the next
  socket uses.
- **`allowed_mentions`:** `sendMessage` and `sendDirectMessage` take
  `allowedMentions`. A reply mentions the author of the message it replies
  to; `AllowedMentions(repliedUser: false)` sends one that doesn't. In a
  multipart form it goes as a JSON string, as `message_reference` does.
  `ReferencedMessage.mentionAuthor` says whether a reply mentions them (false
  from an API before it).
- `ConversationUser`, the user of conversation members and DMs, has
  `custom` (the bio), `flags`, `emailVerified`, `createdAt`, `updatedAt` and
  `deletedAt`: the API sends the whole public user there.
- `SpaceMemberEvent.userId`, which SPACE_MEMBER_ADD and SPACE_MEMBER_REMOVE
  carry, and SPACE_MEMBER_ADD's `statusId` and `user`.
- `GatewayUserStatusUpdate.spaceId`: the space of a bot's status in a space;
  null for a person's status, and for a bot's overall one.
- `MessageFlag.ephemeral` (`1 << 6`): a bot's response only the person who
  used the interaction sees. `flags` and `interactionMetadata` were parsed
  already, on the gateway's messages and the API's.
- VOICE_VIDEO_REFUSED (`VoiceVideoRefusedPayloadEvent`, a
  `VoiceVideoRefusedEvent`: the room, the `kind` of video, camera or screen,
  the `reason`, and with "limit" the room's `limit`): the gateway refused or
  stopped the user's camera or screen, and only their session in voice hears
  it. `GatewayEvents.onVoiceVideoRefused`, and
  `WebRTCController.onVoiceVideoRefused`.
- STORAGE_TRANSFER_UPDATE (`StorageTransferUpdatedEvent`, a `StorageTransfer`
  with its `StorageTransferStatus`): a storage transfer the user started, as
  it is now, and `GatewayEvents.onStorageTransferUpdate`.
- READY's `guild_ids` (`GatewayReadyData.guildIds`): the spaces whose
  SPACE_CREATE follows, which the desktop app counts to know when all came.
- CONVERSATION_UPDATE's `owner_id` (`ConversationUpdateEvent.ownerId`), which
  changes when a group's owner leaves; FRIEND_REQUEST_ACCEPT's `status_id`
  (`FriendRequestAcceptEvent.statusId`), the new friend's status; and
  USER_UPDATE's `flags` and `badges` (`UserUpdateEvent.flags` and `badges`).
  Each is null from an API that leaves it out.
- **Failed attempts to connect:** `onConnectFailure`, on the manager and the
  client, gets a `GatewayConnectFailure` for each attempt to open a socket
  that failed: its `shardId`; `failures`, how many failed in a row since a
  socket last opened; `httpStatus`, the gateway's answer when it refused the
  upgrade; and the `error`, the token masked, which keeps the status. A token
  that stopped working is refused at the upgrade (401), not closed (4004), so
  the app couldn't tell: it can ask the API about the session then. The
  desktop app, which can't see the status, asks on the first failure and
  every 5th after it (failures 1, 6, 11…). While the gateway can't check
  tokens it answers 503 with `Retry-After: 5`, which the desktop app can't
  read: it waits as after any failure, and so does this package.
- **`retryNow()`**, on the client and the manager, ends the wait before the
  next attempt to open a socket, so that it goes now: when the app comes back
  to the foreground, say, rather than waiting up to 30 seconds. It answers
  whether there was a wait.

### Fixed

- A `close-with-reason` frame was read as an event without data: it set the
  sequence number to 0, and counted as hearing from the gateway, so after a
  sleep a refused identify hid how long the sleep lasted from
  `silenceBeforeReady`. It does neither now, as in the desktop app.
- **A bot's shards sent no shard in identify**, though `GatewayClient`'s doc
  said they did: each one got every space. With more than one shard, each
  sends its `shard_id` and `num_shards` now. With one, as by default, neither
  goes, as before: the gateway gives a bot shard 0 of 1, and closes a
  person's socket that sends them (4000).
- **The wait before another socket is the desktop app's:** a second after a
  drop, doubling with each attempt that fails, up to 30 seconds, plus up to a
  second at random (`reconnectDelay` in `gateway/client.dart`). It was half a
  second, doubling up to 2.5 seconds, so a client that couldn't connect tried
  every 2.5 seconds for good, plus a "jitter" that was the same every time
  for a token. And from the 56th wait in a row 500 × 2^55 overflowed: the
  wait went negative, or later to 0, so the client tried again at once, or
  after that jitter, under half a second.
- **A socket the app opened with `connect()` while the client waited to
  reconnect was closed** by the attempt that came after the wait, which
  opened another. The client keeps it now, and makes no attempt.

### Tests

- CALL_OUTGOING, CALL_ONGOING (its voice states, and none), READY's new call
  fields and a READY without them, CALL_ONGOING replacing what `VoiceStates`
  knew of its call, and `WebRTCController` passing both events on. The
  fixtures `call_outgoing_event` and `call_ongoing_event` are new, and
  `ready_event` gains the call fields. They come from gateway#25's branch,
  `calls-across-devices`; every other fixture it makes is unchanged.
- What `updateUser` and `setStatus` send, a bot's refusal, and the new fields,
  present and left out.
- A friend's status, and none from an older API. The fixtures were made again
  from the API (`friend` from its `serializers.Friend`), which also brought
  FRIEND_REQUEST_ACCEPT's `status_id` and replies' `mention_author` into the
  message fixtures.
- The fixtures `user_update_event`, `user_me`, `ready_event` and
  `bot_ready_event` come from the unmerged branches that add these fields: the
  API's `space-delete-bio` (the bio) and `dnd-status` (the status), and the
  gateway's `dnd-status`. Every other fixture they make is unchanged.
- `test/resume_test.dart`, against a fake gateway that keeps sessions as the
  real one does: without `resume`, each socket starts a new session, and the
  identify is what it was; with it, the identify carries the session token and
  the last sequence number, the missed events come, then `onResume`, without
  READY, and the next drop resumes again; a session the gateway can't resume
  gets READY and no `onResume`; `wantFreshSession`; a socket gone before the
  gateway said whether it resumed is followed by the same resume when nothing
  came on it, and by a new session when an event did; an event without a
  sequence number leaves where a resume starts; a `close-with-reason` reaches
  `onCloseReason` and leaves the sequence number alone; a 4000 stops the
  client until `connect()`, and the close reason says which shard; the
  silence before READY counts from before a `close-with-reason`.
- `test/models_test.dart`: each new event from its fixtures, as an event of
  its own and no `UnknownEvent`; activities, cleared and bare;
  SPACE_CREATE's activities; SPACE_MEMBER_ADD's status and user; a bot's
  status's space; the conversation users' new fields; a reply's
  `mention_author`; the ephemeral and loading flags, and flags and interaction
  metadata on the gateway's and the API's messages; close reasons.
- `test/requests_test.dart`: `allowed_mentions` as JSON and in a form, for
  rooms and conversations.
- READY's spaces, CONVERSATION_UPDATE's owner, FRIEND_REQUEST_ACCEPT's
  status, USER_UPDATE's flags and badges, each also left out;
  VOICE_VIDEO_REFUSED with and without its limit, also through
  `WebRTCController`; STORAGE_TRANSFER_UPDATE, full and not started.
- `test/gateway_test.dart`: a bot's two shards identify with theirs, and a
  person's identify carries no shard; the waits before each attempt, as the
  schedule gives them (a second up to 30, also far past where a power of two
  overflows, and at random), and as two refused attempts in a row take them,
  1 then 2 seconds and more.
- `test/gateway_test.dart`: each failed attempt reaches `onConnectFailure`,
  with the gateway's 401 and 503 and their count, which starts over once a
  socket opened; after the 503 the usual wait, not its `Retry-After`; a
  timeout, with no status; and `connect()`'s error keeps the status. A
  shard's failure says which shard; a socket the app opens during the wait is
  kept; `retryNow()` makes the next attempt go at once.
- The fixtures `message_pin_update_event`, `dm_message_pin_update_event`,
  `room_reorder_event` and `team_invite_create_event` (the API's events) and
  `user_activity_update_event` (the gateway's), made by
  `tool/fixtures/generate.sh` from the API's `dev` (c8a65b7) and the gateway's
  (793f502); every other fixture came out unchanged. RECORDING and
  DM_RECORDING use `typing_event` and `dm_typing_event`: the API's `Recording`
  is `Typing`. Then `storage_transfer_update_event` (the API's) and
  `voice_video_refused_event` (the gateway's), the same way.

## 1.0.1 – 2026-10-23

What the Duvet mobile app needs, a gateway connection that recovers from
network changes, and voice and call signalling as the gateway speaks it.
**Breaking changes**: `createSpace` answers the new space, and the voice and
call API changed (it never matched the gateway, so nothing could have used it).

### Breaking changes

- **`createSpace` answers a `CreatedSpace`** (was `Future<void>`): the space
  and the text and voice rooms the API makes with it, so an app can show it
  before the gateway's SPACE_CREATE; its `id` is the space's. Code that typed
  the result `Future<void>` has to change.
- `MentionCreateEvent`'s constructor takes `messageId` and `authorId`
  (required: the server always sends them).
- A new event, `DMMentionCreatedEvent`, joins the sealed
  `GatewayEventPayload`: a `switch` over it without a default case has to
  handle it.
- **Voice and calls, as the gateway speaks them** (`WebRTCController` sent
  `join_voice`, `leave_voice`, `call_accept` and other names the gateway
  ignores, and read its events' data wrongly):
  - `WebRTCController`'s sends are now `joinVoice`, `leaveVoice`,
    `syncVoice` (the whole state, every field required: the gateway turns off
    what a VOICE_SYNC leaves out), `sendIceCandidate`, `sendAnswer`,
    `sendRenegotiateOffer`, `initiateCall`, `acceptCall`, `declineCall`,
    `cancelCall` and `leaveCall`; each answers whether the message went out.
    `joinVoiceRoom`, `leaveVoiceRoom`, `updateVoiceState`, `sendRenegotiate`,
    `sendRenegotiateAnswer` and `activeRoomId` are gone.
  - `WebRTCEvent` is gone. WEBRTC_ICE_CANDIDATE's data is an
    `IceCandidateEvent` (its `candidate` an `IceCandidateInit`, parsed from the
    JSON string the gateway sends), WEBRTC_RENEGOTIATE's a
    `RenegotiateOfferEvent` (its `offer`), WEBRTC_RENEGOTIATE_ANSWER's a
    `RenegotiateAnswerEvent` (its `answer`).
  - `VoiceStateEvent`'s and `GatewayVoiceState`'s `muted`, `deafened` and
    `screenSharing` are `bool` (were `bool?`: the gateway always sends them).
  - `WebRTCController.participantsIn` no longer throws for an empty room.

### Fixed

- **Gateway: stuck after a network change.** The client waited for
  web_socket_client's `Connected`, which it never sends after a retry of its
  own (it sends `Reconnected`), with no timeout: the shard went silent, without
  heartbeats or retries. And a dropped socket could stay open next to the new
  one, as web_socket_client kept reconnecting it. The gateway now connects
  through dart:io's `WebSocket`:
  - one socket at a time, closed before the next one opens;
  - each attempt has `connectTimeout` (15 s) to open;
  - a socket that drops or fails is followed by another, with the same
    backoff, until `destroy()`; `reconnect()` completes once one is open;
  - `connectAll()` completes once every shard has a socket open, trying again
    while one can't (it could wait forever before), and throws a `StateError`
    if the manager is destroyed first.
- **Gateway: no socket after `destroy()`**, also when it comes during the wait
  between attempts or while a socket opens. `destroy()` closes every stream
  (`errors` stayed open), and `waitForConnection()` answers false once
  destroyed.
- **The token is no longer logged.** The gateway's URL carries it in its query:
  the log names the host and path only, and a failed handshake's error, which
  holds the URL, has the token masked (`***`) before it's logged or thrown.
  The example doesn't print it either.
- **REST requests time out.** One that makes no progress for `requestTimeout`
  (20 s) fails with a `TimeoutException` and its connection is closed; the
  session refresh too. Connecting, each piece of the body sent and of the
  answer received count as progress, so an upload that keeps moving goes
  through however long it takes.
- A file sent from a Windows path written with `/` (`C:\tmp/cat.png`) was
  named with its folders.
- MENTION_CREATE's `message_id` and `author_id` were dropped, and
  DM_MENTION_CREATE was an `UnknownEvent`.

### Added

- Voice and calls:
  - `VoiceStates`: who's in voice in every room and call, from READY's calls,
    each SPACE_CREATE's voice rooms and every VOICE_STATE_UPDATE, kept in
    version order (an update older than one applied is dropped, as the
    desktop app drops it). `WebRTCController.voiceStates` keeps one, and
    `onVoiceStateUpdate` passes on only the updates it applied.
  - `camera` and `version` on `VoiceStateEvent`, `GatewayVoiceState` and
    `CallVoiceState`.
  - READY's `ice_servers` as `GatewayReadyData.iceServers` (`IceServer`:
    `urls`, `username`, `credential`, and `toJson()` as a peer connection's
    configuration takes it): the STUN server, and the TURN relay with the
    user's own credentials.
  - VOICE_SESSION_REPLACED (`VoiceSessionReplacedPayloadEvent`, a
    `VoiceSessionReplacedEvent` with `roomId` and `reason`), and
    `GatewayEvents.onVoiceSessionReplaced`: another device took the voice, or
    the user lost access to the room.
  - `SessionDescription.toJson()` and `IceCandidateInit`.
  - `GatewayClient.connection` and `GatewayManager.connection`: the number of
    the open socket (each one gets a READY: the client doesn't resume), or
    null while none is open. `silenceBeforeReady`: how long the gateway was
    silent (no event, no heartbeat ack) before the last READY, taken as READY
    comes.
  - `GatewayClient.sendMessage` and `GatewayManager.sendMessage` answer
    whether the message went out (they answered nothing).
- `GatewayConnectionState` (`connecting`, `connected`, `reconnecting`,
  `disconnected`): `GatewayManager.onConnectionState`, and
  `GatewayClient.onConnectionState` and `connectionState`. READY comes again
  after `reconnecting`: the client doesn't resume sessions.
- `GatewaySpaceCreatePayload.memberStatuses`: SPACE_CREATE's
  `member_statuses`, the status of each member who isn't offline, by user ID.
- `DMMentionCreatedEvent` (DM_MENTION_CREATE, a `DMMentionCreateEvent` with
  `messageId`, `conversationId` and `authorId`) and
  `GatewayEvents.onDMMentionCreate`. `MentionCreateEvent` has `messageId` and
  `authorId`.
- `deleteSpace(spaceId)`: `DELETE /api/spaces/{id}`, its owner's (403 for
  anyone else, 404 once it's gone). An API without the route answers a
  plain-text 404.
- `getConversationMessageThread`: a conversation message's reply thread, as
  `getMessageThread` gives a room's.
- `count` on `getMessages` and `getDirectMessages` (1 to 100, 100 by default),
  e.g. to fetch a room's newest message alone.
- `format` on `sendVoiceNote` and `sendDMVoiceNote`: `webm` (the default, as
  the desktop app records), `ogg` (Ogg/Opus) or `m4a` (AAC in MP4, what Android
  records before version 10); anything else is an `ArgumentError`. Any `.m4a`
  file goes as `audio/mp4`.
- Upload progress and cancel: `onProgress(sent, total)` and `abortTrigger` on
  `sendMessage` and `sendDirectMessage`. Completing the trigger aborts the
  request, which fails with `package:http`'s `RequestAbortedException`.
- `useComponent`, `useCommand` and `submitModal` answer an `InteractionReply`:
  the type of the bot's first response and, when the bot opened a modal
  (`isModal`), the modal and its application. `submitModal` sends a modal's
  answers (interaction type 5). `sendComponentInteraction` and
  `sendCommandInteraction` still answer the type alone.
  `InteractionCallbackType` names the types.
- `RestClient(requestTimeout:)` (`defaultRequestTimeout`),
  `request(timeout:, onProgress:, abortTrigger:)`, and `connectTimeout` on
  `GatewayManager` and `GatewayClient` (`defaultConnectTimeout`).
- `ApiRouter(secure: false)` reaches the API and the gateway over http and ws,
  e.g. a local server.
- Dependencies: `http` ^1.5.0, for aborting requests. `web_socket_client` is
  gone.

### Tests

- `test/voice_test.dart`: `VoiceStates` in version order (late updates, a
  leave then a late join, READY's calls, SPACE_CREATE that doesn't bring back
  older states), and, against a fake gateway on 127.0.0.1, every voice and
  call message as `payload.go` reads it, the voice states and fresh updates,
  `silenceBeforeReady` (bound to READY, whatever comes after it), and a new
  socket's number. `test/models_test.dart`:
  READY's ICE servers, the voice events' new fields, the ICE candidate as a
  JSON string, VOICE_SESSION_REPLACED with and without a reason.
- `voice_session_replaced_event` fixtures, from the gateway
  (`tool/fixtures/gateway_fixtures_test.go.tmpl`); the other gateway fixtures
  are unchanged against the gateway's `dev` (19e7e1d).
- `test/gateway_test.dart`, against a fake gateway on 127.0.0.1: identifying
  with the token and hearing READY; a dropped socket replaced by one new
  socket; the first connection trying again past refusals; an attempt that
  hangs dropped after `connectTimeout`; no socket after `destroy()`; the token
  kept out of the logs and of a failed handshake's error.
- `test/timeouts_test.dart`, against servers on 127.0.0.1: a request and a
  session refresh with no answer time out, and the request's connection is
  closed; a cancelled upload stops mid-way; an upload to a slow server reports
  its progress and finishes; the timeout counts from the last progress.
- `test/requests_test.dart` and `test/models_test.dart`: what's above, and that
  a conversation's thread parses.
- The fixtures come from the current api and gateway, with
  `create_space_result` and `dm_mention_create_event` added. The generator now
  leaves a struct type inside itself empty (a component's components): filling
  every level again had grown the message fixtures to some 49,000 lines each.
  They're under 300 lines now; only those nested fields are left out.

## 1.0.0 – 2026-10-22

The REST client now follows the API as the desktop app
(`desktop-electrobun/src/mainview/src/lib/api/`) uses it, and its models
follow what the server really sends. **This release breaks the 0.x API**: see
"Breaking changes".

### Breaking changes

- **Default instance:** `ApiRouter` defaults to `api.duvet.chat` (REST),
  `ws.duvet.chat` (gateway) and `duvet.chat`. The `andremor.eu.org` hosts are
  no longer Duvet instances.
- **Argument order — still compiles, so check your calls:**
  `assignRoleToMember` and `removeRoleFromMember` now take
  `(spaceId, roleId, memberId)` (was `(spaceId, memberId, roleId)`).
  `updateMessage` and `deleteMessage` take `(messageId, …, roomId)`, as the
  desktop app does.
- **Renamed methods** (the desktop app's names):

  | 0.x | 1.0.0 |
  |---|---|
  | `sendMessageWithFiles(roomId, files, content:)` | `sendMessage(roomId, content, files:)` |
  | `editMessage` | `updateMessage` |
  | `getMessagesThread` | `getMessageThread` |
  | `sendRoomTypingIndicator` | `sendTypingIndicator` |
  | `getUnreadCount` | `getMentionCounts` |
  | `removeReaction` | `removeRoomReaction` |
  | `updateRoomOverwrite` | `upsertRoomOverwrite` |
  | `unassignRoleFromMember` | `removeRoleFromMember` |
  | `getPendingFriendRequests` | `getPendingRequests` |
  | `updateMe` | `updateUser` |
  | `signUp` | `signIn` (registers an account, as the API's `/auth/signin`) |

- **Changed signatures:** `createRoom(spaceId, name, type, {parentId})`;
  `createRole(spaceId, name, {…})`; `createEmoji`/`createSticker(spaceId,
  name, file)`; `createRoomInvite(spaceId, roomId, maxAge)`; `getMessages`
  answers `List<GatewayMessage>` (was `List<Message>`); `createSpace` answers
  nothing.
- **Removed** `getSpace`, `deleteSpace`, `getRoom` and `getRooms`: the API has
  no such routes.
- **`RestClient`:** `sessionCookie` is gone. The session token comes from the
  login response's `session_token` (`sessionToken`), and `authHeaders` no
  longer includes `Content-Type`.
- **Models now match the server's JSON:**
  - `UserMeResult` has no `email` or `password` (the API sends neither).
    `birthdate` is a `DateTime?`. Added `flags`, `badges` and `isBot`.
  - `ReferencedMessage` has no `id`.
  - `GatewayMessage.authorId` is nullable: webhook messages have none.
  - `GatewayRoom.spaceId` and `Attachment.messageId` are nullable.
  - `Conversation` has `type`, `ownerId`, `deletedAt` and `members`
    (`ConversationMember`) in place of `memberIds`. `DirectMessage.user` is a
    `ConversationUser`, and its `conversationId` is nullable.
  - `FriendRequest` has `recipientId` (was `receiverId`), plus `updatedAt` and
    the other user's details. `Friend` has `requestId`, `senderId`,
    `recipientId` and the user's details.
  - The gateway's FRIEND_REQUEST_CREATE and FRIEND_REQUEST_ACCEPT carry
    `FriendRequestCreateEvent` and `FriendRequestAcceptEvent`.
  - READY's `activeCalls` hold `CallVoiceState`s: a call's voice states have
    no room.
  - `VoiceJoinedEvent` has `roomId` and `answer` (a `SessionDescription`),
    not `userId` and `sdp`.
  - `FriendRequestRejectEvent.id` (was `requestId`; the gateway sends `id`).
  - `MemberRoleEvent.spaceId` is nullable: MEMBER_ROLE_REMOVE doesn't carry
    it.
  - `CallIncomingEvent` has no `memberIds` (the gateway sends none).

### Fixed

- Paths: accepting and rejecting friend requests, and mention counts
  (`/users/@me/…`).
- Multipart requests (files) were sent with a JSON `Content-Type`, so every
  upload failed. File parts now declare their media type, which the API keeps.
- Emojis and stickers send their file as `file` (was `files`). Messages with
  files send their reply as `message_reference` (was `reference`).
- Emoji names in reaction URLs were encoded twice.
- Updating a room, role or the user sent `null` for every field not given,
  which could clear them. Now only the fields given are sent; `clear…` flags
  send an explicit `null`.
- Responses the models couldn't parse:
  - `/users/@me`: the models required `email` and `password`.
  - Referenced messages: required an `id`.
  - Webhook messages: no `author_id`.
  - A member added to a conversation: may come without `user`.
  - Gateway: READY (while in a call), VOICE_JOINED, MEMBER_ROLE_REMOVE,
    FRIEND_REQUEST_REJECT and CALL_INCOMING all failed to parse, so the
    client dropped them.
- `Embed` can now be sent (it had no `toJson`).
- API errors no longer include the auth headers.

### Added

- Conversations and DMs: messages, pins, search, voice notes, typing and
  recording indicators, reactions.
- Room messages: pins, search, `getMessagesAfter`, voice notes, recording
  indicator.
- Read acks (`ackRoom`, `ackConversation`), sent at most once per room or
  conversation every 3 s with the newest message, as the desktop app does.
- Invites, webhooks, interactions, and space commands (cached for 5 minutes).
- Space members (paged), space updates (with icon and banner), attachments,
  storage and buckets.
- The user's storage, attachments and buckets. Profile images with a crop.
- Teams, team invites, applications and bots.
- The email/password endpoints (verify, reset, change email) and `logout`.
- `RestClient(client, token:, sessionToken:)` resumes a saved session.
  `refreshSession()` renews it, waiting out a 429. A request that gets a 401
  renews the session once and is sent again; concurrent requests share one
  refresh. A rejected refresh forgets the tokens.
- `RestMethods.request(…)` for routes the client doesn't wrap.
- Models: `SpaceMemberWithUser`, `MessageSearch`, `MessageSearchResponse`,
  `StorageStatus`, `StorageBucket`, `BucketPayload`, `Team`, `TeamMember`,
  `TeamInvite`, `Application`, `BotUser`, `InviteInfo`, `InviteLink`,
  `Webhook`, `SpaceCommands`, `ApplicationCommand`, `CommandOption`,
  `ComponentUse`, `CommandUse`, `InteractionMetadata`, `MessageFlag`,
  `EmbedType`, `MessageType.pinNotice`.
- `GatewayMessage`: `webhookId`, `pinnedAt`, `flags`, `components`,
  `interactionMetadata`. `GatewayUser`: `flags`, `badges`, `isBot`.
  `GatewaySpace.icon`. `Attachment`: `url`, `deletedAt`. `Embed.provider`.
- Dependencies: `http_parser`. Dev dependencies: `test`.

### Tests

- `test/requests_test.dart`: what each method sends (method, path, query,
  body, form fields), and the session renewal, against a mock server.
- `test/models_test.dart`: every model parses the server's JSON, and every
  gateway event the client handles parses through `GatewayEnvelope` (a test
  fails when an event has no fixture). CONVERSATION_DELETE,
  GUILD_MEMBER_ADD and GUILD_MEMBER_REMOVE are still handled, but neither the
  API nor the gateway sends them.
- `test/fixtures/` holds the server's own response and event types (the Go
  structs that the handlers pass to `c.JSON` and that the API and the gateway
  publish), marshalled with `encoding/json` in three variants:
  - **full:** every field set;
  - **nulls:** every nullable field null and every list empty;
  - **partial:** nested objects present but their nullable fields null.

  `tool/fixtures/generate.sh` makes them again from the `api` and `gateway`
  checkouts.
- `test/live_test.dart`: read-only checks against the live instance.
  - Run `DUVET_LIVE=1 dart test -t live`.
  - With `DUVET_EMAIL` and `DUVET_PASSWORD` set, it also parses the account's
    data, READY and the SPACE_CREATE events.
  - It prints which responses it parsed.
- The command-line example moved from `test/` to `example/`.

## 0.1.1
- Fix: issue with authentication
- Tidy up the code
- Add a more reliable test module
- Tested on my own instance

## 0.1.0

- **Migrate to null safety** (requires Dart SDK >=3.0.0).
- Complete rewrite of the client API:
  - Gateway client with WebRTC support (`lib/gateway/`).
  - HTTP methods and REST helpers (`lib/http/`).
  - Data models for gateway envelopes and types (`lib/models/`).
  - Robust error handling (`lib/errors.dart`)
- Update dependencies:
  - `http: ^1.2.0`
  - `web_socket_client: ^0.1.0`
- Add development dependency on `lints: ^3.0.0`.
- Improve error handling with dedicated error classes.
- Add utility extensions and helper functions.

## 0.0.2 – unpublished (pre‑null safety)

- Initial proof‑of‑concept version.
- Not null‑safe; requires Dart SDK <3.0.0.
