## 1.0.1 – 2026-10-23

What the Duvet mobile app needs, and a gateway connection that recovers from
network changes. **One breaking change**: `createSpace` answers the new space.

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
